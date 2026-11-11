import 'package:flutter/material.dart';

import '../../models/address.dart';
import '../../models/collect_checkout.dart';
import '../../models/feed_preview_item.dart';
import '../../screens/available_piece_detail_page.dart';
import '../../services/address_service.dart';
import '../../services/order_service.dart';
import '../../services/piece_service.dart';
import '../../utils/explore_detail_route.dart';
import '../../utils/slide_up_page_route.dart';
import 'collect_shipping_method_sheet.dart';

/// `shipping_quote_ready` (FRONTEND_HANDOFF 8.3): a quote Convelio priced by hand is ready.
/// Opens the piece, reads the quote (`GET /api/shipping-quotes/:id`, never polled), and opens
/// checkout on it with the address it was asked for (or the default one). A quote that can no
/// longer be used, or a piece that's gone, opens just the piece page (or nothing).
Future<void> openShippingQuoteReady(
  BuildContext context, {
  required String pieceId,
  required String quoteId,
}) async {
  try {
    final piece = await PieceService.instance.getById(pieceId);
    if (!context.mounted) return;
    final item = FeedPreviewItem.fromPieceSummary(piece);
    CollectShippingSelection? checkout;
    try {
      final quote = await OrderService.instance.getShippingQuoteById(quoteId);
      final address = await _quoteAddress(quoteId);
      if (quote.isPriced && address != null) {
        checkout = CollectShippingSelection(address: address, quote: quote);
      }
    } catch (_) {
      // Just the piece.
    }
    if (!context.mounted) return;
    if (checkout == null || !item.isAvailable) {
      await openPieceDetailPreview(context, item);
      return;
    }
    await Navigator.of(context).push<void>(
      SlideUpPageRoute<void>(page: AvailablePieceDetailPage(item: item, initialCheckout: checkout)),
    );
  } catch (_) {
    // The piece is gone: stay put.
  }
}

Future<Address?> _quoteAddress(String quoteId) async {
  final known = CollectShippingMethodSheet.pendingQuoteAddresses[quoteId];
  if (known != null) return known;
  final addresses = await AddressService.instance.getAddresses();
  if (addresses.isEmpty) return null;
  return addresses.where((a) => a.isDefault).firstOrNull ?? addresses.first;
}
