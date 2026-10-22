import 'package:flutter/material.dart';

import '../../models/feed_preview_item.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_on_image.dart';

/// Pieces of the piece page shared by the fixed-price page (`BuyPiece`, `BuyPieceFull`) and
/// the not-for-sale page (`PieceNotForSale`, `ListOwnerPiece` top), which draw them the same.

/// White top icons over the image: Back; Save (not on your own piece), Share, and More —
/// or Edit in More's place on your own piece (`ListOwnerPiece` drops Save; the app's edit
/// stays reachable there).
class PieceTopIcons extends StatelessWidget {
  const PieceTopIcons({
    super.key,
    required this.isOwner,
    required this.saved,
    required this.onBack,
    required this.onSave,
    required this.onShare,
    required this.onMore,
    required this.onEdit,
  });

  final bool isOwner;
  final bool saved;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return StudioTopIconBar(
      leading: [StudioTopIcon(icon: StudioIcons.back, semanticLabel: 'Back', onTap: onBack)],
      trailing: [
        if (!isOwner)
          StudioTopIcon(
            icon: saved ? StudioIcons.saved : StudioIcons.save,
            semanticLabel: saved ? 'Saved' : 'Save',
            onTap: onSave,
          ),
        StudioTopIcon(icon: StudioIcons.share, semanticLabel: 'Share', onTap: onShare),
        if (isOwner)
          StudioTopIcon(icon: StudioIcons.edit, semanticLabel: 'Edit piece', onTap: onEdit)
        else
          StudioTopIcon(icon: StudioIcons.more, semanticLabel: 'More', onTap: onMore),
      ],
    );
  }
}

/// Title 26/500, then the medium and style tags (14 Graphite), then dimensions and year in
/// Mono 13, 8 apart; [status] (e.g. the not-for-sale line) goes under them, 6 lower.
class PieceTitleBlock extends StatelessWidget {
  const PieceTitleBlock({super.key, required this.item, this.status});

  final FeedPreviewItem item;
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final meta = [
      item.medium,
      ...item.styleTags,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    final facts = [
      item.dimensions,
      '${item.year}',
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.title, style: StudioType.title26(color: c.textPrimary)),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(meta, style: StudioType.body14(color: c.textSecondary)),
        ],
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(facts, style: StudioType.mono13(color: c.textPrimary)),
        ],
        if (status != null) ...[const SizedBox(height: 8 + 6), status!],
      ],
    );
  }
}

/// "Made with" (D7): 17/500 header, then one row per material name (15, 11 above and below,
/// 1 px Line under). The piece stores names only, so the brand column and the MATERIALS /
/// TOOLS labels stay off until the data carries them.
class PieceMadeWith extends StatelessWidget {
  const PieceMadeWith({super.key, required this.materials});

  final List<String> materials;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Made with', style: StudioType.header17(color: c.textPrimary)),
        const SizedBox(height: 2),
        for (final material in materials)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.line)),
            ),
            child: Text(material, style: StudioType.sans(15, color: c.textPrimary)),
          ),
      ],
    );
  }
}

/// "Details": 17/500 header, rows of label (14 Graphite) and value (14, right aligned),
/// 16 apart, 11 above and below, 1 px Line under. Only rows with data: Framing, Handling,
/// Ships from.
class PieceDetailsSection extends StatelessWidget {
  const PieceDetailsSection({super.key, required this.rows});

  final List<(String, String)> rows;

  static List<(String, String)> rowsFor(FeedPreviewItem item) => [
    if ((item.framingNote ?? '').trim().isNotEmpty) ('Framing', item.framingNote!.trim()),
    if ((item.handlingNotes ?? '').trim().isNotEmpty) ('Handling', item.handlingNotes!.trim()),
    if ((item.location ?? '').trim().isNotEmpty) ('Ships from', item.location!.trim()),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Details', style: StudioType.header17(color: c.textPrimary)),
        const SizedBox(height: 2),
        for (final (label, value) in rows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: StudioType.body14(color: c.textSecondary)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: StudioType.body14(color: c.textPrimary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The body's description: 16 / 1.55.
class PieceDescription extends StatelessWidget {
  const PieceDescription(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: StudioType.sans(16, height: 1.55, color: context.studio.textBody));
  }
}
