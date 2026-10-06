import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/order.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/glass_card.dart';
import 'order_detail_page.dart';

class MySalesPage extends StatefulWidget {
  const MySalesPage({super.key});

  @override
  State<MySalesPage> createState() => _MySalesPageState();
}

class _MySalesPageState extends State<MySalesPage> {
  final List<Order> _orders = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextCursor;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    if (append && (_nextCursor == null || _nextCursor!.isEmpty)) return;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
      }
    });
    try {
      final page = await OrderService.instance.getMySales(
        cursor: append ? _nextCursor : null,
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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
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
          'My Sales',
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
    if (_loading && _orders.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_orders.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              'No sales yet',
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
          child: _SaleCard(
            order: order,
            onTap: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => OrderDetailPage(orderId: order.id, isSeller: true),
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

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.order, required this.onTap});

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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                order.status.replaceAll('_', ' '),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
