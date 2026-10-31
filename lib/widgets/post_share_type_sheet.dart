import 'package:flutter/material.dart';

import '../services/drafts_service.dart';
import 'studio/studio.dart';

/// What + opens (`PostCreate`, "Post 0: what are you sharing").
enum PostShareChoice { piece, scene, drafts }

/// "What are you sharing?" (`PostCreate`): title 20/500 centred, then Piece ("A finished work,
/// up to 4 angles") and Scene ("Process, studio, or anything else") with a 20 icon in a 44
/// Surface square (radius 12), title 17/500 and a 13 Graphite line; then, under a Line and only
/// when there is at least one draft, a plain Drafts row with its Mono count and a chevron.
class PostShareTypeSheet extends StatefulWidget {
  const PostShareTypeSheet({super.key});

  static Future<PostShareChoice?> show(BuildContext context) {
    return showStudioSheet<PostShareChoice>(
      context: context,
      builder: (_) => const PostShareTypeSheet(),
    );
  }

  /// + in the bottom bar: the chooser, then the picker for that type, or Drafts.
  static Future<void> showAndOpenPost(BuildContext context) async {
    final choice = await show(context);
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case PostShareChoice.piece:
        await Navigator.pushNamed(context, '/post', arguments: 'piece');
      case PostShareChoice.scene:
        await Navigator.pushNamed(context, '/post', arguments: 'scene');
      case PostShareChoice.drafts:
        await Navigator.pushNamed(context, '/drafts');
    }
  }

  @override
  State<PostShareTypeSheet> createState() => _PostShareTypeSheetState();
}

class _PostShareTypeSheetState extends State<PostShareTypeSheet> {
  int _drafts = 0;

  @override
  void initState() {
    super.initState();
    _countDrafts();
  }

  Future<void> _countDrafts() async {
    try {
      final drafts = await DraftsService.instance.pieces();
      if (mounted) setState(() => _drafts = drafts.length);
    } catch (_) {
      // No row: Drafts only shows when we know there is one.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 0,
      children: [
        const SizedBox(height: 18),
        Text(
          'What are you sharing?',
          textAlign: TextAlign.center,
          style: StudioType.sans(20, weight: StudioType.medium, color: c.textPrimary),
        ),
        const SizedBox(height: 10),
        _TypeRow(
          icon: StudioIcons.pieceGrid,
          title: 'Piece',
          line: 'A finished work, up to 4 angles',
          onTap: () => Navigator.pop(context, PostShareChoice.piece),
        ),
        _TypeRow(
          icon: StudioIcons.scene,
          title: 'Scene',
          line: 'Process, studio, or anything else',
          onTap: () => Navigator.pop(context, PostShareChoice.scene),
        ),
        if (_drafts > 0) ...[
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label: 'Drafts, $_drafts',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => Navigator.pop(context, PostShareChoice.drafts),
              child: Container(
                padding: const EdgeInsets.only(top: 14),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
                child: Row(
                  children: [
                    Text('Drafts', style: StudioType.sans(15, color: c.textPrimary)),
                    const SizedBox(width: 4),
                    Text('$_drafts', style: StudioType.mono(12, color: c.textSecondary)),
                    const Spacer(),
                    StudioIcon(StudioIcons.chevronRight, size: 18, color: c.textPlaceholder),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
      ],
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.icon, required this.title, required this.line, required this.onTap});

  final String icon;
  final String title;
  final String line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
                child: StudioIcon(icon, size: 20, color: c.textPrimary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: StudioType.sans(17, weight: StudioType.medium, color: c.textPrimary)),
                    const SizedBox(height: 3),
                    Text(line, style: StudioType.sans(13, color: c.textSecondary)),
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
