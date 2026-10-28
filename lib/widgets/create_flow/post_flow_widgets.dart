import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_button.dart';
import '../studio/studio_field.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_progress_segments.dart';
import '../studio/studio_tooltip.dart';
import '../studio/studio_tap_area.dart';

/// Pieces shared by the light posting screens (`PostAvailFixed`, `PostDetails*`,
/// `PostReview`, `ScenePhotoDetails`, the published and error screens).

/// Back 22 in a 44 target, then the step bar when [current] is set (8 12 20 padding, 12 gap).
class PostStepHeader extends StatelessWidget {
  const PostStepHeader({super.key, required this.onBack, this.current, this.total = 3});

  final VoidCallback onBack;
  final int? current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
      child: Row(
        children: [
          PostIconButton(icon: StudioIcons.backBold, label: 'Back', onTap: onBack),
          if (current != null) ...[
            const SizedBox(width: 12),
            Expanded(child: StudioProgressSegments(current: current!, total: total)),
          ],
        ],
      ),
    );
  }
}

/// A 22 icon in a 44 target, Ink (or [color]).
class PostIconButton extends StatelessWidget {
  const PostIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: StudioSize.tapTarget,
          child: Center(
            child: StudioIcon(icon, size: 22, color: color ?? context.studio.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// 54 × 72 cover (radius 8), title 15/500 over the Mono 12 photo count, Edit 14/500.
class PostPieceCard extends StatelessWidget {
  const PostPieceCard({
    super.key,
    required this.cover,
    required this.title,
    required this.photoCount,
    required this.onEdit,
  });

  final Widget cover;
  final String title;
  final int photoCount;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 54, height: 72, child: cover),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                '$photoCount ${photoCount == 1 ? 'photo' : 'photos'}',
                style: StudioType.mono(12, color: c.textSecondary),
              ),
            ],
          ),
        ),
        PostTextLink(label: 'Edit', onTap: onEdit, padding: const EdgeInsets.only(left: 12)),
      ],
    );
  }
}

/// 14/500 Graphite text action in a 44-tall target.
class PostTextLink extends StatelessWidget {
  const PostTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.padding = EdgeInsets.zero,
    this.weight = StudioType.medium,
    this.height = StudioSize.tapTarget,
  });

  final String label;
  final VoidCallback onTap;
  final EdgeInsets padding;
  final FontWeight weight;
  final double height;

  @override
  Widget build(BuildContext context) {
    return StudioTapArea(child: Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: padding,
            child: Center(
              child: Text(
                label,
                style: StudioType.body14(weight: weight, color: context.studio.textSecondary),
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

/// `title30` heading with the 15/1.45 Graphite line 8 under it (none when [subtitle] is null).
class PostHeading extends StatelessWidget {
  const PostHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: StudioType.title30(color: c.textPrimary)),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: StudioType.body15(color: c.textSecondary)),
        ],
      ],
    );
  }
}

/// Label / value / chevron row (`PostDetailsForSale`): 16 padding, 1 px Line under, label 16,
/// value 14 (placeholder grey when [placeholder]), 16 chevron. A red dot follows the label
/// while [required]; [info] adds a 24 info button that opens a tooltip under the row.
class PostChevronRow extends StatelessWidget {
  const PostChevronRow({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.placeholder = 'Add',
    this.mono = false,
    this.required = false,
    this.info,
    this.divider = true,
  });

  final String label;
  final String? value;
  final String placeholder;
  final bool mono;
  final bool required;
  final String? info;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final empty = value == null || value!.isEmpty;
    final valueStyle = mono
        ? StudioType.mono(14, color: c.textPrimary)
        : StudioType.body14(color: empty ? c.textPlaceholder : c.textPrimary);
    Widget row(VoidCallback? toggle) => Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
          ),
          // The label group on the left and the value + chevron on the right edge; either side
          // shrinks with an ellipsis before it can push the row past the screen. (A Flexible
          // label next to an Expanded value split the spare width and left the value short of
          // the edge.)
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: StudioType.sans(16, color: c.textPrimary),
                      ),
                    ),
                    if (required) const StudioRequiredDot(),
                    if (toggle != null)
                      StudioInfoButton(onTap: toggle, semanticLabel: 'What is ${label.toLowerCase()}?'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        empty ? placeholder : value!,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: empty ? StudioType.body14(color: c.textPlaceholder) : valueStyle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StudioIcon(StudioIcons.chevronRight, size: 16, color: c.textTertiary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (info == null) return row(null);
    return StudioTooltip(message: info!, builder: (context, toggle) => row(toggle));
  }
}

/// Review card (`PostReview`): 1 px Line, radius 14, 14 16 8 padding; 15/500 title with an
/// Edit link; rows 14 with 7 vertical padding, label Graphite, value Ink on the right.
class PostReviewCard extends StatelessWidget {
  const PostReviewCard({
    super.key,
    required this.title,
    required this.onEdit,
    required this.rows,
  });

  final String title;
  final VoidCallback onEdit;
  final List<PostReviewRow> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(StudioRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                  ),
                ),
                PostTextLink(
                  label: 'Edit',
                  onTap: onEdit,
                  weight: StudioType.regular,
                  height: 32,
                ),
              ],
            ),
          ),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.label, style: StudioType.body14(color: c.textSecondary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      r.value,
                      textAlign: TextAlign.right,
                      style: r.mono
                          ? StudioType.mono(13, color: c.textPrimary)
                          : StudioType.sans(r.small ? 13 : 14, color: c.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class PostReviewRow {
  const PostReviewRow(this.label, this.value, {this.mono = false, this.small = false});

  final String label;
  final String value;
  final bool mono;

  /// Money values are 13 on the board.
  final bool small;
}

/// The pinned bottom of a step: 24 sides, [bottom] from the frame's bottom (36, or the
/// device inset when larger), a 54 primary button and an optional caption under it.
class PostBottomAction extends StatelessWidget {
  const PostBottomAction({
    super.key,
    required this.button,
    this.caption,
    this.bottom = 36,
    this.gap = 6,
  });

  final StudioButton button;
  final Widget? caption;
  final double bottom;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final inset = math.max(bottom, MediaQuery.viewPaddingOf(context).bottom);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [button, if (caption != null) ...[SizedBox(height: gap), caption!]],
      ),
    );
  }
}

/// CSS `1px dashed` round box border: 3 on, 3 off.
class PostDashedBorder extends StatelessWidget {
  const PostDashedBorder({
    super.key,
    required this.child,
    required this.color,
    this.radius = 8,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(0.5),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 6) {
        canvas.drawPath(metric.extractPath(d, d + 3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) =>
      old.color != color || old.radius != radius;
}

/// [child] covering its box at [aspect] (width / height), cropped like `object-fit: cover`.
/// The child gets a bounded size, so aspect-ratio previews lay out inside it.
class PostCoverFit extends StatelessWidget {
  const PostCoverFit({super.key, required this.child, this.aspect = 3 / 4});

  final Widget child;
  final double aspect;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: 400 * aspect, height: 400, child: child),
      ),
    );
  }
}
