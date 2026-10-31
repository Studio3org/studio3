import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';

/// Option row (`SignIn4Intention`; `HandoffRules` "Selection"): selected is Ink with a 2 px
/// line on the left that draws down in 0.22 s and its text indented 16; others sit flush and
/// fade to grey. No radios, checkmarks or boxes. Rows are separated by a 1 px line; pass
/// `divider: false` on the last.
class StudioSelectRow extends StatelessWidget {
  const StudioSelectRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.divider = true,
    this.titleSize = 22,
    this.titleLetterSpacing = -0.3,
    this.verticalPadding = 22,
    this.ruleInset = 18,
    this.subtitleSize = 14,
    this.subtitleGap = 6,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool divider;

  /// 22 / -0.3 on sign-in; option sheets use 19 / -0.2 or 17.
  final double titleSize;
  final double titleLetterSpacing;

  /// 22 on sign-in, 16 on posting and checkout rows.
  final double verticalPadding;

  /// Gap above and below the selection line: 18 on 22-padded rows, 14–16 on 16-padded.
  final double ruleInset;

  /// 14, 6 under the title on sign-in; 13, 3 under on checkout (`BuyShipping`).
  final double subtitleSize;
  final double subtitleGap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
          ),
          child: Stack(
            children: [
              AnimatedPadding(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : StudioMotion.quick,
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  selected ? 16 : 0,
                  verticalPadding,
                  0,
                  verticalPadding,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: StudioMotion.quick,
                            style: StudioType.sans(
                              titleSize,
                              weight: StudioType.medium,
                              letterSpacing: titleLetterSpacing,
                              color: selected ? c.textPrimary : c.textTertiary,
                            ),
                            child: Text(title),
                          ),
                          if (subtitle != null) ...[
                            SizedBox(height: subtitleGap),
                            AnimatedDefaultTextStyle(
                              duration: StudioMotion.quick,
                              style: StudioType.sans(
                                subtitleSize,
                                color: selected ? c.textSecondary : c.textPlaceholder,
                              ),
                              child: Text(subtitle!),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[const SizedBox(width: 16), trailing!],
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  left: 0,
                  top: ruleInset,
                  bottom: ruleInset,
                  child: _SelectionRule(color: c.textPrimary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionRule extends StatelessWidget {
  const _SelectionRule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final rule = SizedBox(width: 2, child: ColoredBox(color: color));
    if (MediaQuery.disableAnimationsOf(context)) return rule;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: StudioMotion.quick,
      curve: Curves.easeOut,
      builder: (context, t, child) => Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.diagonal3Values(1, t, 1),
        child: child,
      ),
      child: rule,
    );
  }
}

/// List option row in picker sheets (`PostMedium`, `PostLocation`): 13 vertical padding, title
/// 16 — the selected one 500 Ink with the left line and a 16 indent, the others 400 Graphite;
/// an optional 13 subtitle (Graphite when selected, placeholder grey otherwise). Rows are
/// separated by a 1 px line; pass `divider: false` on the last.
class StudioListRow extends StatelessWidget {
  const StudioListRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.divider = true,
    this.ruleInset = 14,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final bool divider;
  final double ruleInset;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      checked: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
          ),
          child: Stack(
            children: [
              AnimatedPadding(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : StudioMotion.quick,
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(selected ? 16 : 0, 13, 0, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: StudioType.sans(
                        16,
                        weight: selected ? StudioType.medium : StudioType.regular,
                        color: selected ? c.textPrimary : c.textBody,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: StudioType.label13(
                          color: selected ? c.textSecondary : c.textPlaceholder,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  left: 0,
                  top: ruleInset,
                  bottom: ruleInset,
                  child: _SelectionRule(color: c.textPrimary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
