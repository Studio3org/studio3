import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/explore_feed_block.dart';
import '../models/feed_item.dart';
import '../models/feed_page.dart';
import '../services/chat_service.dart';
import '../services/connectivity_service.dart';
import '../services/blocked_authors_store.dart';
import '../services/feed_service.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import '../utils/explore_category_filter.dart';
import '../utils/explore_detail_route.dart';
import '../utils/profile_navigation.dart';
import '../widgets/explore/explore_browse.dart';
import '../widgets/explore/explore_feed_image.dart';
import '../widgets/explore/nearby_sellers_row.dart';
import '../widgets/explore/explore_sticky_header.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/studio/studio_avatar.dart';
import '../utils/scrolls_to_top_on_double_tap.dart';
import 'behind_the_work_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with ScrollsToTopOnDoubleTap<ExplorePage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  final _browseKey = GlobalKey();

  ExploreCategory _category = ExploreCategory.all;
  String? _medium;
  List<FeedItem> _allItems = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextCursor;
  String _searchQuery = '';
  bool _artistsSettled = false;
  bool _artistsVisible = false;

  Timer? _userSearchDebounce;
  List<MessageableUser> _userResults = [];
  bool _userSearchLoading = false;
  String? _userSearchError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    ConnectivityService.instance.addReconnectHook(_onReconnected);
    BlockedAuthorsStore.instance.addListener(_onAuthorBlocked);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _userSearchDebounce?.cancel();
    ConnectivityService.instance.removeReconnectHook(_onReconnected);
    BlockedAuthorsStore.instance.removeListener(_onAuthorBlocked);
    super.dispose();
  }

  Future<void> _onReconnected() => _loadData(refresh: true);

  @override
  void scrollToTopAndRefresh() {
    if (_scrollController.hasClients) {
      final reduce = MediaQuery.disableAnimationsOf(context);
      _scrollController.animateTo(
        0,
        duration: reduce ? Duration.zero : StudioMotion.standard,
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
      if (!mounted) return;
      setState(() {
        if (append) {
          _allItems.addAll(page.items);
        } else {
          _allItems = page.items;
        }
        _nextCursor = page.nextCursor;
        _loading = false;
        _loadingMore = false;
        if (_medium != null && !exploreMediumNames(_allItems).contains(_medium)) {
          _medium = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!append) {
          _allItems = [];
          _nextCursor = null;
        }
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  /// Applies a page fetched silently in the background (see
  /// [CacheService.fetchWithCache]'s `onBackgroundUpdate`) — mirrors the
  /// non-append branch of `_loadData` (replace items), just without ever
  /// showing a spinner for it.
  void _mergeBackgroundPage(FeedPage page) {
    if (!mounted) return;
    setState(() {
      _allItems = page.items;
      _nextCursor = page.nextCursor;
      if (_medium != null && !exploreMediumNames(_allItems).contains(_medium)) {
        _medium = null;
      }
    });
  }

  // Blocked-this-session accounts are hidden at read time, so a block from
  // anywhere in the app clears them off Explore without a refetch.
  List<FeedItem> get _sourceItems {
    final blocked = BlockedAuthorsStore.instance;
    return _allItems
        .where((item) => !blocked.isBlocked(item.authorUsername))
        .toList();
  }

  void _onAuthorBlocked() {
    if (mounted) setState(() {});
  }

  List<FeedItem> get _feedItems => filterExploreByMedium(
        filterExploreItems(_sourceItems, _category),
        _medium,
      );

  void _onMediumSelected(String medium) {
    setState(() => _medium = _medium == medium ? null : medium);
  }

  void _onCategoryChanged(ExploreCategory category) {
    if (_category == category) return;
    setState(() => _category = category);
  }

  void _onArtistsOccupied(bool occupied) {
    if (!mounted) return;
    if (_artistsSettled && _artistsVisible == occupied) return;
    setState(() {
      _artistsSettled = true;
      _artistsVisible = occupied;
    });
  }

  void _seeAll(ExploreCategory category) {
    if (_category != category) setState(() => _category = category);
    _scrollToBrowse();
  }

  void _scrollToBrowse() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _browseKey.currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        duration: reduce ? Duration.zero : StudioMotion.standard,
        curve: Curves.easeOut,
        alignment: 0.05,
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
    if (_nextCursor != null && _nextCursor!.isNotEmpty) {
      _loadData(append: true);
    }
  }

  String get _emptyMessage => 'Nothing to explore yet.';

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final showSkeleton = _loading && _allItems.isEmpty;
    final isSearchingUsers = _searchQuery.isNotEmpty;
    final bottom = MediaQuery.paddingOf(context).bottom +
        StudioSize.navHeight +
        StudioSize.navBottomGap +
        StudioSpace.feedGap;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.textPrimary,
          onRefresh: () => _loadData(refresh: true),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: ExploreTop(
                  searchController: _searchController,
                  onSearchChanged: _onSearchChanged,
                  selectedCategory: _category,
                  onCategorySelected: _onCategoryChanged,
                  mediums: exploreMediumNames(_sourceItems),
                  selectedMedium: _medium,
                  onMediumSelected: _onMediumSelected,
                ),
              ),
              if (isSearchingUsers)
                SliverToBoxAdapter(child: _buildUserSearchBody())
              else ...[
                if (showSkeleton)
                  const SliverToBoxAdapter(child: ExploreFeedSkeleton())
                else
                  SliverToBoxAdapter(child: _buildExploreBody()),
              ],
              SliverToBoxAdapter(child: SizedBox(height: bottom)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExploreBody() {
    final items = _feedItems;
    final forSale = items.where((item) => item.isForSale).toList();
    final scenes = items.where((item) => item.isVideo).toList();
    final series = exploreSeriesEntries(items);
    final filterActive = _medium != null || _category != ExploreCategory.all;
    final showEmpty =
        items.isEmpty && (filterActive || (_artistsSettled && !_artistsVisible));
    final shelves = <Widget>[];
    void addShelf(Widget shelf) {
      shelves.add(
        Padding(
          padding: EdgeInsets.only(top: shelves.isEmpty ? 36 : exploreSectionGap),
          child: shelf,
        ),
      );
    }
    if (forSale.length >= exploreShelfMinCount) {
      addShelf(
        ExplorePieceShelf(
          items: forSale,
          onOpen: (item) => openExploreDetail(context, item),
          onSeeAll: () => _seeAll(ExploreCategory.pieces),
        ),
      );
    }
    if (scenes.length >= exploreShelfMinCount) {
      addShelf(
        ExploreSceneShelf(
          items: scenes,
          onOpen: (item) => openExploreDetail(context, item, from: scenes),
          // `BehindTheWork`: its own page, in the shelf's order.
          onSeeAll: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => BehindTheWorkPage(initialItems: scenes)),
          ),
        ),
      );
    }
    if (series.length >= exploreShelfMinCount) {
      addShelf(
        ExploreSeriesShelf(
          entries: series,
          onOpen: (entry) {
            final username = entry.authorUsername;
            if (username != null && username.isNotEmpty) {
              openUserProfile(context, username);
            }
          },
          onSeeAll: _scrollToBrowse,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...shelves,
        NearbySellersRow(
          topGap: shelves.isEmpty ? 36 : exploreSectionGap,
          onOccupied: _onArtistsOccupied,
        ),
        if (showEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: StudioSpace.marginFeed,
              vertical: 48,
            ),
            child: Text(
              _emptyMessage,
              textAlign: TextAlign.center,
              style: StudioType.body14(color: context.studio.textSecondary),
            ),
          )
        else if (items.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
              top: shelves.isNotEmpty || _artistsVisible ? exploreSectionGap : 36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  key: _browseKey,
                  padding: const EdgeInsets.symmetric(horizontal: StudioSpace.marginFeed),
                  child: Text(
                    'Browse everything',
                    style: StudioType.sans(
                      20,
                      weight: StudioType.medium,
                      height: 1.2,
                      color: context.studio.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: exploreShelfInnerGap),
                ExploreBrowseGrid(
                  items: items,
                  onOpen: (item) => openExploreDetail(context, item, from: items),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<FeedItem> get _searchMatches => _sourceItems
      .where((item) => exploreItemMatchesQuery(item, _searchQuery))
      .toList();

  Widget _buildUserSearchBody() {
    final c = context.studio;
    final matches = _searchMatches;
    final showPeopleLabel = _userResults.isNotEmpty && matches.isNotEmpty;
    if (_userSearchLoading && _userResults.isEmpty && matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: ListRowSkeleton(),
      );
    }
    if (_userResults.isEmpty && matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Text(
          _userSearchError != null
              ? 'Search failed: $_userSearchError'
              : 'Nothing matches "$_searchQuery"',
          textAlign: TextAlign.center,
          style: StudioType.body14(color: c.textSecondary),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        StudioSpace.marginFeed,
        StudioSpace.s16,
        StudioSpace.marginFeed,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_userSearchError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: StudioSpace.s12),
              child: Text(
                'Search failed: $_userSearchError',
                style: StudioType.body14(color: c.textSecondary),
              ),
            ),
          if (showPeopleLabel)
            Padding(
              padding: const EdgeInsets.only(bottom: StudioSpace.s8),
              child: Text('People', style: StudioType.label13(color: c.textSecondary)),
            ),
          for (final user in _userResults)
            GestureDetector(
              onTap: () => openUserProfile(context, user.username),
              behavior: HitTestBehavior.opaque,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: StudioSize.tapTarget),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: StudioSpace.s8),
                  child: Row(
                    children: [
                      StudioAvatar(url: user.profilePhotoUrl, size: 48),
                      const SizedBox(width: StudioSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: StudioType.body14(
                                weight: StudioType.medium,
                                color: c.textPrimary,
                              ),
                            ),
                            Text(
                              '@${user.username}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: StudioType.label13(color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (matches.isNotEmpty) ...[
            if (showPeopleLabel)
              Padding(
                padding: const EdgeInsets.only(top: StudioSpace.s8, bottom: StudioSpace.s8),
                child: Text('Pieces', style: StudioType.label13(color: c.textSecondary)),
              ),
            for (final item in matches)
              GestureDetector(
                onTap: () => openExploreDetail(context, item),
                behavior: HitTestBehavior.opaque,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: StudioSize.tapTarget),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: StudioSpace.s8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(StudioRadius.card),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: ExploreFeedImage(
                              url: item.isVideo
                                  ? (item.thumbnailUrl ?? item.mediaUrl)
                                  : item.mediaUrl,
                            ),
                          ),
                        ),
                        const SizedBox(width: StudioSpace.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title ?? item.authorName ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: StudioType.body14(
                                  weight: StudioType.medium,
                                  color: c.textPrimary,
                                ),
                              ),
                              if (item.authorName != null)
                                Text(
                                  item.authorName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: StudioType.label13(color: c.textSecondary),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
