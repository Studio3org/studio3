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

/// Courier tracking for an order, entered by the Studiothree team (there is no
/// carrier API in this phase, so it is updated manually).
class OrderShipment {
  const OrderShipment({
    required this.courier,
    required this.trackingNumber,
    required this.status,
    this.shipmentDate,
  });

  final String courier;
  final String trackingNumber;
  final String status;
  final DateTime? shipmentDate;

  bool get isDelivered => status == 'delivered';

  String get statusLabel => switch (status) {
        'label_created' => 'Label created',
        'picked_up' => 'Picked up',
        'in_transit' => 'In transit',
        'delivered' => 'Delivered',
        _ => status,
      };

  factory OrderShipment.fromJson(Map<String, dynamic> json) {
    return OrderShipment(
      courier: json['courier'] as String? ?? '',
      trackingNumber: json['trackingNumber'] as String? ?? '',
      status: json['status'] as String? ?? 'label_created',
      shipmentDate: DateTime.tryParse(json['shipmentDate'] as String? ?? ''),
    );
  }
}

/// An open or resolved issue the collector raised on an order.
class OrderDispute {
  const OrderDispute({required this.status, required this.reason, this.openedAt});

  final String status;
  final String reason;
  final DateTime? openedAt;

  bool get isOpen => status == 'open';

  factory OrderDispute.fromJson(Map<String, dynamic> json) {
    return OrderDispute(
      status: json['status'] as String? ?? 'open',
      reason: json['reason'] as String? ?? '',
      openedAt: DateTime.tryParse(json['openedAt'] as String? ?? ''),
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
    this.received = false,
    this.receivedAt,
    this.shipment,
    this.payoutStatus,
    this.dispute,
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
  final bool received;
  final DateTime? receivedAt;
  final OrderShipment? shipment;
  final String? payoutStatus;
  final OrderDispute? dispute;

  /// The artwork has been delivered and is waiting on the collector to confirm
  /// receipt — the step that releases the artist's payment.
  bool get awaitingConfirmation => status == 'awaiting_confirmation';

  bool get isDisputed => status == 'disputed';

  /// Whether the collector can still act on this order (confirm or report).
  bool get canConfirmReceipt => awaitingConfirmation;
  bool get canReportIssue =>
      status == 'shipped' || status == 'awaiting_confirmation' || status == 'paid';

  String get statusLabel => switch (status) {
        'pending_payment' => 'Awaiting payment',
        'paid' => 'Paid — preparing to ship',
        'shipped' => 'On its way',
        'awaiting_confirmation' => 'Delivered — confirm receipt',
        'completed' => 'Completed',
        'disputed' => 'Issue reported',
        'refunded' => 'Refunded',
        'cancelled' => 'Cancelled',
        'failed' => 'Payment failed',
        _ => status,
      };

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
      received: json['received'] as bool? ?? false,
      receivedAt: DateTime.tryParse(json['receivedAt'] as String? ?? ''),
      shipment: json['shipment'] is Map<String, dynamic>
          ? OrderShipment.fromJson(json['shipment'] as Map<String, dynamic>)
          : null,
      payoutStatus: json['payoutStatus'] as String?,
      dispute: json['dispute'] is Map<String, dynamic>
          ? OrderDispute.fromJson(json['dispute'] as Map<String, dynamic>)
          : null,
    );
  }

  String get artworkDisplay => '\$${(artworkCents / 100).toStringAsFixed(2)}';
  String get shippingDisplay => '\$${(shippingCents / 100).toStringAsFixed(2)}';
  String get taxDisplay => '\$${(taxCents / 100).toStringAsFixed(2)}';
  String get totalDisplay => '\$${(totalCents / 100).toStringAsFixed(2)}';
}
