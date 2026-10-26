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

  bool _initialized = false;

  List<FeedItem> get availableItems => apiItems.where((item) => item.isForSale).toList();

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
    final before = apiItems.length;
    apiItems.removeWhere((item) => store.isBlocked(item.authorUsername));
    if (apiItems.length != before) notifyListeners();
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
      }
      nextCursor = page.nextCursor;
      loading = false;
      loadingMore = false;
      showOfflineState = apiItems.isEmpty && !ConnectivityService.instance.isOnline;
      notifyListeners();
    } catch (_) {
      // Keep whatever's already showing (cached or previously-loaded) on
      // a failed refresh — a silent background failure shouldn't blank a
      // screen that already has content, only a genuinely empty one
      // falls through to the offline state.
      loading = false;
      loadingMore = false;
      showOfflineState = apiItems.isEmpty && !ConnectivityService.instance.isOnline;
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

class _HomePageState extends State<HomePage> with RouteAware, ScrollsToTopOnDoubleTap<HomePage> {
  static const double _loadMoreThreshold = 200;

  final ScrollController _scrollController = ScrollController();
  bool _showAvailable = false;

  /// The one event card for this feed load (`NoteMain`): picked when the feed loads and again
  /// on pull to refresh.
  StudioEvent? _feedEvent;

  @override
  void initState() {
    super.initState();
    widget.store.ensureInitialized();
    widget.store.addListener(_onStoreChanged);
    _scrollController.addListener(_onScroll);
    _loadFeedEvent();
  }

  Future<void> _loadFeedEvent() async {
    final given = widget.debugFeedEvent;
    if (given != null) {
      _feedEvent = given;
      return;
    }
    try {
      final browse = await EventService.instance.browseCached();
      final picked = pickFeedEvent(browse, DateTime.now());
      if (picked == null) {
        if (mounted) setState(() => _feedEvent = null);
        return;
      }
      if (mounted) setState(() => _feedEvent = picked);
      // The browse card has no lineup; the detail says whether to show "Showing work".
      final full = await EventService.instance.getById(picked.id);
      if (mounted && _feedEvent?.id == full.id) setState(() => _feedEvent = full);
    } catch (_) {
      // No card this time; the feed itself is unaffected.
    }
  }

  Future<void> _refresh() async {
    await widget.store.refresh();
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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() => widget.store.refresh();

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    final store = widget.store;
    if (store.loadingMore) return;
    if (store.nextCursor == null || store.nextCursor!.isEmpty) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (!pos.hasPixels || !pos.hasViewportDimension) return;
    if (pos.pixels >= pos.maxScrollExtent - _loadMoreThreshold) {
      store.loadMore();
    }
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
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void scrollToTopAndRefresh() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    widget.store.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom + 64 + 28 + 20;
    final store = widget.store;
    final items = _showAvailable ? store.availableItems : store.feedItems;
    final filter = _showAvailable ? FeedAvailabilityFilter.available : FeedAvailabilityFilter.all;

    return Scaffold(
      backgroundColor: context.studio.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FeedHomeHeader(
              filter: filter,
              onFilterChanged: _onFilterTap,
              hasAvailableItems: store.availableItems.isNotEmpty,
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
    if (store.loading && store.apiItems.isEmpty) {
      // First-load only — a revisit (cache hit) never reaches this branch
      // since loading is seeded false whenever peekForYouCached() finds
      // something in ensureInitialized().
      return const FeedListSkeleton();
    }

    if (items.isEmpty) {
      return RefreshIndicator(
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
      color: context.studio.textPrimary,
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomInset),
        itemCount: rows.length + (store.loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: StudioSpace.feedGap),
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
