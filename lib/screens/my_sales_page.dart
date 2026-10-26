import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/order_service.dart';
import '../widgets/orders/order_row.dart';
import '../widgets/studio/studio.dart';
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
    final c = context.studio;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'My sales'),
      body: RefreshIndicator(
        color: c.textPrimary,
        onRefresh: () => _load(),
        child: _buildBody(),
      ),
    );
  }

  Widget _spinner() {
    final c = context.studio;
    return SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
    );
  }

  Widget _buildBody() {
    if (_loading && _orders.isEmpty) {
      return Center(child: _spinner());
    }
    if (_orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          StudioEmptyState(title: 'No sales yet', message: 'Pieces you sell show up here.'),
        ],
      );
    }
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(StudioSpace.marginPage, 4, StudioSpace.marginPage, 40),
      itemCount: _orders.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _orders.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: _spinner()),
          );
        }
        final order = _orders[index];
        return OrderRow(
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
        );
      },
    );
  }
}
