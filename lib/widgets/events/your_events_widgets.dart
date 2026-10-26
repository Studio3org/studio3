import 'package:flutter/material.dart';

import '../../models/studio_event.dart';
import '../studio/studio.dart';
import 'event_detail_widgets.dart' show EventCover, eventDayLabel;
import 'event_tab_widgets.dart' show eventCity;
import 'event_tickets_sheet.dart' show eventStartLabel;

/// How soon the next event is (`EvMyTickets` "In 3 days"): Happening now, Today, Tomorrow, In
/// n days (to 13), then In n weeks. Counted in calendar days.
String eventHowSoon(StudioEvent e, DateTime now) {
  if (!e.startsAt.isAfter(now) && e.endsAt.isAfter(now)) return 'Happening now';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(e.startsAt.year, e.startsAt.month, e.startsAt.day);
  final days = day.difference(today).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days < 14) return 'In $days days';
  return 'In ${days ~/ 7} weeks';
}

/// A section label (`EvMyTickets` Upcoming / Saved): Mono 11 Tertiary, caps, 0.5 spacing; 30
/// above, 12 below.
class YourEventsLabel extends StatelessWidget {
  const YourEventsLabel(this.text, {super.key, this.top = 30});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: StudioType.mono(11, letterSpacing: 0.5, color: context.studio.textTertiary),
      ),
    );
  }
}

/// The next event (`EvMyTickets`): flyer full width × 228 at radius 14 with how soon it is
/// (Mono 12 white) 12 / 14 in; under it, 10 below, the name 18/500, the Mono 12 date and
/// "venue, city" 13 Graphite, with the outline button (36, radius 10, 13/500) on the right.
class NextEventCard extends StatelessWidget {
  const NextEventCard({
    super.key,
    required this.event,
    required this.now,
    required this.onTap,
    required this.buttonLabel,
    this.detail,
  });

  final StudioEvent event;
  final DateTime now;
  final VoidCallback onTap;
  final String buttonLabel;

  /// Added after the place: "2 tickets".
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final place = [
      [event.venue, ?eventCity(event)].where((p) => p.isNotEmpty).join(', '),
      ?detail,
    ].where((p) => p.isNotEmpty).join(' · ');
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(StudioRadius.panel),
              child: SizedBox(
                height: 228,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EventCover(url: event.imageUrl),
                    Positioned(
                      top: 12,
                      left: 14,
                      child: Text(
                        eventHowSoon(event, now),
                        style: StudioType.mono(12, color: Colors.white).copyWith(
                          shadows: const [Shadow(color: Color(0x73000000), offset: Offset(0, 1), blurRadius: 0.87)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: StudioType.sans(18, weight: StudioType.medium, color: c.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(eventStartLabel(event), style: StudioType.mono(12, color: c.textSecondary)),
                      if (place.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(place, style: StudioType.label13(color: c.textSecondary)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.lineStrong),
                    ),
                    child: Text(buttonLabel, style: StudioType.label13(weight: StudioType.medium, color: c.textPrimary)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A smaller event row (`EvMyTickets`): 52 × 69 flyer at radius 8, 14 gap, name 15/500, the
/// Mono 12 date and a 13 Graphite line; chevron 16; 12 above and below with a Line under it
/// ([first] adds one over it too).
class YourEventRow extends StatelessWidget {
  const YourEventRow({
    super.key,
    required this.event,
    required this.line,
    required this.onTap,
    this.first = false,
    this.trailing,
  });

  final StudioEvent event;
  final String line;
  final VoidCallback onTap;
  final bool first;

  /// Replaces the chevron (the host's ··· menu).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final side = BorderSide(color: c.line);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(top: first ? side : BorderSide.none, bottom: side)),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(StudioRadius.small),
                child: SizedBox(width: 52, height: 69, child: EventCover(url: event.imageUrl)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(eventStartLabel(event), style: StudioType.mono(12, color: c.textSecondary)),
                    if (line.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: StudioType.label13(color: c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ?? StudioIcon(StudioIcons.chevronRight, size: 16, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A saved event (`EvMyTickets` Saved): 132 × 176 flyer at radius 10, the name 14/500 8 below,
/// the Mono 11 day, then "Only n left" (red, 5 or fewer) or "Sold out" (Tertiary).
class SavedEventCard extends StatelessWidget {
  const SavedEventCard({super.key, required this.event, required this.onTap});

  final StudioEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final left = event.spotsLeft;
    final (String? status, Color statusColor) = event.isFull
        ? ('Sold out', c.textTertiary)
        : (left != null && left > 0 && left <= 5)
        ? ('Only $left left', c.alert)
        : (null, c.textTertiary);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 132,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(StudioRadius.card),
                child: SizedBox(width: 132, height: 176, child: EventCover(url: event.imageUrl)),
              ),
              const SizedBox(height: 8),
              Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(eventDayLabel(event), style: StudioType.mono(11, color: c.textSecondary)),
              if (status != null) ...[
                const SizedBox(height: 4),
                Text(status, style: StudioType.mono(11, color: statusColor)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A row that opens a list (`EvMyTickets` "Past events"): 15, chevron 16, 16 above and below,
/// a Line over and under.
class YourEventsLinkRow extends StatelessWidget {
  const YourEventsLinkRow({super.key, required this.label, required this.onTap, this.detail});

  final String label;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final side = BorderSide(color: c.line);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(border: Border(top: side, bottom: side)),
          child: Row(
            children: [
              Expanded(child: Text(label, style: StudioType.body15(color: c.textPrimary))),
              if (detail != null) ...[
                Text(detail!, style: StudioType.mono(12, color: c.textTertiary)),
                const SizedBox(width: 8),
              ],
              StudioIcon(StudioIcons.chevronRight, size: 16, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
