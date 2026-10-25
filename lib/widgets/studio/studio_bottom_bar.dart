import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';

/// One side of the bottom bar's info row: label 12 Graphite above value Geist 17/400.
class StudioBottomBarInfo {
  const StudioBottomBarInfo({
    required this.label,
    required this.value,
    this.valueColor,
    this.strong = false,
    this.mono = false,
  });

  final String label;
  final String value;

  /// Red time remaining under 24 hours (`BidOutbid`); 500 when [strong].
  final Color? valueColor;
  final bool strong;

  /// Geist Mono 14 for a date (`EvDetail` "When").
  final bool mono;
}

/// Pinned bottom bar (`BuyPiece`; `HandoffRules` "Bottom bars"): fades in from the page over
/// 22 px (no border line), info row on top (label above value, both sides), then the
/// full-width [button] with an optional [messageButton] 10 beside it. 28 20 padding,
/// 12 between rows; the bottom sits on the safe area (16 when there is none).
class StudioBottomBar extends StatelessWidget {
  const StudioBottomBar({
    super.key,
    required this.button,
    this.left,
    this.right,
    this.messageButton,
    this.leftChild,
    this.note,
  });

  final StudioBottomBarInfo? left;

  /// Replaces [left] with a custom block (the bid status on `BidLeading` / `BidOutbid`).
  final Widget? leftChild;

  /// A line under the info row, 6 closer (`BidLeading` "Reserve not met yet").
  final Widget? note;
  final StudioBottomBarInfo? right;
  final Widget button;

  /// Usually a [StudioMessageButton].
  final Widget? messageButton;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return _Fade(
      color: c.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          StudioSpace.marginPage,
          28,
          StudioSpace.marginPage,
          safe > 0 ? safe : StudioSize.noInsetBottomPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (left != null || right != null || leftChild != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (leftChild != null)
                    leftChild!
                  else if (left != null)
                    _info(c, left!, CrossAxisAlignment.start),
                  const Spacer(),
                  if (right != null) _info(c, right!, CrossAxisAlignment.end),
                ],
              ),
              if (note != null) ...[const SizedBox(height: 6), note!],
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(child: button),
                if (messageButton != null) ...[const SizedBox(width: 10), messageButton!],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(StudioColors c, StudioBottomBarInfo info, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(info.label, style: StudioType.caption12(color: c.textSecondary)),
        const SizedBox(height: 2),
        Text(
          info.value,
          style: info.mono
              ? StudioType.mono(14, color: info.valueColor ?? c.textPrimary)
              : StudioType.header17(
                  weight: info.strong ? StudioType.medium : StudioType.regular,
                  color: info.valueColor ?? c.textPrimary,
                ),
        ),
      ],
    );
  }
}

/// `linear-gradient(to bottom, transparent 0, <background> 22px)` behind the bar.
class _Fade extends StatelessWidget {
  const _Fade({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _FadePainter(color), child: child);
  }
}

class _FadePainter extends CustomPainter {
  _FadePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const fade = 22.0;
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: 0), color],
    ).createShader(Rect.fromLTWH(0, 0, size.width, fade));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, fade), Paint()..shader = shader);
    canvas.drawRect(Rect.fromLTWH(0, fade, size.width, size.height - fade), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FadePainter old) => old.color != color;
}
