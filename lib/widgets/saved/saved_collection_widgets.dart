import 'package:flutter/material.dart';

import '../../models/feed_preview_item.dart';
import '../../services/saved_content_store.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../home_feed/home_feed_widgets.dart';
import '../studio/studio_chip.dart';
import '../studio/studio_icon.dart';

/// Up to four cover urls, newest first in the list the caller passes.
List<String> savedCoverUrls(List<SavedEntry> entries) {
  final urls = <String>[];
  for (final entry in entries) {
    final url = savedEntryThumbnailUrl(entry);
    if (url == null || url.isEmpty) continue;
    urls.add(url);
    if (urls.length == 4) break;
  }
  return urls;
}

/// A change line only when the saved item already carries that fact.
/// Price drops and auction deadlines are not on the payload, so they stay off.
String? savedChangeLine(SavedEntry entry) {
  final preview = entry.preview;
  if (preview == null) return null;
  if (_isCollected(preview)) return null;
  if (preview.isAvailable && preview.priceDisplay != null) {
    return 'Now listed · ${preview.priceDisplay}';
  }
  return null;
}

bool savedIsCollected(SavedEntry entry) =>
    entry.preview != null && _isCollected(entry.preview!);

bool _isCollected(FeedPreviewItem preview) =>
    preview.status?.toLowerCase() == 'collected';

double _scaledLine(BuildContext context, double size) {
  final scale = MediaQuery.textScalerOf(context).scale(size) / size;
  return size * StudioType.normalLineHeight(size) * scale;
}

/// Folder tile: square 2×2 cover, name 15/500, count in Mono 12.
class SavedFolderTile extends StatelessWidget {
  const SavedFolderTile({
    super.key,
    required this.title,
    required this.count,
    required this.imageUrls,
    required this.onTap,
    this.onLongPress,
  });

  final String title;
  final int count;
  final List<String> imageUrls;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SavedCoverGrid(imageUrls: imageUrls),
          const SizedBox(height: StudioSpace.s8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            count == 1 ? '1 piece' : '$count pieces',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: StudioType.mono(12, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class SavedCoverGrid extends StatelessWidget {
  const SavedCoverGrid({
    super.key,
    required this.imageUrls,
    this.radius = StudioRadius.panel,
  });

  final List<String> imageUrls;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fill = context.studio.surface;
    Widget cell(int index) {
      final url = index < imageUrls.length ? imageUrls[index] : null;
      if (url == null || url.isEmpty) return ColoredBox(color: fill);
      return FeedPicsumImage(url: url);
    }

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: cell(0)),
                  const SizedBox(width: 2),
                  Expanded(child: cell(1)),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: cell(2)),
                  const SizedBox(width: 2),
                  Expanded(child: cell(3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Piece inside a folder: column width × 223/167, radius 10.
class SavedPieceTile extends StatelessWidget {
  const SavedPieceTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  final SavedEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final url = savedEntryThumbnailUrl(entry);
    final change = savedChangeLine(entry);
    final collected = savedIsCollected(entry);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 167 / 223,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(StudioRadius.card),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (url != null && url.isNotEmpty)
                    FeedPicsumImage(url: url)
                  else
                    ColoredBox(color: c.surface),
                  if (entry.isVideoScene)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: StudioIcon(
                        StudioIcons.video,
                        size: 12,
                        color: StudioColors.galleryWhite,
                        semanticLabel: 'Video',
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
          ),
          if (_authorName(entry) != null)
            Text(
              _authorName(entry)!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StudioType.caption12(color: c.textSecondary),
            ),
          if (collected)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: StudioStatusChip(StudioStatus.collected),
            )
          else if (change != null)
            Text(
              change,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StudioType.caption12(color: c.positive).copyWith(
                fontWeight: StudioType.medium,
              ),
            ),
        ],
      ),
    );
  }
}

String? _authorName(SavedEntry entry) {
  final name = entry.preview?.authorName ?? entry.feedItem?.authorName;
  if (name == null || name.isEmpty) return null;
  return name;
}

class SavedEmptyState extends StatelessWidget {
  const SavedEmptyState({super.key, required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 200, 44, 0),
      child: Column(
        children: [
          const _ThreeCircles(),
          const SizedBox(height: 28),
          Text(
            'Nothing saved yet',
            textAlign: TextAlign.center,
            style: StudioType.sans(
              22,
              letterSpacing: -0.3,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap the bookmark on any piece to keep it here. Only you can see what you save.',
            textAlign: TextAlign.center,
            style: StudioType.body15(height: 1.5, color: c.textSecondary),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            key: const Key('saved-browse'),
            onTap: onBrowse,
            behavior: HitTestBehavior.opaque,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: StudioSize.tapTarget),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Browse the feed',
                    style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                  ),
                  const SizedBox(width: 6),
                  StudioIcon(StudioIcons.arrowRight, size: 16, color: c.textPrimary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreeCircles extends StatelessWidget {
  const _ThreeCircles();

  @override
  Widget build(BuildContext context) {
    final color = context.studio.line;
    return SizedBox(
      width: 76,
      height: 60,
      child: Stack(
        children: [
          Positioned(left: 0, top: 18, child: _dot(color, 28)),
          Positioned(right: 8, top: 0, child: _dot(color, 18)),
          Positioned(right: 0, bottom: 0, child: _dot(color, 12)),
        ],
      ),
    );
  }

  Widget _dot(Color color, double diameter) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Height of a folder tile for the current text scale, given its column width.
double savedFolderTileExtent(BuildContext context, double width) =>
    width + StudioSpace.s8 + _scaledLine(context, 15) + 2 + _scaledLine(context, 12);

/// Height of a piece tile, including the artist line and one change line
/// or the Collected chip, whichever is taller.
double savedPieceTileExtent(BuildContext context, double width) {
  final caption = _scaledLine(context, 12);
  final chip = 2 + 10 + _scaledLine(context, 11);
  return width * 223 / 167 + 6 + _scaledLine(context, 14) + caption + (chip > caption ? chip : caption) + 4;
}

/// Plus in the Saved header. 44 px, same slot as the board's new-folder control.
class SavedNewFolderButton extends StatelessWidget {
  const SavedNewFolderButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('saved-new-folder'),
      onPressed: onPressed,
      tooltip: 'New folder',
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: const Size(StudioSize.tapTarget, StudioSize.tapTarget),
        fixedSize: const Size(StudioSize.tapTarget, StudioSize.tapTarget),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: StudioIcon(StudioIcons.post, size: 24, color: context.studio.textPrimary),
    );
  }
}

/// The Saved tab body: privacy line, All saved, Available when something is
/// for sale, then the person's own folders.
class SavedFolderIndex extends StatelessWidget {
  const SavedFolderIndex({
    super.key,
    required this.entries,
    required this.collections,
    required this.entriesForCollection,
    required this.onOpenAll,
    required this.onOpenAvailable,
    required this.onOpenCollection,
    required this.onLongPressCollection,
    required this.onRefresh,
    this.controller,
  });

  final List<SavedEntry> entries;
  final List<SavedCollection> collections;
  final List<SavedEntry> Function(String collectionId) entriesForCollection;
  final VoidCallback onOpenAll;
  final VoidCallback onOpenAvailable;
  final void Function(SavedCollection collection) onOpenCollection;
  final void Function(SavedCollection collection) onLongPressCollection;
  final Future<void> Function() onRefresh;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final newest = List<SavedEntry>.of(entries)
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final available = newest.where((entry) => entry.preview?.isAvailable == true).toList();
    final bottom = MediaQuery.paddingOf(context).bottom +
        StudioSize.navHeight +
        StudioSize.navBottomGap +
        StudioSpace.feedGap;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - StudioSpace.marginPage * 2 - StudioSpace.s16) / 2;
        final extent = savedFolderTileExtent(context, tileWidth);
        return RefreshIndicator(
          color: c.textPrimary,
          onRefresh: onRefresh,
          child: CustomScrollView(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Only you can see what you save.',
                    style: StudioType.body14(color: c.textSecondary),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: StudioSpace.s16,
                    mainAxisSpacing: StudioSpace.s24,
                    mainAxisExtent: extent,
                  ),
                  delegate: SliverChildListDelegate([
                    SavedFolderTile(
                      title: 'All saved',
                      count: newest.length,
                      imageUrls: savedCoverUrls(newest),
                      onTap: onOpenAll,
                    ),
                    if (available.isNotEmpty)
                      SavedFolderTile(
                        title: 'Available',
                        count: available.length,
                        imageUrls: savedCoverUrls(available),
                        onTap: onOpenAvailable,
                      ),
                  ]),
                ),
              ),
              if (collections.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 16),
                  sliver: SliverToBoxAdapter(child: _YourFoldersLabel(color: c)),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, bottom),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: StudioSpace.s16,
                      mainAxisSpacing: StudioSpace.s24,
                      mainAxisExtent: extent,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final collection = collections[index];
                        final items = entriesForCollection(collection.id);
                        return SavedFolderTile(
                          title: collection.name,
                          count: items.length,
                          imageUrls: savedCoverUrls(items),
                          onTap: () => onOpenCollection(collection),
                          onLongPress: () => onLongPressCollection(collection),
                        );
                      },
                      childCount: collections.length,
                    ),
                  ),
                ),
              ] else
                SliverToBoxAdapter(child: SizedBox(height: bottom)),
            ],
          ),
        );
      },
    );
  }
}

class _YourFoldersLabel extends StatelessWidget {
  const _YourFoldersLabel({required this.color});

  final StudioColors color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'YOUR FOLDERS',
          style: StudioType.mono11(color: color.textTertiary, letterSpacing: 0.5),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: color.line)),
      ],
    );
  }
}
