import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/feed_item.dart';
import '../models/feed_preview_item.dart';
import '../services/post_service.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import '../screens/available_piece_detail_page.dart';
import '../screens/piece_detail_page.dart';
import '../services/saved_content_store.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/reels_route.dart';
import '../widgets/collection_name_sheet.dart';
import '../widgets/home_feed/home_feed_widgets.dart';
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
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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

  Future<void> _showFolderActions(SavedCollection collection) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HomeFeedTokens.detailBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(
                  'Rename',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: HomeFeedTokens.textPrimary,
                  ),
                ),
                onTap: () => Navigator.pop(context, 'rename'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  'Delete',
                  style: GoogleFonts.inter(fontSize: 16, color: Colors.red),
                ),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;

    if (action == 'rename') {
      final name = await CollectionNameSheet.show(
        context,
        initialName: collection.name,
        title: 'Rename collection',
        actionLabel: 'Rename',
      );
      if (name != null && name.isNotEmpty) {
        await _store.renameCollection(collection.id, name);
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: HomeFeedTokens.background,
          title: Text(
            'Delete "${collection.name}"?',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
          content: Text(
            'Saved items inside will stay in Saved — only this folder is removed.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: HomeFeedTokens.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: HomeFeedTokens.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await _store.deleteCollection(collection.id);
      }
    }
  }

  void _openFolder(String? collectionId, String title) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: HomeFeedTokens.background,
          appBar: AppBar(
            backgroundColor: HomeFeedTokens.background,
            elevation: 0,
            iconTheme: const IconThemeData(color: HomeFeedTokens.textPrimary),
            title: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: HomeFeedTokens.textPrimary,
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: _SavedItemsView(
              collectionId: collectionId,
              onRefresh: collectionId == null
                  ? _refreshSaved
                  : () => _store.loadCollectionDetailFromApi(collectionId),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Saved',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: HomeFeedTokens.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add,
                      color: HomeFeedTokens.textPrimary,
                    ),
                    tooltip: 'Create collection',
                    onPressed: _createCollection,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _store.hasCollections
                  ? _SavedFoldersGrid(
                      store: _store,
                      controller: _scrollController,
                      onOpenFolder: _openFolder,
                      onCreate: _createCollection,
                      onLongPressFolder: _showFolderActions,
                      onRefresh: _refreshSaved,
                    )
                  : _SavedItemsView(
                      collectionId: null,
                      controller: _scrollController,
                      onRefresh: _refreshSaved,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The existing filter-tabs + 3-column grid, scoped to either the flat
/// "Saved" bucket (`collectionId == null`) or a single collection.
class _SavedItemsView extends StatefulWidget {
  const _SavedItemsView({
    required this.collectionId,
    required this.onRefresh,
    this.controller,
  });

  final String? collectionId;
  final Future<void> Function() onRefresh;
  final ScrollController? controller;

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
    return collectionId == null
        ? _store.entries(filter: _filter)
        : _store.entriesForCollection(collectionId, filter: _filter);
  }

  void _openEntry(SavedEntry entry) {
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

  Future<void> _confirmUnsave(SavedEntry entry) async {
    final remove = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: HomeFeedTokens.detailBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.bookmark_remove_outlined),
                title: Text(
                  'Remove from saved',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: HomeFeedTokens.textPrimary,
                  ),
                ),
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (remove == true) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FeedFilterTab(
                label: 'All',
                active: _filter == SavedContentFilter.all,
                onTap: () => setState(() => _filter = SavedContentFilter.all),
              ),
              const SizedBox(width: 24),
              FeedFilterTab(
                label: 'Piece',
                active: _filter == SavedContentFilter.piece,
                onTap: () =>
                    setState(() => _filter = SavedContentFilter.piece),
              ),
              const SizedBox(width: 24),
              FeedFilterTab(
                label: 'Scene',
                active: _filter == SavedContentFilter.scene,
                onTap: () =>
                    setState(() => _filter = SavedContentFilter.scene),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: widget.controller,
                    children: [
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
                      Center(
                        child: Text(
                          _emptyMessage(),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: HomeFeedTokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: GridView.builder(
                    controller: widget.controller,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                      childAspectRatio: 1,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final entry = items[index];
                      return _SavedGridCard(
                        entry: entry,
                        onTap: () => _openEntry(entry),
                        onLongPress: () => _confirmUnsave(entry),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _SavedGridCard extends StatelessWidget {
  const _SavedGridCard({
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  final SavedEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isVideo = entry.isVideoScene;
    final imageUrl = savedEntryThumbnailUrl(entry);

    return Material(
      color: HomeFeedTokens.textPrimary.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              FeedPicsumImage(url: imageUrl)
            else
              ColoredBox(
                color: HomeFeedTokens.textPrimary.withValues(alpha: 0.08),
                child: Icon(
                  Icons.image_outlined,
                  color: HomeFeedTokens.textSecondary.withValues(alpha: 0.7),
                  size: 28,
                ),
              ),
            if (isVideo) ...[
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.28),
              ),
              const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Two-column grid of "Saved" (all items) plus every user-created
/// collection, Instagram-style — shown once at least one collection exists.
class _SavedFoldersGrid extends StatelessWidget {
  const _SavedFoldersGrid({
    required this.store,
    required this.onOpenFolder,
    required this.onCreate,
    required this.onLongPressFolder,
    required this.onRefresh,
    this.controller,
  });

  final SavedContentStore store;
  final void Function(String? collectionId, String title) onOpenFolder;
  final VoidCallback onCreate;
  final void Function(SavedCollection collection) onLongPressFolder;
  final Future<void> Function() onRefresh;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final collections = store.collections;
    final itemCount = collections.length + 2; // "Saved" tile + "+" tile

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: GridView.builder(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.92,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            final cover = store.mostRecentEntryOverall();
            return _SavedFolderTile(
              title: 'Saved',
              count: store.entries().length,
              imageUrl: cover != null ? savedEntryThumbnailUrl(cover) : null,
              icon: Icons.bookmark,
              onTap: () => onOpenFolder(null, 'Saved'),
            );
          }
          if (index == itemCount - 1) {
            return _SavedFolderTile(
              title: 'New collection',
              count: null,
              imageUrl: null,
              icon: Icons.add,
              onTap: onCreate,
            );
          }
          final collection = collections[index - 1];
          final items = store.entriesForCollection(collection.id);
          final cover = items.isNotEmpty ? items.first : null;
          return _SavedFolderTile(
            title: collection.name,
            count: items.length,
            imageUrl: cover != null ? savedEntryThumbnailUrl(cover) : null,
            icon: Icons.folder_outlined,
            onTap: () => onOpenFolder(collection.id, collection.name),
            onLongPress: () => onLongPressFolder(collection),
          );
        },
      ),
    );
  }
}

class _SavedFolderTile extends StatelessWidget {
  const _SavedFolderTile({
    required this.title,
    required this.count,
    required this.imageUrl,
    required this.icon,
    required this.onTap,
    this.onLongPress,
  });

  final String title;
  final int? count;
  final String? imageUrl;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(HomeFeedTokens.cardRadius),
      child: Material(
        color: HomeFeedTokens.textPrimary.withValues(alpha: 0.06),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl!.isNotEmpty)
                      FeedPicsumImage(url: imageUrl!)
                    else
                      ColoredBox(
                        color: HomeFeedTokens.textPrimary.withValues(alpha: 0.08),
                        child: Icon(
                          icon,
                          color:
                              HomeFeedTokens.textSecondary.withValues(alpha: 0.7),
                          size: 32,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: HomeFeedTokens.textPrimary,
                        ),
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: HomeFeedTokens.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
