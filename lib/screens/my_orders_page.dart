import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/piece_summary.dart';
import '../services/connectivity_service.dart';
import '../services/order_service.dart';
import '../widgets/offline_state.dart';
import '../widgets/orders/order_list_row.dart';
import '../widgets/studio/studio.dart';
import 'order_detail_page.dart';

/// Purchases (`SettingsPurchases`, Flow 12): everything they bought, newest first. Each row has
/// the piece's picture and title, where it is (Being packed, Shipped, Delivered, Refunded), then
/// COLLECTED or AUCTION WIN and the date in Mono; under the list "Tap an order for its receipt
/// and tracking." A row opens the order (receipt, tracking, address).
///
/// The board's All / Art / Tickets filter and the ticket rows wait on ticket sales
/// (BACKEND_CHANGES B22, on hold), so every row is art and there is no filter; the arrival
/// window ("arriving Nov 13 to 16") waits on B32. Each piece is read (cached) for its title and
/// picture until the order carries it (B34).
class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key, this.debugOrders, this.debugPieces});

  /// For tests: the orders instead of loading them.
  @visibleForTesting
  final List<Order>? debugOrders;

  /// For tests: the pieces on [debugOrders], by id.
  @visibleForTesting
  final Map<String, PieceSummary>? debugPieces;

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  final List<Order> _orders = [];
  final Map<String, PieceSummary> _pieces = {};
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextCursor;
  final _scrollController = ScrollController();

  bool _showOfflineState = false;

  @override
  void initState() {
    super.initState();
    final given = widget.debugOrders;
    if (given != null) {
      _orders.addAll(given);
      _pieces.addAll(widget.debugPieces ?? const {});
      _loading = false;
      return;
    }
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
    if (widget.debugOrders != null) return;
    if (append && (_nextCursor == null || _nextCursor!.isEmpty)) return;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = _orders.isEmpty;
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
      await loadOrderPieces(page.items, _pieces);
      if (!mounted) return;
      setState(() {
        if (!append) _orders.clear();
        _orders.addAll(page.items);
        _nextCursor = page.nextCursor;
        _loading = false;
        _loadingMore = false;
        _showOfflineState = _orders.isEmpty && !ConnectivityService.instance.isOnline;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _showOfflineState = _orders.isEmpty && !ConnectivityService.instance.isOnline;
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

  Future<void> _open(Order order) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => OrderDetailPage(orderId: order.id)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Purchases'),
      body: RefreshIndicator(
        color: c.textPrimary,
        onRefresh: () => _load(),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final c = context.studio;
    if (_showOfflineState) {
      return OfflineState(onRetry: () => _load(refresh: true));
    }
    if (_loading && _orders.isEmpty) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: OrderListSkeleton(),
      );
    }
    if (_orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          StudioEmptyState(title: 'No orders yet', message: 'Pieces you collect show up here.'),
        ],
      );
    }
    // The rows, then the footnote (or the spinner while the next page loads).
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
      itemCount: _orders.length + 1,
      itemBuilder: (context, index) {
        if (index >= _orders.length) {
          if (_loadingMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              'Tap an order for its receipt and tracking.',
              style: StudioType.caption12(height: 1.5, color: c.textSecondary),
            ),
          );
        }
        final order = _orders[index];
        final piece = orderPiece(order, _pieces);
        return OrderListRow(
          title: orderPieceTitle(piece),
          imageUrl: piece?.mediaUrl,
          step: purchaseStep(order),
          meta: purchaseMeta(order, piece),
          onTap: () => _open(order),
        );
      },
    );
  }
}
