import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../models/piece_summary.dart';
import '../../services/piece_service.dart';
import '../../utils/app_clock.dart';
import '../../utils/money_format.dart';
import '../loading/skeleton_primitives.dart';
import '../studio/studio.dart';
import 'order_row.dart';

/// A row in Settings › Sales and Purchases (`SettingsSales`, `SettingsPurchases`): a 48 × 64
/// picture (radius 6), 14 apart, then the title 15/500, what happens next 13 (red when it is
/// the viewer's move) and the type, amount and date in Mono 11; a chevron 18. 12 above and
/// below, a Line under.
class OrderListRow extends StatelessWidget {
  const OrderListRow({
    super.key,
    required this.title,
    required this.step,
    required this.meta,
    this.imageUrl,
    this.urgent = false,
    required this.onTap,
  });

  final String title;
  final String step;

  /// "SOLD · $3,500 · Nov 2".
  final String meta;
  final String? imageUrl;

  /// The viewer's move: the step in red.
  final bool urgent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final url = imageUrl;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 48,
                  height: 64,
                  child: url == null || url.isEmpty
                      ? ColoredBox(color: c.surface)
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          memCacheWidth: 144,
                          placeholder: (_, _) => ColoredBox(color: c.surface),
                          errorWidget: (_, _, _) => ColoredBox(color: c.surface),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      step,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.label13(color: urgent ? c.alert : c.textSecondary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.mono(11, color: c.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StudioIcon(StudioIcons.chevronRight, size: 18, color: c.textPlaceholder),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder rows for the first load of Sales or Purchases.
class OrderListSkeleton extends StatelessWidget {
  const OrderListSkeleton({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final line = context.studio.line;
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            for (var i = 0; i < rows; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line))),
                child: Row(
                  children: [
                    const SkeletonBox(width: 48, height: 64, radius: 6),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 120.0 + (i * 37) % 70, height: 14, radius: 4),
                        const SizedBox(height: 8),
                        const SkeletonBox(width: 110, height: 11, radius: 3),
                        const SizedBox(height: 8),
                        const SkeletonBox(width: 90, height: 9, radius: 3),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Nov 2", or "Nov 2, 2025" outside this year.
String orderRowDate(DateTime? at) {
  if (at == null) return '';
  final local = at.toLocal();
  final day = '${_months[local.month - 1]} ${local.day}';
  return local.year == appNow().year ? day : '$day, ${local.year}';
}

/// What comes next on a sale, for the artist (`SettingsSales`), and whether it is their move
/// (red). The pickup date ("Pack it for pickup Nov 5") waits on BACKEND_CHANGES B32.
({String text, bool urgent}) saleStep(Order order) {
  final shipment = order.shipment?.status;
  return switch (order.status) {
    'pending_payment' => (text: 'Waiting for payment', urgent: false),
    'failed' => (text: 'Payment failed', urgent: false),
    'cancelled' => (text: 'Cancelled', urgent: false),
    'refunded' => (text: 'Refunded', urgent: false),
    'disputed' => (text: 'Issue reported', urgent: false),
    'paid' when shipment == 'picked_up' || shipment == 'in_transit' => (
      text: 'On its way',
      urgent: false,
    ),
    'paid' when shipment == 'delivered' => (text: 'Delivered', urgent: false),
    'paid' => (text: 'Pack it for pickup', urgent: true),
    'shipped' => (text: 'On its way', urgent: false),
    'awaiting_confirmation' => (text: 'Delivered · waiting on the collector', urgent: false),
    'completed' => (
      text: order.payoutStatus == 'released' ? 'Delivered · paid out' : 'Delivered · payout on the way',
      urgent: false,
    ),
    _ => (text: orderStatusLabel(order.status), urgent: false),
  };
}

/// What comes next on a purchase, for the collector (`SettingsPurchases`). The arrival window
/// ("Shipped · arriving Nov 13 to 16") waits on BACKEND_CHANGES B32.
String purchaseStep(Order order) {
  final shipment = order.shipment?.status;
  return switch (order.status) {
    'pending_payment' => 'Payment pending',
    'failed' => 'Payment failed',
    'cancelled' => 'Cancelled',
    'refunded' => 'Refunded',
    'disputed' => 'Issue reported',
    'paid' when shipment == 'picked_up' || shipment == 'in_transit' => 'Shipped',
    'paid' when shipment == 'delivered' => 'Delivered',
    'paid' => 'Being packed',
    'shipped' => 'Shipped',
    'awaiting_confirmation' => 'Delivered · confirm you got it',
    'completed' => 'Delivered',
    _ => orderStatusLabel(order.status),
  };
}

/// "COLLECTED · Nov 2" or "AUCTION WIN · Oct 12" (no amount on Purchases).
String purchaseMeta(Order order, PieceSummary? piece) {
  final kind = piece?.isAuction == true ? 'AUCTION WIN' : 'COLLECTED';
  final date = orderRowDate(order.createdAt);
  return [kind, if (date.isNotEmpty) date].join(' · ');
}

/// The piece on [order] (its first item) in [pieces], if read.
PieceSummary? orderPiece(Order order, Map<String, PieceSummary> pieces) =>
    order.items.isEmpty ? null : pieces[order.items.first.pieceId];

/// Reads into [pieces] the pieces on [orders] not read yet (cached), for the rows' titles and
/// pictures: orders carry piece ids only (a piece summary on the order is BACKEND_CHANGES B34).
/// One that fails is left out and its row shows "Untitled".
Future<void> loadOrderPieces(List<Order> orders, Map<String, PieceSummary> pieces) async {
  final ids = {
    for (final order in orders)
      if (order.items.isNotEmpty) order.items.first.pieceId,
  }.where((id) => id.isNotEmpty && !pieces.containsKey(id));
  await Future.wait(
    ids.map((id) async {
      try {
        pieces[id] = await PieceService.instance.getByIdCached(id);
      } catch (_) {
        // The row shows without its picture.
      }
    }),
  );
}

/// The row's title: the piece's, or "Untitled" when it couldn't be read.
String orderPieceTitle(PieceSummary? piece) {
  final title = piece?.title.trim() ?? '';
  return title.isEmpty ? 'Untitled' : title;
}

/// "SOLD · $3,500 · Nov 2" (a fixed-price sale) or "AUCTION · $1,300 · Nov 1" (an auction
/// result): the artwork amount and the day of the order.
String saleMeta(Order order, PieceSummary? piece) {
  final kind = piece?.isAuction == true ? 'AUCTION' : 'SOLD';
  final date = orderRowDate(order.createdAt);
  return [kind, formatMoney(order.artworkCents), if (date.isNotEmpty) date].join(' · ');
}
