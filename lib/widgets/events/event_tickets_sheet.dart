import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/studio_event.dart';
import '../../utils/money_format.dart' show formatMoney;
import '../studio/studio.dart';
import 'event_detail_widgets.dart';

/// What was picked in Choose tickets: how many of each type.
class EventTicketChoice {
  const EventTicketChoice(this.counts);

  final Map<EventTicketType, int> counts;

  int get count => counts.values.fold(0, (a, b) => a + b);

  /// How many of [type] (matched by id, so a refreshed event still finds it).
  int countOf(EventTicketType type) =>
      counts.entries.where((e) => e.key.id == type.id).fold(0, (sum, e) => sum + e.value);

  /// `1 General Admission, 1 VIP`.
  String get summary => [
    for (final e in counts.entries)
      if (e.value > 0) '${e.value} ${e.key.name}',
  ].join(', ');
  int get totalCents => counts.entries.fold(0, (sum, e) => sum + e.key.priceCents * e.value);

  /// Only free tickets: Reserve, no payment (`HandoffEvents`).
  bool get isFree => totalCents == 0;
}

/// `#B8B8B4`: the border of a card with a ticket picked. Dark value proposed.
Color _pickedBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5A5A57) : const Color(0xFFB8B8B4);

/// `Sat, Nov 21 · 8:00 PM CST`: every event time shows the event's zone (`NoteEvDetail`), when
/// it is known.
String eventStartLabel(StudioEvent e) {
  final d = e.startsAt;
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final suffix = d.hour < 12 ? 'AM' : 'PM';
  final zone = e.zoneLabel.isEmpty ? '' : ' ${e.zoneLabel}';
  return '${eventDayLabel(e)} · $hour:${d.minute.toString().padLeft(2, '0')} $suffix$zone';
}

/// Choose tickets (`EvChooseTickets`): a sheet over the event page, which blurs (14) behind
/// it. Grabber; the name 20/500 with the Mono start time and venue 13 Graphite; one card per
/// ticket type; the count and total; then Reserve (free) or Continue to payment.
class EventTicketsSheet extends StatefulWidget {
  const EventTicketsSheet({super.key, required this.event, this.initial});

  final StudioEvent event;

  /// What was picked before (changing the tickets from checkout).
  final EventTicketChoice? initial;

  /// Opens the sheet; null when it is closed without choosing.
  static Future<EventTicketChoice?> show(
    BuildContext context,
    StudioEvent event, {
    EventTicketChoice? initial,
  }) {
    return showGeneralDialog<EventTicketChoice>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, _) => EventTicketsSheet(event: event, initial: initial),
      transitionBuilder: (context, animation, _, child) {
        final t = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return AnimatedBuilder(
          animation: t,
          builder: (context, _) => Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 14 * t.value, sigmaY: 14 * t.value),
                    child: const ColoredBox(color: Colors.transparent),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionalTranslation(translation: Offset(0, 1 - t.value), child: child),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  State<EventTicketsSheet> createState() => _EventTicketsSheetState();
}

class _EventTicketsSheetState extends State<EventTicketsSheet> {
  late final List<EventTicketType> _types = widget.event.ticketOptions;
  late final Map<EventTicketType, int> _counts = {
    for (final type in _types)
      type:
          widget.initial?.countOf(type) ??
          // One type with places left (a free RSVP): already at 1, so Reserve is one tap.
          (_types.length == 1 && !type.isSoldOut ? 1 : 0),
  };

  EventTicketChoice get _choice => EventTicketChoice({
    for (final e in _counts.entries)
      if (e.value > 0) e.key: e.value,
  });

  void _change(EventTicketType type, int by) => setState(() => _counts[type] = (_counts[type] ?? 0) + by);

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final e = widget.event;
    final choice = _choice;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * StudioSize.sheetMaxHeightFactor;
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        // Swiping down closes it, like the other sheets.
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).maybePop();
        },
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(StudioRadius.sheet)),
          ),
          padding: EdgeInsets.fromLTRB(20, 10, 20, safe > 0 ? safe : StudioSize.noInsetBottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: c.lineStrong, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                e.title,
                style: StudioType.sans(20, weight: StudioType.medium, color: c.textPrimary),
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: eventStartLabel(e),
                      style: StudioType.mono(13, color: c.textSecondary),
                    ),
                    if (e.venue.isNotEmpty) TextSpan(text: ' · ${e.venue}'),
                  ],
                ),
                style: StudioType.label13(color: c.textSecondary),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final type in _types) ...[
                        const SizedBox(height: 12),
                        EventTicketCard(
                          type: type,
                          count: _counts[type] ?? 0,
                          onAdd: () => _change(type, 1),
                          onRemove: () => _change(type, -1),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${choice.count}',
                            style: StudioType.mono(13, color: c.textSecondary),
                          ),
                          TextSpan(text: choice.count == 1 ? ' ticket' : ' tickets'),
                          if (!choice.isFree) const TextSpan(text: ' · tax added at checkout'),
                        ],
                      ),
                      style: StudioType.label13(color: c.textSecondary),
                    ),
                  ),
                  Text(
                    choice.isFree ? 'Free' : formatMoney(choice.totalCents),
                    style: StudioType.sans(18, color: c.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StudioButton(
                label: choice.count > 0 && !choice.isFree ? 'Continue to payment' : 'Reserve',
                onPressed: choice.count == 0 ? null : () => Navigator.of(context).pop(choice),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One ticket type (`EvChooseTickets`): white card, radius 14, 14 14 12 padding, a Line border
/// (`#B8B8B4` once one is picked); name 16/500 and price 16 (or Free); what it includes 13
/// Graphite; then the places left in Mono 11 (red "Only 3 left" at 5 or fewer) and the
/// − count + stepper. A sold-out type turns grey with "Sold out" instead of the stepper.
class EventTicketCard extends StatelessWidget {
  const EventTicketCard({
    super.key,
    required this.type,
    required this.count,
    required this.onAdd,
    required this.onRemove,
  });

  final EventTicketType type;
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final soldOut = type.isSoldOut;
    final ink = soldOut ? c.textTertiary : c.textPrimary;
    final left = type.left;
    final max = type.maxPerOrder;
    final String? leftLine;
    final Color leftColor;
    if (soldOut) {
      leftLine = null;
      leftColor = c.textTertiary;
    } else if (left != null && left <= 5) {
      leftLine = 'Only $left left';
      leftColor = c.alert;
    } else {
      leftLine = left == null ? null : '$left left';
      leftColor = c.textTertiary;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: soldOut ? c.surface : c.card,
        borderRadius: BorderRadius.circular(StudioRadius.panel),
        border: Border.all(color: count > 0 ? _pickedBorder(context) : c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  type.name,
                  style: StudioType.sans(16, weight: StudioType.medium, color: ink),
                ),
              ),
              Text(
                type.isFree ? 'Free' : formatMoney(type.priceCents),
                style: StudioType.sans(16, color: ink),
              ),
            ],
          ),
          if (type.includes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              type.includes!.trim(),
              style: StudioType.label13(color: soldOut ? c.textTertiary : c.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: Row(
              children: [
                Expanded(
                  child: leftLine == null
                      ? const SizedBox.shrink()
                      : Text(leftLine, style: StudioType.mono(11, color: leftColor)),
                ),
                if (soldOut)
                  Text('Sold out', style: StudioType.mono(11, color: c.textTertiary))
                else
                  Container(
                    height: 34,
                    decoration: BoxDecoration(
                      border: Border.all(color: c.line),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StepButton(
                          label: '−',
                          semanticLabel: 'One less ${type.name}',
                          onTap: count > 0 ? onRemove : null,
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 16),
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: StudioType.mono(14, color: c.textPrimary),
                          ),
                        ),
                        _StepButton(
                          label: '+',
                          semanticLabel: 'One more ${type.name}',
                          onTap: max == null || count < max ? onAdd : null,
                        ),
                      ],
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

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.semanticLabel, required this.onTap});

  final String label;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 34,
          height: 32,
          child: Center(
            child: Text(
              label,
              style: StudioType.sans(17, color: onTap == null ? c.textPlaceholder : c.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
