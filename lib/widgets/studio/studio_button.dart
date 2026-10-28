import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import 'studio_icon.dart';
import 'studio_tap_area.dart';

enum StudioButtonVariant {
  /// Ink fill, full width, 52 (or 54) tall, radius 12, 15/500 (`SignIn1Sheet`, `BuyPiece`).
  primary,

  /// 1 px #D4D4D0 outline, 44 tall, radius 12, 14/500 (`ProfileSeller` "Message").
  outline,

  /// Ink fill at inline size, 44 tall (`ProfileSeller` "Follow").
  inline,

  /// Plain text, 44 tall, 14/500 Graphite (`SignIn4Intention` "Skip for now").
  text,

  /// Small Follow: 34 tall, 0 16 padding, radius 8, 1 px outline, 13/500 (`BuyPiece`).
  small,
}

/// The one button. Buttons are never pills (`HandoffRules` "Corners").
class StudioButton extends StatelessWidget {
  const StudioButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = StudioButtonVariant.primary,
    this.height,
    this.fontSize,
    this.expand = true,
    this.loading = false,
    this.semanticLabel,
    this.filled = false,
    this.icon,
  });

  final String label;

  /// Null disables the button (primary: #D4D4D0 fill in light, 16% white in dark).
  final VoidCallback? onPressed;
  final StudioButtonVariant variant;

  /// Overrides the variant's height, e.g. [StudioSize.buttonPrimaryTall] (54) on posting.
  final double? height;

  /// Overrides the variant's text size, e.g. 16 for "Collect" on the piece bottom bar.
  final double? fontSize;

  /// Fill the available width (primary, outline, inline). Small and text hug their label.
  final bool expand;
  final bool loading;
  final String? semanticLabel;

  /// Small only: Ink fill, no border. The app's follow convention is a filled Follow and a
  /// light Unfollow on every surface, so the small Follow fills until you follow.
  final bool filled;

  /// A 20 icon 10 before the label (`PostSuccess` "Share your piece").
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final enabled = onPressed != null && !loading;

    late final double h;
    late final double radius;
    late final double size;
    late final Color fill;
    late final Color fg;
    Color? border;
    var padding = const EdgeInsets.symmetric(horizontal: 20);
    var hug = !expand;

    switch (variant) {
      case StudioButtonVariant.primary:
      case StudioButtonVariant.inline:
        final primary = variant == StudioButtonVariant.primary;
        h = primary ? StudioSize.buttonPrimary : StudioSize.buttonInline;
        radius = StudioRadius.button;
        size = primary ? 15 : 14;
        fill = enabled ? c.buttonFill : c.buttonDisabledFill;
        fg = enabled ? c.buttonText : c.buttonDisabledText;
      case StudioButtonVariant.outline:
        h = StudioSize.buttonInline;
        radius = StudioRadius.button;
        size = 14;
        fill = Colors.transparent;
        fg = enabled ? c.textPrimary : c.textTertiary;
        border = c.lineStrong;
      case StudioButtonVariant.text:
        h = StudioSize.tapTarget;
        radius = StudioRadius.button;
        size = 14;
        fill = Colors.transparent;
        fg = enabled ? c.textSecondary : c.textPlaceholder;
        padding = const EdgeInsets.symmetric(horizontal: 8);
      case StudioButtonVariant.small:
        h = StudioSize.buttonSmall;
        radius = StudioRadius.small;
        size = 13;
        if (filled) {
          final on = enabled || loading;
          fill = on ? c.buttonFill : c.buttonDisabledFill;
          fg = on ? c.buttonText : c.buttonDisabledText;
        } else {
          fill = Colors.transparent;
          fg = enabled ? c.textPrimary : c.textTertiary;
          border = c.lineStrong;
        }
        padding = const EdgeInsets.symmetric(horizontal: 16);
        hug = true;
    }

    final content = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: StudioType.sans(fontSize ?? size, weight: StudioType.medium, color: fg),
          );
    final body = icon == null || loading
        ? content
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StudioIcon(icon!, size: 20, color: fg),
              const SizedBox(width: 10),
              Flexible(child: content),
            ],
          );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border == null ? BorderSide.none : BorderSide(color: border),
    );

    // The small button is 34 tall on the boards; it still answers over 44 (`StudioTapArea`).
    return StudioTapArea(
      child: Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      // Full width where the width is bounded; hugs the label inside a Row or other
      // unbounded parent.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stretch = !hug && constraints.hasBoundedWidth;
          return SizedBox(
            height: height ?? h,
            width: stretch ? double.infinity : null,
            child: Material(
              color: fill,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? onPressed : null,
                child: Padding(
                  padding: padding,
                  child: Center(widthFactor: stretch ? null : 1, child: body),
                ),
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}

/// Outlined square message button beside the primary button: 52 × 52, radius 12, 1 px
/// #D4D4D0, 22 px chat icon (stroke 1.7) (`BuyPiece` bottom bar). [icon] swaps the chat
/// icon (the edit button on `ListOwnerPiece`).
class StudioMessageButton extends StatelessWidget {
  const StudioMessageButton({
    super.key,
    required this.onPressed,
    this.semanticLabel = 'Message',
    this.size = 52,
    this.icon = StudioIcons.chat,
  });

  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudioRadius.button),
            side: BorderSide(color: c.lineStrong),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(child: StudioIcon(icon, size: 22, color: c.textPrimary)),
          ),
        ),
      ),
    );
  }
}
