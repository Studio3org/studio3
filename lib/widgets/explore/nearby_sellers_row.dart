import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/nearby_seller.dart';
import '../../services/auth_session.dart';
import '../../services/nearby_service.dart';
import '../../services/social_service.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../../utils/profile_navigation.dart';
import '../../utils/require_login.dart';
import '../follow_button.dart';
import '../studio/studio_toast.dart';
import 'explore_browse.dart';

/// Nearby sellers, drawn as the Artists shelf. Hidden under about 6 people.
/// [onOccupied] reports whether the shelf or the location prompt is showing.
class NearbySellersRow extends StatefulWidget {
  const NearbySellersRow({super.key, this.onOccupied, this.topGap = exploreSectionGap});

  final ValueChanged<bool>? onOccupied;
  final double topGap;

  @override
  State<NearbySellersRow> createState() => _NearbySellersRowState();
}

class _NearbySellersRowState extends State<NearbySellersRow> {
  List<NearbySeller> _sellers = [];
  bool _loading = true;
  bool _permissionDenied = false;
  final Map<String, FollowState> _follow = {};
  final Set<String> _followBusy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _permissionDenied = true;
          _loading = false;
        });
        _publish(true);
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final sellers = await NearbyService.instance.getNearbySellers(
        lat: position.latitude,
        lng: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _sellers = sellers;
        _loading = false;
        for (final seller in sellers) {
          _follow.putIfAbsent(
            seller.username,
            () => seller.isFollowing ? FollowState.following : FollowState.none,
          );
        }
      });
      _publish(sellers.length >= exploreShelfMinCount);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _publish(false);
    }
  }

  bool _isSelf(NearbySeller seller) {
    final me = AuthSession.instance.user?.username;
    return me != null && me.isNotEmpty && me == seller.username;
  }

  Future<void> _toggleFollow(NearbySeller seller) async {
    if (_followBusy.contains(seller.username) || seller.username.isEmpty) return;
    if (!await requireLogin(
      context,
      title: 'Sign in to follow',
      message: 'Log in or create a free account to follow artists.',
    )) {
      return;
    }
    if (!mounted) return;
    final wasActive = (_follow[seller.username] ?? FollowState.none) != FollowState.none;
    setState(() => _followBusy.add(seller.username));
    try {
      if (wasActive) {
        await SocialService.instance.unfollow(seller.username);
        if (!mounted) return;
        setState(() => _follow[seller.username] = FollowState.none);
      } else {
        final result = await SocialService.instance.follow(seller.username);
        if (!mounted) return;
        setState(() {
          _follow[seller.username] = result.following
              ? FollowState.following
              : (result.requested ? FollowState.pending : FollowState.none);
        });
      }
    } catch (_) {
      if (!mounted) return;
      showStudioToast(context, 'Could not update follow', icon: null);
    } finally {
      if (mounted) setState(() => _followBusy.remove(seller.username));
    }
  }

  void _publish(bool occupied) {
    final report = widget.onOccupied;
    if (report == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => report(occupied));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    if (_permissionDenied) {
      final c = context.studio;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          StudioSpace.marginFeed,
          widget.topGap,
          StudioSpace.marginFeed,
          0,
        ),
        child: GestureDetector(
          onTap: _load,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: StudioSize.tapTarget),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Enable location to discover nearby sellers',
                style: StudioType.body14(color: c.textSecondary),
              ),
            ),
          ),
        ),
      );
    }

    if (_sellers.length < exploreShelfMinCount) return const SizedBox.shrink();

    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    final text = 13 * StudioType.normalLineHeight(13) +
        4 +
        12 * StudioType.normalLineHeight(12);
    final height = exploreArtistAvatar +
        StudioSpace.s8 +
        text * scale +
        StudioSpace.s8 +
        StudioSize.tapTarget;

    return Padding(
      padding: EdgeInsets.only(top: widget.topGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ExploreShelfHeader(title: 'Artists to know'),
          const SizedBox(height: exploreShelfInnerGap),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: StudioSpace.marginFeed),
              itemCount: _sellers.length,
              separatorBuilder: (context, index) => const SizedBox(width: StudioSpace.s12),
              itemBuilder: (context, index) {
                final seller = _sellers[index];
                final state = _follow[seller.username] ??
                    (seller.isFollowing ? FollowState.following : FollowState.none);
                final label = switch (state) {
                  FollowState.none => 'Follow',
                  FollowState.pending => 'Requested',
                  FollowState.following => 'Following',
                };
                final showFollow = !_isSelf(seller) && seller.username.isNotEmpty;
                return ExploreArtistTile(
                  name: seller.displayName,
                  photoUrl: seller.profilePhotoUrl,
                  subtitle: seller.distanceDisplay,
                  onTap: () => openUserProfile(context, seller.username),
                  followLabel: showFollow ? label : null,
                  followBusy: _followBusy.contains(seller.username),
                  onFollow: showFollow ? () => _toggleFollow(seller) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
