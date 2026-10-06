import 'address.dart';

class OrderItem {
  const OrderItem({
    required this.pieceId,
    required this.priceCents,
    required this.quantity,
  });

  final String pieceId;
  final int priceCents;
  final int quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      pieceId: json['pieceId'] as String? ?? '',
      priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

class Order {
  const Order({
    required this.id,
    this.buyerId,
    this.sellerId,
    required this.status,
    this.shippingMethod,
    this.shippingAddress,
    required this.artworkCents,
    required this.shippingCents,
    required this.taxCents,
    required this.totalCents,
    this.paymentProvider,
    this.items = const [],
    this.createdAt,
    this.updatedAt,
    this.devMode,
    this.clientSecret,
  });

  final String id;
  final String? buyerId;
  final String? sellerId;
  final String status;
  final String? shippingMethod;
  final Address? shippingAddress;
  final int artworkCents;
  final int shippingCents;
  final int taxCents;
  final int totalCents;
  final String? paymentProvider;
  final List<OrderItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? devMode;
  final String? clientSecret;

  factory Order.fromJson(Map<String, dynamic> json) {
    final addressJson = json['shippingAddress'];
    final itemsJson = json['items'] as List?;
    return Order(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      buyerId: json['buyerId'] as String?,
      sellerId: json['sellerId'] as String?,
      status: json['status'] as String? ?? 'pending_payment',
      shippingMethod: json['shippingMethod'] as String?,
      shippingAddress: addressJson is Map<String, dynamic>
          ? Address.fromJson(addressJson)
          : null,
      artworkCents: (json['artworkCents'] as num?)?.toInt() ?? 0,
      shippingCents: (json['shippingCents'] as num?)?.toInt() ?? 0,
      taxCents: (json['taxCents'] as num?)?.toInt() ?? 0,
      totalCents: (json['totalCents'] as num?)?.toInt() ?? 0,
      paymentProvider: json['paymentProvider'] as String?,
      items: itemsJson
              ?.whereType<Map<String, dynamic>>()
              .map(OrderItem.fromJson)
              .toList() ??
          const [],
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      devMode: json['devMode'] as bool?,
      clientSecret: json['clientSecret'] as String?,
    );
  }

  String get artworkDisplay => '\$${(artworkCents / 100).toStringAsFixed(2)}';
  String get shippingDisplay => '\$${(shippingCents / 100).toStringAsFixed(2)}';
  String get taxDisplay => '\$${(taxCents / 100).toStringAsFixed(2)}';
  String get totalDisplay => '\$${(totalCents / 100).toStringAsFixed(2)}';
}
