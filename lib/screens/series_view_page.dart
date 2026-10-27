import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/auction.dart' show auctionTimeLeft;
import '../models/feed_item.dart';
import '../models/piece_summary.dart';
import '../models/post_summary.dart';
import '../models/series_summary.dart';
import '../services/auth_session.dart';
import '../services/piece_service.dart';
import '../services/post_service.dart';
import '../services/series_service.dart';
import '../services/user_service.dart';
import '../utils/money_format.dart';
import '../utils/profile_navigation.dart';
import '../utils/reels_route.dart';
import '../utils/series_share.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/follow_button.dart';
import '../widgets/piece_detail/detail_follow_state.dart';
import '../widgets/share/share_sheet.dart';
import '../widgets/studio/studio.dart';
import 'profile/widgets/profile_masonry_grid.dart';
import 'series_editor_page.dart';

/// The series page (`SeriesPage`), from a series row on Home, a series on a profile, or the
/// Part of a series card on a piece page.
///
/// Back and Share (24 icons, 44 targets). Then Mono 11 "SERIES · 6 PIECES", the name 30/500,
/// the artist (32 photo, 14/500) with Follow, or Edit series on your own, and the artist's
/// description (15/1.55) when there is one. "All" with its Mono count and the Available chip,
/// then every piece newest first, 2 across at 3:4 (radius 10, 20 between rows, 16 between
/// columns): the title 14/500 and its status: a green dot and "Available · $3,500", the
/// iridescent Collected chip, "Bid $1,300 · 6h left", or nothing for not for sale. Collected
/// pieces always stay. "Behind this series": the Scenes linked to any of its pieces, 120 × 213
/// cards that open the Scene viewer.
class SeriesViewPage extends StatefulWidget {
  const SeriesViewPage({
    super.key,
    required this.seriesId,
    this.initialName,
    this.initialPieceCount,
    this.initialCoverUrl,
    this.authorName,
    this.authorUsername,
    this.isOwner = false,
  });

  final String seriesId;
  final String? initialName;
  final int? initialPieceCount;
  final String? initialCoverUrl;
  final String? authorName;
  final String? authorUsername;
  final bool isOwner;

  @override
  State<SeriesViewPage> createState() => _SeriesViewPageState();
}

class _SeriesViewPageState extends State<SeriesViewPage> with DetailFollowState<SeriesViewPage> {
  SeriesSummary? _series;
  List<PieceSummary> _pieces = const [];
  List<PostSummary> _scenes = const [];
  bool _loading = true;
  bool _availableOnly = false;

  static const _public = {null, 'live', 'reserved', 'sold', 'auction_won'};

  @override
  String get followUsername => _authorUsername ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final series = await SeriesService.instance.getById(widget.seriesId);
      final username = series.authorUsername ?? widget.authorUsername;
      var pieces = series.pieces;
      if (pieces.isEmpty && series.pieceIds.isNotEmpty && username != null) {
        final all = await PieceService.instance.getUserPieces(username);
        final ids = series.pieceIds.toSet();
        pieces = all.where((p) => ids.contains(p.id)).toList();
      }
      final mine = _isMe(username);
      pieces = [
        for (final piece in pieces)
          if (mine || _public.contains(piece.status)) piece,
      ]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      if (!mounted) return;
      setState(() {
        _series = series;
        _pieces = pieces;
        _loading = false;
      });
      if (username != null) {
        _loadScenes(username, pieces.map((p) => p.id).toSet());
        if (!mine) _loadFollow(username);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// "Behind this series": the artist's Scenes linked to any piece in it.
  Future<void> _loadScenes(String username, Set<String> pieceIds) async {
    try {
      final posts = await PostService.instance.getUserPostsCached(username);
      final linked = posts.where((post) {
        final ids = {...post.linkedPieceIds, ?post.pieceId};
        return ids.any(pieceIds.contains);
      }).toList();
      if (mounted) setState(() => _scenes = linked);
    } catch (_) {
      // The row stays hidden.
    }
  }

  Future<void> _loadFollow(String username) async {
    try {
      final profile = await UserService.instance.getPublicProfile(username);
      if (!mounted) return;
      setState(() => followState = profile.isFollowing ? FollowState.following : FollowState.none);
    } catch (_) {
      // Follow stays as Follow.
    }
  }

  bool _isMe(String? username) {
    final me = AuthSession.instance.user?.username.toLowerCase();
    return widget.isOwner || (me != null && me.isNotEmpty && me == username?.toLowerCase());
  }

  String get _name => _series?.name ?? widget.initialName ?? 'Series';

  int get _pieceCount => _series == null ? (widget.initialPieceCount ?? 0) : _pieces.length;

  String? get _authorName => _series?.authorName ?? widget.authorName;

  String? get _authorUsername => _series?.authorUsername ?? widget.authorUsername;

  bool get _isOwner => _isMe(_authorUsername);

  static bool canBuy(PieceSummary piece) => piece.isAvailableListing || piece.isAuctionLive;

  Future<void> _onEdit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => SeriesEditorPage(seriesId: widget.seriesId),
      ),
    );
    if (changed == true) await _load();
  }

  void _onShare() {
    final series = _series;
    if (series == null) return;
    ShareSheet.show(context, shareText: buildSeriesShareText(series));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final description = _series?.description?.trim();
    final shown = _availableOnly ? _pieces.where(canBuy).toList() : _pieces;
    final username = _authorUsername;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Row(
                  children: [
                    _HeaderIcon(
                      icon: StudioIcons.back,
                      label: 'Back',
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    _HeaderIcon(
                      icon: StudioIcons.share,
                      label: 'Share',
                      onTap: _series == null ? null : _onShare,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 13, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SERIES · $_pieceCount ${_pieceCount == 1 ? 'PIECE' : 'PIECES'}',
                      style: StudioType.mono(11, color: c.textTertiary).copyWith(letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _name,
                      style: StudioType.sans(30, weight: StudioType.medium, color: c.textPrimary)
                          .copyWith(letterSpacing: -0.6, height: 1.2),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: username == null ? null : () => openUserProfile(context, username),
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              children: [
                                StudioAvatar(url: _series?.authorAvatarUrl, size: 32),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    _authorName ?? (username == null ? '' : '@$username'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: StudioType.sans(14, weight: StudioType.medium, color: c.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_isOwner)
                          StudioButton(
                            label: 'Edit series',
                            variant: StudioButtonVariant.small,
                            filled: false,
                            onPressed: _onEdit,
                          )
                        else if (username != null && username.isNotEmpty)
                          StudioButton(
                            label: followState.actionLabel,
                            icon: followState.icon,
                            variant: StudioButtonVariant.small,
                            filled: followState.filled,
                            loading: followBusy,
                            onPressed: followBusy ? null : toggleFollow,
                          ),
                      ],
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(description, style: StudioType.sans(15, height: 1.55, color: c.textBody)),
                    ],
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Text('All', style: StudioType.header17(weight: StudioType.medium, color: c.textPrimary)),
                        const SizedBox(width: 5),
                        Text('${_pieces.length}', style: StudioType.mono(13, color: c.textSecondary)),
                        const Spacer(),
                        StudioChip(
                          label: 'Available',
                          selected: _availableOnly,
                          leading: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: c.available, shape: BoxShape.circle),
                          ),
                          onTap: () => setState(() => _availableOnly = !_availableOnly),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            if (_loading && _pieces.isEmpty)
              const SliverToBoxAdapter(child: ProfileGridSkeleton())
            else if (shown.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: StudioEmptyState(
                    title: _availableOnly ? 'Nothing available right now' : 'No pieces in this series yet',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 16,
                    // 3:4 picture, 6, the title, 6, the status line.
                    mainAxisExtent: _cardExtent(context),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => SeriesPieceCard(
                      piece: shown[i],
                      onTap: () => openProfilePiece(context, shown[i]),
                    ),
                    childCount: shown.length,
                  ),
                ),
              ),
            if (_scenes.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Behind this series',
                          style: StudioType.header17(weight: StudioType.medium, color: c.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 213,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _scenes.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, i) => _SceneCard(
                            post: _scenes[i],
                            onTap: () {
                              final items = [for (final post in _scenes) FeedItem.post(post)];
                              openScenes(context, items[i], from: items);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: 40 + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }

  double _cardExtent(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 40 - 16) / 2;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return width * 4 / 3 + 6 + 20 * scale + 6 + 22 * scale;
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: 44,
          child: Center(child: StudioIcon(icon, size: 22, color: context.studio.textPrimary)),
        ),
      ),
    );
  }
}

/// One piece in the series grid: the 3:4 picture, the title, and its status.
class SeriesPieceCard extends StatelessWidget {
  const SeriesPieceCard({super.key, required this.piece, required this.onTap});

  final PieceSummary piece;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final url = piece.mediaUrl ?? (piece.imageUrls.isEmpty ? null : piece.imageUrls.first);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: url == null || url.isEmpty
                    ? ColoredBox(color: c.surface)
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => ColoredBox(color: c.surface),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              piece.title.isEmpty ? 'Untitled' : piece.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StudioType.sans(14, weight: StudioType.medium, color: c.textPrimary),
            ),
            const SizedBox(height: 6),
            SeriesPieceStatus(piece: piece),
          ],
        ),
      ),
    );
  }
}

/// Available (green dot, "Available · $3,500"), the Collected chip, the current bid and time
/// left, or nothing (not for sale gets no chip).
class SeriesPieceStatus extends StatelessWidget {
  const SeriesPieceStatus({super.key, required this.piece, this.now});

  final PieceSummary piece;

  /// For tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    if (piece.isCollectedListing || piece.status == 'sold') {
      return const Align(
        alignment: Alignment.centerLeft,
        child: StudioStatusChip(StudioStatus.collected),
      );
    }
    if (piece.isAuctionLive) {
      final bid = piece.highestBidCents ?? piece.startingBidCents;
      final left = auctionTimeLeft(piece.auctionEndsAt, now ?? DateTime.now());
      final parts = [
        if (bid != null) 'Bid ${formatMoney(bid)}',
        if (left.isNotEmpty) '$left left',
      ];
      return Text(
        parts.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: StudioType.sans(13, color: c.textSecondary),
      );
    }
    if (piece.isAvailableListing) {
      final price = piece.priceCents == null ? null : formatMoney(piece.priceCents!);
      return Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c.available, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              price == null ? 'Available' : 'Available · $price',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StudioType.sans(13, color: c.textPrimary),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.post, required this.onTap});

  final PostSummary post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final url = post.thumbnailUrl ?? post.mediaUrl;
    return Semantics(
      button: true,
      label: 'Scene',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 120,
            height: 213,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url == null || url.isEmpty)
                  ColoredBox(color: c.surface)
                else
                  CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => ColoredBox(color: c.surface),
                  ),
                if (post.isVideo)
                  const Positioned(top: 8, left: 8, child: ScenePlayMark()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The white play triangle on a video Scene card (12, soft shadow), no circle.
class ScenePlayMark extends StatelessWidget {
  const ScenePlayMark({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 28,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // The board's drop shadow (0 1 3 at 45 %).
            Transform.translate(
              offset: const Offset(0, 1),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                child: const StudioIcon(StudioIcons.play, size: 12, color: Color(0x73000000)),
              ),
            ),
            const StudioIcon(StudioIcons.play, size: 12, color: StudioColors.galleryWhite),
          ],
        ),
      ),
    );
  }
}
