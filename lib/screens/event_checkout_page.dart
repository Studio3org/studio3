import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show StripeException;

import '../models/collect_checkout.dart';
import '../models/event_order.dart';
import '../models/studio_event.dart';
import '../services/api_exception.dart';
import '../services/event_service.dart';
import '../services/user_service.dart';
import '../theme/collect_detail_tokens.dart' show formatMoney;
import '../widgets/events/event_tab_widgets.dart' show eventCity;
import '../widgets/events/event_tickets_sheet.dart';
import '../widgets/events/event_detail_widgets.dart' show EventCover;
import '../widgets/piece_detail/collect_payment_sheet.dart';
import '../widgets/piece_detail/collect_piece_sheet.dart' show CheckoutNavRow;
import '../widgets/studio/studio.dart';

/// How checkout ended, for the event page.
enum EventCheckoutOutcome {
  /// Paid; the viewer is going.
  paid,

  /// The tickets were changed to free ones only, which skip checkout: the event page
  /// reserves them instead (`NoteEvCheckout`).
  reserveInstead,
}

/// `$25.00`: checkout amounts always show cents (`EvCheckout`).
String eventCheckoutMoney(int cents) =>
    '${formatMoney(cents - cents % 100)}.${(cents % 100).toString().padLeft(2, '0')}';

/// Checkout for paid tickets (`EvCheckout`), laid out like buying a piece: the event (56 × 74
/// flyer, name 16/500, Mono start time, venue and city), rows for Tickets (change them),
/// Sent to (the account email) and Payment, then the order summary (each type × count, Free
/// when free, Service fee, Sales tax, Total), the refund line and "Confirm and pay $…".
///
/// The server prices the order (fee and tax) and takes the payment: BACKEND_CHANGES B22. Until
/// it can, the fee, tax and total show "–" and the button stays off. Orders of free tickets
/// only never come here.
class EventCheckoutPage extends StatefulWidget {
  const EventCheckoutPage({
    super.key,
    required this.event,
    required this.choice,
    @visibleForTesting this.debugQuote,
    @visibleForTesting this.debugEmail,
  });

  final StudioEvent event;
  final EventTicketChoice choice;

  /// Tests only: the server's price, instead of asking for it.
  final EventOrderQuote? debugQuote;
  final String? debugEmail;

  static Future<EventCheckoutOutcome?> open(
    BuildContext context, {
    required StudioEvent event,
    required EventTicketChoice choice,
  }) {
    return Navigator.of(context).push<EventCheckoutOutcome>(
      MaterialPageRoute(
        builder: (_) => EventCheckoutPage(event: event, choice: choice),
      ),
    );
  }

  @override
  State<EventCheckoutPage> createState() => _EventCheckoutPageState();
}

class _EventCheckoutPageState extends State<EventCheckoutPage> {
  late EventTicketChoice _choice = widget.choice;
  EventOrderQuote? _quote;
  bool _quoting = false;
  bool _paying = false;
  CollectPaymentMethod? _payment;
  String? _email;

  @override
  void initState() {
    super.initState();
    _email = widget.debugEmail ?? UserService.instance.peekMeCached()?.email;
    if (widget.debugQuote != null) {
      _quote = widget.debugQuote;
      return;
    }
    if (_email == null) _loadEmail();
    _loadQuote();
  }

  Future<void> _loadEmail() async {
    try {
      final me = await UserService.instance.getMeCached();
      if (mounted) setState(() => _email = me.email);
    } catch (_) {}
  }

  Future<void> _loadQuote() async {
    if (widget.debugQuote != null) return;
    setState(() {
      _quoting = true;
      _quote = null;
    });
    try {
      final quote = await EventService.instance.quoteOrder(widget.event.id, _choice.counts);
      if (mounted) setState(() => _quote = quote);
    } catch (_) {
      // Fee, tax and total stay "–" and Confirm and pay stays off.
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _changeTickets() async {
    final next = await EventTicketsSheet.show(context, widget.event, initial: _choice);
    if (next == null || !mounted) return;
    if (next.isFree) {
      Navigator.of(context).pop(EventCheckoutOutcome.reserveInstead);
      return;
    }
    setState(() => _choice = next);
    _loadQuote();
  }

  Future<void> _openPayment() async {
    final result = await CollectPaymentSheet.show(context, initial: _payment);
    if (result != null && mounted) setState(() => _payment = result);
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      await EventService.instance.placeOrder(widget.event.id, _choice.counts);
      if (mounted) Navigator.of(context).pop(EventCheckoutOutcome.paid);
    } on StripeException {
      // Closed the payment sheet: nothing was charged.
      if (mounted) setState(() => _paying = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      showStudioToast(context, e.message, icon: null);
      // A type may have sold out while this was open.
      _loadQuote();
    } catch (_) {
      if (!mounted) return;
      setState(() => _paying = false);
      showStudioToast(context, 'Could not finish checkout. Please try again.', icon: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final e = widget.event;
    final quote = _quote;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    final place = [e.venue, ?eventCity(e)].where((p) => p.isNotEmpty).join(', ');
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Checkout'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(StudioRadius.small),
                      child: SizedBox(width: 56, height: 74, child: EventCover(url: e.imageUrl)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
                          ),
                          const SizedBox(height: 3),
                          Text(eventStartLabel(e), style: StudioType.mono(12, color: c.textSecondary)),
                          if (place.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(place, style: StudioType.label13(color: c.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.line)),
                  ),
                  child: Column(
                    children: [
                      CheckoutNavRow(
                        label: 'Tickets',
                        value: _choice.summary,
                        placeholder: 'Choose tickets',
                        onTap: _paying ? null : _changeTickets,
                      ),
                      CheckoutNavRow(
                        label: 'Sent to',
                        value: _email,
                        placeholder: 'Your account email',
                        onTap: null,
                      ),
                      CheckoutNavRow(
                        label: 'Payment',
                        value: _payment?.label,
                        placeholder: 'Add a payment method',
                        onTap: _paying ? null : _openPayment,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _EventOrderSummary(choice: _choice, quote: quote),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, safe > 0 ? safe : StudioSize.noInsetBottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (quote?.refundPolicy?.trim().isNotEmpty == true) ...[
                  _RefundLine(policy: quote!.refundPolicy!.trim()),
                  const SizedBox(height: 10),
                ],
                StudioButton(
                  label: quote == null
                      ? 'Confirm and pay'
                      : 'Confirm and pay ${eventCheckoutMoney(quote.totalCents)}',
                  loading: _paying || _quoting,
                  onPressed: quote == null || _paying ? null : _pay,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Order summary" 15/500; each type × count (Free when free), Service fee, Sales tax (14,
/// label Graphite, 6 above and below); a Line, then Total 15/500. "–" in Mono until the server
/// has priced the order.
class _EventOrderSummary extends StatelessWidget {
  const _EventOrderSummary({required this.choice, required this.quote});

  final EventTicketChoice choice;
  final EventOrderQuote? quote;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    Widget line(String label, String? value, {bool strong = false}) {
      final style = strong
          ? StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary)
          : StudioType.body14(color: c.textPrimary);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: strong ? style : StudioType.body14(color: c.textSecondary)),
            ),
            Text(
              value ?? '–',
              style: value == null
                  ? StudioType.mono(strong ? 15 : 14, weight: style.fontWeight!, color: c.textPrimary)
                  : style,
            ),
          ],
        ),
      );
    }

    final q = quote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Order summary',
          style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
        ),
        const SizedBox(height: 6),
        for (final e in choice.counts.entries)
          if (e.value > 0)
            line(
              '${e.key.name} × ${e.value}',
              e.key.isFree ? 'Free' : eventCheckoutMoney(e.key.priceCents * e.value),
            ),
        line('Service fee', q == null ? null : eventCheckoutMoney(q.serviceFeeCents)),
        line('Sales tax', q == null ? null : eventCheckoutMoney(q.taxCents)),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: line('Total', q == null ? null : eventCheckoutMoney(q.totalCents), strong: true),
        ),
        if (q == null) ...[
          const SizedBox(height: 8),
          Text(
            'The service fee and tax are added once the order is priced.',
            style: StudioType.caption12(color: c.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// "Refunds up to 24 hours before the event. See policy" (12 Graphite, centred; the link in
/// Ink, opening the terms).
class _RefundLine extends StatefulWidget {
  const _RefundLine({required this.policy});

  final String policy;

  @override
  State<_RefundLine> createState() => _RefundLineState();
}

class _RefundLineState extends State<_RefundLine> {
  late final TapGestureRecognizer _link = TapGestureRecognizer()
    ..onTap = () => Navigator.of(context).pushNamed('/terms');

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final style = StudioType.caption12(height: 1.5, color: c.textSecondary);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: '${widget.policy} '),
          TextSpan(
            text: 'See policy',
            recognizer: _link,
            style: style.copyWith(
              color: c.textPrimary,
              decoration: TextDecoration.underline,
              decorationColor: c.textPrimary,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
