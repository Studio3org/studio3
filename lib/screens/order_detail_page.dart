import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/api_exception.dart';
import '../services/order_service.dart';
import '../widgets/orders/order_row.dart';
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

  Future<void> _updateStatus(String status) async {
    setState(() => _updating = true);
    try {
      final order = await OrderService.instance.updateOrderStatus(widget.orderId, status);
      if (!mounted) return;
      setState(() {
        _order = order;
        _updating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      showStudioToast(context, e is ApiException ? e.message : 'Could not update order', icon: null);
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
        const SizedBox(height: 28),
        Text(
          'Order summary',
          style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
        ),
        const SizedBox(height: 6),
        _SummaryLine(label: 'Piece', value: order.artworkDisplay),
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

  List<Widget> _sellerActions(Order order) {
    final actions = <Widget>[];
    if (order.status == 'paid') {
      actions.add(_actionButton('Mark as shipped', () => _updateStatus('shipped')));
    }
    if (order.status == 'shipped') {
      actions.add(_actionButton('Mark as completed', () => _updateStatus('completed')));
    }
    if (order.status == 'pending_payment' || order.status == 'paid') {
      actions.add(_actionButton('Cancel order', () => _updateStatus('cancelled'), secondary: true));
    }
    return actions;
  }

  List<Widget> _buyerActions(Order order) {
    final actions = <Widget>[];
    if (order.status == 'pending_payment' || order.status == 'paid') {
      actions.add(_actionButton('Cancel order', () => _updateStatus('cancelled'), secondary: true));
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
