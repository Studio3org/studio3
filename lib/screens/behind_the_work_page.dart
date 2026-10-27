import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/feed_item.dart';
import '../models/piece_summary.dart';
import '../services/feed_service.dart';
import '../services/piece_service.dart';
import '../utils/reels_route.dart';
import '../widgets/studio/studio.dart';
import 'series_view_page.dart' show ScenePlayMark;

/// Explore's Behind the work, See all (`BehindTheWork`).
///
/// Back and Search (Scenes only). "Behind the work" 28/500 and "Studios, process, and art out
/// in the world." 15 Graphite, then the shelf's Scenes in the same order, 2 across at 9:16
/// (radius 12, 12 apart, 16 from the sides): the picture, a play mark on videos, the linked
/// piece's thumbnail (32 × 43, white 2 edge) when there is one, and the artist strip at the
/// bottom (24 photo with a white ring, 13/500 white over a 45 % dark band). A card opens the
/// Scene viewer, which swipes on in this order. More load as you reach the end.
class BehindTheWorkPage extends StatefulWidget {
  const BehindTheWorkPage({super.key, this.initialItems = const []});

  /// The Scenes on the shelf, in its order.
  final List<FeedItem> initialItems;

  @override
  State<BehindTheWorkPage> createState() => _BehindTheWorkPageState();
}

class _BehindTheWorkPageState extends State<BehindTheWorkPage> {
  late List<FeedItem> _items = [
    for (final item in widget.initialItems)
      if (item.type == FeedItemType.post) item,
  ];
  String? _cursor;
  bool _loading = false;
  bool _done = false;
  bool _searching = false;
  String _query = '';
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) _loadMore();
  }

  /// After the shelf's own Scenes, the rest of the Scenes feed (without repeats).
  Future<void> _loadMore() async {
    if (_loading || _done) return;
    setState(() => _loading = true);
    try {
      final page = await FeedService.instance.getVideoScenes(cursor: _cursor);
      if (!mounted) return;
      final seen = _items.map((item) => item.id).toSet();
      setState(() {
        _items = [..._items, ...page.items.where((item) => !seen.contains(item.id))];
        _cursor = page.nextCursor;
        _done = page.nextCursor == null || page.nextCursor!.isEmpty;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _done = true;
        });
      }
    }
  }

  /// Search looks at Scenes only: the caption and the artist.
  List<FeedItem> get _shown {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((item) {
      final post = item.post;
      return [
        post?.caption,
        item.authorName,
        item.authorUsername,
      ].any((text) => text != null && text.toLowerCase().contains(q));
    }).toList();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _search.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final shown = _shown;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Row(
                  children: [
                    _Icon(
                      icon: StudioIcons.back,
                      label: 'Back to Explore',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    if (_searching)
                      Expanded(
                        child: TextField(
                          controller: _search,
                          autofocus: true,
                          onChanged: (value) => setState(() => _query = value),
                          style: StudioType.sans(15, color: c.textPrimary),
                          cursorColor: c.textPrimary,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: 'Search Scenes',
                            hintStyle: StudioType.sans(15, color: c.textTertiary),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    _Icon(
                      icon: _searching ? StudioIcons.close : StudioIcons.search,
                      label: _searching ? 'Close search' : 'Search Behind the work',
                      onTap: _toggleSearch,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Behind the work',
                      style: StudioType.sans(28, weight: StudioType.medium, color: c.textPrimary)
                          .copyWith(height: 1.15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Studios, process, and art out in the world.',
                      style: StudioType.sans(15, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            if (shown.isEmpty && !_loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: StudioEmptyState(title: _query.isEmpty ? 'No Scenes yet' : 'No Scenes match'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 9 / 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => BehindTheWorkCard(
                      item: shown[i],
                      onTap: () => openScenes(context, shown[i], from: shown),
                    ),
                    childCount: shown.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: 40 + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }
}

class _Icon extends StatelessWidget {
  const _Icon({required this.icon, required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback onTap;

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

/// A 9:16 Scene card (`BehindTheWork`).
class BehindTheWorkCard extends StatefulWidget {
  const BehindTheWorkCard({super.key, required this.item, required this.onTap});

  final FeedItem item;
  final VoidCallback onTap;

  @override
  State<BehindTheWorkCard> createState() => _BehindTheWorkCardState();
}

class _BehindTheWorkCardState extends State<BehindTheWorkCard> {
  PieceSummary? _linked;

  @override
  void initState() {
    super.initState();
    _loadLinked();
  }

  /// The feed sends the linked piece's id only; its picture comes from the piece cache.
  Future<void> _loadLinked() async {
    final post = widget.item.post;
    if (post == null) return;
    if (post.linkedPiece != null) {
      _linked = post.linkedPiece;
      return;
    }
    final id = post.linkedPieceIds.isNotEmpty ? post.linkedPieceIds.first : post.pieceId;
    if (id == null || id.isEmpty) return;
    try {
      final piece = await PieceService.instance.getByIdCached(id);
      if (mounted) setState(() => _linked = piece);
    } catch (_) {
      // No thumbnail, then.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final item = widget.item;
    final url = item.thumbnailUrl ?? item.mediaUrl;
    final linkedUrl = _linked?.mediaUrl;
    final name = item.authorName ?? item.authorUsername ?? '';
    return Semantics(
      button: true,
      label: name.isEmpty ? 'Scene' : 'Scene by $name',
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
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
              if (item.isVideo) const Positioned(top: 10, left: 10, child: ScenePlayMark()),
              if (_linked != null)
                Positioned(
                  right: 10,
                  bottom: 46,
                  child: Container(
                    width: 32,
                    height: 43,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: StudioColors.galleryWhite, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: linkedUrl == null || linkedUrl.isEmpty
                          ? const ColoredBox(color: Color(0x33FFFFFF))
                          : CachedNetworkImage(imageUrl: linkedUrl, fit: BoxFit.cover),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: const Color(0x73141414),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Row(
                      children: [
                        StudioAvatar(
                          url: item.authorAvatarUrl,
                          size: 24,
                          ringWidth: 1.5,
                          ringColor: StudioColors.galleryWhite,
                          ringInside: true,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.sans(13, weight: StudioType.medium, color: StudioColors.galleryWhite),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
