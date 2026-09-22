import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/explore_feed_block.dart';
import '../models/feed_item.dart';
import '../models/feed_page.dart';
import '../models/user_profile.dart';
import '../services/chat_service.dart';
import '../services/connectivity_service.dart';
import '../services/feed_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../theme/explore_tokens.dart';
import '../utils/explore_category_filter.dart';
import '../utils/explore_detail_route.dart';
import '../utils/explore_featured_ranker.dart';
import '../utils/explore_layout_engine.dart';
import '../utils/profile_navigation.dart';
import '../widgets/explore/explore_featured_card.dart';
import '../widgets/explore/explore_feed_section.dart';
import '../widgets/explore/explore_near_you_placeholder.dart';
import '../widgets/explore/nearby_sellers_row.dart';
import '../widgets/explore/explore_sticky_header.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/glass_card.dart';
import '../widgets/home_feed/home_feed_widgets.dart';
import '../utils/scrolls_to_top_on_double_tap.dart';
import '../theme/app_fonts.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with ScrollsToTopOnDoubleTap<ExplorePage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  ExploreCategory _category = ExploreCategory.all;
  List<FeedItem> _allItems = [];
  UserProfile? _profile;
  FeedItem? _featured;
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextCursor;
  String _searchQuery = '';
  int _visibleCycleCount = 2;

  /// Set when a load failed and left nothing on screen — drives the
  /// retry state instead of the "nothing here" copy, which reads as "the
  /// app is empty" when the truth is "the request didn't land".
  bool _loadFailed = false;
  int _loadAttempts = 0;
  Timer? _retryTimer;

  Timer? _userSearchDebounce;
  List<MessageableUser> _userResults = [];
  bool _userSearchLoading = false;
  String? _userSearchError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    ConnectivityService.instance.addReconnectHook(_onReconnected);
    _seedFromCache();
    _loadData();
  }

  /// Paints the last-seen Explore grid on the first frame. Without this the
  /// tab starts empty on every open and depends entirely on the live
  /// request landing.
  void _seedFromCache() {
    final cached = FeedService.instance.peekExploreCached();
    if (cached == null || cached.items.isEmpty) return;
    _allItems = cached.items;
    _nextCursor = cached.nextCursor;
    _featured = ExploreFeaturedRanker.pickFeatured(
      _filterItems(_allItems, _category),
      profile: _profile,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _userSearchDebounce?.cancel();
    _retryTimer?.cancel();
    ConnectivityService.instance.removeReconnectHook(_onReconnected);
    super.dispose();
  }

  Future<void> _onReconnected() => _loadData(refresh: true);

  @override
  void scrollToTopAndRefresh() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    _loadData(refresh: true);
  }

  Future<void> _loadData({bool append = false, bool refresh = false}) async {
    if (append) {
      if (_loadingMore || _nextCursor == null || _nextCursor!.isEmpty) return;
      setState(() => _loadingMore = true);
    } else if (refresh) {
      setState(() => _loading = true);
    } else if (_allItems.isEmpty) {
      setState(() => _loading = true);
    }

    try {
      final page = append
          ? await FeedService.instance.getExplore(cursor: _nextCursor)
          : await FeedService.instance.getExploreCached(
              forceRefresh: refresh,
              // Stale cache paints immediately; this silently merges the
              // background-refreshed page once it lands, no flicker.
              onBackgroundUpdate: _mergeBackgroundPage,
            );
      UserProfile? profile = _profile;
      if (!append) {
        try {
          profile = await UserService.instance.getMeCached();
        } catch (_) {
          profile = null;
        }
      }
      if (!mounted) return;
      _loadAttempts = 0;
      setState(() {
        if (append) {
          _allItems.addAll(page.items);
        } else {
          _allItems = page.items;
        }
        _nextCursor = page.nextCursor;
        _profile = profile;
        _loading = false;
        _loadingMore = false;
        _loadFailed = false;
      });
      if (!append) {
        final filtered = _filterItems(_allItems, _category);
        final featured = ExploreFeaturedRanker.pickFeatured(
          filtered,
          profile: profile,
        );
        if (!mounted) return;
        setState(() {
          _featured = featured;
          _visibleCycleCount = 2;
        });
      }
    } catch (_) {
      if (!mounted) return;
      // Deliberately keeps whatever is already on screen. This used to
      // clear `_allItems`, so a single failed request — and the deployed
      // backend spins down on idle, taking 30-60s to wake, so failures
      // here are routine — permanently replaced a populated Explore with
      // "Nothing to explore yet." until the user thought to pull down.
      setState(() {
        _loading = false;
        _loadingMore = false;
        _loadFailed = _allItems.isEmpty;
      });
      if (!append && _allItems.isEmpty) _scheduleRetry();
    }
  }

  /// Retries a failed first load a few times with backoff, mirroring
  /// `ProfilePage._loadProfileShell`. A cold backend is the common case and
  /// nothing else would otherwise retry for the user.
  void _scheduleRetry() {
    if (_loadAttempts >= 3) return;
    _loadAttempts++;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: 2 * _loadAttempts), () {
      if (!mounted || _allItems.isNotEmpty) return;
      _loadData(refresh: true);
    });
  }

  Future<void> _retryNow() {
    _loadAttempts = 0;
    _retryTimer?.cancel();
    return _loadData(refresh: true);
  }

  /// Applies a page fetched silently in the background (see
  /// [CacheService.fetchWithCache]'s `onBackgroundUpdate`) — mirrors the
  /// non-append branch of `_loadData` (replace items, recompute featured),
  /// just without ever showing a spinner for it.
  void _mergeBackgroundPage(FeedPage page) {
    if (!mounted) return;
    setState(() {
      _allItems = page.items;
      _nextCursor = page.nextCursor;
    });
    final filtered = _filterItems(_allItems, _category);
    final featured = ExploreFeaturedRanker.pickFeatured(filtered, profile: _profile);
    if (!mounted) return;
    setState(() {
      _featured = featured;
      _visibleCycleCount = 2;
    });
  }

  List<FeedItem> get _sourceItems => _allItems;

  FeedItem? get _effectiveFeatured => _featured;

  List<FeedItem> _filterItems(List<FeedItem> items, ExploreCategory category) {
    return filterExploreItems(items, category);
  }

  List<FeedItem> get _feedItems {
    final filtered = _filterItems(_sourceItems, _category);
    final featured = _effectiveFeatured;
    if (featured == null) return filtered;
    return filtered.where((item) => item.id != featured.id).toList();
  }

  List<ExploreFeedBlock> get _visibleBlocks {
    final maxCycles = ExploreLayoutEngine.cycleCountForItems(_feedItems.length);
    final count = _visibleCycleCount.clamp(0, maxCycles);
    return ExploreLayoutEngine.buildBlocks(_feedItems, maxCycles: count);
  }

  void _onCategoryChanged(ExploreCategory category) {
    if (_category == category) return;
    setState(() {
      _category = category;
      _visibleCycleCount = 2;
      final filtered = _filterItems(_allItems, category);
      _featured = ExploreFeaturedRanker.pickFeatured(
        filtered,
        profile: _profile,
      );
    });
  }

  /// Unlike the old local title/author substring filter, this searches all
  /// users on the app by name/username (same endpoint + debounce pattern as
  /// the Chats search) — typing here shows matching people, not a filtered
  /// piece/scene grid.
  void _onSearchChanged(String value) {
    final query = value.trim();
    _userSearchDebounce?.cancel();
    setState(() => _searchQuery = query);
    if (query.isEmpty) {
      setState(() {
        _userResults = [];
        _userSearchLoading = false;
        _userSearchError = null;
      });
      return;
    }
    setState(() {
      _userSearchLoading = true;
      _userSearchError = null;
    });
    _userSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await ChatService.instance.searchUsers(query);
        if (!mounted || _searchController.text.trim() != query) return;
        setState(() {
          _userResults = results;
          _userSearchLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _userSearchLoading = false;
          _userSearchError = '$e';
        });
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || _loading) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 300) return;

    final maxCycles = ExploreLayoutEngine.cycleCountForItems(_feedItems.length);
    if (_visibleCycleCount < maxCycles &&
        _visibleCycleCount < ExploreLayoutEngine.maxCycles) {
      setState(() {
        _visibleCycleCount =
            (_visibleCycleCount + 2).clamp(0, maxCycles);
      });
      return;
    }

    if (_nextCursor != null && _nextCursor!.isNotEmpty) {
      _loadData(append: true);
    }
  }

  String get _emptyMessage => 'Nothing to explore yet.';

  @override
  Widget build(BuildContext context) {
    final showSkeleton = _loading && _allItems.isEmpty;
    final isSearchingUsers = _searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: ExploreTokens.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: ExploreTokens.textPrimary,
          onRefresh: () => _loadData(refresh: true),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: ExploreStickyHeader(
                  searchController: _searchController,
                  onSearchChanged: _onSearchChanged,
                  selectedCategory: _category,
                  onCategorySelected: _onCategoryChanged,
                  onFilterTap: () {},
                ),
              ),
              if (isSearchingUsers)
                SliverToBoxAdapter(child: _buildUserSearchBody())
              else ...[
                if (!showSkeleton && _effectiveFeatured != null)
                  SliverToBoxAdapter(
                    child: ExploreFeaturedCard(
                      item: _effectiveFeatured!,
                      onTap: () =>
                          openExploreDetail(context, _effectiveFeatured!),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: ExploreNearYouPlaceholder(),
                ),
                const SliverToBoxAdapter(
                  child: NearbySellersRow(),
                ),
                if (showSkeleton)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12, bottom: 48),
                      child: ExploreFeedSkeleton(),
                    ),
                  )
                else if (_loadFailed)
                  SliverToBoxAdapter(child: _ExploreLoadFailed(onRetry: _retryNow))
                else
                  SliverToBoxAdapter(
                    child: ExploreFeedSection(
                      blocks: _visibleBlocks,
                      emptyMessage: _emptyMessage,
                    ),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserSearchBody() {
    if (_userSearchLoading && _userResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: ListRowSkeleton(),
      );
    }
    if (_userSearchError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Center(
          child: Text(
            'Search failed: $_userSearchError',
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: 14,
              color: ExploreTokens.textSecondary,
            ),
          ),
        ),
      );
    }
    if (_userResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'No users found for "$_searchQuery"',
            style: AppFonts.inter(
              fontSize: 14,
              color: ExploreTokens.textSecondary,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ExploreTokens.sideMargin,
        vertical: 12,
      ),
      child: Column(
        children: [
          for (final user in _userResults)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDims.spaceSm),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => openUserProfile(context, user.username),
                  borderRadius: BorderRadius.circular(AppDims.radiusMd),
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        UserAvatar(
                          url: user.profilePhotoUrl,
                          name: user.displayName,
                          size: 48,
                        ),
                        const SizedBox(width: AppDims.spaceSm + 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: AppFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.slate900,
                                ),
                              ),
                              Text(
                                '@${user.username}',
                                style: AppFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.slate500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown when Explore has nothing *because the request failed*, as opposed
/// to there genuinely being nothing to show — the two used to render the
/// same "Nothing to explore yet." copy, which made a transient backend
/// hiccup look like an empty app and gave the user nothing to act on.
class _ExploreLoadFailed extends StatelessWidget {
  const _ExploreLoadFailed({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ExploreTokens.sideMargin,
        vertical: 48,
      ),
      child: Column(
        children: [
          Text(
            "Couldn't load Explore",
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: ExploreTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: 13,
              color: ExploreTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(
              'Try again',
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ExploreTokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
