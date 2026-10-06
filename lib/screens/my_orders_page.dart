import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/order.dart';
import '../services/connectivity_service.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/offline_state.dart';
import 'order_detail_page.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  final List<Order> _orders = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextCursor;
  final _scrollController = ScrollController();

  bool _showOfflineState = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    ConnectivityService.instance.addReconnectHook(_onReconnected);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    ConnectivityService.instance.removeReconnectHook(_onReconnected);
    super.dispose();
  }

  Future<void> _onReconnected() => _load(refresh: true);

  Future<void> _load({bool append = false, bool refresh = false}) async {
    if (append && (_nextCursor == null || _nextCursor!.isEmpty)) return;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
      }
    });
    try {
      // Always force-refresh on a non-append load — order status matters
      // more than avoiding the request, unlike the feed/address caches.
      final page = append
          ? await OrderService.instance.getMyOrders(cursor: _nextCursor)
          : await OrderService.instance.getMyOrdersCached(
              forceRefresh: refresh || ConnectivityService.instance.isOnline,
            );
      if (!mounted) return;
      setState(() {
        if (append) {
          _orders.addAll(page.items);
        } else {
          _orders
            ..clear()
            ..addAll(page.items);
        }
        _nextCursor = page.nextCursor;
        _loading = false;
        _loadingMore = false;
        _showOfflineState =
            _orders.isEmpty && !ConnectivityService.instance.isOnline;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _showOfflineState =
            _orders.isEmpty && !ConnectivityService.instance.isOnline;
      });
    }
  }

  void _onScroll() {
    if (_loadingMore) return;
    if (_nextCursor == null || _nextCursor!.isEmpty) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _load(append: true);
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
          'My Orders',
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
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_showOfflineState) {
      return OfflineState(onRetry: () => _load(refresh: true));
    }
    if (_loading && _orders.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_orders.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              'No orders yet',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate400),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _orders.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _orders.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final order = _orders[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _OrderCard(
            order: order,
            onTap: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => OrderDetailPage(orderId: order.id),
                ),
              );
              _load();
            },
          ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.id.substring(0, order.id.length > 8 ? 8 : order.id.length)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.items.length} item${order.items.length == 1 ? '' : 's'} · ${order.totalDisplay}',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600),
                  ),
                ],
              ),
            ),
            _StatusPill(status: order.status),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.slate700,
        ),
      ),
    );
  }
}
