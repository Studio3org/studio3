import 'package:flutter/material.dart';

import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';

/// A plain card: Card colour, a 1 px Line, radius 14 (the old frosted glass is gone; no blur
/// in the redesign). Kept for the screens that still use it; Phase 11 removes it.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Container(
      padding: padding ?? const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(StudioRadius.panel),
        border: Border.all(color: c.line),
      ),
      child: child,
    );
  }
}

/// Text strip over an image: Ink at 55 %, radius 10 (`imageCaptionBar`-like).
class GlassDark extends StatelessWidget {
  const GlassDark({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: StudioColors.ink.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(StudioRadius.card),
      ),
      child: child,
    );
  }
}
