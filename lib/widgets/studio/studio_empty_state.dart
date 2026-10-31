import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import 'studio_icon.dart';
import 'studio_logo.dart';

/// Empty state (`SavedEmpty`): grey three-circle mark (76 × 60), title 22/400 (-0.3)
/// 28 below it, a grey line 15 / 1.5, and an optional plain text link 15/500 with →.
/// Centred, 44 side padding.
class StudioEmptyState extends StatelessWidget {
  const StudioEmptyState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StudioMarkGrey(),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: StudioType.sans(22, letterSpacing: -0.3, color: c.textPrimary),
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: StudioType.body15(height: 1.5, color: c.textSecondary),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAction,
                child: SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel!,
                        style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                      ),
                      const SizedBox(width: 6),
                      StudioIcon(StudioIcons.arrowRight, size: 16, color: c.textPrimary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
