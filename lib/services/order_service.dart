import '../models/order.dart';
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
    return Order.fromJson(data);
  }

  Future<Order> confirm(String orderId) async {
    final json = await _api.post('/api/orders/$orderId/confirm', auth: true);
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
