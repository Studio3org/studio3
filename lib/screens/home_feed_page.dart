import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/feed_item.dart';
import '../models/feed_page.dart';
import '../models/feed_preview_item.dart' show FeedAvailabilityFilter;
import '../theme/home_feed_tokens.dart';
import '../utils/explore_detail_route.dart';
import '../utils/image_aspect_ratio_resolver.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/home_feed/home_feed_widgets.dart';
import '../widgets/offline_state.dart';
import '../services/connectivity_service.dart';
import '../services/feed_service.dart';
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

  List<FeedItem> get availableItems =>
      apiItems.where((item) => item.isForSale).toList();

  /// The "All" tab never shows video scenes — those live in Explore/Reels
  /// only.
  List<FeedItem> get feedItems =>
      apiItems.where((item) => !item.isVideo).toList();

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
    loadFeed();
  }

  @override
  void dispose() {
    ConnectivityService.instance.removeReconnectHook(_onReconnected);
    super.dispose();
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
      showOfflineState =
          apiItems.isEmpty && !ConnectivityService.instance.isOnline;
      notifyListeners();
    } catch (_) {
      // Keep whatever's already showing (cached or previously-loaded) on
      // a failed refresh — a silent background failure shouldn't blank a
      // screen that already has content, only a genuinely empty one
      // falls through to the offline state.
      loading = false;
      loadingMore = false;
      showOfflineState =
          apiItems.isEmpty && !ConnectivityService.instance.isOnline;
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
    showOfflineState =
        apiItems.isEmpty && !ConnectivityService.instance.isOnline;
    notifyListeners();
  }
}

/// The Home ("For You") page — a single page with one header and one
/// `Scaffold`, whose "All"/"Available" tabs switch by *tapping* only (no
/// swipe): both are just two views over the same [HomeFeedStore], toggled
/// with local state, rather than separate pages in the shell's outer
/// Home/Discover/Reels/Saved swipe sequence (`MainShell`, `lib/main.dart`).
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});

  final HomeFeedStore store;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with RouteAware, ScrollsToTopOnDoubleTap<HomePage> {
  static const double _loadMoreThreshold = 200;

  final ScrollController _scrollController = ScrollController();
  bool _showAvailable = false;

  @override
  void initState() {
    super.initState();
    widget.store.ensureInitialized();
    widget.store.addListener(_onStoreChanged);
    _scrollController.addListener(_onScroll);
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
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    widget.store.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom + 100;
    final store = widget.store;
    final items = _showAvailable ? store.availableItems : store.feedItems;
    final filter = _showAvailable
        ? FeedAvailabilityFilter.available
        : FeedAvailabilityFilter.all;

    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
              child: FeedHomeHeader(
                filter: filter,
                onFilterChanged: _onFilterTap,
                onAddTap: () => Navigator.pushNamed(context, '/post'),
                hasAvailableItems: store.availableItems.isNotEmpty,
              ),
            ),
            Expanded(
              child: _buildFeed(
                bottomInset,
                items: items,
                emptyMessage: _showAvailable
                    ? 'No available pieces yet'
                    : 'No feed items yet',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed(
    double bottomInset, {
    required List<FeedItem> items,
    required String emptyMessage,
  }) {
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
        onRefresh: () => store.refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.35),
            Center(
              child: Text(
                emptyMessage,
                style: TextStyle(
                  color: HomeFeedTokens.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => store.refresh(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomInset),
        itemCount: items.length + (store.loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeFeedTokens.sideMargin,
            ).copyWith(bottom: HomeFeedTokens.rowGap),
            child: _ApiFeedTile(item: item, onTap: () => _openApiItem(item)),
          );
        },
      ),
    );
  }
}

/// A "For You" feed card that sizes itself to the item's real posted
/// aspect ratio (3:4 or 16:9) instead of a fixed shape, so the image shows
/// fully instead of being cropped to a mismatched box.
class _ApiFeedTile extends StatefulWidget {
  const _ApiFeedTile({required this.item, required this.onTap});

  final FeedItem item;
  final VoidCallback onTap;

  @override
  State<_ApiFeedTile> createState() => _ApiFeedTileState();
}

class _ApiFeedTileState extends State<_ApiFeedTile> {
  double _aspectRatio = ImageAspectRatioResolver.portrait3x4;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _ApiFeedTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.mediaUrl != widget.item.mediaUrl) {
      _resolveAspectRatio();
    }
  }

  void _resolveAspectRatio() {
    final stored = widget.item.mediaAspectRatio;
    if (stored != null) {
      // Known synchronously from the baked-at-publish-time ratio — no
      // decode round-trip, so the tile never renders at the wrong shape
      // before snapping to the real one.
      _aspectRatio = stored == '16:9'
          ? ImageAspectRatioResolver.landscape16x9
          : ImageAspectRatioResolver.portrait3x4;
      return;
    }

    // Fallback for legacy content published before mediaAspectRatio existed
    // (and for videos, which have no crop/transform step today).
    if (widget.item.isVideo) {
      _aspectRatio = ImageAspectRatioResolver.landscape16x9;
    }
    final url = widget.item.mediaUrl;
    if (url == null) return;
    final cached = ImageAspectRatioResolver.cached(url);
    if (cached != null) {
      _aspectRatio = cached;
      return;
    }
    ImageAspectRatioResolver.resolve(url).then((ratio) {
      if (mounted) setState(() => _aspectRatio = ratio);
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final url = item.mediaUrl;

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HomeFeedTokens.cardRadius),
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url != null)
                CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  memCacheWidth:
                      (MediaQuery.sizeOf(context).width *
                              MediaQuery.devicePixelRatioOf(context))
                          .round(),
                  errorWidget: (context, error, stackTrace) =>
                      ColoredBox(color: Colors.grey.shade300),
                )
              else
                ColoredBox(color: Colors.grey.shade300),
              if (item.type == FeedItemType.piece)
                FeedApiCardOverlay(
                  avatarUrl: item.authorAvatarUrl,
                  name: item.authorName ?? 'Artist',
                  medium: item.piece?.medium,
                  authorUsername: item.authorUsername,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
