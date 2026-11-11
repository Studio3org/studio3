import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order.dart';
import '../services/api_exception.dart';
import '../services/order_service.dart';
import '../widgets/orders/order_row.dart';
import '../widgets/piece_detail/collected_bar.dart' show DeliveryTracker, PieceDelivery;
import '../widgets/settings_tile.dart' show SettingsSectionLabel;
import '../widgets/studio/studio.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.orderId, this.isSeller = false, this.debugOrder});

  final String orderId;
  final bool isSeller;

  /// For tests: the order, instead of asking the server.
  @visibleForTesting
  final Order? debugOrder;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Order? _order;
  bool _loading = true;
  bool _updating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final given = widget.debugOrder;
    if (given != null) {
      setState(() {
        _order = given;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await OrderService.instance.getOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load order';
        _loading = false;
      });
    }
  }

  /// Cancels the order (FRONTEND_HANDOFF 2.1). Before payment either side may. Once paid only
  /// the artist can, after a confirmation, and the server refunds the buyer in full: the order
  /// comes back `refunded`.
  Future<void> _cancel(Order order) async {
    final refunds = order.status == 'paid';
    if (refunds) {
      final confirmed = await showStudioConfirm(
        context,
        title: 'Cancel this sale?',
        message: 'The buyer will be refunded in full and the piece goes back on sale.',
        confirmLabel: 'Cancel sale',
        cancelLabel: 'Keep sale',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _updating = true);
    try {
      final updated = await OrderService.instance.updateOrderStatus(widget.orderId, 'cancelled');
      if (!mounted) return;
      setState(() {
        _order = updated;
        _updating = false;
      });
      if (refunds && updated.status == 'refunded') {
        showStudioToast(context, 'Sale cancelled. The buyer is being refunded.');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      showStudioToast(context, cancelErrorMessage(e), icon: null);
      // "Already going through": the payment is landing, so the order is about to be paid.
      if (e.statusCode == 409) _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _updating = false);
      showStudioToast(context, 'Could not update order', icon: null);
    }
  }

  /// "Confirm received" (FRONTEND_HANDOFF 8.4): the buyer says it arrived, which completes the
  /// order and pays the artist.
  Future<void> _confirmReceived() async {
    setState(() => _updating = true);
    try {
      final updated = await OrderService.instance.confirmReceived(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = updated;
        _updating = false;
      });
      showStudioToast(context, 'Thanks for confirming');
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      showStudioToast(context, e is ApiException ? e.message : 'Could not confirm. Try again.', icon: null);
    }
  }

  /// "Track shipment": Convelio's tracking page, outside the app.
  Future<void> _track(String url) async {
    try {
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && mounted) showStudioToast(context, "Couldn't open tracking", icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, "Couldn't open tracking", icon: null);
    }
  }

  /// "Report an issue" (FRONTEND_HANDOFF 2.1): the buyer's route once an order is paid. It
  /// holds the artist's payment and opens a dispute; the order comes back `disputed`.
  Future<void> _reportIssue() async {
    final reason = await showStudioSheet<String>(
      context: context,
      builder: (_) => const _ReportIssueSheet(),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    setState(() => _updating = true);
    try {
      final updated = await OrderService.instance.reportIssue(widget.orderId, reason);
      if (!mounted) return;
      setState(() {
        _order = updated;
        _updating = false;
      });
      showStudioToast(context, "Thanks. We'll look into it and get back to you.");
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      showStudioToast(context, e is ApiException ? e.message : 'Could not report the issue', icon: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.studio.background,
      appBar: StudioTopBar(context: context, title: 'Order details'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final c = context.studio;
    if (_loading) {
      return Center(
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
        ),
      );
    }
    final order = _order;
    if (order == null) {
      return Center(
        child: StudioEmptyState(
          title: "This order didn't load",
          message: _error,
          actionLabel: 'Try again',
          onAction: _load,
        ),
      );
    }

    final address = order.shippingAddress;
    final line = StudioType.body15(color: c.textPrimary);
    final actions = widget.isSeller ? _sellerActions(order) : _buyerActions(order);

    return ListView(
      padding: const EdgeInsets.fromLTRB(StudioSpace.marginForm, 8, StudioSpace.marginForm, 40),
      children: [
        Text('Status', style: StudioType.label13(color: c.textSecondary)),
        const SizedBox(height: 4),
        Text(
          orderStatusLabel(order.status),
          // Ink, except the status colours (Completed green, Cancelled grey).
          style: StudioType.header17(color: orderStatusColor(c, order.status, neutral: c.textPrimary)),
        ),
        if (address != null) ...[
          const SettingsSectionLabel('Shipping address', top: 28),
          const SizedBox(height: 8),
          Text(address.fullName, style: line),
          Text(address.line1, style: line),
          if (address.line2 != null && address.line2!.isNotEmpty) Text(address.line2!, style: line),
          Text('${address.city}, ${address.state} ${address.zip}', style: line),
        ],
        ..._shippingSection(order),
        const SizedBox(height: 28),
        Text(
          'Order summary',
          style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
        ),
        const SizedBox(height: 6),
        _SummaryLine(label: 'Piece', value: order.artworkDisplay),
        if (order.insuranceCents > 0) ...[
          // Shipping includes the insurance (FRONTEND_HANDOFF 8.3): shown on separate lines.
          _SummaryLine(label: 'Shipping', value: _money(order.shippingCents - order.insuranceCents)),
          _SummaryLine(label: 'Insurance', value: _money(order.insuranceCents)),
        ] else
          _SummaryLine(label: 'Shipping', value: order.shippingDisplay),
        _SummaryLine(label: 'Tax', value: order.taxDisplay),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: _SummaryLine(label: 'Total', value: order.totalDisplay, bold: true),
        ),
        if (actions.isNotEmpty) ...[const SizedBox(height: 28), ...actions],
      ],
    );
  }

  static String _money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  /// Convelio's tracking (FRONTEND_HANDOFF 8.4), when the order carries it: the tracker, a hold
  /// or cancellation, the reference in Mono, and Track shipment.
  List<Widget> _shippingSection(Order order) {
    final shipment = order.shipment;
    if (shipment == null || (shipment.steps.isEmpty && (shipment.trackingUrl ?? '').isEmpty)) return const [];
    final c = context.studio;
    final delivered = order.status == 'awaiting_confirmation' || order.status == 'completed' || shipment.isDelivered;
    final step = delivered ? 3 : (PieceDelivery.trackerStep(shipment) ?? 0);
    final flag = shipment.cancelled ? 'Shipment cancelled' : (shipment.onHold ? 'Shipment on hold' : null);
    final reference = (shipment.reference ?? '').isNotEmpty ? shipment.reference! : shipment.trackingNumber;
    final url = shipment.trackingUrl ?? '';
    return [
      const SettingsSectionLabel('Shipping', top: 28),
      const SizedBox(height: 12),
      DeliveryTracker(step: step, forArtist: widget.isSeller),
      if (flag != null) ...[
        const SizedBox(height: 10),
        Text(flag, style: StudioType.body14(color: c.textPrimary)),
      ],
      if (reference.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(reference, style: StudioType.mono(14, color: c.textPrimary)),
      ],
      if (url.isNotEmpty) ...[
        const SizedBox(height: 14),
        StudioButton(
          label: 'Track shipment',
          variant: StudioButtonVariant.outline,
          onPressed: () => _track(url),
        ),
      ],
    ];
  }

  /// The artist only cancels: shipping is updated by Studio 3 (and Convelio), and completion
  /// comes from the buyer's Confirm received (FRONTEND_HANDOFF 2.1).
  List<Widget> _sellerActions(Order order) {
    final actions = <Widget>[];
    if (order.status == 'pending_payment' || order.status == 'paid') {
      actions.add(_actionButton('Cancel order', () => _cancel(order), secondary: true));
    }
    return actions;
  }

  /// The buyer cancels only before payment; after it, they report an issue instead.
  List<Widget> _buyerActions(Order order) {
    final actions = <Widget>[];
    if (order.status == 'pending_payment') {
      actions.add(_actionButton('Cancel order', () => _cancel(order), secondary: true));
    }
    // Delivered (FRONTEND_HANDOFF 8.4): confirm it, or it completes by itself in 7 days.
    if (order.canConfirmReceipt) {
      actions.add(_actionButton('Confirm received', _confirmReceived));
      actions.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            'or it completes automatically in 7 days',
            textAlign: TextAlign.center,
            style: StudioType.caption12(color: context.studio.textSecondary),
          ),
        ),
      );
    }
    if (order.canReportIssue) {
      actions.add(_actionButton('Report an issue', _reportIssue, secondary: true));
    }
    return actions;
  }

  /// The order's next step in Ink; Cancel order as an outline (never red, `HandoffRules`).
  Widget _actionButton(String label, VoidCallback onTap, {bool secondary = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StudioButton(
        label: label,
        variant: secondary ? StudioButtonVariant.outline : StudioButtonVariant.primary,
        loading: _updating && !secondary,
        onPressed: _updating ? null : onTap,
      ),
    );
  }
}

/// What to show when a cancel is refused. The server's line as it is, except the rare 409 for an
/// artist already paid out: that text is for staff, so the artist is sent to support instead.
@visibleForTesting
String cancelErrorMessage(ApiException e) {
  if (e.statusCode == 409 && e.message.contains('already been paid')) {
    return 'We couldn\'t cancel this sale. Please contact support.';
  }
  return e.message.isNotEmpty ? e.message : 'Could not update order';
}

/// "Report an issue": a title 22, what happens 14 Graphite, one field, Send and Cancel (the
/// Settings field sheets).
class _ReportIssueSheet extends StatefulWidget {
  const _ReportIssueSheet();

  @override
  State<_ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<_ReportIssueSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final reason = _text.text.trim();
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 14,
      children: [
        Text('Report an issue', style: StudioType.title22(color: c.textPrimary)),
        Text(
          "Tell us what's wrong. We'll hold the artist's payment while we sort it out.",
          style: StudioType.body14(color: c.textSecondary),
        ),
        StudioUnderlineField(
          label: 'What went wrong',
          controller: _text,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
        StudioButton(
          label: 'Send',
          onPressed: reason.isEmpty ? null : () => Navigator.pop(context, reason),
        ),
        StudioButton(label: 'Cancel', variant: StudioButtonVariant.text, onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}

/// 14 Graphite label and Ink value, 6 above and below; Total 15/500 (the checkout summary).
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final strong = StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: bold ? strong : StudioType.body14(color: c.textSecondary)),
          const Spacer(),
          Text(value, style: bold ? strong : StudioType.body14(color: c.textPrimary)),
        ],
      ),
    );
  }
}
