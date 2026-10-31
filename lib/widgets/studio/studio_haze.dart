import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';

/// The sign-in background (`.shimmer` on `SignInFirst` / `SignInFirstDark`): four soft
/// radial glows on the sign-in base color, drawn 10 % past every edge, blurred (18 px light,
/// 22 px dark) and drifting over 18 s. Static when reduced motion is on.
///
/// Put it first in a full-screen [Stack]; content goes above it.
class StudioHaze extends StatefulWidget {
  const StudioHaze({super.key});

  @override
  State<StudioHaze> createState() => StudioHazeState();
}

class StudioHazeState extends State<StudioHaze> with SingleTickerProviderStateMixin {
  /// True while the haze is drifting. Stays false when reduced motion is on.
  bool get isDrifting => _controller.isAnimating;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: StudioMotion.hazeLoop,
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
    final c = context.studio;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: ColoredBox(
        color: c.signInBackground,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth, h = constraints.maxHeight;
            return ClipRect(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // inset: -10 %
                  Positioned(
                    left: -0.1 * w,
                    top: -0.1 * h,
                    width: 1.2 * w,
                    height: 1.2 * h,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: dark ? 22 : 18,
                        sigmaY: dark ? 22 : 18,
                        tileMode: TileMode.decal,
                      ),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _HazePainter(_controller, dark ? _darkGlows : _lightGlows),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One `radial-gradient(<rx>% <ry>% at <cx>% <cy>%, color, transparent 70%)` layer and the
/// background-position it drifts between (keyframes 0 % / 50 % / 100 %).
class _Glow {
  const _Glow(this.color, this.rx, this.ry, this.cx, this.cy, this.from, this.to);

  final Color color;
  final double rx, ry, cx, cy;
  final Offset from, to;
}

// Listed top layer first, as in the CSS.
const _lightGlows = [
  _Glow(Color(0xD9BECED6), .60, .45, .15, .20, Offset(0, 0), Offset(.30, .20)),
  _Glow(Color(0xCCD6CCDE), .55, .45, .85, .15, Offset(1, 0), Offset(.70, .10)),
  _Glow(Color(0xCCE2CED6), .60, .50, .20, .70, Offset(0, 1), Offset(.20, .80)),
  _Glow(Color(0xD9ECE6CE), .65, .55, .85, .75, Offset(1, 1), Offset(.80, .70)),
];

const _darkGlows = [
  _Glow(Color(0xBF46688C), .60, .45, .15, .20, Offset(0, 0), Offset(.30, .20)),
  _Glow(Color(0xB3684E96), .55, .45, .85, .15, Offset(1, 0), Offset(.70, .10)),
  _Glow(Color(0x998C466E), .60, .50, .20, .70, Offset(0, 1), Offset(.20, .80)),
  _Glow(Color(0x80967846), .65, .55, .85, .75, Offset(1, 1), Offset(.80, .70)),
];

class _HazePainter extends CustomPainter {
  _HazePainter(this.animation, this.glows) : super(repaint: animation);

  final Animation<double> animation;
  final List<_Glow> glows;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final p = Curves.easeInOut.transform(t < 0.5 ? t * 2 : (1 - t) * 2);
    // background-size: 140 % 140 %
    final tile = Size(size.width * 1.4, size.height * 1.4);
    for (final g in glows.reversed) {
      final pos = Offset.lerp(g.from, g.to, p)!;
      final origin = Offset(
        (size.width - tile.width) * pos.dx,
        (size.height - tile.height) * pos.dy,
      );
      final center = origin + Offset(g.cx * tile.width, g.cy * tile.height);
      final rx = g.rx * tile.width, ry = g.ry * tile.height;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, ry / rx);
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          rx,
          [g.color, g.color.withValues(alpha: 0)],
          const [0, 0.7],
        );
      canvas.drawCircle(Offset.zero, rx * 0.7, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HazePainter old) => old.animation != animation || old.glows != glows;
}
