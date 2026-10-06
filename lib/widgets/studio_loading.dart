import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/home_feed_tokens.dart';
import 'auth_ui.dart';

/// Exact Figma geometry for node `2559:1688` ("Logo for loading screen").
///
/// Source artboard is 1088×854. Bubble order is largest → medium → smallest.
abstract final class StudioBubbleGeometry {
  static const double designWidth = 1088;
  static const double designHeight = 854;

  /// Largest, medium, smallest — left/top/diameter in design pixels.
  static const List<({double left, double top, double diameter})> bubbles = [
    (left: 0, top: 231, diameter: 623),
    (left: 586, top: 0, diameter: 398),
    (left: 846, top: 442, diameter: 242),
  ];

  static const int bubbleCount = 3;
  static const Duration cycleDuration = Duration(milliseconds: 1200);
  static const Duration phaseDuration = Duration(milliseconds: 400);

  /// Inactive → active fill opacity.
  static const double inactiveOpacity = 0.38;
  static const double activeOpacity = 1.0;

  /// Peak scale while a bubble is active — kept subtle to avoid layout jitter.
  static const double activeScalePeak = 1.075;

  /// Returns 0 for inactive, 0..1 pulse for the active phase of [index].
  ///
  /// [t] is the normalized cycle progress in `0..1`.
  static double emphasis(double t, int index) {
    final start = index / bubbleCount;
    final end = (index + 1) / bubbleCount;
    if (t < start || t >= end) return 0;
    final local = (t - start) / (end - start);
    final riseFall = local < 0.5 ? local * 2 : (1 - local) * 2;
    return Curves.easeInOut.transform(riseFall);
  }

  /// Index of the bubble that should be active at normalized time [t].
  static int activeIndex(double t) {
    final clamped = t.clamp(0.0, 0.999999);
    return (clamped * bubbleCount).floor();
  }
}

/// Theme-aware sequential three-bubble loading mark.
///
/// Supports full-screen and compact/embedded use. Animation order is always
/// largest → medium → smallest → repeat.
class StudioBubbleLoader extends StatefulWidget {
  const StudioBubbleLoader({
    super.key,
    this.width = 120,
    this.color,
    this.message,
    this.semanticLabel = 'Loading',
  });

  /// Rendered width of the composition; height follows Figma aspect ratio.
  final double width;

  /// Bubble fill. Defaults to [ColorScheme.onSurface].
  final Color? color;

  /// Optional caption below the mark (future-ready; unused by default).
  final String? message;

  final String semanticLabel;

  @override
  State<StudioBubbleLoader> createState() => _StudioBubbleLoaderState();
}

class _StudioBubbleLoaderState extends State<StudioBubbleLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: StudioBubbleGeometry.cycleDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _resolveColor(BuildContext context) {
    if (widget.color != null) return widget.color!;
    return Theme.of(context).colorScheme.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor(context);
    final height =
        widget.width *
        StudioBubbleGeometry.designHeight /
        StudioBubbleGeometry.designWidth;
    final reduceMotion = _reduceMotion ?? false;

    final Widget mark;
    if (reduceMotion) {
      mark = _BubbleComposition(
        width: widget.width,
        height: height,
        color: color,
        emphases: List.filled(StudioBubbleGeometry.bubbleCount, 0),
      );
    } else {
      mark = AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return _BubbleComposition(
            width: widget.width,
            height: height,
            color: color,
            emphases: List.generate(
              StudioBubbleGeometry.bubbleCount,
              (i) => StudioBubbleGeometry.emphasis(t, i),
            ),
          );
        },
      );
    }

    final content = widget.message == null
        ? mark
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              mark,
              const SizedBox(height: 16),
              Text(
                widget.message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );

    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      child: ExcludeSemantics(child: content),
    );
  }
}

class _BubbleComposition extends StatelessWidget {
  const _BubbleComposition({
    required this.width,
    required this.height,
    required this.color,
    required this.emphases,
  });

  final double width;
  final double height;
  final Color color;
  final List<double> emphases;

  @override
  Widget build(BuildContext context) {
    final sx = width / StudioBubbleGeometry.designWidth;
    final sy = height / StudioBubbleGeometry.designHeight;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < StudioBubbleGeometry.bubbles.length; i++)
            _Bubble(
              geometry: StudioBubbleGeometry.bubbles[i],
              scaleX: sx,
              scaleY: sy,
              color: color,
              emphasis: emphases[i],
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.geometry,
    required this.scaleX,
    required this.scaleY,
    required this.color,
    required this.emphasis,
  });

  final ({double left, double top, double diameter}) geometry;
  final double scaleX;
  final double scaleY;
  final Color color;
  final double emphasis;

  @override
  Widget build(BuildContext context) {
    final size = geometry.diameter * scaleX;
    // Uniform X scale for diameter keeps circles circular; Y offset uses scaleY.
    final left = geometry.left * scaleX;
    final top = geometry.top * scaleY;
    final opacity =
        StudioBubbleGeometry.inactiveOpacity +
        (StudioBubbleGeometry.activeOpacity -
                StudioBubbleGeometry.inactiveOpacity) *
            emphasis;
    final scale = 1.0 + (StudioBubbleGeometry.activeScalePeak - 1.0) * emphasis;

    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

/// Compact/embedded bubble loader (replaces the old logo + wave animation).
///
/// [iconSize] is mapped to composition width for backward compatibility with
/// call sites such as [showUploadingDialog].
class StudioLoadingAnimation extends StatelessWidget {
  const StudioLoadingAnimation({
    super.key,
    this.iconSize = 56,
    this.dotColor,
    this.message,
  });

  final double iconSize;
  final Color? dotColor;
  final String? message;

  @override
  Widget build(BuildContext context) {
    // Map legacy iconSize (~56) to a composition footprint that feels premium.
    final width = (iconSize * 2.15).clamp(72.0, 160.0);
    return StudioBubbleLoader(width: width, color: dotColor, message: message);
  }
}

/// Centered body placeholder for scaffold/page initial loads.
class StudioLoadingBody extends StatelessWidget {
  const StudioLoadingBody({super.key, this.width = 96, this.color});

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: StudioBubbleLoader(
        width: width,
        color: color ?? HomeFeedTokens.textPrimary,
      ),
    );
  }
}

/// Full-screen loading layer with centered Studio bubble loader.
class StudioLoadingOverlay extends StatelessWidget {
  const StudioLoadingOverlay({super.key, this.backgroundColor, this.dotColor});

  final Color? backgroundColor;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: backgroundColor ?? HomeFeedTokens.background,
      child: Center(
        child: StudioBubbleLoader(
          width: 128,
          color:
              dotColor ??
              (scheme.brightness == Brightness.dark
                  ? scheme.onSurface
                  : HomeFeedTokens.textPrimary),
        ),
      ),
    );
  }
}

/// Dark variant for auth screens — uses [AppTheme.dark] semantics.
class StudioLoadingOverlayDark extends StatelessWidget {
  const StudioLoadingOverlayDark({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.dark;
    final scheme = dark.colorScheme;
    return Theme(
      data: dark,
      child: ColoredBox(
        color: dark.scaffoldBackgroundColor,
        child: Center(
          child: StudioBubbleLoader(width: 128, color: scheme.onSurface),
        ),
      ),
    );
  }
}

/// Immersive loading experience used only while the login request completes.
class StudioLoginLoadingOverlay extends StatelessWidget {
  const StudioLoginLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.dark;
    final scheme = dark.colorScheme;

    return Theme(
      data: dark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AuthBackground(),
          Center(
            child: StudioBubbleLoader(width: 136, color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}

/// When [loading] is true, covers the entire page with [StudioLoadingOverlay].
class StudioLoadingGate extends StatelessWidget {
  const StudioLoadingGate({
    super.key,
    required this.loading,
    required this.child,
    this.dark = false,
    this.loginExperience = false,
    this.backgroundColor,
  });

  final bool loading;
  final Widget child;
  final bool dark;
  final bool loginExperience;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (loading)
          Positioned.fill(
            child: loginExperience
                ? const StudioLoginLoadingOverlay()
                : dark
                ? const StudioLoadingOverlayDark()
                : StudioLoadingOverlay(backgroundColor: backgroundColor),
          ),
      ],
    );
  }
}
