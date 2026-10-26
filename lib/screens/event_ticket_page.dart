import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/event_order.dart';
import '../models/studio_event.dart';
import '../services/event_service.dart';
import '../widgets/events/event_detail_widgets.dart' show EventCover, openEventDirections;
import '../widgets/events/event_tab_widgets.dart' show eventCity;
import '../widgets/events/event_tickets_sheet.dart' show eventStartLabel;
import '../widgets/studio/studio.dart';

/// The ticket (`EvTicket`): one per screen, swiped left and right with small bars showing
/// which; each a white card in a thin iridescent border with the event at the top and, under a
/// dashed tear line, the QR code scanned at the door, the ticket type and the Mono number.
/// Then Directions.
///
/// Tickets come from `GET /api/user/me/tickets` (BACKEND_CHANGES B22); this page opens only for
/// events with tickets. Add to Apple Wallet waits on B25.
class EventTicketPage extends StatefulWidget {
  const EventTicketPage({super.key, required this.event, this.tickets});

  final StudioEvent event;

  /// Already loaded (tests); fetched otherwise.
  final List<EventTicket>? tickets;

  static Future<void> open(BuildContext context, StudioEvent event) {
    return Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => EventTicketPage(event: event)));
  }

  @override
  State<EventTicketPage> createState() => _EventTicketPageState();
}

class _EventTicketPageState extends State<EventTicketPage> {
  final _pages = PageController();
  List<EventTicket>? _tickets;
  bool _failed = false;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _tickets = widget.tickets;
    if (_tickets == null) _load();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final tickets = await EventService.instance.myTickets(widget.event.id);
      if (mounted) setState(() => _tickets = tickets);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final tickets = _tickets;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    final scaler = MediaQuery.textScalerOf(context);
    // Card: 2 border, 113 event block, the code block (22 + 189 + 10 + type + 10 + number + 18).
    final cardHeight = 4 + 113 + 22 + 189 + 10 + scaler.scale(14) * 1.3 + 10 + scaler.scale(11) * 1.3 + 18;

    Widget body;
    if (tickets == null) {
      body = Center(
        child: _failed
            ? StudioEmptyState(title: "Your tickets didn't load", actionLabel: 'Try again', onAction: _load)
            : SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
              ),
      );
    } else if (tickets.isEmpty) {
      body = const Center(
        child: StudioEmptyState(
          title: 'No tickets for this event',
          message: 'Tickets you get for it show up here.',
        ),
      );
    } else {
      final many = tickets.length > 1;
      body = ListView(
        padding: const EdgeInsets.only(top: 12),
        children: [
          SizedBox(
            height: cardHeight,
            child: PageView.builder(
              controller: _pages,
              itemCount: tickets.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: EventTicketCard(
                  event: widget.event,
                  ticket: tickets[i],
                  position: i + 1,
                  of: tickets.length,
                ),
              ),
            ),
          ),
          if (many) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < tickets.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  AnimatedContainer(
                    duration: StudioMotion.quick,
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index ? c.textPrimary : c.lineStrong,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              many
                  ? 'Swipe for your other ${tickets.length == 2 ? 'ticket' : 'tickets'}. '
                        'Turn your brightness up at the door.'
                  : 'Turn your brightness up at the door.',
              textAlign: TextAlign.center,
              style: StudioType.label13(color: c.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Ticket'),
      body: body,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, safe > 0 ? safe : StudioSize.noInsetBottomPadding),
        child: StudioButton(
          label: 'Directions',
          variant: StudioButtonVariant.outline,
          height: 50,
          onPressed: () => openEventDirections(context, widget.event),
        ),
      ),
    );
  }
}

/// One ticket (`EvTicket`): a 2 px iridescent border (115°) around a white card at radius 20.
/// Top: 60 × 80 flyer, name 16/500, Mono 12 date, place 13; a dashed tear line; then the QR
/// code (189), the type 14 and "Ticket 1 of 2 · number" in Mono 11. White in both themes so the
/// code always scans.
class EventTicketCard extends StatelessWidget {
  const EventTicketCard({
    super.key,
    required this.event,
    required this.ticket,
    required this.position,
    required this.of,
  });

  final StudioEvent event;
  final EventTicket ticket;
  final int position;
  final int of;

  @override
  Widget build(BuildContext context) {
    const ink = StudioColors.ink;
    const graphite = Color(0xFF6B6B6B);
    final place = [event.venue, ?eventCity(event)].where((p) => p.isNotEmpty).join(', ');
    final used = ticket.scannedAt != null;
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(22)),
          gradient: LinearGradient(
            begin: Alignment(-1, -0.47),
            end: Alignment(1, 0.47),
            colors: StudioColors.iridescentStops,
            stops: StudioColors.iridescentPositions,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ColoredBox(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(StudioRadius.small),
                        child: SizedBox(width: 60, height: 80, child: EventCover(url: event.imageUrl)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              event.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: StudioType.sans(16, weight: StudioType.medium, color: ink),
                            ),
                            const SizedBox(height: 3),
                            Text(eventStartLabel(event), style: StudioType.mono(12, color: graphite)),
                            if (place.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(place, style: StudioType.label13(color: graphite)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const CustomPaint(size: Size.fromHeight(1), painter: _DashedLine(Color(0xFFD4D4D0))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                  child: Column(
                    children: [
                      Semantics(
                        label: 'Ticket QR code',
                        image: true,
                        child: Opacity(
                          opacity: used ? 0.25 : 1,
                          child: QrImageView(
                            data: ticket.code,
                            size: 189,
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ink),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        used ? '${ticket.typeName} · Scanned in' : ticket.typeName,
                        style: StudioType.body14(color: ink),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Ticket $position of $of · ${ticket.label}',
                        style: StudioType.mono(11, color: const Color(0xFF8E8E8E)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `border-bottom: 1px dashed`.
class _DashedLine extends CustomPainter {
  const _DashedLine(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 3.0;
    for (var x = 0.0; x < size.width; x += dash * 2) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + dash, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLine old) => old.color != color;
}
