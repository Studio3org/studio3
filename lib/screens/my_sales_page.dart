import 'package:flutter/material.dart';

import '../models/feed_preview_item.dart';
import '../models/order.dart';
import '../models/piece_summary.dart';
import '../services/order_service.dart';
import '../services/piece_service.dart';
import '../utils/slide_up_page_route.dart';
import '../widgets/orders/order_list_row.dart';
import '../widgets/studio/studio.dart';
import 'available_piece_detail_page.dart';
import 'order_detail_page.dart';

/// Sales (`SettingsSales`, Flow 12), for seller profiles: everything they sold, newest first.
/// Each row has the piece's picture and title, what comes next (red when it is their move:
/// "Pack it for pickup"), then SOLD or AUCTION, the amount and the date in Mono.
///
/// A sold piece opens its page, where the artist sees the delivery card; anything else (waiting
/// for payment, cancelled, refunded) opens the order. The board's All / Art / Tickets filter and
/// the ticket rows wait on ticket sales (BACKEND_CHANGES B22, on hold), so every row is art and
/// there is no filter; the pickup date in "Pack it for pickup Nov 5" waits on B32.
///
/// The title and picture come with the order (`items[0].piece`, B34); the full piece is read
/// only when a sold one is tapped.
class MySalesPage extends StatefulWidget {
  const MySalesPage({super.key, this.debugSales, this.debugOpenPiece});

  /// For tests: the sales instead of loading them.
  @visibleForTesting
  final List<Order>? debugSales;

  /// For tests: called with the piece id instead of reading and opening the piece page.
  @visibleForTesting
  final void Function(String pieceId)? debugOpenPiece;

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
    final given = widget.debugSales;
    if (given != null) {
      _orders.addAll(given);
      _loading = false;
      return;
    }
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
    if (widget.debugSales != null) return;
    if (append && (_nextCursor == null || _nextCursor!.isEmpty)) return;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = _orders.isEmpty;
      }
    });
    try {
      final page = await OrderService.instance.getMySales(cursor: append ? _nextCursor : null);
      if (!mounted) return;
      setState(() {
        if (!append) _orders.clear();
        _orders.addAll(page.items);
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

  /// A sold piece (the order paid or later) opens its page, the artist's delivery card;
  /// anything else, or a piece that can't be read, opens the order.
  Future<void> _open(Order order) async {
    final pieceId = orderPiece(order)?.id ?? '';
    PieceSummary? piece;
    if (pieceId.isNotEmpty && saleIsSold(order)) {
      final debugOpen = widget.debugOpenPiece;
      if (debugOpen != null) {
        debugOpen(pieceId);
        return;
      }
      try {
        piece = await PieceService.instance.getByIdCached(pieceId);
      } catch (_) {
        // Falls back to the order.
      }
      if (!mounted) return;
    }
    if (piece != null) {
      await Navigator.of(context).push<void>(
        SlideUpPageRoute<void>(
          page: AvailablePieceDetailPage(item: FeedPreviewItem.fromPieceSummary(piece)),
        ),
      );
    } else {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => OrderDetailPage(orderId: order.id, isSeller: true),
        ),
      );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Sales'),
      body: RefreshIndicator(
        color: c.textPrimary,
        onRefresh: () => _load(),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final c = context.studio;
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
          StudioEmptyState(title: 'No sales yet', message: 'Pieces you sell show up here.'),
        ],
      );
    }
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
      itemCount: _orders.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _orders.length) {
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
        final order = _orders[index];
        final piece = orderPiece(order);
        final step = saleStep(order);
        return OrderListRow(
          title: orderPieceTitle(piece),
          imageUrl: piece?.mediaUrl,
          step: step.text,
          urgent: step.urgent,
          meta: saleMeta(order),
          onTap: () => _open(order),
        );
      },
    );
  }
}
