import '../services/event_service.dart';
import 'event_detail_page.dart';
import '../widgets/studio/studio_toast.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/feed_item.dart';
import '../models/feed_preview_item.dart';
import '../services/auth_session.dart';
import '../services/main_nav_service.dart';
import '../services/post_service.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import '../screens/available_piece_detail_page.dart';
import '../screens/piece_detail_page.dart';
import '../services/saved_content_store.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import '../widgets/piece_detail/detail_share.dart';
import '../widgets/save_to_collection_sheet.dart';
import '../widgets/saved/saved_collection_widgets.dart';
import '../widgets/saved/saved_sheet_menus.dart';
import '../widgets/studio/studio_chip.dart';
import '../widgets/studio/studio_top_bar.dart';
import '../utils/reels_route.dart';
import '../widgets/collection_name_sheet.dart';
import '../utils/require_login.dart';
import '../utils/scrolls_to_top_on_double_tap.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage>
    with ScrollsToTopOnDoubleTap<SavedPage> {
  final _store = SavedContentStore.instance;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Saved items and collections are per-account; a guest sees a login
    // prompt instead (and signing in rebuilds this page from scratch).
    if (!AuthSession.instance.isLoggedIn) return;
    // Seed before attaching the listener so populating the store here can't
    // trigger a setState via _onStoreChanged before the first build.
    _seedFromCache();
    _store.addListener(_onStoreChanged);
    _loadSavedFromApi();
    unawaited(_store.loadCollectionsFromApi());
  }

  Future<void> _refreshSaved() => Future.wait([
        _loadSavedFromApi(),
        _store.loadCollectionsFromApi(),
      ]);

  @override
  void scrollToTopAndRefresh() {
    if (!AuthSession.instance.isLoggedIn) return;
    if (_scrollController.hasClients) {
      final reduce = MediaQuery.disableAnimationsOf(context);
      if (reduce) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
    _refreshSaved();
  }

  /// Paints Saved instantly from whatever's cached (if anything) instead of
  /// an empty state on cold app start — `_loadSavedFromApi` below still
  /// runs to confirm/silently refresh via the cached (SWR) service calls.
  void _seedFromCache() {
    final pieces = UserService.instance.peekSavedPiecesCached();
    if (pieces != null) {
      for (final piece in pieces) {
        _store.savePreview(FeedPreviewItem.fromPieceSummary(piece));
      }
    }
    final posts = PostService.instance.peekSavedPostsCached();
    if (posts != null) {
      for (final post in posts) {
        _store.saveFeedItem(FeedItem.post(post));
      }
    }
  }

  Future<void> _loadSavedFromApi() async {
    try {
      final pieces = await UserService.instance.getSavedPiecesCached(
        onBackgroundUpdate: (fresh) {
          for (final piece in fresh) {
            _store.savePreview(FeedPreviewItem.fromPieceSummary(piece));
          }
        },
      );
      for (final piece in pieces) {
        _store.savePreview(FeedPreviewItem.fromPieceSummary(piece));
      }
      final posts = await PostService.instance.getSavedPostsCached(
        onBackgroundUpdate: (fresh) {
          for (final post in fresh) {
            _store.saveFeedItem(FeedItem.post(post));
          }
        },
      );
      for (final post in posts) {
        _store.saveFeedItem(FeedItem.post(post));
      }
    } catch (_) {
      // Keep local saved entries when API is unavailable.
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onStoreChanged() => setState(() {});

  Future<void> _createCollection() async {
    final name = await CollectionNameSheet.show(context);
    if (name == null || name.isEmpty) return;
    await _store.createCollection(name);
  }

  SavedCollection? _collectionById(String id) {
    for (final collection in _store.collections) {
      if (collection.id == id) return collection;
    }
    return null;
  }

  Future<void> _showFolderActions(SavedCollection collection) async {
    final action = await SavedFolderMenu.show(context);
    if (!mounted) return;

    if (action == 'rename') {
      final name = await CollectionNameSheet.show(
        context,
        initialName: collection.name,
        title: 'Rename folder',
        actionLabel: 'Rename',
      );
      if (name != null && name.isNotEmpty) {
        await _store.renameCollection(collection.id, name);
      }
    } else if (action == 'delete') {
      final confirmed = await SavedDeleteFolderSheet.show(
        context,
        name: collection.name,
      );
      if (confirmed == true) {
        await _store.deleteCollection(collection.id);
      }
    }
  }

  void _openFolder(String? collectionId, String title, {bool availableOnly = false}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
          backgroundColor: routeContext.studio.background,
          appBar: StudioTopBar(
            context: routeContext,
            title: availableOnly ? '' : title,
            actions: collectionId == null
                ? null
                : [
                    SavedFolderOptionsButton(
                      onPressed: () {
                        final current = _collectionById(collectionId);
                        if (current != null) _showFolderActions(current);
                      },
                    ),
                  ],
          ),
          body: _SavedItemsView(
            collectionId: collectionId,
            availableOnly: availableOnly,
            onRefresh: collectionId == null
                ? _refreshSaved
                : () => _store.loadCollectionDetailFromApi(collectionId),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthSession.instance.isLoggedIn) {
      return const GuestAccountPlaceholder(
        icon: Icons.bookmark_border_rounded,
        title: 'Keep track of the art you love',
        message: 'Save pieces, follow artists, share your own work, and keep '
            'your event tickets in one place.',
      );
    }
    final c = context.studio;
    final empty = _store.entries().isEmpty && !_store.hasCollections;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(
        context: context,
        title: 'Saved',
        automaticallyImplyLeading: false,
        actions: [SavedNewFolderButton(onPressed: _createCollection)],
      ),
      body: empty
          ? RefreshIndicator(
              color: c.textPrimary,
              onRefresh: _refreshSaved,
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom +
                      StudioSize.navHeight +
                      StudioSize.navBottomGap,
                ),
                children: [
                  SavedEmptyState(onBrowse: () => MainNavService.instance.goHome()),
                ],
              ),
            )
          : SavedFolderIndex(
              entries: _store.entries(),
              collections: _store.collections,
              entriesForCollection: _store.entriesForCollection,
              onOpenAll: () => _openFolder(null, 'All saved'),
              onOpenAvailable: () => _openFolder(null, 'Available', availableOnly: true),
              onOpenCollection: (collection) => _openFolder(collection.id, collection.name),
              onLongPressCollection: _showFolderActions,
              onRefresh: _refreshSaved,
              controller: _scrollController,
            ),
    );
  }
}

/// Pieces inside a folder. All / Piece / Scene stay. Available is the same
/// view limited to items already marked for sale.
class _SavedItemsView extends StatefulWidget {
  const _SavedItemsView({
    required this.collectionId,
    required this.onRefresh,
    this.availableOnly = false,
  });

  final String? collectionId;
  final bool availableOnly;
  final Future<void> Function() onRefresh;

  @override
  State<_SavedItemsView> createState() => _SavedItemsViewState();
}

class _SavedItemsViewState extends State<_SavedItemsView> {
  final _store = SavedContentStore.instance;
  SavedContentFilter _filter = SavedContentFilter.all;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    final collectionId = widget.collectionId;
    if (collectionId != null) {
      unawaited(_store.loadCollectionDetailFromApi(collectionId));
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() => setState(() {});

  List<SavedEntry> get _items {
    final collectionId = widget.collectionId;
    final list = collectionId == null
        ? _store.entries(filter: _filter)
        : _store.entriesForCollection(collectionId, filter: _filter);
    if (widget.availableOnly) return savedAvailableEntries(list);
    final visible = List<SavedEntry>.of(list);
    if (collectionId == null) {
      visible.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    }
    return visible;
  }

  Future<void> _openEntry(SavedEntry entry) async {
    // Saved events open their event page (restored from before commit 76f4ef9). Entries
    // saved before events carried a payload are fetched, never substituted.
    if (entry.kind == SavedContentKind.event) {
      final cached = entry.event;
      if (cached != null) {
        openEventDetail(context, cached);
        return;
      }
      try {
        final event = await EventService.instance.getById(entry.id);
        if (!mounted) return;
        openEventDetail(context, event);
      } catch (_) {
        if (mounted) showStudioToast(context, 'That event is no longer available.', icon: null);
      }
      return;
    }

    if (entry.isVideoScene && entry.feedItem != null) {
      final videoItems = _store.videoSceneFeedItems;
      final index = videoItems.indexWhere((item) => item.id == entry.id);
      openReels(
        context,
        initialIndex: index >= 0 ? index : 0,
        items: videoItems,
      );
      return;
    }

    final preview = entry.preview;
    if (preview != null) {
      final page = preview.isAvailable
          ? AvailablePieceDetailPage(item: preview)
          : PieceDetailPage(item: preview);
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => page,
        ),
      );
      return;
    }

    final feedItem = entry.feedItem;
    if (feedItem != null && feedItem.type == FeedItemType.post) {
      final scenePreview = FeedPreviewItem.fromFeedItem(feedItem);
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PieceDetailPage(item: scenePreview),
        ),
      );
    }
  }

  Set<String> _foldersContaining(String entryId) {
    return {
      for (final collection in _store.collections)
        if (collection.entryIds.contains(entryId)) collection.id,
    };
  }

  Future<void> _shareEntry(SavedEntry entry) async {
    final preview = entry.preview ??
        (entry.feedItem == null ? null : FeedPreviewItem.fromFeedItem(entry.feedItem!));
    if (preview == null) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    await SharePlus.instance.share(
      ShareParams(text: buildPieceShareText(preview), sharePositionOrigin: origin),
    );
  }

  Future<void> _confirmUnsave(SavedEntry entry) async {
    final action = await SavedHoldMenu.show(
      context,
      imageUrl: savedEntryThumbnailUrl(entry),
    );
    if (!mounted || action == null) return;
    if (action == SavedHoldAction.move) {
      final picked = await SaveToCollectionSheet.pick(
        context,
        pieceTitle: entry.title,
        thumbnailUrl: savedEntryThumbnailUrl(entry),
        forSale: entry.preview?.isAvailable ?? false,
        initiallySelected: _foldersContaining(entry.id),
      );
      if (picked == null || !mounted) return;
      final targetType = entry.kind == SavedContentKind.scene ? 'post' : 'piece';
      final before = _foldersContaining(entry.id);
      for (final id in picked) {
        if (before.contains(id)) continue;
        _store.addEntryToCollection(id, entry.id, targetType: targetType);
      }
      final source = widget.collectionId;
      if (source != null && before.contains(source) && !picked.contains(source)) {
        _store.removeEntryFromCollection(source, entry.id, targetType: targetType);
      }
      return;
    }
    if (action == SavedHoldAction.share) {
      await _shareEntry(entry);
      return;
    }
    if (action == SavedHoldAction.remove) {
      try {
        if (entry.kind == SavedContentKind.scene) {
          await SocialService.instance.unsavePost(entry.id);
        } else {
          await SocialService.instance.unsavePiece(entry.id);
        }
      } catch (_) {
        // Keep local removal even if API call fails.
      }
      _store.unsave(entry.id);
    }
  }

  String _emptyMessage() {
    switch (_filter) {
      case SavedContentFilter.all:
        return 'Saved pieces and scenes will appear here';
      case SavedContentFilter.piece:
        return 'No saved pieces yet';
      case SavedContentFilter.scene:
        return 'No saved scenes yet';
      case SavedContentFilter.event:
        return 'No saved events yet';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.availableOnly) {
      return SavedAvailableBody(
        entries: _items,
        onOpen: _openEntry,
        onLongPress: _confirmUnsave,
        onRefresh: widget.onRefresh,
      );
    }
    final c = context.studio;
    final items = _items;
    final bottom = MediaQuery.paddingOf(context).bottom + StudioSpace.marginPage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              StudioChip(
                label: 'All',
                selected: _filter == SavedContentFilter.all,
                onTap: () => setState(() => _filter = SavedContentFilter.all),
              ),
              const SizedBox(width: 8),
              StudioChip(
                label: 'Piece',
                selected: _filter == SavedContentFilter.piece,
                onTap: () => setState(() => _filter = SavedContentFilter.piece),
              ),
              const SizedBox(width: 8),
              StudioChip(
                label: 'Scene',
                selected: _filter == SavedContentFilter.scene,
                onTap: () => setState(() => _filter = SavedContentFilter.scene),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Text(
            items.length == 1 ? '1 piece' : '${items.length} pieces',
            style: StudioType.mono(12, color: c.textSecondary),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth =
                  (constraints.maxWidth - StudioSpace.marginPage * 2 - StudioSpace.s16) / 2;
              final extent = savedPieceTileExtent(context, tileWidth);
              if (items.isEmpty) {
                return RefreshIndicator(
                  color: c.textPrimary,
                  onRefresh: widget.onRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 48, 20, bottom),
                    children: [
                      Text(
                        _emptyMessage(),
                        textAlign: TextAlign.center,
                        style: StudioType.body14(color: c.textSecondary),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                color: c.textPrimary,
                onRefresh: widget.onRefresh,
                child: GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 8, 20, bottom),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: StudioSpace.s16,
                    mainAxisSpacing: StudioSpace.s20,
                    mainAxisExtent: extent,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    return SavedPieceTile(
                      entry: entry,
                      onTap: () => _openEntry(entry),
                      onLongPress: () => _confirmUnsave(entry),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
