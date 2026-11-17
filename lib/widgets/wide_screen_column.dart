import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps the app to a centred, phone-width column on wide windows (an iPad, in portrait,
/// landscape or a wide Split View). Launch checklist 1.5: the app ships for iPad too, and every
/// screen was designed for a phone; stretched across an iPad they looked broken.
///
/// Wraps the app's Navigator (`MaterialApp.builder`), so every page, sheet, dialog and toast
/// sits in the column. Inside it, [MediaQuery] reports the column's width, so layouts that read
/// the screen size get the size they actually have. Side safe-area insets that fall within the
/// margins are dropped. At [maxWidth] or narrower (every phone, a narrow iPad window) the
/// app is left exactly as it is.
class WideScreenColumn extends StatelessWidget {
  const WideScreenColumn({super.key, required this.child});

  final Widget child;

  /// Wide enough to feel at home on an iPad, close enough to the phone boards (390) that every
  /// screen keeps its proportions.
  static const double maxWidth = 600;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    if (width <= maxWidth) return child;
    final margin = (width - maxWidth) / 2;

    EdgeInsets inside(EdgeInsets e) => e.copyWith(
      left: math.max(0, e.left - margin),
      right: math.max(0, e.right - margin),
    );

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: MediaQuery(
            data: mq.copyWith(
              size: Size(maxWidth, mq.size.height),
              padding: inside(mq.padding),
              viewPadding: inside(mq.viewPadding),
              viewInsets: inside(mq.viewInsets),
              systemGestureInsets: inside(mq.systemGestureInsets),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
