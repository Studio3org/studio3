import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/piece_summary.dart';
import '../models/post_summary.dart';
import '../models/user_profile.dart';
import '../services/auth_session.dart';
import '../services/main_nav_service.dart';
import '../services/piece_service.dart';
import '../services/post_service.dart';
import '../services/series_service.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import '../theme/home_feed_tokens.dart';
import 'conversation_thread_page.dart';
import 'follow_list_page.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/profile_avatar_preview_sheet.dart';
import 'profile/models/profile_series_data.dart';
import 'profile/profile_constants.dart';
import '../widgets/follow_button.dart';
import 'profile/widgets/profile_header.dart';
import 'profile/widgets/profile_hero.dart';
import 'profile/widgets/profile_locked_placeholder.dart';
import 'profile/widgets/profile_tab_content.dart';
import 'profile/widgets/profile_tabs.dart';
import 'profile/widgets/profile_viewer_mode_capsule.dart';
import 'reels_page.dart' show routeObserver;
import '../utils/scrolls_to_top_on_double_tap.dart';

/// Artist profile — own tab or pushed public profile by [username].
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.username, this.viewerMode = false});

  /// When null, loads the signed-in user's profile (bottom-nav tab).
  final String? username;

  /// When true, loads public profile data and hides owner-only actions.
  final bool viewerMode;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with RouteAware, ScrollsToTopOnDoubleTap<ProfilePage> {
  final _scrollController = ScrollController();
  String _tab = 'pieces';
  UserProfile? _profile;
  List<PieceSummary> _pieces = [];
  List<PostSummary> _scenes = [];
  List<PieceSummary> _listedPieces = [];
  List<ProfileSeriesData> _series = [];
  bool _tabContentLoading = false;
  bool? _lastKnownSeller;
  bool _piecesLoaded = false;
  bool _scenesLoaded = false;
  bool _listedPiecesLoaded = false;
  bool _seriesLoaded = false;
  String _collectSegment = 'all';
  String _sceneFilter = 'all';
  bool _followBusy = false;
  int _profileLoadAttempts = 0;

  bool get _isTabContext => widget.username == null;

  bool get _isOwnProfile {
    if (_isTabContext) return true;
    final sessionUser = AuthSession.instance.user?.username;
    return sessionUser != null && sessionUser == widget.username;
  }

  bool get _isPushedRoute => widget.username != null;

  @override
  void initState() {
    super.initState();
    _lastKnownSeller = AuthSession.instance.sellerEnabled;
    if (_isTabContext) {
      AuthSession.instance.addListener(_onSessionChanged);
    }
    _seedContentFromCache();
    _loadProfileShell();
  }

  /// Paints Profile's tabs instantly from whatever's already cached (if
  /// anything) instead of an empty/skeleton state on cold app start — the
  /// cached service calls in `_loadActiveTab` still run once `_profile`
  /// resolves to confirm/silently refresh this. Deliberately doesn't set
  /// the `*Loaded` flags: that's what lets `_loadActiveTab` still run for
  /// real, which is what actually wires up the background refresh.
  void _seedContentFromCache() {
    final username = widget.username ?? AuthSession.instance.user?.username;
    if (username == null) return;
    final pieces = PieceService.instance.peekUserPiecesCached(username);
    if (pieces != null) _pieces = pieces;
    final scenes = PostService.instance.peekUserPostsCached(username);
    if (scenes != null) _scenes = scenes;
    final forSale = PieceService.instance.peekUserPiecesForSaleCached(username);
    if (forSale != null) _listedPieces = forSale;
    final series = SeriesService.instance.peekUserSeriesCached(username);
    if (series != null) {
      _series = series.map(ProfileSeriesData.fromSeries).toList();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isTabContext) {
      routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
    }
  }

  @override
  void dispose() {
    if (_isTabContext) {
      AuthSession.instance.removeListener(_onSessionChanged);
      routeObserver.unsubscribe(this);
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void scrollToTopAndRefresh() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    _loadProfile();
  }

  @override
  void didPopNext() {
    _resetTabCache();
    _loadProfileShell(silent: true);
    _loadActiveTab(force: true);
  }

  void _onSessionChanged() {
    if (!_isTabContext) return;
    final seller = AuthSession.instance.sellerEnabled;
    if (seller == _lastKnownSeller) return;
    _lastKnownSeller = seller;
    if (!mounted) return;
    setState(() {
      if (seller) {
        _tab = 'collect';
        _listedPiecesLoaded = false;
      } else if (_tab == 'collect') {
        _tab = 'pieces';
        _listedPieces = [];
        _listedPiecesLoaded = false;
      }
    });
    _loadProfileShell(silent: true);
    _loadActiveTab(force: true);
  }

  void _resetTabCache() {
    _piecesLoaded = false;
    _scenesLoaded = false;
    _listedPiecesLoaded = false;
    _seriesLoaded = false;
  }

  Future<void> _loadProfileShell({bool silent = false}) async {
    try {
      final UserProfile profile;
      if (_isTabContext || (_isOwnProfile && !widget.viewerMode)) {
        profile = await UserService.instance.getMeCached(
          onBackgroundUpdate: (fresh) {
            if (!mounted) return;
            setState(() {
              _profile = fresh;
              _lastKnownSeller = fresh.sellerEnabled;
              if (!fresh.sellerEnabled && _tab == 'collect') _tab = 'pieces';
            });
          },
        );
      } else {
        profile = await UserService.instance.getPublicProfile(widget.username!);
      }
      if (!mounted) return;
      _profileLoadAttempts = 0;
      setState(() {
        _profile = profile;
        _lastKnownSeller = profile.sellerEnabled;
        if (!profile.sellerEnabled && _tab == 'collect') _tab = 'pieces';
      });
      if (profile.sellerEnabled && !profile.isLocked) {
        _prefetchListedPieces(profile);
      }
      // Locked (private, not-yet-approved) profiles never fetch tab content
      // — the backend gates those endpoints the same way, so there's
      // nothing to show and no point firing the requests.
      if (!silent && !profile.isLocked) _loadActiveTab();
    } catch (_) {
      // Keep session-backed shell visible when profile cannot be loaded, but
      // don't get stuck there forever — a cold backend or a momentary
      // network blip is common on the very first load, and nothing else
      // (short of a manual pull-to-refresh) would otherwise retry it.
      if (_profile == null && mounted && _profileLoadAttempts < 3) {
        _profileLoadAttempts++;
        final attempt = _profileLoadAttempts;
        Future.delayed(Duration(seconds: 2 * attempt), () {
          if (mounted && _profile == null) _loadProfileShell(silent: silent);
        });
      }
    }
  }

  Future<void> _loadProfile() async {
    _resetTabCache();
    await _loadProfileShell();
    if (_profile?.isLocked != true) {
      await _loadActiveTab(force: true);
    }
  }

  Future<void> _loadActiveTab({bool force = false}) async {
    final profile = _profile;
    if (profile == null) return;

    final tab = _tab;
    if (tab == 'pieces' && (_piecesLoaded && !force)) return;
    if (tab == 'scenes' && (_scenesLoaded && !force)) return;
    if (tab == 'collect' && (_listedPiecesLoaded && !force)) return;
    if (tab == 'series' && (_seriesLoaded && !force)) return;

    // Only show the loading flag when this tab is truly empty — if a cache
    // peek (or a prior load) already put content on screen, the cached
    // fetch below resolves near-instantly and refreshes silently, so a
    // spinner would just be a flash for nothing.
    final hasVisibleData = switch (tab) {
      'pieces' => _pieces.isNotEmpty,
      'scenes' => _scenes.isNotEmpty,
      'collect' => _listedPieces.isNotEmpty,
      'series' => _series.isNotEmpty,
      _ => false,
    };
    if (!hasVisibleData) setState(() => _tabContentLoading = true);

    try {
      if (tab == 'pieces') {
        final pieces = await PieceService.instance.getUserPiecesCached(
          profile.username,
          forceRefresh: force,
          onBackgroundUpdate: (fresh) {
            if (!mounted) return;
            setState(() => _pieces = fresh);
          },
        );
        if (!mounted) return;
        setState(() {
          _pieces = pieces;
          _piecesLoaded = true;
          _tabContentLoading = false;
        });
      } else if (tab == 'scenes') {
        final scenes = await PostService.instance.getUserPostsCached(
          profile.username,
          forceRefresh: force,
          onBackgroundUpdate: (fresh) {
            if (!mounted) return;
            setState(() => _scenes = fresh);
          },
        );
        if (!mounted) return;
        setState(() {
          _scenes = scenes;
          _scenesLoaded = true;
          _tabContentLoading = false;
        });
      } else if (tab == 'collect' && profile.sellerEnabled) {
        final listedPieces = await _loadListedPieces(profile, force: force);
        if (!mounted) return;
        setState(() {
          _listedPieces = listedPieces;
          _listedPiecesLoaded = true;
          _tabContentLoading = false;
        });
      } else if (tab == 'series') {
        final series = await SeriesService.instance.getUserSeriesCached(
          profile.username,
          forceRefresh: force,
          onBackgroundUpdate: (fresh) {
            if (!mounted) return;
            setState(() {
              _series = fresh.map(ProfileSeriesData.fromSeries).toList();
            });
          },
        );
        if (!mounted) return;
        setState(() {
          _series = series.map(ProfileSeriesData.fromSeries).toList();
          _seriesLoaded = true;
          _tabContentLoading = false;
        });
      } else {
        if (mounted) setState(() => _tabContentLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _tabContentLoading = false);
    }
  }

  Future<List<PieceSummary>> _loadListedPieces(
    UserProfile profile, {
    bool force = false,
  }) async {
    return PieceService.instance.getUserPiecesForSaleCached(
      profile.username,
      forceRefresh: force,
      onBackgroundUpdate: (fresh) {
        if (!mounted) return;
        setState(() => _listedPieces = fresh);
      },
    );
  }

  Future<void> _prefetchListedPieces(UserProfile profile) async {
    try {
      final listed = await _loadListedPieces(profile);
      if (!mounted) return;
      setState(() {
        _listedPieces = listed;
        _listedPiecesLoaded = true;
      });
    } catch (_) {}
  }

  void _onTabChanged(String tab) {
    setState(() {
      _tab = tab;
    });
    _loadActiveTab();
  }

  void _onCollectSegmentChanged(String segment) {
    setState(() => _collectSegment = segment);
  }

  void _onSceneFilterChanged(String filter) {
    setState(() => _sceneFilter = filter);
  }

  FollowState get _followState {
    final profile = _profile;
    if (profile == null) return FollowState.none;
    if (profile.isFollowing) return FollowState.following;
    if (profile.followRequestPending) return FollowState.pending;
    return FollowState.none;
  }

  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _followBusy) return;
    final wasFollowingOrPending =
        profile.isFollowing || profile.followRequestPending;
    setState(() => _followBusy = true);
    try {
      if (wasFollowingOrPending) {
        // Unfollow also cancels a still-pending request — same endpoint.
        await SocialService.instance.unfollow(profile.username);
        if (!mounted) return;
        setState(() {
          _profile = profile.copyWith(
            isFollowing: false,
            followRequestPending: false,
            followersCount: profile.isFollowing
                ? profile.followersCount - 1
                : null,
          );
        });
      } else {
        final result = await SocialService.instance.follow(profile.username);
        if (!mounted) return;
        setState(() {
          _profile = profile.copyWith(
            isFollowing: result.following,
            followRequestPending: result.requested,
            followersCount: result.following
                ? profile.followersCount + 1
                : null,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  void _onAvatarTap(String? avatarUrl) {
    showProfileAvatarPreview(
      context,
      avatarUrl: avatarUrl,
      allowChange: _isOwnProfile && !widget.viewerMode,
      onChanged: () async {
        _resetTabCache();
        await _loadProfileShell(silent: true);
      },
    );
  }

  void _onTapFollowStat(FollowListTab tab) {
    final username =
        _profile?.username ??
        widget.username ??
        AuthSession.instance.user?.username;
    if (username == null || username.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FollowListPage(username: username, initialTab: tab),
      ),
    );
  }

  void _onMessageTap() {
    if (widget.viewerMode) {
      _showViewerModePreviewSnackBar();
      return;
    }
    final target = _profile;
    if (target == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationThreadPage(
          otherPartyUsername: target.username,
          otherPartyName: target.name,
          otherPartyAvatarUrl: target.profilePhotoUrl,
        ),
      ),
    );
  }

  void _onFollowTap() {
    if (widget.viewerMode) {
      _showViewerModePreviewSnackBar();
      return;
    }
    _toggleFollow();
  }

  Future<void> _deletePiece(PieceSummary piece) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      itemLabel: 'piece',
    );
    if (confirmed != true || !mounted) return;

    // Optimistic: remove immediately (same pattern as
    // detail_save_state.dart's like/save toggles), roll back on failure
    // instead of waiting on the network before the UI reflects the delete.
    final pieceIndex = _pieces.indexWhere((p) => p.id == piece.id);
    final listedIndex = _listedPieces.indexWhere((p) => p.id == piece.id);
    setState(() {
      if (pieceIndex != -1) _pieces = List.of(_pieces)..removeAt(pieceIndex);
      if (listedIndex != -1) {
        _listedPieces = List.of(_listedPieces)..removeAt(listedIndex);
      }
    });
    try {
      await PieceService.instance.delete(piece.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (pieceIndex != -1) {
          _pieces = List.of(_pieces)
            ..insert(pieceIndex.clamp(0, _pieces.length), piece);
        }
        if (listedIndex != -1) {
          _listedPieces = List.of(_listedPieces)
            ..insert(listedIndex.clamp(0, _listedPieces.length), piece);
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete piece: $e')));
    }
  }

  Future<void> _deleteScene(PostSummary post) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      itemLabel: 'scene',
    );
    if (confirmed != true || !mounted) return;

    final index = _scenes.indexWhere((p) => p.id == post.id);
    setState(() {
      if (index != -1) _scenes = List.of(_scenes)..removeAt(index);
    });
    try {
      await PostService.instance.delete(post.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (index != -1) {
          _scenes = List.of(_scenes)
            ..insert(index.clamp(0, _scenes.length), post);
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete scene: $e')));
    }
  }

  Future<void> _publishPiece(PieceSummary piece) async {
    try {
      final updated = await PieceService.instance.update(piece.id, {
        'status': 'live',
      });
      if (!mounted) return;
      setState(() {
        final index = _pieces.indexWhere((p) => p.id == piece.id);
        if (index != -1) _pieces = List.of(_pieces)..[index] = updated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to publish piece: $e')));
    }
  }

  Future<void> _publishScene(PostSummary post) async {
    try {
      final updated = await PostService.instance.update(post.id, {
        'status': 'live',
      });
      if (!mounted) return;
      setState(() {
        final index = _scenes.indexWhere((p) => p.id == post.id);
        if (index != -1) _scenes = List.of(_scenes)..[index] = updated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to publish scene: $e')));
    }
  }

  void _showProfileActionsSheet(UserProfile? profile) {
    if (profile == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HomeFeedTokens.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.block_outlined,
                color: Color(0xFFE05252),
              ),
              title: Text(
                'Block ${profile.handle}',
                style: const TextStyle(
                  color: Color(0xFFE05252),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmBlockUser(profile);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBlockUser(UserProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Block ${profile.handle}?'),
        content: const Text(
          "They won't be notified. You can unblock anytime from Settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Block',
              style: TextStyle(color: Color(0xFFE05252)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SocialService.instance.blockUser(profile.username);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to block user: $e')));
    }
  }

  void _onBackToHome() {
    if (MainNavService.instance.goHome()) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _showViewerModePreviewSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This is a preview of your public profile')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final bottomPad =
        (_isPushedRoute ? safeBottom + 24 : safeBottom + 100) +
        (widget.viewerMode ? 56 : 0);
    final profile = _profile;
    final sessionUser = AuthSession.instance.user;
    final isOwnProfile = _isOwnProfile;
    final showPublicActions = widget.viewerMode || !isOwnProfile;
    // Only borrow the viewer's own session data while `_profile` is still
    // loading for their own profile — otherwise viewing another artist's
    // profile flashes the viewer's own name/handle/seller state first.
    final sellerEnabled =
        profile?.sellerEnabled ??
        (isOwnProfile ? AuthSession.instance.sellerEnabled : false);

    final name =
        profile?.name ?? (isOwnProfile ? sessionUser?.name : null) ?? '';
    final handle =
        profile?.handle ??
        (isOwnProfile && sessionUser != null ? '@${sessionUser.username}' : '');
    final coverUrl = profile?.coverPhotoUrl;
    final avatarUrl = profile?.profilePhotoUrl;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: kProfilePageBackground,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadProfile,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: ProfileHero(
                      width: width,
                      coverUrl: coverUrl,
                      avatarUrl: avatarUrl,
                      showDefaultCover: profile != null,
                      onBack: _onBackToHome,
                      onMore: isOwnProfile && _isTabContext
                          ? () async {
                              await Navigator.pushNamed(
                                context,
                                '/profile-settings',
                              );
                              if (mounted) {
                                _resetTabCache();
                                await _loadProfileShell(silent: true);
                                await _loadActiveTab(force: true);
                              }
                            }
                          : (!isOwnProfile &&
                                !widget.viewerMode &&
                                _isPushedRoute)
                          ? () => _showProfileActionsSheet(profile)
                          : null,
                      onAvatarTap: () => _onAvatarTap(avatarUrl),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ProfileHeader(
                      name: name,
                      handle: handle,
                      followingCount: profile?.followingCount ?? 0,
                      followersCount: profile?.followersCount ?? 0,
                      bio: profile?.bio ?? '',
                      piecesCount: profile?.piecesCount ?? _pieces.length,
                      scenesCount: _scenes.length,
                      savesCount: profile?.savesCount,
                      availableCount: _listedPieces
                          .where((p) => p.isForSale && p.status != 'sold')
                          .length,
                      collectedCount: profile?.collectedCount,
                      rating: profile?.rating,
                      sellerMode: sellerEnabled,
                      isOwnProfile: !showPublicActions,
                      followState: _followState,
                      followBusy: _followBusy,
                      onFollow: showPublicActions && !_followBusy
                          ? _onFollowTap
                          : null,
                      onMessage: showPublicActions ? _onMessageTap : null,
                      onTapFollowing: () =>
                          _onTapFollowStat(FollowListTab.following),
                      onTapFollowers: () =>
                          _onTapFollowStat(FollowListTab.followers),
                    ),
                  ),
                  if (profile != null && profile.isLocked && !isOwnProfile)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        kProfileHorizontalPad,
                        0,
                        kProfileHorizontalPad,
                        bottomPad,
                      ),
                      sliver: const SliverToBoxAdapter(
                        child: ProfileLockedPlaceholder(),
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: ProfileTabs(
                        currentTab: _tab,
                        showCollect: sellerEnabled,
                        collectSegment: _collectSegment,
                        onCollectSegmentChanged: _onCollectSegmentChanged,
                        onTabChanged: _onTabChanged,
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        kProfileHorizontalPad,
                        kProfileGridTopGap,
                        kProfileHorizontalPad,
                        bottomPad,
                      ),
                      sliver: ProfileTabContent(
                        currentTab: _tab,
                        seriesItems: _series,
                        pieces: _pieces,
                        scenes: _scenes,
                        listedPieces: _listedPieces,
                        collectSegment: _collectSegment,
                        sellerMode: sellerEnabled,
                        loading: _tabContentLoading,
                        isOwnProfile: isOwnProfile && !widget.viewerMode,
                        onDeletePiece: _deletePiece,
                        onDeleteScene: _deleteScene,
                        onPublishPiece: _publishPiece,
                        onPublishScene: _publishScene,
                        sceneFilter: _sceneFilter,
                        onSceneFilterChanged: _onSceneFilterChanged,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.viewerMode)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, safeBottom + 16),
                  child: const ProfileViewerModeCapsule(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
