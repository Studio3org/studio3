import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auction.dart';
import '../models/order.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'cache_service.dart';
import 'stripe_setup.dart';

/// A card saved on the Stripe customer (`GET /api/payments/payment-methods`).
class SavedCard {
  const SavedCard({required this.id, required this.brand, required this.last4});

  final String id;
  final String brand;
  final String last4;

  /// "Visa ending 4242".
  String get label {
    final b = brand.isEmpty ? 'Card' : '${brand[0].toUpperCase()}${brand.substring(1)}';
    return '$b ending $last4';
  }

  factory SavedCard.fromJson(Map<String, dynamic> json) => SavedCard(
    id: json['id'] as String? ?? '',
    brand: json['brand'] as String? ?? '',
    last4: json['last4'] as String? ?? '',
  );
}

/// The auction-checkout order and what is still owed on it (the hammer price was already
/// charged when the auction closed).
class AuctionOrder {
  const AuctionOrder({required this.order, required this.balanceDueCents});

  final Order order;
  final int balanceDueCents;
}

/// Bidding (Flow 7) against the server's auction endpoints, plus the card Stripe saves for
/// it. Every call needs a signed-in, onboarded account.
class BidService {
  BidService._();
  static final BidService instance = BidService._();

  final _api = ApiClient.instance;

  /// Saved cards, newest first as the server lists them; empty when none.
  Future<List<SavedCard>> cards() async {
    final json = await _api.get('/api/payments/payment-methods', auth: true);
    final data = _api.extractData(json);
    final list = data is Map<String, dynamic> ? data['paymentMethods'] : null;
    return list is List
        ? list.whereType<Map<String, dynamic>>().map(SavedCard.fromJson).toList()
        : const [];
  }

  /// `BidVerify`: confirms a SetupIntent with what is in the card field, so the card is
  /// saved for bidding without a charge or hold. Returns the payment method id.
  Future<String> saveCard({required String zip}) async {
    if (!StripeSetup.ready) {
      throw ApiException('Card payments are not set up in this build yet.');
    }
    final json = await _api.post('/api/payments/setup-intent', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    final secret = data['clientSecret'] as String?;
    if (secret == null) throw ApiException('Could not start saving the card.');
    final intent = await Stripe.instance.confirmSetupIntent(
      paymentIntentClientSecret: secret,
      params: PaymentMethodParams.card(
        paymentMethodData: PaymentMethodData(
          billingDetails: BillingDetails(address: Address(
            city: null,
            country: null,
            line1: null,
            line2: null,
            postalCode: zip,
            state: null,
          )),
        ),
      ),
    );
    final id = intent.paymentMethodId;
    if (id.isEmpty) throw ApiException("The card couldn't be saved. Try again.");
    return id;
  }

  /// Places a bid of [amountCents]. The server rejects one that is now too low (409) and
  /// says what the minimum is; the returned summary is the auction after the bid.
  Future<AuctionSummary> placeBid(
    String pieceId, {
    required int amountCents,
    required String paymentMethodId,
  }) async {
    final json = await _api.post(
      '/api/pieces/$pieceId/bids',
      body: {'amountCents': amountCents, 'paymentMethodId': paymentMethodId},
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    await BidStore.instance.recordBid(pieceId, amountCents);
    await CacheService.instance.invalidate('piece.$pieceId');
    return AuctionSummary.fromJson(data) ??
        (throw ApiException('The bid went through but the auction could not be read.'));
  }

  /// `BidPaymentFailed`: re-authorises and charges the winning bid on [paymentMethodId].
  Future<AuctionSummary?> retryPayment(String pieceId, {required String paymentMethodId}) async {
    final json = await _api.post(
      '/api/pieces/$pieceId/auction/retry-payment',
      body: {'paymentMethodId': paymentMethodId},
      auth: true,
    );
    final data = _api.extractData(json);
    return data is Map<String, dynamic> ? AuctionSummary.fromJson(data) : null;
  }

  /// `BidCheckout`: the winner's shipping. The hammer price is already paid; what is left
  /// (shipping and tax) is [AuctionOrder.balanceDueCents].
  Future<AuctionOrder> auctionCheckout(
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
    await CacheService.instance.invalidate('orders.mine');
    final order = Order.fromJson(data);
    final due = (data['balanceDueCents'] as num?)?.toInt() ?? order.totalCents;
    return AuctionOrder(order: order, balanceDueCents: due);
  }

  /// Pays what is still owed on [orderId] with Stripe's payment sheet. Debug builds
  /// without Stripe use the server's dev confirm, as the fixed-price checkout does.
  Future<void> payBalance(String orderId) async {
    if (!StripeSetup.ready) {
      if (kDebugMode) {
        await _api.post('/api/orders/$orderId/confirm', auth: true);
        return;
      }
      throw ApiException('Card payments are not set up in this build yet.');
    }
    final json = await _api.post('/api/orders/$orderId/create-payment-intent', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    final secret = data['clientSecret'] as String?;
    if (secret == null) throw ApiException('Could not start the payment.');
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: secret,
        merchantDisplayName: 'Studio 3',
      ),
    );
    await Stripe.instance.presentPaymentSheet();
    await CacheService.instance.invalidate('orders.mine');
  }
}

/// What this phone remembers about the viewer's own bids. The server only says whether
/// they are the highest bidder (`isHighestBidder`), so "Outbid" and "Your top bid" come from
/// here (BACKEND_CHANGES B18).
class BidStore {
  BidStore._();
  static final BidStore instance = BidStore._();

  static const _bidsKey = 'bids.mine';
  static const _zipKey = 'bids.zip';

  Map<String, int>? _bids;
  String? _zip;

  @visibleForTesting
  void debugSet({Map<String, int> bids = const {}, String? zip}) {
    _bids = Map.of(bids);
    _zip = zip;
  }

  Future<void> _load() async {
    if (_bids != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_bidsKey);
      final decoded = raw == null ? null : jsonDecode(raw);
      _bids = decoded is Map
          ? {for (final e in decoded.entries) '${e.key}': (e.value as num).toInt()}
          : {};
      _zip = prefs.getString(_zipKey);
    } catch (_) {
      _bids = {};
    }
  }

  /// The viewer's highest bid on [pieceId], if they have bid on it from this phone.
  Future<int?> topBid(String pieceId) async {
    await _load();
    return _bids![pieceId];
  }

  int? topBidNow(String pieceId) => _bids?[pieceId];

  Future<void> recordBid(String pieceId, int amountCents) async {
    await _load();
    final current = _bids![pieceId];
    if (current != null && current >= amountCents) return;
    _bids![pieceId] = amountCents;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bidsKey, jsonEncode(_bids));
    } catch (_) {}
  }

  /// The ZIP from `BidVerify`, for the shipping estimate.
  Future<String?> zip() async {
    await _load();
    return _zip;
  }

  Future<void> saveZip(String zip) async {
    await _load();
    _zip = zip;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_zipKey, zip);
    } catch (_) {}
  }
}
