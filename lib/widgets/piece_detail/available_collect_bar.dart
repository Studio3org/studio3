import 'package:flutter/material.dart';

import '../../theme/studio_metrics.dart';
import '../studio/studio_bottom_bar.dart';
import '../studio/studio_button.dart';
import '../studio/studio_chip.dart';

/// Fixed bottom bar of the piece page (`BuyPiece`; `NoteBuyPiece`): fades in from the
/// page with no border, Price on the left (Geist 17), then Collect (52, 16/500).
///
/// * "Ships in" (artist handling + crating time) is not in the piece payload, so the
///   right side stays empty (plan rule 5).
/// * No message button: piece messaging is off in the current flow.
/// * Sold: the Collected chip replaces Collect. Other unavailable states keep a disabled
///   button with their word ("Reserved", "Not for sale", "Unavailable").
class AvailableCollectBar extends StatelessWidget {
  const AvailableCollectBar({
    super.key,
    required this.priceDisplay,
    this.onCollect,
    this.statusLabel,
    this.collected = false,
  });

  /// "$3,500"; null or empty hides the info row.
  final String? priceDisplay;
  final VoidCallback? onCollect;

  /// Word on the disabled button when the piece can't be collected.
  final String? statusLabel;

  /// Sold: shows the Collected chip instead of the button.
  final bool collected;

  bool get _hasInfo => priceDisplay != null && priceDisplay!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final Widget action = collected
        ? const SizedBox(
            height: StudioSize.buttonPrimary,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StudioStatusChip(StudioStatus.collected),
            ),
          )
        : StudioButton(
            label: statusLabel ?? 'Collect',
            fontSize: 16,
            onPressed: statusLabel == null ? onCollect : null,
          );
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: StudioBottomBar(
        left: _hasInfo ? StudioBottomBarInfo(label: 'Price', value: priceDisplay!) : null,
        button: action,
      ),
    );
  }

  /// Bar height for scroll padding and the save toast: 28 top padding, the info row
  /// (12 label + 2 + 17 value at Chrome line heights = 40) and 12 gap, the 52 button,
  /// then the bottom inset (16 when there is none).
  static double totalHeight(BuildContext context, {bool hasInfo = true}) {
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return 28 +
        (hasInfo ? 40 + 12 : 0) +
        StudioSize.buttonPrimary +
        (safe > 0 ? safe : StudioSize.noInsetBottomPadding);
  }
}
