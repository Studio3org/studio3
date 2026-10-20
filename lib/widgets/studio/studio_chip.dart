import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import 'studio_iridescent.dart';

/// Filter chip: 36 tall, round, 0 14 padding, 14/500. Off = 1 px #D4D4D0 outline on
/// white; on = Ink fill (`Explore`, `NotifActivity` tabs).
class StudioChip extends StatelessWidget {
  const StudioChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.horizontalPadding = 14,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final fg = selected ? c.buttonText : c.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: StudioMotion.quick,
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            color: selected ? c.buttonFill : c.card,
            borderRadius: BorderRadius.circular(StudioRadius.round),
            border: Border.all(color: selected ? c.buttonFill : c.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                IconTheme.merge(
                  data: IconThemeData(color: fg, size: 14),
                  child: leading!,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: StudioType.body14(weight: StudioType.medium, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum StudioStatus { available, collected, notForSale }

/// Status chips stay pills (`HandoffRules` "Top of images"): Mono 11.
/// * Available: 7 px green dot, 1 px Line outline, 5 10 padding (`Main`).
/// * Collected: iridescent fill, Ink text, 5 10 padding — the only iridescent chip.
/// * Not for sale: 1 px #D4D4D0 outline, 4 10 padding (`PieceNotForSale`).
class StudioStatusChip extends StatelessWidget {
  const StudioStatusChip(this.status, {super.key, this.label});

  final StudioStatus status;

  /// Overrides the default word ("Available", "Collected", "Not for sale").
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    switch (status) {
      case StudioStatus.available:
        return _pill(
          border: c.line,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: c.available, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label ?? 'Available', style: StudioType.mono11(color: c.textPrimary)),
          ],
        );
      case StudioStatus.collected:
        // The iridescent fill is light in both themes, so the text stays Ink.
        return StudioIridescent(
          borderRadius: BorderRadius.circular(StudioRadius.round),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(label ?? 'Collected', style: StudioType.mono11(color: StudioColors.ink)),
          ),
        );
      case StudioStatus.notForSale:
        return _pill(
          border: c.lineStrong,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          children: [Text(label ?? 'Not for sale', style: StudioType.mono11(color: c.textPrimary))],
        );
    }
  }

  Widget _pill({
    required Color border,
    required EdgeInsets padding,
    required List<Widget> children,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StudioRadius.round),
        border: Border.all(color: border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
