import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/event_order.dart';
import '../models/studio_event.dart';
import '../services/api_exception.dart';
import '../services/event_service.dart';
import '../utils/money_format.dart';
import '../widgets/events/event_detail_widgets.dart' show EventCover, openEventDirections, rescheduledNote;
import '../widgets/events/event_tab_widgets.dart' show eventCity;
import '../widgets/events/event_tickets_sheet.dart' show eventStartLabel;
import '../widgets/events/event_wallet_button.dart';
import '../widgets/studio/studio.dart';

/// The ticket (`EvTicket`): one per screen, swiped left and right with small bars showing
/// which; each a white card in a thin iridescent border with the event at the top and, under a
/// dashed tear line, the QR code scanned at the door, the ticket type and the Mono number.
/// Then Add to Apple / Google Wallet for the ticket on screen, when the server says that wallet
/// can take it (B25), and Directions.
///
/// Tickets come from `GET /api/user/me/tickets` (BACKEND_CHANGES B22); this page opens only for
/// events with tickets.
///
/// Under the card, "Refund this ticket" while the server says the ticket on screen can be
/// refunded (Phase 4.1); nothing when it can't. After a reschedule, a line says so (4.4).
class EventTicketPage extends StatefulWidget {
  const EventTicketPage({super.key, required this.event, this.tickets, this.onRefunded});

  final StudioEvent event;

  /// Already loaded (tests); fetched otherwise.
  final List<EventTicket>? tickets;

  /// Called after a refund, so whatever opened the page can refresh the event's count.
  final VoidCallback? onRefunded;

  /// True when tickets were refunded while it was open, so the caller reloads the event's
  /// `ticketCount` / `viewerIsGoing`.
  static Future<bool> open(BuildContext context, StudioEvent event) async {
    var refunded = false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => EventTicketPage(event: event, onRefunded: () => refunded = true)),
    );
    return refunded;
  }

  @override
  State<EventTicketPage> createState() => _EventTicketPageState();
}

class _EventTicketPageState extends State<EventTicketPage> {
  final _pages = PageController();
  List<EventTicket>? _tickets;
  bool _failed = false;
  int _index = 0;
  bool _refunding = false;

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

  /// Refund the ticket on screen, or every refundable one in its order (Phase 4.1). The
  /// confirmation names the amount the server will return.
  Future<void> _refund(EventTicket ticket) async {
    final orderId = ticket.orderId;
    final tickets = _tickets;
    if (orderId == null || tickets == null || _refunding) return;
    setState(() => _refunding = true);
    final service = EventService.instance;
    EventOrderStatus? order;
    var types = widget.event.ticketTypes;
    try {
      order = await service.getOrder(widget.event.id, orderId);
    } catch (_) {
      // The confirmation goes without the amount.
    }
    if (types.isEmpty) {
      try {
        types = (await service.getById(widget.event.id)).ticketTypes;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _refunding = false);
    final prices = {for (final t in types.reversed) t.name: t.priceCents};
    final inOrder = tickets.where((t) => t.orderId == orderId).toList();
    final live = order?.ticketCount ?? inOrder.length;
    final refundable = inOrder.where((t) => t.refundable).toList();
    int? amount(List<EventTicket> picked) =>
        ticketRefundCents(order: order, unitPrices: [for (final t in picked) prices[t.typeName]], liveInOrder: live);
    final one = amount([ticket]);
    final all = refundable.length > 1 ? amount(refundable) : null;
    String money(int? cents) => cents == null ? '' : ' ${formatMoney(cents)}';
    String? choice;
    if (refundable.length > 1) {
      choice = await showStudioSheet<String>(
        context: context,
        builder: (sheetContext) {
          final c = sheetContext.studio;
          return StudioSheet(
            horizontalPadding: StudioSpace.marginForm,
            gap: 14,
            children: [
              Text('Refund tickets?', style: StudioType.title22(color: c.textPrimary)),
              Text(
                'The money goes back to your card. It may take a few days to appear.',
                style: StudioType.body14(color: c.textSecondary),
              ),
              const SizedBox(height: 2),
              StudioButton(
                label: 'Refund this ticket${money(one)}',
                onPressed: () => Navigator.pop(sheetContext, 'one'),
              ),
              StudioButton(
                label: 'Refund all ${refundable.length} tickets${money(all)}',
                variant: StudioButtonVariant.outline,
                height: 52,
                onPressed: () => Navigator.pop(sheetContext, 'all'),
              ),
              StudioButton(
                label: 'Keep tickets',
                variant: StudioButtonVariant.text,
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          );
        },
      );
    } else {
      final ok = await showStudioConfirm(
        context,
        title: 'Refund this ticket?',
        message: one == null
            ? 'The money goes back to your card. It may take a few days to appear.'
            : "We'll refund ${formatMoney(one)} to your card. It may take a few days to appear.",
        confirmLabel: 'Refund',
        cancelLabel: 'Keep ticket',
      );
      choice = ok ? 'one' : null;
    }
    if (choice == null || !mounted) return;
    setState(() => _refunding = true);
    try {
      final result = await service.refundTickets(
        widget.event.id,
        orderId,
        ticketIds: choice == 'all' ? null : [ticket.id],
      );
      if (!mounted) return;
      widget.onRefunded?.call();
      showStudioToast(
        context,
        result.amountCents > 0 ? 'Refunded ${formatMoney(result.amountCents)}' : 'Refunded',
      );
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, "The refund didn't go through. Try again.", icon: null);
    }
    if (!mounted) return;
    setState(() => _refunding = false);
    await _load();
    if (!mounted) return;
    setState(() => _index = 0);
    if (_pages.hasClients) _pages.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final tickets = _tickets;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    final scaler = MediaQuery.textScalerOf(context);
    // Card: 2 border, 113 event block, the code block (22 + 189 + 10 + type + 10 + number + 18).
    final current = tickets == null || tickets.isEmpty ? null : tickets[_index.clamp(0, tickets.length - 1)];
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
          if (widget.event.rescheduledAt != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                rescheduledNote(widget.event),
                textAlign: TextAlign.center,
                style: StudioType.label13(color: c.textSecondary),
              ),
            ),
          ],
          if (current != null && current.refundable && current.orderId != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: StudioButton(
                key: const ValueKey('refund-ticket'),
                label: 'Refund this ticket',
                variant: StudioButtonVariant.text,
                loading: _refunding,
                onPressed: _refunding ? null : () => _refund(current),
              ),
            ),
          ],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (current?.orderId case final orderId? when EventWalletButton.showsFor(current!.walletPasses)) ...[
              EventWalletButton(
                key: ValueKey('wallet-${current.id}'),
                eventId: widget.event.id,
                orderId: orderId,
                passes: current.walletPasses,
                ticketId: current.id,
              ),
              const SizedBox(height: 10),
            ],
            StudioButton(
              label: 'Directions',
              variant: StudioButtonVariant.outline,
              height: 50,
              onPressed: () => openEventDirections(context, widget.event),
            ),
          ],
        ),
      ),
    );
  }
}

/// What refunding [unitPrices] (one entry per ticket; null when its price is unknown) of an
/// order returns, as the server works it out (`ticket_refunds._split`): the tickets' prices
/// plus their tax, or exactly what's left when they are the order's last [liveInOrder]
/// tickets. Null without the order's totals.
@visibleForTesting
int? ticketRefundCents({required EventOrderStatus? order, required List<int?> unitPrices, required int liveInOrder}) {
  final total = order?.totalCents;
  if (order == null || total == null || unitPrices.isEmpty) return null;
  final remaining = math.max(0, total - order.refundedCents);
  if (unitPrices.length >= liveInOrder) return remaining;
  if (unitPrices.any((p) => p == null)) {
    return liveInOrder <= 0 ? null : (remaining * unitPrices.length / liveInOrder).round();
  }
  final subtotal = unitPrices.fold<int>(0, (sum, p) => sum + p!);
  final tax = _taxFor(subtotal, orderSubtotal: order.subtotalCents ?? total - (order.taxCents ?? 0), orderTax: order.taxCents ?? 0);
  return math.min(subtotal + tax, remaining);
}

/// The server's tax on [cents] (`(cents × bps + 5000) ÷ 10000`), with the rate read back from
/// the order's own subtotal and tax. When several rates fit the order, the roundest one (a
/// configured rate like 8.25 % is 825) is taken; the order's ratio is the last resort.
int _taxFor(int cents, {required int orderSubtotal, required int orderTax}) {
  if (cents <= 0 || orderTax <= 0 || orderSubtotal <= 0) return 0;
  int roundness(int bps) => bps % 100 == 0 ? 3 : bps % 25 == 0 ? 2 : bps % 5 == 0 ? 1 : 0;
  int? best;
  for (var bps = 1; bps <= 10000; bps++) {
    if ((orderSubtotal * bps + 5000) ~/ 10000 != orderTax) continue;
    if (best == null || roundness(bps) > roundness(best)) best = bps;
  }
  if (best == null) return (cents * orderTax / orderSubtotal).round();
  return (cents * best + 5000) ~/ 10000;
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
                        // The ticket is white in both themes, so it uses the light tertiary.
                        style: StudioType.mono(11, color: StudioColors.light.textTertiary),
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
