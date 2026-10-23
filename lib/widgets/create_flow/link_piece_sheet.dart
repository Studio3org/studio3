import 'package:flutter/material.dart';

import '../../models/piece_summary.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import '../home_feed/home_feed_widgets.dart';
import '../studio/studio_button.dart';
import '../studio/studio_on_image.dart';
import '../studio/studio_sheet.dart';

/// Picks the pieces a Scene shows on ("Link a piece" on `ScenePhotoDetails`). No board of
/// its own: a board sheet with the artist's pieces in a 3-up 3:4 grid; tap to link or
/// unlink; linked tiles get an Ink outline and a plain white "Linked" label, as the
/// related-Scenes grid (`NotePostRelatedScenes`). Done returns them in the order linked.
class LinkPieceSheet extends StatefulWidget {
  const LinkPieceSheet({
    super.key,
    required this.pieces,
    required this.selectedIds,
    this.title = 'Link pieces',
    this.mark = 'Linked',
  });

  final List<PieceSummary> pieces;
  final List<String> selectedIds;
  final String title;

  /// The label on a chosen tile.
  final String mark;

  static Future<List<PieceSummary>?> show(
    BuildContext context, {
    required List<PieceSummary> pieces,
    required List<String> selectedIds,
    String title = 'Link pieces',
    String mark = 'Linked',
  }) {
    return showStudioSheet<List<PieceSummary>>(
      context: context,
      builder: (_) => LinkPieceSheet(
        pieces: pieces,
        selectedIds: selectedIds,
        title: title,
        mark: mark,
      ),
    );
  }

  @override
  State<LinkPieceSheet> createState() => _LinkPieceSheetState();
}

class _LinkPieceSheetState extends State<LinkPieceSheet> {
  late final List<String> _selected = List.of(widget.selectedIds);

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final byId = {for (final p in widget.pieces) p.id: p};
    return StudioSheet(
      horizontalPadding: 24,
      gap: 16,
      scrollable: true,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.title, style: StudioType.title22(color: c.textPrimary)),
            ),
            Text(
              '${_selected.length}',
              style: StudioType.mono(13, color: c.textSecondary),
            ),
          ],
        ),
        if (widget.pieces.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Post a piece first, then link Scenes to it.',
              style: StudioType.body14(color: c.textSecondary),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.pieces.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 14,
              childAspectRatio: 0.62,
            ),
            itemBuilder: (context, i) {
              final piece = widget.pieces[i];
              final linked = _selected.contains(piece.id);
              final url = piece.mediaUrl;
              return Semantics(
                button: true,
                selected: linked,
                label: piece.title,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => _toggle(piece.id),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: linked ? c.textPrimary : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (url == null || url.isEmpty)
                                  ColoredBox(color: c.surface)
                                else
                                  FeedPicsumImage(url: url),
                                if (linked)
                                  Positioned(
                                    left: 8,
                                    bottom: 6,
                                    child: StudioImageLabel(
                                      widget.mark,
                                      mono: false,
                                      size: 12,
                                      weight: StudioType.medium,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        piece.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: StudioType.sans(12, height: 1.3, color: c.textPrimary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        StudioButton(
          label: 'Done',
          height: 54,
          onPressed: () => Navigator.pop(context, [
            for (final id in _selected)
              if (byId[id] != null) byId[id]!,
          ]),
        ),
      ],
    );
  }
}
