import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';

/// The iridescent fill (`.holo` on the boards): a 115° gradient drawn at 300 % of the box
/// and slid left–right over 6 s, ease-in-out. Static when reduced motion is on.
///
/// Used ONLY for the Collected chip and the collect confirmation (`HandoffRules`).
/// As a frame, set [padding]: the child covers the middle and the gradient shows around it
/// (`CollectConfirm`: 4 px around the art, 1.5 px around the provenance card).
class StudioIridescent extends StatefulWidget {
  const StudioIridescent({
    super.key,
    this.child,
    this.borderRadius = BorderRadius.zero,
    this.padding = EdgeInsets.zero,
    this.boxShadow,
  });

  final Widget? child;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final List<BoxShadow>? boxShadow;

  @override
  State<StudioIridescent> createState() => _StudioIridescentState();
}

class _StudioIridescentState extends State<StudioIridescent> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: StudioMotion.iridescentLoop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: widget.borderRadius, boxShadow: widget.boxShadow),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: CustomPaint(
          painter: _IridescentPainter(_controller),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

class _IridescentPainter extends CustomPainter {
  _IridescentPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  // CSS keyframes 0% → 50% → 100% of background-position-x (0% → 100% → 0%), each half
  // eased in-out.
  double get _positionX {
    final t = animation.value;
    return Curves.easeInOut.transform(t < 0.5 ? t * 2 : (1 - t) * 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // background-size 300 %: the gradient box is 3w × 3h; background-position x% / 50 %.
    final box = Rect.fromLTWH(-2 * w * _positionX, -h, 3 * w, 3 * h);
    canvas.drawRect(Offset.zero & size, Paint()..shader = cssLinearGradient(box, 115));
  }

  @override
  bool shouldRepaint(_IridescentPainter old) => old.animation != animation;
}

/// A CSS `linear-gradient(<angle>deg, …)` of the iridescent stops over [box].
ui.Gradient cssLinearGradient(Rect box, double degrees) {
  final a = degrees * math.pi / 180;
  final dir = Offset(math.sin(a), -math.cos(a));
  final half = (box.width * math.sin(a).abs() + box.height * math.cos(a).abs()) / 2;
  return ui.Gradient.linear(
    box.center - dir * half,
    box.center + dir * half,
    StudioColors.iridescentStops,
    StudioColors.iridescentPositions,
  );
}
