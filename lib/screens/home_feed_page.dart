import 'package:flutter/material.dart';

import '../models/feed_item.dart';
import '../models/feed_page.dart';
import '../models/feed_preview_item.dart' show FeedAvailabilityFilter;
import '../models/studio_event.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import '../utils/explore_detail_route.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/home_feed/home_feed_widgets.dart';
import '../widgets/offline_state.dart';
import '../widgets/studio/studio_empty_state.dart';
import '../services/blocked_authors_store.dart';
import '../services/connectivity_service.dart';
import '../services/feed_service.dart';
import '../services/event_service.dart';
import '../utils/profile_navigation.dart';
import '../widgets/home_feed/feed_event_card.dart';
import 'event_detail_page.dart';
import '../utils/scrolls_to_top_on_double_tap.dart';
import 'reels_page.dart' show routeObserver;

/// Owns the "For You" feed's data/pagination — shared by both the "All" and
/// "Available" tabs of [HomePage] so they read from one fetch instead of
/// each maintaining their own.
class HomeFeedStore extends ChangeNotifier {
  final List<FeedItem> apiItems = [];
  bool loading = true;
  bool loadingMore = false;
  String? nextCursor;
  bool showOfflineState = false;

  /// The first page failed while online and there is nothing to show: Try again.
  bool failed = false;

  /// The last page after the first failed; the feed stops asking on its own until the next
  /// scroll or refresh, so a server error doesn't turn into a request loop.
  bool appendFailed = false;

  bool _initialized = false;

  /// The event card the server put on the first page (BACKEND_CHANGES B27), if any.
  StudioEvent? feedEvent;

  // --- Available (BACKEND_CHANGES B29): its own pages from the server's filter --------------

  /// Pages from `?available=1`, once the Available tab has been opened.
  final List<FeedItem> availableApi = [];
  String? availableCursor;
  bool availableStarted = false;
  bool availableLoading = false;
  bool availableLoadingMore = false;
  bool availableFailed = false;
  bool availableAppendFailed = false;

  static bool _collectable(FeedItem item) => item.isAvailableListing || item.isAuctionLive;

  /// What can be collected now: available, or in a live auction. Not `isForSale`, which the
  /// server leaves on after a piece is collected. From the server's filter once Available has
  /// loaded; before that (and to decide whether to offer the tab), from All's pages. Filtered
  /// here as well, so a server without the filter still shows only these.
  List<FeedItem> get availableItems =>
      (availableStarted ? availableApi : apiItems).where(_collectable).toList();

  /// Loads Available's first page (again with [refresh]) or its next page ([append]). An older
  /// server ignores the filter and sends everything; the screen then keeps asking for pages
  /// until something collectable shows, as before.
  Future<void> loadAvailable({bool append = false, bool refresh = false}) async {
    if (availableLoadingMore || (availableLoading && !refresh)) return;
    if (append && (availableCursor == null || availableCursor!.isEmpty)) return;
    if (!append && availableStarted && !refresh) return;
    availableStarted = true;
    if (append) {
      availableLoadingMore = true;
    } else {
      availableLoading = availableApi.isEmpty;
    }
    notifyListeners();
    try {
      final page = await FeedService.instance.getForYou(
        cursor: append ? availableCursor : null,
        available: true,
      );
      final blocked = BlockedAuthorsStore.instance;
      final items = page.items.where((item) => !blocked.isBlocked(item.authorUsername));
      if (!append) availableApi.clear();
      availableApi.addAll(items);
      availableCursor = page.nextCursor;
      availableFailed = false;
      availableAppendFailed = false;
    } catch (_) {
      if (append) {
        availableAppendFailed = true;
      } else {
        availableFailed = availableApi.isEmpty;
      }
    } finally {
      availableLoading = false;
      availableLoadingMore = false;
      notifyListeners();
    }
  }

  /// The "All" tab never shows video scenes — those live in Explore/Reels
  /// only.
  List<FeedItem> get feedItems => apiItems.where((item) => !item.isVideo).toList();

  /// Paints instantly from whatever's already cached (if anything) instead
  /// of starting from an empty spinner, then kicks off a fetch to silently
  /// refresh in the background. Safe to call from both slides — only runs
  /// once.
  void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    final cached = FeedService.instance.peekForYouCached();
    if (cached != null && cached.items.isNotEmpty) {
      apiItems.addAll(cached.items);
      nextCursor = cached.nextCursor;
      feedEvent = cached.event;
      loading = false;
    }
    ConnectivityService.instance.addReconnectHook(_onReconnected);
    BlockedAuthorsStore.instance.addListener(_onAuthorBlocked);
    loadFeed();
  }

  @override
  void dispose() {
    ConnectivityService.instance.removeReconnectHook(_onReconnected);
    BlockedAuthorsStore.instance.removeListener(_onAuthorBlocked);
    super.dispose();
  }

  /// A block takes the account's work off the feed immediately; the backend
  /// already leaves it out of every later fetch.
  void _onAuthorBlocked() {
    final store = BlockedAuthorsStore.instance;
    final before = apiItems.length + availableApi.length;
    apiItems.removeWhere((item) => store.isBlocked(item.authorUsername));
    availableApi.removeWhere((item) => store.isBlocked(item.authorUsername));
    if (apiItems.length + availableApi.length != before) notifyListeners();
  }

  Future<void> _onReconnected() => loadFeed(refresh: true);

  Future<void> refresh() => loadFeed(refresh: true);

  Future<void> loadMore() => loadFeed(append: true);

  Future<void> loadFeed({bool append = false, bool refresh = false}) async {
    if (loadingMore) return;
    if (append && (nextCursor == null || nextCursor!.isEmpty)) return;

    if (append) {
      loadingMore = true;
      notifyListeners();
    } else if (apiItems.isEmpty) {
      // Only block with a spinner when there's truly nothing to show yet
      // — a refresh with existing (cached or previously-loaded) content
      // already on screen updates silently in place instead.
      loading = true;
      notifyListeners();
    }
    try {
      final page = append
          ? await FeedService.instance.getForYou(cursor: nextCursor)
          : await FeedService.instance.getForYouCached(
              forceRefresh: refresh,
              // Stale cache paints immediately (see ensureInitialized);
              // this silently merges the background-refreshed page in
              // place once it lands, with no spinner or flicker.
              onBackgroundUpdate: _mergeBackgroundPage,
            );
      if (append) {
        apiItems.addAll(page.items);
      } else {
        apiItems
          ..clear()
          ..addAll(page.items);
        feedEvent = page.event;
      }
      nextCursor = page.nextCursor;
      loading = false;
      loadingMore = false;
      failed = false;
      appendFailed = false;
      showOfflineState = apiItems.isEmpty && !ConnectivityService.instance.isOnline;
      notifyListeners();
    } catch (_) {
      // Keep whatever's already showing (cached or previously-loaded) on
      // a failed refresh — a silent background failure shouldn't blank a
      // screen that already has content, only a genuinely empty one
      // falls through to the offline state (or, online, to Try again).
      loading = false;
      loadingMore = false;
      if (append) appendFailed = true;
      showOfflineState = apiItems.isEmpty && !ConnectivityService.instance.isOnline;
      failed = apiItems.isEmpty && !showOfflineState;
      notifyListeners();
    }
  }

  /// Applies a page fetched silently in the background (see
  /// [CacheService.fetchWithCache]'s `onBackgroundUpdate`) — same
  /// replace-from-page-1 convention `loadFeed`'s foreground refresh
  /// already uses, just without ever showing a spinner for it.
  void _mergeBackgroundPage(FeedPage page) {
    apiItems
      ..clear()
      ..addAll(page.items);
    feedEvent = page.event;
    nextCursor = page.nextCursor;
    showOfflineState = apiItems.isEmpty && !ConnectivityService.instance.isOnline;
    notifyListeners();
  }
}

/// The Home ("For You") page — a single page with one header and one
/// `Scaffold`, whose "All"/"Available" tabs switch by *tapping* only (no
/// swipe): both are just two views over the same [HomeFeedStore], toggled
/// with local state, rather than separate pages in the shell's outer
/// Home/Discover/Reels/Saved swipe sequence (`MainShell`, `lib/main.dart`).
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store, this.debugFeedEvent});

  final HomeFeedStore store;

  /// For tests: the event card's event, instead of picking one from the Events tab data.
  @visibleForTesting
  final StudioEvent? debugFeedEvent;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with RouteAware, ScrollsToTopOnDoubleTap<HomePage>, SingleTickerProviderStateMixin {
  static const double _loadMoreThreshold = 200;

  /// How far the feed moves one way before the top bar hides or comes back, so a small
  /// wobble of the thumb doesn't flick it.
  static const double _headerScrollSlop = 12;

  final ScrollController _scrollController = ScrollController();

  /// The top bar (the user's call, 2026-11-08): scrolling down slides it up and folds it
  /// away; scrolling up slides it back down. 1 is shown, 0 hidden.
  late final AnimationController _header = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 200),
    value: 1,
  );
  late final Animation<double> _headerSize = CurvedAnimation(
    parent: _header,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  double _lastOffset = 0;
  double _headerTravel = 0;

  /// While the app itself takes the feed to the top (Home tapped again, the phone's back), the
  /// bar stays shown whatever the list does on the way.
  bool _scrollingToTop = false;

  /// The feed's pull-to-refresh, so the phone's back and a second tap on Home show the same
  /// spinner a pull does (only one of the feed's states is on screen at a time).
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  bool _showAvailable = false;

  /// The one event card for this feed load (`NoteMain`): the server's pick on the first page
  /// (B27), or, when the feed has none (an older server), one picked from the Events tab data;
  /// again on pull to refresh.
  StudioEvent? _feedEvent;

  /// The id of the server's pick now shown, so a store update with the same pick doesn't
  /// fetch it again.
  String? _fromFeedId;

  @override
  void initState() {
    super.initState();
    widget.store.ensureInitialized();
    widget.store.addListener(_onStoreChanged);
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_onScrollHeader);
    // The feed may bring its own event card, so the Events tab is asked only once it has
    // answered (or there is something cached to go on).
    if (widget.debugFeedEvent != null || !widget.store.loading) _startFeedEvent();
    _initDone = true;
  }

  bool _initDone = false;

  bool _feedEventStarted = false;

  void _startFeedEvent() {
    _feedEventStarted = true;
    _loadFeedEvent();
  }

  /// Takes the server's event card when the feed has one; true if it did.
  bool _adoptFeedEvent({bool again = false}) {
    if (widget.debugFeedEvent != null) return false;
    final given = widget.store.feedEvent;
    if (given == null) return false;
    if (!again && given.id == _fromFeedId) return true;
    _fromFeedId = given.id;
    _feedEvent = given;
    _loadEventLineup(given.id);
    return true;
  }

  /// The card has no lineup; the detail says whether to show "Showing work".
  Future<void> _loadEventLineup(String id) async {
    try {
      final full = await EventService.instance.getById(id);
      if (mounted && _feedEvent?.id == full.id) setState(() => _feedEvent = full);
    } catch (_) {
      // The card shows without the artists.
    }
  }

  Future<void> _loadFeedEvent() async {
    final given = widget.debugFeedEvent;
    if (given != null) {
      _feedEvent = given;
      return;
    }
    if (_adoptFeedEvent(again: true)) {
      // From initState the first build shows it; setState isn't allowed there.
      if (mounted && _initDone) setState(() {});
      return;
    }
    try {
      final browse = await EventService.instance.browseCached();
      // The feed brought its own pick meanwhile.
      if (_fromFeedId != null) return;
      final picked = pickFeedEvent(browse, DateTime.now());
      if (picked == null) {
        if (mounted) setState(() => _feedEvent = null);
        return;
      }
      if (mounted) setState(() => _feedEvent = picked);
      await _loadEventLineup(picked.id);
    } catch (_) {
      // No card this time; the feed itself is unaffected.
    }
  }

  Future<void> _refresh() async {
    if (_showAvailable) {
      await widget.store.loadAvailable(refresh: true);
      return;
    }
    await widget.store.refresh();
    _fromFeedId = null;
    await _loadFeedEvent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    widget.store.removeListener(_onStoreChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.removeListener(_onScrollHeader);
    _scrollController.dispose();
    _header.dispose();
    super.dispose();
  }

  /// Back from a piece or profile: refresh only near the top. Further down, a refresh would
  /// swap the pages already scrolled through for the first one and move the list.
  @override
  void didPopNext() {
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    if (offset < _loadMoreThreshold) _refreshShown();
  }

  void _onStoreChanged() {
    if (!_feedEventStarted && !widget.store.loading) {
      _startFeedEvent();
    } else {
      _adoptFeedEvent();
    }
    if (mounted) setState(() {});
  }

  /// A short list (few Available pieces, or a page of videos Home leaves out) can't be
  /// scrolled to its end, so it asks for the next page itself until the screen is full.
  void _fillScreen() {
    final store = widget.store;
    if (!mounted || !_canLoadMore) return;
    if (_showAvailable ? store.availableLoading : store.loading) return;
    final shown = _showAvailable ? store.availableItems : store.feedItems;
    final short = shown.isEmpty ||
        (_scrollController.hasClients &&
            _scrollController.position.hasContentDimensions &&
            _scrollController.position.maxScrollExtent <= _loadMoreThreshold);
    if (short) _loadMore();
  }

  /// The tab on screen has another page and isn't fetching or stopped on a failure.
  bool get _canLoadMore {
    final store = widget.store;
    if (_showAvailable) {
      if (store.availableLoadingMore || store.availableAppendFailed) return false;
      return store.availableCursor?.isNotEmpty == true;
    }
    if (store.loadingMore || store.appendFailed) return false;
    return store.nextCursor?.isNotEmpty == true;
  }

  void _loadMore() => _showAvailable ? widget.store.loadAvailable(append: true) : widget.store.loadMore();

  void _onScroll() {
    if (!_canLoadMore) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (!pos.hasPixels || !pos.hasViewportDimension) return;
    if (pos.pixels >= pos.maxScrollExtent - _loadMoreThreshold) {
      _loadMore();
    }
  }

  /// Hides the top bar once the feed has gone [_headerScrollSlop] down, shows it once it has
  /// gone that far up, and always at the top. Pull-to-refresh and the bounce past either end
  /// don't count. A screen reader keeps it in place.
  void _onScrollHeader() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (!pos.hasPixels || !pos.hasContentDimensions) return;
    final offset = pos.pixels.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    final delta = offset - _lastOffset;
    _lastOffset = offset;
    if (_scrollingToTop) {
      _headerTravel = 0;
      return;
    }
    if (offset <= pos.minScrollExtent || MediaQuery.accessibleNavigationOf(context)) {
      _headerTravel = 0;
      _showHeader();
      return;
    }
    if (delta == 0) return;
    // Start counting again when the direction changes.
    if ((delta > 0) != (_headerTravel > 0)) _headerTravel = 0;
    _headerTravel += delta;
    // A feed barely taller than the screen would grow back under a hidden bar and bounce.
    if (_headerTravel > _headerScrollSlop && pos.maxScrollExtent > _loadMoreThreshold) {
      _hideHeader();
    } else if (_headerTravel < -_headerScrollSlop) {
      _showHeader();
    }
  }

  void _showHeader() {
    // By direction, not value: a fold that has only just started still reads 1.
    if (_header.status == AnimationStatus.completed || _header.status == AnimationStatus.forward) return;
    _header.duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220);
    _header.forward();
  }

  void _hideHeader() {
    if (_header.status == AnimationStatus.dismissed || _header.status == AnimationStatus.reverse) return;
    _header.reverseDuration =
        MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200);
    _header.reverse();
  }

  void _openApiItem(FeedItem item) {
    openExploreDetail(context, item);
  }

  /// Tapping "All"/"Available" only ever swaps which items this single page
  /// shows — no swipe/PageView is involved. Also snaps back to the top of
  /// the list, matching how switching tabs behaves elsewhere in the app.
  void _onFilterTap(FeedAvailabilityFilter filter) {
    final showAvailable = filter == FeedAvailabilityFilter.available;
    if (showAvailable == _showAvailable) return;
    setState(() => _showAvailable = showAvailable);
    _showHeader();
    // Available asks the server for its own pages the first time (B29).
    if (showAvailable) widget.store.loadAvailable();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  bool get isScrolledToTop => !_scrollController.hasClients || _scrollController.offset <= 1;

  /// The phone's back on Home and a second tap on Home: to the very top, then the
  /// pull-to-refresh spinner while the feed reloads, as a pull would (as on Instagram).
  @override
  void scrollToTopAndRefresh() {
    _showHeader();
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollingToTop = true;
      _scrollController
          .animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)
          .whenComplete(() {
            _scrollingToTop = false;
            _showRefresh();
          });
    } else {
      _showRefresh();
    }
  }

  void _showRefresh() {
    if (!mounted) return;
    final indicator = _refreshKey.currentState;
    if (indicator == null) {
      // Offline or still loading: nothing to pull, refresh quietly.
      _refreshShown();
      return;
    }
    indicator.show();
  }

  /// Refreshes the tab on screen without a spinner.
  void _refreshShown() {
    widget.store.refresh();
    if (_showAvailable) widget.store.loadAvailable(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom + 64 + 28 + 20;
    final store = widget.store;
    final items = _showAvailable ? store.availableItems : store.feedItems;
    final filter = _showAvailable ? FeedAvailabilityFilter.available : FeedAvailabilityFilter.all;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillScreen());

    return Scaffold(
      backgroundColor: context.studio.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Folds from the top, so the bar slides up out of view and back down into it.
            SizeTransition(
              key: const ValueKey('home-header'),
              sizeFactor: _headerSize,
              alignment: Alignment.bottomCenter,
              child: FeedHomeHeader(
                filter: filter,
                onFilterChanged: _onFilterTap,
                hasAvailableItems: store.availableItems.isNotEmpty,
              ),
            ),
            Expanded(
              child: _buildFeed(
                bottomInset,
                items: items,
                emptyMessage: _showAvailable ? 'No available pieces yet' : 'No feed items yet',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed(double bottomInset, {required List<FeedItem> items, required String emptyMessage}) {
    final store = widget.store;
    if (store.showOfflineState) {
      return OfflineState(onRetry: () => store.refresh());
    }
    if (_showAvailable && store.availableLoading && store.availableApi.isEmpty) {
      return const FeedListSkeleton();
    }
    if (store.loading && store.apiItems.isEmpty) {
      // First-load only — a revisit (cache hit) never reaches this branch
      // since loading is seeded false whenever peekForYouCached() finds
      // something in ensureInitialized().
      return const FeedListSkeleton();
    }
    if (store.failed || (_showAvailable && store.availableFailed)) {
      return RefreshIndicator(
        key: _refreshKey,
        color: context.studio.textPrimary,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
            StudioEmptyState(
              title: "Couldn't load your feed",
              message: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: _refresh,
            ),
          ],
        ),
      );
    }
    // Nothing on this filter yet, but more pages to look through (see [_fillScreen]).
    final fetching = _showAvailable ? store.availableLoadingMore : store.loadingMore;
    if (items.isEmpty && (fetching || _canLoadMore)) {
      return Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: context.studio.textPrimary),
        ),
      );
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        key: _refreshKey,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.35),
            Center(
              child: Text(emptyMessage, style: StudioType.body14(color: context.studio.textSecondary)),
            ),
          ],
        ),
      );
    }

    final rows = <Widget>[];
    final seenSeries = <String>{};
    for (final item in items) {
      final series = item.piece?.series;
      if (series != null && series.previewPieces.isNotEmpty && seenSeries.add(series.id)) {
        rows.add(
          FeedSeriesRow(
            series: series,
            artistName: item.authorName?.trim().isNotEmpty == true ? item.authorName!.trim() : 'Artist',
            artistUsername: item.authorUsername,
          ),
        );
      }
      rows.add(FeedPieceCard(item: item, onTap: () => _openApiItem(item)));
    }

    // One event card per load, on All only, never next to a series row (`NoteMain`).
    final event = _showAvailable ? null : _feedEvent;
    final at = event == null ? -1 : feedEventSlot([for (final r in rows) r is FeedSeriesRow]);
    if (event != null && at >= 0) {
      rows.insert(
        at,
        FeedEventCard(
          key: const ValueKey('feed-event'),
          event: event,
          onOpen: () => openEventDetail(context, event),
          onGetTickets: () => openEventDetail(context, event, openTickets: true),
          onArtist: (artist) => openUserProfile(context, artist.username),
        ),
      );
    }

    return RefreshIndicator(
      key: _refreshKey,
      color: context.studio.textPrimary,
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomInset),
        itemCount: rows.length + (fetching ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: StudioSpace.homePostGap),
        itemBuilder: (context, index) {
          if (index >= rows.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: context.studio.textPrimary),
                ),
              ),
            );
          }
          return rows[index];
        },
      ),
    );
  }
}
