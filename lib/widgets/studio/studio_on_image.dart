import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import 'studio_icon.dart';

/// Top icons over a hero image (`BuyPiece`): a 120 tall Ink gradient (38 % → 0) under
/// white 20 px icons in 44 × 44 targets, 6 from the sides and 8 below the status bar.
/// No circles or pills behind the icons.
class StudioTopIconBar extends StatelessWidget {
  const StudioTopIconBar({super.key, this.leading = const [], this.trailing = const []});

  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: top + 120,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [StudioColors.topIconGradientStart, Color(0x00111111)],
                ),
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 6,
            right: 6,
            child: Row(
              children: [
                ...leading,
                const Spacer(),
                for (var i = 0; i < trailing.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  trailing[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One white icon over an image, with the board's faint drop shadow
/// (`drop-shadow(0 1px 2px rgba(0,0,0,0.3))`).
class StudioTopIcon extends StatelessWidget {
  const StudioTopIcon({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.size = 20,
  });

  final String icon;
  final VoidCallback? onTap;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 1,
                  left: 0,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                    child: StudioIcon(icon, size: size, color: const Color(0x4D000000)),
                  ),
                ),
                StudioIcon(icon, size: size, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Text (and optional icon) on an image: plain white with only a faint shadow — no
/// background, circles or pills (`HandoffRules` "Top of images"). Facts such as "1 / 4"
/// or a video length set [mono] (Mono 11); titles use Geist (e.g. 13/500).
class StudioImageLabel extends StatelessWidget {
  const StudioImageLabel(
    this.text, {
    super.key,
    this.icon,
    this.mono = true,
    this.size = 11,
    this.weight = StudioType.regular,
  });

  final String text;
  final String? icon;
  final bool mono;
  final double size;
  final FontWeight weight;

  // text-shadow: 0 1px 2px rgba(0,0,0,0.4). CSS blur 2 px = sigma 1; Flutter's
  // blurRadius r gives sigma 0.57735 r + 0.5, so r = 0.87.
  static const shadow = Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 0.87);

  @override
  Widget build(BuildContext context) {
    final style =
        (mono
                ? StudioType.mono(size, weight: weight, color: Colors.white)
                : StudioType.sans(size, weight: weight, color: Colors.white))
            .copyWith(shadows: const [shadow]);
    final label = Text(text, style: style);
    if (icon == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 1,
              left: 0,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                child: StudioIcon(icon!, size: 14, color: const Color(0x66000000)),
              ),
            ),
            StudioIcon(icon!, size: 14, color: Colors.white),
          ],
        ),
        const SizedBox(width: 4),
        label,
      ],
    );
  }
}
