import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/order.dart';
import '../services/api_exception.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/glass_card.dart';

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
          style: GoogleFonts.inter(
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final order = _order;
    if (order == null) {
      return Center(
        child: Text(
          _error ?? 'Order not found',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate400),
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
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
              ),
              const SizedBox(height: 4),
              Text(
                order.status.replaceAll('_', ' '),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (address != null)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shipping address',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
                ),
                const SizedBox(height: 8),
                Text(address.fullName, style: GoogleFonts.inter(fontSize: 14)),
                Text(address.line1, style: GoogleFonts.inter(fontSize: 14)),
                if (address.line2 != null && address.line2!.isNotEmpty)
                  Text(address.line2!, style: GoogleFonts.inter(fontSize: 14)),
                Text(
                  '${address.city}, ${address.state} ${address.zip}',
                  style: GoogleFonts.inter(fontSize: 14),
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
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
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
    if (order.status == 'paid') {
      actions.add(_actionButton('Mark as shipped', () => _updateStatus('shipped')));
    }
    if (order.status == 'shipped') {
      actions.add(_actionButton('Mark as completed', () => _updateStatus('completed')));
    }
    if (order.status == 'pending_payment' || order.status == 'paid') {
      actions.add(_actionButton('Cancel order', () => _updateStatus('cancelled'),
          destructive: true));
    }
    return actions;
  }

  List<Widget> _buyerActions(Order order) {
    final actions = <Widget>[];
    if (order.status == 'pending_payment' || order.status == 'paid') {
      actions.add(_actionButton('Cancel order', () => _updateStatus('cancelled'),
          destructive: true));
    }
    return actions;
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
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: AppColors.slate700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: AppColors.slate900,
          ),
        ),
      ],
    );
  }
}
