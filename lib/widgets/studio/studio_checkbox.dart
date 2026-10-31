import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import 'studio_icon.dart';

/// Checkbox row (`BuyAddress` "Save for next time"): 20 × 20 box, radius 6, Ink with a
/// 13 px check when on, a 1.5 px #D4D4D0 outline when off; 12 gap, label 14. The whole row
/// is the tap target (at least 44 tall).
class StudioCheckbox extends StatelessWidget {
  const StudioCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : StudioMotion.quick;
    return Semantics(
      checked: value,
      enabled: onChanged != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: StudioSize.tapTarget),
          child: Row(
            children: [
              AnimatedContainer(
                duration: duration,
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: value ? c.buttonFill : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: value ? null : Border.all(color: c.lineStrong, width: 1.5),
                ),
                alignment: Alignment.center,
                child: value ? StudioIcon(StudioIcons.check, size: 13, color: c.buttonText) : null,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(label, style: StudioType.body14(color: c.textPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
