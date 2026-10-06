import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../models/feed_item.dart';
import '../models/feed_page.dart';
import '../services/connectivity_service.dart';
import '../services/feed_service.dart';
import '../services/reels_tab_service.dart';
import '../utils/scrolls_to_top_on_double_tap.dart';
import '../utils/snappy_page_physics.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/reels/reel_player_page.dart';

/// App-wide observer so ReelsPage can pause playback when another route is
/// pushed on top of it (e.g. opening a reel author's profile).
final routeObserver = RouteObserver<PageRoute>();

class ReelsPage extends StatefulWidget {
  const ReelsPage({
    super.key,
    this.initialIndex = 0,
    this.initialItems,
    this.activeListenable,
    this.jumpRequests,
  });

  final int initialIndex;
  final List<FeedItem>? initialItems;

  /// Whether this Reels instance is the currently visible bottom-nav tab —
  /// a [ValueListenable] (rather than a plain bool) so the host (MainShell)
  /// can flip it without reconstructing this widget: that lets MainShell
  /// build its tab list once as a fully-`const` `late final`, instead of
  /// rebuilding a fresh `ReelsPage` on every nav tap. `null` (the default
  /// for standalone pushes, e.g. from a saved-video deep link) means always
  /// active. Playback still pauses independently while another route is
  /// pushed on top (see [_routePaused]).
  final ValueListenable<bool>? activeListenable;

  /// Fires when a "open this video" call site (see
  /// `lib/utils/reels_route.dart`/`ReelsTabService`) wants this already-live
  /// tab to jump to a specific video without being rebuilt — `initialIndex`/
  /// `initialItems` are only read once in [State.initState], so they can't
  /// do this on their own for a tab that's already mounted.
  final ValueListenable<ReelsJumpRequest?>? jumpRequests;

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage>
    with RouteAware, ScrollsToTopOnDoubleTap<ReelsPage> {
  late final PageController _pageController;
  List<FeedItem> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextCursor;
  int _currentIndex = 0;
  bool _routePaused = false;
  bool _isActive = true;

  bool get _playbackActive => _isActive && !_routePaused;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _isActive = widget.activeListenable?.value ?? true;
    widget.activeListenable?.addListener(_onActiveChanged);
    widget.jumpRequests?.addListener(_onJumpRequest);
    _pageController = PageController(initialPage: widget.initialIndex);
    ConnectivityService.instance.addReconnectHook(_onReconnected);
    _loadItems();
  }

  void _onActiveChanged() {
    if (!mounted) return;
    setState(() => _isActive = widget.activeListenable!.value);
  }

  void _onJumpRequest() {
    final request = widget.jumpRequests?.value;
    if (request == null || !mounted) return;
    final index = request.items.isEmpty
        ? 0
        : request.index.clamp(0, request.items.length - 1);
    setState(() {
      _items = List<FeedItem>.from(request.items);
      _currentIndex = index;
      _loading = false;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  Future<void> _onReconnected() => _loadItems(refresh: true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didPushNext() {
    setState(() => _routePaused = true);
  }

  @override
  void didPopNext() {
    setState(() => _routePaused = false);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    widget.activeListenable?.removeListener(_onActiveChanged);
    widget.jumpRequests?.removeListener(_onJumpRequest);
    _pageController.dispose();
    ConnectivityService.instance.removeReconnectHook(_onReconnected);
    super.dispose();
  }

  Future<void> _loadItems({bool append = false, bool refresh = false}) async {
    if (widget.initialItems != null && widget.initialItems!.isNotEmpty && !append) {
      setState(() {
        _items = List<FeedItem>.from(widget.initialItems!);
        _loading = false;
      });
      return;
    }
    if (append) {
      if (_loadingMore || _nextCursor == null || _nextCursor!.isEmpty) return;
      setState(() => _loadingMore = true);
    } else if (_items.isEmpty || refresh) {
      setState(() => _loading = _items.isEmpty);
    }
    try {
      final page = append
          ? await FeedService.instance.getVideoScenes(cursor: _nextCursor)
          : await FeedService.instance.getExploreCached(
              videoOnly: true,
              forceRefresh: refresh,
              onBackgroundUpdate: _onBackgroundUpdate,
            );
      if (!mounted) return;
      setState(() {
        if (append) {
          _items.addAll(page.items);
        } else {
          _items = page.items;
        }
        _nextCursor = page.nextCursor;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!append) _items = [];
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  /// Applies a page fetched silently in the background (see
  /// [CacheService.fetchWithCache]'s `onBackgroundUpdate`) — mirrors
  /// `HomeFeedStore._mergeBackgroundPage`'s replace-from-page-1 convention,
  /// so a stale cached page (e.g. opened before new videos were published)
  /// self-heals without requiring a manual pull-to-refresh.
  void _onBackgroundUpdate(FeedPage page) {
    if (!mounted) return;
    setState(() {
      _items = page.items;
      _nextCursor = page.nextCursor;
    });
  }

  void _maybeLoadMore(int index) {
    if (_loadingMore || _nextCursor == null || _nextCursor!.isEmpty) return;
    if (index < _items.length - 2) return;
    _loadItems(append: true);
  }

  Future<void> _onRefresh() async {
    await _loadItems(refresh: true);
    if (!mounted || _items.isEmpty) return;
    final nextIndex = _currentIndex.clamp(0, _items.length - 1);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(nextIndex);
    }
    setState(() => _currentIndex = nextIndex);
  }

  @override
  void scrollToTopAndRefresh() {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    setState(() => _currentIndex = 0);
    _onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 96;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading && _items.isEmpty
          ? const ReelSkeleton()
          : _items.isEmpty
            ? RefreshIndicator(
                color: Colors.white,
                backgroundColor: Colors.black,
                onRefresh: _onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 240),
                    Center(
                      child: Text(
                        'No scene videos yet',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                color: Colors.white,
                backgroundColor: Colors.black,
                onRefresh: _onRefresh,
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  physics: const SnappyPageScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  itemCount: _items.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                    _maybeLoadMore(index);
                  },
                  itemBuilder: (context, index) {
                    return ReelPlayerPage(
                      key: ValueKey(_items[index].id),
                      item: _items[index],
                      isActive: index == _currentIndex && _playbackActive,
                      bottomOverlayPadding: bottomPadding,
                    );
                  },
                ),
              ),
    );
  }
}
