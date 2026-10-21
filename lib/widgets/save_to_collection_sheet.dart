import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/saved_content_store.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import 'collection_name_sheet.dart';
import 'home_feed/home_feed_widgets.dart';
import 'saved/saved_collection_widgets.dart';
import 'studio/studio_button.dart';
import 'studio/studio_icon.dart';
import 'studio/studio_sheet.dart';

/// Outcome of [resolveSaveCollection]. Dismissing the sheet cancels the save.
/// `collectionIds` are the extra folders; an empty list still saves to All saved.
class SaveResolution {
  const SaveResolution._(this.cancelled, this.collectionIds);

  factory SaveResolution.proceed(String? collectionId) =>
      SaveResolution._(false, [?collectionId]);

  factory SaveResolution.proceedMany(List<String> collectionIds) =>
      SaveResolution._(false, List<String>.unmodifiable(collectionIds));

  static const proceedDefault = SaveResolution._(false, []);
  static const cancelledResult = SaveResolution._(true, []);

  final bool cancelled;
  final List<String> collectionIds;

  String? get collectionId => collectionIds.isEmpty ? null : collectionIds.first;
}

/// Resolves which folders a new save should land in.
///
/// With no folders yet, this returns immediately and the piece goes to All
/// saved. Once a folder exists, the picker opens. Dismissing it cancels the
/// save. Done saves to All saved plus every folder left checked.
Future<SaveResolution> resolveSaveCollection(
  BuildContext context, {
  String? pieceTitle,
  String? thumbnailUrl,
  bool forSale = false,
}) async {
  if (!SavedContentStore.instance.hasCollections) {
    return SaveResolution.proceedDefault;
  }
  final picked = await SaveToCollectionSheet.pick(
    context,
    pieceTitle: pieceTitle,
    thumbnailUrl: thumbnailUrl,
    forSale: forSale,
  );
  if (picked == null) return SaveResolution.cancelledResult;
  return SaveResolution.proceedMany(picked);
}

class _SheetFolder {
  const _SheetFolder({
    required this.id,
    required this.name,
    required this.count,
    required this.imageUrls,
  });

  final String id;
  final String name;
  final int count;
  final List<String> imageUrls;
}

/// Folder picker from `SavedSheet`. All saved stays checked. Available is
/// omitted. New folder is the last tile.
class SaveToCollectionSheet extends StatelessWidget {
  const SaveToCollectionSheet({super.key});

  static Future<List<String>?> pick(
    BuildContext context, {
    String? pieceTitle,
    String? thumbnailUrl,
    bool forSale = false,
    Set<String> initiallySelected = const {},
  }) {
    final store = SavedContentStore.instance;
    final entries = store.entries()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final folders = [
      for (final collection in store.collections)
        _SheetFolder(
          id: collection.id,
          name: collection.name,
          count: collection.entryIds.length,
          imageUrls: savedCoverUrls(store.entriesForCollection(collection.id)),
        ),
    ];
    return showStudioSheet<List<String>>(
      context: context,
      builder: (sheetContext) => SavedFolderPicker(
        pieceTitle: pieceTitle,
        thumbnailUrl: thumbnailUrl,
        forSale: forSale,
        allSavedCount: entries.length,
        allSavedImageUrls: savedCoverUrls(entries),
        folders: [
          for (final folder in folders)
            SavedSheetFolder(
              id: folder.id,
              name: folder.name,
              count: folder.count,
              imageUrls: folder.imageUrls,
            ),
        ],
        initiallySelected: initiallySelected,
        onDone: (ids) => Navigator.pop(sheetContext, ids),
        onNewFolder: (selected) async {
          final name = await CollectionNameSheet.show(
            sheetContext,
            pieceTitle: pieceTitle,
          );
          if (name == null || name.isEmpty || !sheetContext.mounted) return;
          final collection = await SavedContentStore.instance.createCollection(name);
          if (!sheetContext.mounted) return;
          Navigator.pop(sheetContext, {...selected, collection.id}.toList());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class SavedSheetFolder {
  const SavedSheetFolder({
    required this.id,
    required this.name,
    required this.count,
    this.imageUrls = const [],
  });

  final String id;
  final String name;
  final int count;
  final List<String> imageUrls;
}

class SavedFolderPicker extends StatefulWidget {
  const SavedFolderPicker({
    super.key,
    required this.allSavedCount,
    required this.folders,
    required this.onDone,
    required this.onNewFolder,
    this.pieceTitle,
    this.thumbnailUrl,
    this.forSale = false,
    this.allSavedImageUrls = const [],
    this.initiallySelected = const {},
  });

  final String? pieceTitle;
  final String? thumbnailUrl;
  final bool forSale;
  final int allSavedCount;
  final List<String> allSavedImageUrls;
  final List<SavedSheetFolder> folders;
  final Set<String> initiallySelected;
  final ValueChanged<List<String>> onDone;
  final ValueChanged<Set<String>> onNewFolder;

  @override
  State<SavedFolderPicker> createState() => _SavedFolderPickerState();
}

class _SavedFolderPickerState extends State<SavedFolderPicker> {
  late final Set<String> _selected = {...widget.initiallySelected};

  void _toggle(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final title = widget.pieceTitle?.trim();
    final subtitle = (title == null || title.isEmpty)
        ? null
        : widget.forSale
            ? '$title · for sale, so it\'s also in Available'
            : title;
    final tiles = 1 + widget.folders.length + 1;

    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 14,
      scrollable: true,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 42,
                height: 56,
                child: (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
                    ? FeedPicsumImage(url: widget.thumbnailUrl!)
                    : ColoredBox(color: c.surface),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saved', style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: StudioType.label13(color: c.textSecondary)),
                  ],
                ],
              ),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cell = (constraints.maxWidth - StudioSpace.s12 * 2) / 3;
            final image = cell - 4;
            final extent = image +
                4 +
                6 +
                _line(context, 13) +
                2 +
                _line(context, 11) +
                4;
            final rows = (tiles / 3).ceil();
            final full = rows * extent + (rows - 1) * StudioSpace.s16;
            return SizedBox(
              height: math.min(full, 300),
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                physics: const ClampingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: StudioSpace.s12,
                  mainAxisSpacing: StudioSpace.s16,
                  mainAxisExtent: extent,
                ),
                itemCount: tiles,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _FolderChoice(
                      id: 'all',
                      name: 'All saved',
                      count: widget.allSavedCount,
                      imageUrls: widget.allSavedImageUrls,
                      selected: true,
                      onTap: () {},
                    );
                  }
                  if (index == tiles - 1) {
                    return _NewFolderTile(onTap: () => widget.onNewFolder(_selected));
                  }
                  final folder = widget.folders[index - 1];
                  return _FolderChoice(
                    id: folder.id,
                    name: folder.name,
                    count: folder.count,
                    imageUrls: folder.imageUrls,
                    selected: _selected.contains(folder.id),
                    onTap: () => _toggle(folder.id),
                  );
                },
              ),
            );
          },
        ),
        StudioButton(
          label: 'Done',
          onPressed: () => widget.onDone(_selected.toList()),
        ),
      ],
    );
  }
}

double _line(BuildContext context, double size) {
  final scale = MediaQuery.textScalerOf(context).scale(size) / size;
  return size * StudioType.normalLineHeight(size) * scale;
}

class _FolderChoice extends StatelessWidget {
  const _FolderChoice({
    required this.id,
    required this.name,
    required this.count,
    required this.imageUrls,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String name;
  final int count;
  final List<String> imageUrls;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      checked: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              key: Key('saved-folder-outline-$id'),
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(StudioRadius.button),
                        child: SavedCoverGrid(
                          imageUrls: imageUrls,
                          radius: StudioRadius.button,
                        ),
                      ),
                      if (selected)
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(StudioRadius.button),
                              border: Border.all(color: c.textPrimary, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StudioType.label13(
                weight: selected ? StudioType.medium : StudioType.regular,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StudioType.mono11(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewFolderTile extends StatelessWidget {
  const _NewFolderTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return GestureDetector(
      key: const Key('saved-new-folder-tile'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: CustomPaint(
                painter: _DashedRRectPainter(color: c.lineStrong, radius: StudioRadius.button),
                child: Center(
                  child: StudioIcon(StudioIcons.newFolder, size: 22, color: c.textSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'New folder',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: StudioType.label13(color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(
          RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(0.5),
        );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + 4, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 3;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
