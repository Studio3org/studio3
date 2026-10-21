import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import 'studio_icon.dart';

/// Shared screen header (`SavedCollection`, `NotifActivity`): 12 px above a 44 px row,
/// back chevron 22 px, title 17/500 centered. Colors come from the theme, so the bar
/// follows light and dark. At the default text size the row stays 44; larger type
/// wraps onto extra lines instead of being cut off.
class StudioTopBar extends StatelessWidget implements PreferredSizeWidget {
  StudioTopBar({
    super.key,
    required BuildContext context,
    required this.title,
    this.onBack,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
  }) : textScaler = MediaQuery.textScalerOf(context);

  final String title;

  /// Defaults to popping the route. Pass this when the pop result matters.
  final VoidCallback? onBack;

  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final TextScaler textScaler;

  /// Board size: 12 px above a 44 px row.
  static const double boardHeight = 56;

  /// Height of the row under the status bar. One line at the default text size.
  static double toolbarHeightFor(TextScaler scaler, String title) {
    if (scaler.scale(1) <= 1.01) return boardHeight;
    final painter = TextPainter(
      text: TextSpan(text: title, style: StudioType.header17()),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: 200);
    return 12 + math.max(StudioSize.tapTarget, painter.height);
  }

  double get _toolbarHeight => toolbarHeightFor(textScaler, title);

  @override
  Size get preferredSize =>
      Size.fromHeight(_toolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    final showBack = automaticallyImplyLeading && canPop;
    final toolbar = _toolbarHeight;
    return AppBar(
      toolbarHeight: toolbar,
      backgroundColor: c.background,
      foregroundColor: c.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: const SizedBox.shrink(),
      leadingWidth: 0,
      title: const SizedBox.shrink(),
      bottom: bottom,
      flexibleSpace: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: toolbar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Row(
              children: [
                if (showBack)
                  _BackButton(onPressed: onBack ?? () => Navigator.maybePop(context))
                else
                  const SizedBox(width: StudioSize.tapTarget),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: StudioType.header17(color: c.textPrimary),
                  ),
                ),
                if (actions != null && actions!.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: actions!)
                else
                  const SizedBox(width: StudioSize.tapTarget),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'Back',
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: const Size(StudioSize.tapTarget, StudioSize.tapTarget),
        fixedSize: const Size(StudioSize.tapTarget, StudioSize.tapTarget),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: StudioIcon(
        StudioIcons.backBold,
        size: 22,
        color: context.studio.textPrimary,
      ),
    );
  }
}

/// "Save" on edit screens. Same 44 px target and 17/500 type as the bar title.
class StudioSaveAction extends StatelessWidget {
  const StudioSaveAction({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: c.textPrimary,
        disabledForegroundColor: c.textPlaceholder,
        minimumSize: const Size(44, StudioSize.tapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: StudioType.header17(),
      ),
      child: const Text('Save'),
    );
  }
}
