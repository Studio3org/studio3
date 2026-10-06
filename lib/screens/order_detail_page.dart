import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/api_exception.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/loading/app_skeletons.dart';
import '../theme/app_fonts.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    super.key,
    required this.orderId,
    this.isSeller = false,
  });

  final String orderId;
  final bool isSeller;

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

  Future<void> _updateStatus(String status) async {
    setState(() => _updating = true);
    try {
      final order = await OrderService.instance.updateOrderStatus(
        widget.orderId,
        status,
      );
      if (!mounted) return;
      setState(() {
        _order = order;
        _updating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      final message = e is ApiException ? e.message : 'Could not update order';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      appBar: AppBar(
        backgroundColor: HomeFeedTokens.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Order details',
          style: AppFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: HomeFeedTokens.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Only placehold while there is genuinely no order to show; a
    // refresh over an already-loaded order leaves it on screen.
    if (_loading && _order == null) {
      return const DetailSkeleton();
    }
    final order = _order;
    if (order == null) {
      return Center(
        child: Text(
          _error ?? 'Order not found',
          style: AppFonts.inter(fontSize: 14, color: AppColors.slate400),
        ),
      );
    }

    final address = order.shippingAddress;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status',
                style: AppFonts.inter(fontSize: 12, color: AppColors.slate500),
              ),
              const SizedBox(height: 4),
              Text(
                order.statusLabel,
                style: AppFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate900,
                ),
              ),
              if (_escrowNote(order) != null) ...[
                const SizedBox(height: 6),
                Text(
                  _escrowNote(order)!,
                  style: AppFonts.inter(fontSize: 12, color: AppColors.slate500),
                ),
              ],
            ],
          ),
        ),
        if (order.shipment != null) ...[
          const SizedBox(height: 16),
          _trackingCard(order.shipment!),
        ],
        if (order.dispute != null && order.dispute!.isOpen) ...[
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Issue reported',
                    style: AppFonts.inter(fontSize: 12, color: AppColors.slate500)),
                const SizedBox(height: 6),
                Text(order.dispute!.reason, style: AppFonts.inter(fontSize: 14)),
                const SizedBox(height: 6),
                Text(
                  "Our team is looking into this and will be in touch. The artist "
                  "hasn't been paid while this is open.",
                  style: AppFonts.inter(fontSize: 12, color: AppColors.slate500),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (address != null)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shipping address',
                  style: AppFonts.inter(fontSize: 12, color: AppColors.slate500),
                ),
                const SizedBox(height: 8),
                Text(address.fullName, style: AppFonts.inter(fontSize: 14)),
                Text(address.line1, style: AppFonts.inter(fontSize: 14)),
                if (address.line2 != null && address.line2!.isNotEmpty)
                  Text(address.line2!, style: AppFonts.inter(fontSize: 14)),
                Text(
                  '${address.city}, ${address.state} ${address.zip}',
                  style: AppFonts.inter(fontSize: 14),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order summary',
                style: AppFonts.inter(fontSize: 12, color: AppColors.slate500),
              ),
              const SizedBox(height: 12),
              _SummaryLine(label: 'Piece', value: order.artworkDisplay),
              const SizedBox(height: 6),
              _SummaryLine(label: 'Shipping', value: order.shippingDisplay),
              const SizedBox(height: 6),
              _SummaryLine(label: 'Tax', value: order.taxDisplay),
              const Divider(height: 20),
              _SummaryLine(label: 'Total', value: order.totalDisplay, bold: true),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (widget.isSeller) ..._sellerActions(order),
        if (!widget.isSeller) ..._buyerActions(order),
      ],
    );
  }

  List<Widget> _sellerActions(Order order) {
    final actions = <Widget>[];
    // Shipping is arranged by the Studiothree team, so the seller no longer marks
    // an order shipped or completed. Completion in particular belongs to the
    // collector alone — it is what releases the artist's payout, so the artist
    // confirming their own sale would defeat the point of holding the funds.
    if (order.status == 'pending_payment' || order.status == 'paid') {
      actions.add(_actionButton('Cancel order', () => _updateStatus('cancelled'),
          destructive: true));
    }
    return actions;
  }

  /// Explains where the money is, in the collector's or artist's terms.
  String? _escrowNote(Order order) {
    switch (order.status) {
      case 'paid':
        return widget.isSeller
            ? "We're arranging collection. You'll be paid once the collector confirms it arrived."
            : "We're arranging collection with the artist.";
      case 'shipped':
        return widget.isSeller
            ? 'On its way. Payment is released once the collector confirms receipt.'
            : 'On its way to you.';
      case 'awaiting_confirmation':
        return widget.isSeller
            ? 'Delivered. Waiting for the collector to confirm receipt.'
            : 'Confirm it arrived in good condition to release payment to the artist.';
      case 'completed':
        return widget.isSeller ? 'Payment released.' : 'Thank you — the artist has been paid.';
      case 'refunded':
        return widget.isSeller ? 'This order was refunded.' : 'Your refund is on its way.';
      default:
        return null;
    }
  }

  Widget _trackingCard(OrderShipment shipment) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tracking',
              style: AppFonts.inter(fontSize: 12, color: AppColors.slate500)),
          const SizedBox(height: 8),
          _SummaryLine(label: 'Courier', value: shipment.courier),
          const SizedBox(height: 6),
          _SummaryLine(label: 'Tracking number', value: shipment.trackingNumber),
          const SizedBox(height: 6),
          _SummaryLine(label: 'Status', value: shipment.statusLabel),
        ],
      ),
    );
  }

  List<Widget> _buyerActions(Order order) {
    final actions = <Widget>[];
    if (order.canConfirmReceipt) {
      actions.add(_actionButton('Confirm I received it', _confirmReceived));
    }
    if (order.canReportIssue && !order.isDisputed) {
      actions.add(_actionButton('Report a problem', _reportIssue, destructive: true));
    }
    if (order.status == 'pending_payment' || order.status == 'paid') {
      actions.add(_actionButton('Cancel order', () => _updateStatus('cancelled'),
          destructive: true));
    }
    return actions;
  }

  Future<void> _confirmReceived() async {
    // Releasing money is irreversible from the app's side, so confirm intent first.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm receipt'),
        content: const Text(
          'This releases payment to the artist and completes the order. '
          'Only confirm once you have the artwork and it arrived in good condition.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _updating = true);
    try {
      final order = await OrderService.instance.confirmReceived(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _updating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      final message = e is ApiException ? e.message : 'Could not confirm receipt';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _reportIssue() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report a problem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Tell us what's wrong — damaged, wrong piece, or never arrived. "
              "We'll hold the artist's payment while we look into it.",
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'What happened?'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _updating = true);
    try {
      final order = await OrderService.instance.reportIssue(widget.orderId, reason);
      if (!mounted) return;
      setState(() {
        _order = order;
        _updating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      final message = e is ApiException ? e.message : 'Could not report the issue';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _actionButton(String label, VoidCallback onTap, {bool destructive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 44,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _updating ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: destructive ? Colors.red.shade50 : AppColors.slate900,
            foregroundColor: destructive ? Colors.red.shade700 : AppColors.white,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: AppColors.slate700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: AppColors.slate900,
          ),
        ),
      ],
    );
  }
}
