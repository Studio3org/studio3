import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';

/// Switch: 44 × 26 round track, 20 px knob inset 3 (`NotifSettings`, `SignIn3Profile`).
/// Light: Ink track on, #E3E3E0 off, white knob.
class StudioSwitch extends StatelessWidget {
  const StudioSwitch({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : StudioMotion.quick;
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          width: 44,
          height: 26,
          decoration: BoxDecoration(
            color: value ? c.switchOn : c.switchOff,
            borderRadius: BorderRadius.circular(StudioRadius.round),
          ),
          child: AnimatedAlign(
            duration: duration,
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: AnimatedContainer(
                duration: duration,
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: value ? c.switchKnobOn : c.switchKnob,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
