import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';

/// Opens a board-style bottom sheet: scrim, 24 top corners, height from content and never
/// above 90 % of the screen (`HandoffSizes`). Build the content with [StudioSheet].
Future<T?> showStudioSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
}) {
  final c = context.studio;
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    backgroundColor: c.background,
    barrierColor: c.scrim,
    elevation: 0,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(StudioRadius.sheet)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * StudioSize.sheetMaxHeightFactor,
    ),
  );
}

/// Sheet body: 40 × 5 grabber 10 from the top, then [children] with [gap] between them
/// (`SignIn1Sheet`: 20 sides, gap 16; `SavedSheet`: 24 sides, gap 14). The bottom sits on
/// the safe area (16 when there is none) and rises with the keyboard.
class StudioSheet extends StatelessWidget {
  const StudioSheet({
    super.key,
    required this.children,
    this.horizontalPadding = 20,
    this.gap = 16,
    this.scrollable = false,
  });

  final List<Widget> children;
  final double horizontalPadding;
  final double gap;

  /// Scroll the content when it can be taller than the sheet's 90 % cap.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final safeBottom = mq.viewPadding.bottom > 0
        ? mq.viewPadding.bottom
        : StudioSize.noInsetBottomPadding;
    final spaced = <Widget>[
      const Center(child: StudioSheetGrabber()),
      for (final child in children) ...[SizedBox(height: gap), child],
    ];
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaced,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Padding(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 10, horizontalPadding, safeBottom),
        child: scrollable ? SingleChildScrollView(child: column) : column,
      ),
    );
  }
}

/// The 40 × 5 grabber, radius 3, #D4D4D0 in light.
class StudioSheetGrabber extends StatelessWidget {
  const StudioSheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 5,
      decoration: BoxDecoration(
        color: context.studio.lineStrong,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
