import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import 'studio_icon.dart';

/// Underline field: label 13 above, value on a single underline; 1 px #D4D4D0, focused
/// 1.5 px Ink (`HandoffRules` "Fields"; `PostDetailsForSale`: gap 6, value 17, 8 below).
///
/// Sign-in boards use a larger value (19–20) and 8 / 10 spacing: pass [valueSize],
/// [labelGap] and [underlineGap]. A trailing unit ("lb", "in") goes in [unit]; facts such
/// as dimensions or phone numbers set [mono].
class StudioUnderlineField extends StatefulWidget {
  const StudioUnderlineField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hint,
    this.helper,
    this.errorText,
    this.unit,
    this.trailing,
    this.labelTrailing,
    this.required = false,
    this.mono = false,
    this.valueSize = 17,
    this.labelGap = 6,
    this.underlineGap = 8,
    this.labelColor,
    this.helperColor,
    this.strongUnderline = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;

  /// Grey line under the field, 12 / 1.45 (`SignIn3Profile` phone helper).
  final String? helper;

  /// Shown in Ink with the underline in Ink — never red (`HandoffRules`: errors use Ink
  /// text plus an icon).
  final String? errorText;
  final String? unit;
  final Widget? trailing;

  /// After the label: usually a [StudioInfoButton].
  final Widget? labelTrailing;

  /// Adds the red [StudioRequiredDot] after the label while the field is empty.
  final bool required;
  final bool mono;
  final double valueSize;
  final double labelGap;
  final double underlineGap;
  final Color? labelColor;

  /// Helper line color; tertiary by default (sign-in), Graphite on `BuyAddress`.
  final Color? helperColor;

  /// Ink 1.5 underline even when not focused (`PostAvailFixed` price).
  final bool strongUnderline;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool autofocus;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;

  @override
  State<StudioUnderlineField> createState() => _StudioUnderlineFieldState();
}

class _StudioUnderlineFieldState extends State<StudioUnderlineField> {
  FocusNode? _ownFocus;
  TextEditingController? _ownController;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());
  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_rebuild);
    _controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(StudioUnderlineField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_rebuild);
      _focus.addListener(_rebuild);
    }
    if (old.controller != widget.controller) {
      (old.controller ?? _ownController)?.removeListener(_rebuild);
      _controller.addListener(_rebuild);
    }
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_rebuild);
    _controller.removeListener(_rebuild);
    _ownFocus?.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final focused = _focus.hasFocus;
    final hasError = widget.errorText != null;
    final strong = focused || hasError || widget.strongUnderline;
    final valueStyle = widget.mono
        ? StudioType.mono(widget.valueSize, color: c.textPrimary)
        : StudioType.sans(widget.valueSize, color: c.textPrimary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                widget.label,
                style: StudioType.label13(color: widget.labelColor ?? c.textSecondary),
              ),
            ),
            if (widget.required && _controller.text.trim().isEmpty) const StudioRequiredDot(),
            if (widget.labelTrailing != null) widget.labelTrailing!,
          ],
        ),
        SizedBox(height: widget.labelGap),
        // Container (not DecoratedBox) so the underline takes its own height, as the
        // board's CSS border does: 8 + 1, or 7.5 + 1.5 when focused.
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: strong ? c.textPrimary : c.lineStrong,
                width: strong ? 1.5 : 1,
              ),
            ),
          ),
          child: Padding(
            // Keep the text still when the underline thickens on focus.
            padding: EdgeInsets.only(bottom: widget.underlineGap - (strong ? 0.5 : 0)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    readOnly: widget.readOnly,
                    onTap: widget.onTap,
                    autofocus: widget.autofocus,
                    obscureText: widget.obscureText,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    inputFormatters: widget.inputFormatters,
                    maxLines: widget.obscureText ? 1 : widget.maxLines,
                    minLines: widget.minLines,
                    maxLength: widget.maxLength,
                    autofillHints: widget.autofillHints,
                    textCapitalization: widget.textCapitalization,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    style: valueStyle,
                    cursorColor: c.textPrimary,
                    cursorWidth: 1.5,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      // The theme's input padding (6 / 8) would add 14 under the value;
                      // the board's value sits directly on the underline gap.
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      counterText: '',
                      hintText: widget.hint,
                      hintStyle: valueStyle.copyWith(color: c.textPlaceholder),
                    ),
                  ),
                ),
                if (widget.unit != null) ...[
                  const SizedBox(width: 8),
                  Text(widget.unit!, style: StudioType.body14(color: c.textPrimary)),
                ],
                if (widget.trailing != null) ...[const SizedBox(width: 8), widget.trailing!],
              ],
            ),
          ),
        ),
        // Helper and error sit under the underline at the field's own gap (`BuyAddress` 6,
        // sign-in 8), as the boards' flex columns do.
        if (hasError) ...[
          SizedBox(height: widget.labelGap),
          Text(widget.errorText!, style: StudioType.caption12(height: 1.45, color: c.textPrimary)),
        ] else if (widget.helper != null) ...[
          SizedBox(height: widget.labelGap),
          Text(
            widget.helper!,
            style: StudioType.caption12(height: 1.45, color: widget.helperColor ?? c.textTertiary),
          ),
        ],
      ],
    );
  }
}

/// 6 px alert dot, 6 after a label, while a required field is still empty
/// (`PostDetailsProgress`).
class StudioRequiredDot extends StatelessWidget {
  const StudioRequiredDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'required',
      child: Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(color: context.studio.alert, shape: BoxShape.circle),
      ),
    );
  }
}

/// Info icon after a label: 24 × 24 box, 16 px icon, tertiary (`PostDetailsForSale`).
/// The tap area is padded out to 44 without moving the icon.
class StudioInfoButton extends StatelessWidget {
  const StudioInfoButton({super.key, required this.onTap, required this.semanticLabel});

  final VoidCallback onTap;

  /// e.g. "What is framing?"
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 24,
          height: 24,
          child: OverflowBox(
            maxWidth: 44,
            maxHeight: 44,
            child: SizedBox.square(
              dimension: 44,
              child: Center(
                child: StudioIcon(StudioIcons.info, size: 16, color: context.studio.textTertiary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
