import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';

/// Step bar (`SignIn3Profile`, `PostDetailsForSale`): [total] segments 3 tall, radius 2,
/// 6 apart; the first [current] are Ink, the rest Line.
class StudioProgressSegments extends StatelessWidget {
  const StudioProgressSegments({super.key, required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : StudioMotion.standard;
    return Semantics(
      label: 'Step $current of $total',
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: duration,
                height: 3,
                decoration: BoxDecoration(
                  color: i < current ? c.textPrimary : c.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
