import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import 'studio_icon.dart';

OverlayEntry? _current;
Timer? _timer;

/// Shows the toast (`SignIn5Done`): an Ink box 120 above the bottom, 16 px check (stroke
/// 2.4), 14/500 text, 12 18 padding. The board draws it as a pill, but round corners are only
/// for chips, tags, filters, avatars, switch and nav (`HandoffRules`; plan section 0.3), so it
/// uses the 12 radius of the tooltip box. One at a time; fades in and out.
///
/// With [actionLabel] and [onAction] (e.g. Undo) the label sits after the text, 14/500
/// underlined, and tapping it closes the toast and runs [onAction].
void showStudioToast(
  BuildContext context,
  String message, {
  String? icon = StudioIcons.check,
  Duration duration = const Duration(milliseconds: 2500),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  // A Navigator's own context sits above its Overlay (onboarding's welcome after it replaces
  // itself with the feed): use that Navigator's overlay.
  final overlay =
      Overlay.maybeOf(context, rootOverlay: true) ?? Navigator.maybeOf(context, rootNavigator: true)?.overlay;
  if (overlay == null) return;
  _dismiss();
  final key = GlobalKey<_ToastState>();
  late final OverlayEntry entry;
  final action = actionLabel != null && onAction != null
      ? () {
          if (_current == entry) _dismiss();
          onAction();
        }
      : null;
  entry = OverlayEntry(
    builder: (_) => _Toast(key: key, message: message, icon: icon, actionLabel: actionLabel, onAction: action),
  );
  _current = entry;
  overlay.insert(entry);
  _timer = Timer(duration, () async {
    await key.currentState?.hide();
    if (_current == entry) _dismiss();
  });
}

void _dismiss() {
  _timer?.cancel();
  _timer = null;
  _current?.remove();
  _current = null;
}

class _Toast extends StatefulWidget {
  const _Toast({super.key, required this.message, required this.icon, this.actionLabel, this.onAction});

  final String message;
  final String? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  Future<void> hide() async {
    if (!mounted) return;
    setState(() => _visible = false);
    await Future<void>.delayed(StudioMotion.quick);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 120,
      child: IgnorePointer(
        // Only a toast with an action takes taps.
        ignoring: widget.onAction == null,
        child: Center(
          child: StudioToastBox(
            message: widget.message,
            icon: widget.icon,
            visible: _visible,
            actionLabel: widget.actionLabel,
            onAction: widget.onAction,
          ),
        ),
      ),
    );
  }
}

/// The toast box on its own (also used by the component gallery).
class StudioToastBox extends StatelessWidget {
  const StudioToastBox({
    super.key,
    required this.message,
    this.icon = StudioIcons.check,
    this.visible = true,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? icon;
  final bool visible;

  /// An optional action after the text (e.g. Undo).
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      liveRegion: true,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : StudioMotion.quick,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: c.tooltipFill,
              borderRadius: BorderRadius.circular(StudioRadius.button),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  StudioIcon(icon!, size: 16, color: c.tooltipText),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    message,
                    style: StudioType.body14(weight: StudioType.medium, color: c.tooltipText),
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: 14),
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: onAction,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        actionLabel!,
                        style: StudioType.body14(weight: StudioType.medium, color: c.tooltipText).copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: c.tooltipText,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
