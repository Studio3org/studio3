import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_icon.dart';

/// Like / comment (and, where the page has no top icons for them, save / share) under the
/// piece image. No board draws this row; it stays where it was (plan rule 4) in the
/// boards' style: 22 px outline icons, 13 labels, Ink (liked is filled Ink, never red).
class PieceActionBar extends StatelessWidget {
  const PieceActionBar({
    super.key,
    required this.liked,
    required this.saved,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    this.showSave = true,
    this.showShare = false,
  });

  final bool liked;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;

  /// Off on the fixed-price page, where Save sits in the top icons (`BuyPiece`).
  final bool showSave;

  /// Off unless the page has no Share in its top icons.
  final bool showShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          _ActionButton(
            icon: liked ? StudioIcons.liked : StudioIcons.like,
            label: liked ? 'Liked' : 'Like',
            onTap: onLike,
          ),
          _ActionButton(icon: StudioIcons.chat, label: 'Comment', onTap: onComment),
          const Spacer(),
          if (showShare) _ActionButton(icon: StudioIcons.share, label: 'Share', onTap: onShare),
          if (showSave)
            _ActionButton(
              icon: saved ? StudioIcons.saved : StudioIcons.save,
              label: saved ? 'Saved' : 'Save',
              onTap: onSave,
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StudioIcon(icon, size: 22, color: c.textPrimary),
                const SizedBox(width: 6),
                Text(label, style: StudioType.label13(color: c.textPrimary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
