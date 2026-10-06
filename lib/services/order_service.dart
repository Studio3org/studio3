import '../models/order.dart';
import '../models/payment_intent_info.dart';
import '../models/shipping_quote.dart';
import 'api_client.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

class OrderPage {
  const OrderPage({required this.items, this.nextCursor});

  final List<Order> items;
  final String? nextCursor;
}

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  final _api = ApiClient.instance;

  Future<List<ShippingMethodQuote>> getShippingQuote(String pieceId) async {
    final json = await _api.get('/api/pieces/$pieceId/shipping-quote');
    final data = _api.extractData(json);
    final methods = data is Map<String, dynamic> ? data['methods'] as List? : null;
    return methods
            ?.whereType<Map<String, dynamic>>()
            .map(ShippingMethodQuote.fromJson)
            .toList() ??
        const [];
  }

  Future<Order> collect(
    String pieceId, {
    required String addressId,
    required String shippingMethod,
  }) async {
    final json = await _api.post(
      '/api/pieces/$pieceId/collect',
      body: {'addressId': addressId, 'shippingMethod': shippingMethod},
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    await CacheService.instance.invalidate('orders.mine');
    // The piece is reserved the moment this order is created — server-side, before
    // payment even runs — so its cached detail (still showing "live"/for sale, from
    // whenever it was last viewed) is stale as of this exact call, not just once payment
    // clears. Left un-invalidated, PieceDetail's own post-purchase refresh would just
    // re-serve that stale entry and the Collect button would keep showing.
    await CacheService.instance.invalidate('piece.$pieceId');
    return Order.fromJson(data);
  }

  /// Winning bidder's checkout, once `auction_closer` has flipped the piece to
  /// `auction_won` — priced from the winning bid, not the piece's starting price.
  Future<Order> auctionCheckout(
    String pieceId, {
    required String addressId,
    required String shippingMethod,
  }) async {
    final json = await _api.post(
      '/api/pieces/$pieceId/auction-checkout',
      body: {'addressId': addressId, 'shippingMethod': shippingMethod},
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    await CacheService.instance.invalidate('piece.$pieceId');
    await CacheService.instance.invalidate('orders.mine');
    return Order.fromJson(data);
  }

  /// [pieceId] is optional only because this is also reached from places that don't have
  /// one handy — pass it whenever the caller does, so the piece's cached detail (already
  /// invalidated once at [collect]/[auctionCheckout] time, when it moved to reserved) is
  /// invalidated again for the reserved → sold transition this call makes.
  Future<Order> confirm(String orderId, {String? pieceId}) async {
    final json = await _api.post('/api/orders/$orderId/confirm', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    await CacheService.instance.invalidate('orders.mine');
    if (pieceId != null) {
      await CacheService.instance.invalidate('piece.$pieceId');
    }
    return Order.fromJson(data);
  }

  /// Creates (or reuses) the Stripe PaymentIntent for an order and returns its
  /// client secret for PaymentSheet. Safe to call twice — the backend returns
  /// the same intent rather than charging again.
  Future<PaymentIntentInfo> createPaymentIntent(String orderId) async {
    final json = await _api.post(
      '/api/orders/$orderId/create-payment-intent',
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    return PaymentIntentInfo.fromJson(data);
  }

  /// Polls the order's payment status after PaymentSheet reports success.
  ///
  /// Payment is confirmed by a Stripe webhook, not by the app, so there is a
  /// short window where the sheet has succeeded but the order is still
  /// `pending_payment`. This is what the client waits on.
  Future<bool> isPaid(String orderId) async {
    final json = await _api.get('/api/orders/$orderId/payment-status', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    return data['paid'] == true;
  }

  /// Waits for the webhook to land, giving up after [attempts] tries rather
  /// than spinning forever if it never arrives.
  Future<bool> waitForPayment(
    String orderId, {
    int attempts = 10,
    Duration interval = const Duration(seconds: 2),
  }) async {
    for (var i = 0; i < attempts; i++) {
      if (await isPaid(orderId)) {
        await CacheService.instance.invalidate('orders.mine');
        return true;
      }
      await Future<void>.delayed(interval);
    }
    return false;
  }

  /// Collector confirms the artwork arrived. This is what releases the
  /// artist's payment, so it is deliberately the buyer's action alone.
  Future<Order> confirmReceived(String orderId) async {
    final json = await _api.post('/api/orders/$orderId/confirm-received', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    await CacheService.instance.invalidate('orders.mine');
    return Order.fromJson(data);
  }

  /// Reports a problem instead of confirming — holds the artist's payment and
  /// opens a dispute for the team to resolve.
  Future<Order> reportIssue(String orderId, String reason) async {
    final json = await _api.post(
      '/api/orders/$orderId/report-issue',
      body: {'reason': reason},
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    await CacheService.instance.invalidate('orders.mine');
    return Order.fromJson(data);
  }

  Future<Order> getOrder(String orderId) async {
    final json = await _api.get('/api/orders/$orderId', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    return Order.fromJson(data);
  }

  Future<Order> updateOrderStatus(String orderId, String status) async {
    final json = await _api.patch(
      '/api/orders/$orderId',
      body: {'status': status},
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    return Order.fromJson(data);
  }

  Future<OrderPage> getMyOrders({String? cursor, int? limit}) async {
    final query = <String, String>{};
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    if (limit != null) query['limit'] = limit.toString();
    final json = await _api.get(
      '/api/user/me/orders',
      query: query.isEmpty ? null : query,
      auth: true,
    );
    return _parseOrderPage(json);
  }

  /// Cache-first order list (page 1 only) — cached for offline viewing, but
  /// screens should still force a refresh on focus since order status
  /// (shipped/delivered) is something users expect to be current.
  Future<OrderPage> getMyOrdersCached({bool forceRefresh = false}) {
    return CacheService.instance.fetchWithCache<OrderPage>(
      key: 'orders.mine',
      ttl: const Duration(minutes: 2),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw const CacheMiss('orders.mine');
        }
        return _api.get('/api/user/me/orders', auth: true);
      },
      parse: _parseOrderPage,
    );
  }

  /// Synchronous cache read for seeding the Orders screen before its
  /// first frame — a revisit shows the last known list immediately and the
  /// forced refresh above then updates it in place.
  OrderPage? peekMyOrdersCached() {
    return CacheService.instance.peekCache<OrderPage>(
      key: 'orders.mine',
      parse: _parseOrderPage,
    );
  }

  /// Cache-first sales list (page 1 only) — mirrors [getMyOrdersCached].
  Future<OrderPage> getMySalesCached({bool forceRefresh = false}) {
    return CacheService.instance.fetchWithCache<OrderPage>(
      key: 'sales.mine',
      ttl: const Duration(minutes: 2),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw const CacheMiss('sales.mine');
        }
        return _api.get('/api/user/me/sales', auth: true);
      },
      parse: _parseOrderPage,
    );
  }

  OrderPage? peekMySalesCached() {
    return CacheService.instance.peekCache<OrderPage>(
      key: 'sales.mine',
      parse: _parseOrderPage,
    );
  }

  OrderPage _parseOrderPage(Map<String, dynamic> json) {
    final data = _api.extractData(json);
    final items = _api.extractList(json).map(Order.fromJson).toList(growable: false);
    final nextCursor =
        data is Map<String, dynamic> ? data['nextCursor'] as String? : null;
    return OrderPage(items: items, nextCursor: nextCursor);
  }

  Future<OrderPage> getMySales({String? cursor, int? limit}) async {
    final query = <String, String>{};
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    if (limit != null) query['limit'] = limit.toString();
    final json = await _api.get(
      '/api/user/me/sales',
      query: query.isEmpty ? null : query,
      auth: true,
    );
    final data = _api.extractData(json);
    final items = _api.extractList(json).map(Order.fromJson).toList(growable: false);
    final nextCursor =
        data is Map<String, dynamic> ? data['nextCursor'] as String? : null;
    return OrderPage(items: items, nextCursor: nextCursor);
  }
}
