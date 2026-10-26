import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:flutter/material.dart';

import '../models/studio_event.dart';
import '../widgets/events/event_detail_widgets.dart' show EventCover;
import '../widgets/events/event_tab_widgets.dart' show eventCity;
import '../widgets/events/event_tickets_sheet.dart';
import '../widgets/studio/studio.dart';
import 'event_ticket_page.dart';
import 'my_events_page.dart';

/// `GA · VIP`: each type's initials when it has several words, else its name.
String eventTicketTypesLine(EventTicketChoice choice) => [
  for (final e in choice.counts.entries)
    if (e.value > 0)
      e.key.name.trim().contains(' ')
          ? e.key.name.trim().split(RegExp(r'\s+')).map((w) => w[0].toUpperCase()).join()
          : e.key.name.trim(),
].join(' · ');

/// `SAT NOV 21 · 8:00 PM`.
String eventTicketWhen(StudioEvent e) => eventStartLabel(e).replaceAll(',', '').toUpperCase();

/// You're going (`EvConfirmed`), after Reserve or paying: "You're going." 36/500, the event
/// as a ticket that rises in straight, a line about where the tickets are, then Add to
/// calendar and the way to the tickets.
///
/// Add to Apple Wallet needs a pass the server signs (BACKEND_CHANGES B25), so Add to calendar
/// leads. View tickets opens the tickets (`EvTicket`, B22); a free reservation has no ticket
/// codes, so it says "Your events" and opens those.
class EventConfirmedPage extends StatefulWidget {
  const EventConfirmedPage({super.key, required this.event, required this.choice, this.email});

  final StudioEvent event;
  final EventTicketChoice choice;

  /// Where paid tickets were emailed; null for a free reservation.
  final String? email;

  static Future<void> open(
    BuildContext context, {
    required StudioEvent event,
    required EventTicketChoice choice,
    String? email,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EventConfirmedPage(event: event, choice: choice, email: email),
      ),
    );
  }

  @override
  State<EventConfirmedPage> createState() => _EventConfirmedPageState();
}

class _EventConfirmedPageState extends State<EventConfirmedPage> with SingleTickerProviderStateMixin {
  // The board's timings: headline up at .1 s, the ticket rises over .7 s, the line at .5 s and
  // the buttons at .6 s (each "up" .5 s).
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else if (_motion.value == 0 && !_motion.isAnimating) {
      _motion.forward();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Widget _enter(Widget child, {required int delayMs, required int durationMs, double rise = 10, Curve? curve}) {
    final t = CurvedAnimation(
      parent: _motion,
      curve: Interval(delayMs / 1100, (delayMs + durationMs) / 1100, curve: curve ?? Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: t,
      child: child,
      builder: (context, child) => Opacity(
        opacity: t.value,
        child: Transform.translate(offset: Offset(0, rise * (1 - t.value)), child: child),
      ),
    );
  }

  Future<void> _addToCalendar() async {
    final e = widget.event;
    final added = await cal.Add2Calendar.addEvent2Cal(
      cal.Event(
        title: e.title,
        description: e.details.isEmpty ? null : e.details,
        location: [e.venue, e.address ?? ''].where((p) => p.trim().isNotEmpty).join(', '),
        startDate: e.startsAt,
        endDate: e.endsAt,
      ),
    ).catchError((_) => false);
    if (!added && mounted) showStudioToast(context, 'Could not open your calendar.', icon: null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final choice = widget.choice;
    final paid = !choice.isFree;
    final count = choice.count;
    final email = widget.email;
    final note = paid
        ? 'Your $count ${count == 1 ? 'ticket is' : 'tickets are'} saved here'
              '${email == null ? '.' : ' and emailed to $email.'}'
        : 'Your place is saved in Your events.';
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  button: true,
                  label: 'Close',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox.square(
                      dimension: 44,
                      child: Center(child: StudioIcon(StudioIcons.close, size: 22, color: c.textPrimary)),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _enter(
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "You're going.",
                          style: StudioType.sans(
                            36,
                            weight: StudioType.medium,
                            letterSpacing: -1,
                            height: 1,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      delayMs: 100,
                      durationMs: 500,
                    ),
                    const SizedBox(height: 22),
                    _enter(
                      EventTicketArt(event: widget.event, choice: choice),
                      delayMs: 0,
                      durationMs: 700,
                      rise: 40,
                      curve: const Cubic(0.2, 0.8, 0.2, 1),
                    ),
                    const SizedBox(height: 22),
                    _enter(
                      Text(
                        note,
                        textAlign: TextAlign.center,
                        style: StudioType.sans(14, height: 1.5, color: c.textSecondary),
                      ),
                      delayMs: 500,
                      durationMs: 500,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _enter(
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, safe > 0 ? safe : StudioSize.noInsetBottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StudioButton(label: 'Add to calendar', onPressed: _addToCalendar),
                    const SizedBox(height: 10),
                    StudioButton(
                      label: paid ? 'View tickets' : 'Your events',
                      variant: StudioButtonVariant.outline,
                      height: 48,
                      onPressed: () => paid
                          ? EventTicketPage.open(context, widget.event)
                          : MyEventsPage.open(context),
                    ),
                  ],
                ),
              ),
              delayMs: 600,
              durationMs: 500,
            ),
          ],
        ),
      ),
    );
  }
}

/// The ticket (`EvConfirmed`): 300 × 452, one clip path with the four corners cut inward (18)
/// and a notch (10) on each side at 300; the flyer 300 × 300 on top; 16 dots on the tear
/// line; the stub tinted with the iridescent gradient (115°, 55 %) holding ADMIT n and the
/// types (Mono 11), the name 19/500, the Mono 12 date and the venue 13. A ticket is a white
/// object in both themes, with a soft shadow under it.
class EventTicketArt extends StatelessWidget {
  const EventTicketArt({super.key, required this.event, required this.choice});

  final StudioEvent event;
  final EventTicketChoice choice;

  static const size = Size(300, 452);

  @override
  Widget build(BuildContext context) {
    const ink = StudioColors.ink;
    const stubInk = Color(0xFF333333);
    final place = [event.venue, ?eventCity(event)].where((p) => p.isNotEmpty).join(', ');
    return Semantics(
      label: 'Ticket: ${event.title}, ${eventStartLabel(event)}',
      excludeSemantics: true,
      child: CustomPaint(
        painter: const _TicketShadow(),
        child: ClipPath(
          clipper: const _TicketClip(),
          child: SizedBox.fromSize(
            size: size,
            child: ColoredBox(
              color: Colors.white,
              child: Stack(
                children: [
                  Positioned(left: 0, top: 0, width: 300, height: 300, child: EventCover(url: event.imageUrl)),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 300,
                    bottom: 0,
                    child: Opacity(
                      opacity: 0.55,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            // CSS 115°: from upper left to lower right, a little past horizontal.
                            begin: const Alignment(-1, -0.47),
                            end: const Alignment(1, 0.47),
                            colors: StudioColors.iridescentStops,
                            stops: StudioColors.iridescentPositions,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 22,
                    right: 22,
                    top: 297,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 16; i++)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: Color(0xFFE3E3E0), shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 22,
                    right: 22,
                    top: 318,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                'ADMIT ${choice.count}',
                                style: StudioType.mono(11, letterSpacing: 1, color: stubInk),
                              ),
                            ),
                            Text(eventTicketTypesLine(choice), style: StudioType.mono(11, color: stubInk)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: StudioType.sans(
                            19,
                            weight: StudioType.medium,
                            letterSpacing: -0.3,
                            height: 1.2,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(eventTicketWhen(event), style: StudioType.mono(12, color: ink)),
                        if (place.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.sans(13, color: const Color(0xFF555555)),
                          ),
                        ],
                      ],
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

/// `M 18 0 L 282 0 A 18 18 0 0 0 300 18 L 300 290 A 10 10 0 0 0 300 310 L 300 434
/// A 18 18 0 0 0 282 452 L 18 452 A 18 18 0 0 0 0 434 L 0 310 A 10 10 0 0 0 0 290 L 0 18
/// A 18 18 0 0 0 18 0 Z` at 300 × 452.
Path _ticketPath() {
  const r = Radius.circular(18);
  const n = Radius.circular(10);
  return Path()
    ..moveTo(18, 0)
    ..lineTo(282, 0)
    ..arcToPoint(const Offset(300, 18), radius: r, clockwise: false)
    ..lineTo(300, 290)
    ..arcToPoint(const Offset(300, 310), radius: n, clockwise: false)
    ..lineTo(300, 434)
    ..arcToPoint(const Offset(282, 452), radius: r, clockwise: false)
    ..lineTo(18, 452)
    ..arcToPoint(const Offset(0, 434), radius: r, clockwise: false)
    ..lineTo(0, 310)
    ..arcToPoint(const Offset(0, 290), radius: n, clockwise: false)
    ..lineTo(0, 18)
    ..arcToPoint(const Offset(18, 0), radius: r, clockwise: false)
    ..close();
}

class _TicketClip extends CustomClipper<Path> {
  const _TicketClip();

  @override
  Path getClip(Size size) => _ticketPath();

  @override
  bool shouldReclip(_TicketClip oldClipper) => false;
}

/// `drop-shadow(0 22px 36px rgba(17,17,17,0.2))` under the ticket's shape.
class _TicketShadow extends CustomPainter {
  const _TicketShadow();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _ticketPath().shift(const Offset(0, 22)),
      Paint()
        ..color = const Color(0x33111111)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  @override
  bool shouldRepaint(_TicketShadow oldDelegate) => false;
}
