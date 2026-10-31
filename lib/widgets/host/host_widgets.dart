import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/post_image_transform.dart';
import '../../utils/crop_cover_math.dart';
import '../post_crop_preview.dart';
import '../studio/studio.dart';

/// The four hosting steps (`HostDetails`).
const kHostSteps = ['Details', 'Tickets', 'Lineup', 'Review'];

/// Step tabs under the top bar (`HostDetails`): four equal tabs 42 tall, 13; the current one
/// 500 Ink with a 2 px Ink underline, the rest 400 Tertiary; a Line under the row, 20 in.
/// Steps already reached can be tapped to go back.
class HostStepTabs extends StatelessWidget {
  const HostStepTabs({super.key, required this.step, required this.reached, required this.onStep});

  final int step;

  /// The furthest step reached; it and anything before it can be tapped.
  final int reached;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          for (var i = 0; i < kHostSteps.length; i++)
            Expanded(
              child: StudioTapArea(child: Semantics(
                button: true,
                selected: i == step,
                child: GestureDetector(
                  onTap: i <= reached && i != step ? () => onStep(i) : null,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: i == step ? c.textPrimary : Colors.transparent, width: 2),
                      ),
                    ),
                    child: Text(
                      kHostSteps[i],
                      style: StudioType.label13(
                        weight: i == step ? StudioType.medium : StudioType.regular,
                        color: i == step ? c.textPrimary : c.textTertiary,
                      ),
                    ),
                  ),
                ),
              )),
            ),
        ],
      ),
    );
  }
}

/// The event flyer on Details (`HostDetails`): 132 × 176 at radius 10, centred, 18 above and 6
/// below, with a 26 white edit badge 6 in from the top right. Without one, a Surface tile that
/// says "Add a cover".
class HostFlyerBox extends StatelessWidget {
  const HostFlyerBox({
    super.key,
    required this.onTap,
    this.imagePath,
    this.transform,
    this.imageUrl,
  });

  final VoidCallback onTap;
  final String? imagePath;
  final PostImageTransform? transform;

  /// An event being edited keeps its uploaded cover until a new one is picked.
  final String? imageUrl;

  static const size = Size(132, 176);

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final path = imagePath;
    final url = imageUrl;
    final has = (path != null && path.isNotEmpty) || (url != null && url.isNotEmpty);
    Widget image;
    if (path != null && path.isNotEmpty) {
      image = PostCropPreview(
        imagePath: path,
        transform: transform ?? PostImageTransform(aspectRatio: CropAspectRatio.ratio3x4),
        borderRadius: BorderRadius.circular(StudioRadius.card),
        frameSize: size,
      );
    } else if (url != null && url.isNotEmpty) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(StudioRadius.card),
        child: CachedNetworkImage(
          imageUrl: url,
          width: size.width,
          height: size.height,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => ColoredBox(color: c.surface),
        ),
      );
    } else {
      image = Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(StudioRadius.card)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StudioIcon(StudioIcons.plus, size: 22, color: c.textSecondary),
            const SizedBox(height: 8),
            Text('Add a cover', style: StudioType.label13(color: c.textSecondary)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Center(
        child: Semantics(
          button: true,
          label: has ? 'Change the event cover' : 'Add an event cover',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onTap,
            child: SizedBox.fromSize(
              size: size,
              child: Stack(
                children: [
                  image,
                  if (has)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: StudioColors.galleryWhite.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: StudioIcon(StudioIcons.edit, size: 14, color: StudioColors.ink),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row that opens a sheet (`HostDetails`): label 16 Ink, the value 14 Ink (Mono for a time)
/// and an 18 chevron on the right; 15 above and below, a Line under. A [required] row shows the
/// red dot after its label until it has a value.
class HostNavRow extends StatelessWidget {
  const HostNavRow({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.mono = false,
    this.enabled = true,
    this.required = false,
  });

  final String label;
  final String? value;
  final bool mono;
  final bool enabled;
  final bool required;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final shown = value?.trim() ?? '';
    final valueStyle = mono
        ? StudioType.mono(14, color: c.textPrimary)
        : StudioType.body14(color: c.textPrimary);
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled
            ? () {
                FocusScope.of(context).unfocus();
                onTap();
              }
            : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(
            children: [
              Text(label, style: StudioType.sans(16, color: enabled ? c.textPrimary : c.textTertiary)),
              if (required && enabled && shown.isEmpty) const StudioRequiredDot(),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  shown,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: enabled ? valueStyle : valueStyle.copyWith(color: c.textTertiary),
                ),
              ),
              const SizedBox(width: 8),
              StudioIcon(StudioIcons.chevronRight, size: 18, color: c.textPlaceholder),
            ],
          ),
        ),
      ),
    );
  }
}

/// A switch row (`HostDetails` Public, `HostDate` Multi-day event): 16 with a 12 Graphite line,
/// the switch on the right; 14 above and below, a Line under.
class HostSwitchRow extends StatelessWidget {
  const HostSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.divider = true,
    this.verticalPadding = 14,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool divider;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Container(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      decoration: BoxDecoration(border: divider ? Border(bottom: BorderSide(color: c.line)) : null),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: StudioType.sans(16, color: c.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: StudioType.caption12(color: c.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          StudioSwitch(value: value, onChanged: onChanged ?? (_) {}, semanticLabel: label),
        ],
      ),
    );
  }
}

/// A section label (`HostTickets`, `HostLineup`): Mono 11/500 Tertiary caps, 26 above, 6 below.
class HostLabel extends StatelessWidget {
  const HostLabel(this.text, {super.key, this.top = 26});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: StudioType.mono(11, weight: StudioType.medium, color: context.studio.textTertiary)
            .copyWith(letterSpacing: 0.5),
      ),
    );
  }
}

/// One choice in a hosting sheet or step: the left-line selection rows (`HostAge`, `HostTickets`).
class HostOption<T> {
  const HostOption(this.value, this.title, {this.subtitle, this.enabled = true});

  final T value;
  final String title;
  final String? subtitle;
  final bool enabled;
}

/// The option rows (`HostAge`, `HostArtMode`, `HostTickets`): title 16 (500 Ink when chosen,
/// 400 Tertiary otherwise), a 12 line, 13 above and below, the 2 px left line on the chosen
/// one; a Line between rows.
class HostOptionRows<T> extends StatelessWidget {
  const HostOptionRows({super.key, required this.options, required this.value, required this.onChanged});

  final List<HostOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++)
          StudioSelectRow(
            title: options[i].title,
            subtitle: options[i].subtitle,
            selected: options[i].value == value,
            titleSize: 16,
            titleLetterSpacing: 0,
            verticalPadding: 13,
            ruleInset: 13,
            subtitleSize: 12,
            subtitleGap: 2,
            divider: i < options.length - 1,
            onTap: options[i].enabled ? () => onChanged(options[i].value) : null,
          ),
      ],
    );
  }
}

/// A person in the lineup (`HostLineup`): 56 avatar, the first name 12 and an optional 11
/// Tertiary line, in a 72 column; [onRemove] by long press asks first.
class HostPersonTile extends StatelessWidget {
  const HostPersonTile({super.key, required this.name, this.avatarUrl, this.status, this.onTap});

  final String name;
  final String? avatarUrl;
  final String? status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: onTap != null,
      label: name,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              StudioAvatar(url: avatarUrl, size: 56, semanticLabel: name),
              const SizedBox(height: 3),
              Text(
                name.split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StudioType.caption12(color: c.textPrimary),
              ),
              if (status != null)
                Text(status!, maxLines: 1, style: StudioType.sans(11, color: c.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dashed + tile after the people (`HostLineup`): a 56 dashed circle with + 22 and "Add" 12.
class HostAddTile extends StatelessWidget {
  const HostAddTile({super.key, required this.onTap, required this.semanticLabel});

  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              CustomPaint(
                painter: _DashedCircle(c.lineStrong),
                child: SizedBox.square(
                  dimension: 56,
                  child: Center(child: Text('+', style: StudioType.sans(22, color: c.textSecondary))),
                ),
              ),
              const SizedBox(height: 3),
              Text('Add', style: StudioType.caption12(color: c.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedCircle extends CustomPainter {
  const _DashedCircle(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = size.width / 2 - 0.5;
    const dashes = 28;
    const sweep = 2 * 3.1415926535 / dashes;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.color != color;
}

/// A white card with a Line at radius 14 (`HostTickets` ticket type, `HostLineup` piece,
/// `HostReview` summary).
class HostCard extends StatelessWidget {
  const HostCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(StudioRadius.panel),
        border: Border.all(color: c.line),
      ),
      child: child,
    );
  }
}

/// A 14/500 Ink text action with a 44 tall tap area ("+ Tag a piece", "+ Add ticket type").
/// [inline] sits level with a card's first line (Edit on `HostTickets` and `HostReview`): one
/// line tall, inside a card that opens the same thing when tapped anywhere.
class HostTextAction extends StatelessWidget {
  const HostTextAction({
    super.key,
    required this.label,
    required this.onTap,
    this.size = 14,
    this.underline = false,
    this.inline = false,
  });

  final String label;
  final VoidCallback? onTap;
  final double size;
  final bool inline;

  /// A link (`HostLineup` "+ Tag a piece").
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioTapArea(child: Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: inline ? null : StudioSize.tapTarget,
          padding: inline ? const EdgeInsets.only(left: 16) : null,
          child: Align(
            alignment: inline ? Alignment.topRight : Alignment.centerLeft,
            widthFactor: 1,
            heightFactor: inline ? 1 : null,
            child: Text(
              label,
              style: StudioType.sans(
                size,
                weight: StudioType.medium,
                color: onTap == null ? c.textTertiary : c.textPrimary,
              ).copyWith(decoration: underline ? TextDecoration.underline : null),
            ),
          ),
        ),
      ),
    ));
  }
}

/// A sheet of [options] with a title 22, a 14 Graphite line and Done (`HostAge`): picking a row
/// moves the selection; Done returns it. Null when closed without Done.
Future<T?> showHostOptionSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<HostOption<T>> options,
  required T initial,
  bool scrollable = false,
}) {
  return showStudioSheet<T>(
    context: context,
    builder: (sheetContext) => _HostOptionSheet<T>(
      title: title,
      subtitle: subtitle,
      options: options,
      initial: initial,
      scrollable: scrollable,
    ),
  );
}

class _HostOptionSheet<T> extends StatefulWidget {
  const _HostOptionSheet({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.initial,
    required this.scrollable,
  });

  final String title;
  final String? subtitle;
  final List<HostOption<T>> options;
  final T initial;
  final bool scrollable;

  @override
  State<_HostOptionSheet<T>> createState() => _HostOptionSheetState<T>();
}

class _HostOptionSheetState<T> extends State<_HostOptionSheet<T>> {
  late T _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 10,
      scrollable: widget.scrollable,
      children: [
        Text(widget.title, style: StudioType.title22(color: c.textPrimary)),
        if (widget.subtitle != null) Text(widget.subtitle!, style: StudioType.body14(color: c.textSecondary)),
        HostOptionRows<T>(options: widget.options, value: _value, onChanged: (v) => setState(() => _value = v)),
        StudioButton(label: 'Done', onPressed: () => Navigator.pop(context, _value)),
      ],
    );
  }
}

/// The board's "already listed" dialog (`HostConflict`): a centred card at radius 18, the
/// title 18/500, the line 14 Graphite, Continue and Cancel. True to go ahead.
Future<bool> showHostConflictDialog(BuildContext context, {required String title, required String message}) async {
  final c = context.studio;
  final go = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x73111111),
    builder: (dialogContext) => Dialog(
      backgroundColor: c.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: StudioType.sans(18, weight: StudioType.medium, color: c.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: StudioType.body14(height: 1.5, color: c.textSecondary),
            ),
            const SizedBox(height: 16),
            StudioButton(label: 'Continue', onPressed: () => Navigator.pop(dialogContext, true)),
            const SizedBox(height: 10),
            StudioButton(
              label: 'Cancel',
              variant: StudioButtonVariant.text,
              height: 40,
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
          ],
        ),
      ),
    ),
  );
  return go == true;
}
