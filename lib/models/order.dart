import 'address.dart';

/// The piece on an order line, as the order lists carry it (B34): enough for a row's title and
/// picture. [mediaUrl] is always a picture (a video cover's first photo), or null.
class OrderPiece {
  const OrderPiece({required this.id, this.title = '', this.mediaUrl, this.listingType});

  final String id;
  final String title;
  final String? mediaUrl;
  final String? listingType;

  bool get isAuction => listingType == 'auction';

  factory OrderPiece.fromJson(Map<String, dynamic> json) {
    return OrderPiece(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      mediaUrl: json['mediaUrl'] as String?,
      listingType: json['listingType'] as String?,
    );
  }
}

class OrderItem {
  const OrderItem({
    required this.pieceId,
    required this.priceCents,
    required this.quantity,
    this.piece,
  });

  final String pieceId;
  final int priceCents;
  final int quantity;

  /// The piece, or null when the server didn't send it or the piece no longer exists.
  final OrderPiece? piece;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final pieceJson = json['piece'];
    return OrderItem(
      pieceId: json['pieceId'] as String? ?? '',
      priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      piece: pieceJson is Map<String, dynamic> ? OrderPiece.fromJson(pieceJson) : null,
    );
  }
}

/// One step of the Convelio tracker (FRONTEND_HANDOFF 8.4): `booked`, `picked_up`,
/// `in_transit`, `out_for_delivery`, `delivered`.
class ShipmentStep {
  const ShipmentStep({required this.key, required this.done});

  final String key;
  final bool done;

  factory ShipmentStep.fromJson(Map<String, dynamic> json) =>
      ShipmentStep(key: json['key'] as String? ?? '', done: json['done'] as bool? ?? false);

  Map<String, dynamic> toJson() => {'key': key, 'done': done};
}

/// Courier tracking for an order: entered by the team, or from Convelio (Phase 8.4) with its
/// own status, the tracker [steps], a tracking link and the reference.
class OrderShipment {
  const OrderShipment({
    required this.courier,
    required this.trackingNumber,
    required this.status,
    this.shipmentDate,
    this.provider,
    this.providerStatus,
    this.steps = const [],
    this.trackingUrl,
    this.reference,
    this.deliveredAt,
    this.onHold = false,
    this.cancelled = false,
  });

  final String courier;
  final String trackingNumber;
  final String status;
  final DateTime? shipmentDate;

  /// `convelio`, or null for a shipment entered by hand.
  final String? provider;
  final String? providerStatus;
  final List<ShipmentStep> steps;
  final String? trackingUrl;
  final String? reference;
  final DateTime? deliveredAt;
  final bool onHold;
  final bool cancelled;

  bool get isDelivered => status == 'delivered';

  /// The last step reached, or null without steps.
  String? get currentStepKey {
    String? key;
    for (final step in steps) {
      if (step.done) key = step.key;
    }
    return key;
  }

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
      provider: json['provider'] as String?,
      providerStatus: json['providerStatus'] as String?,
      steps: (json['steps'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ShipmentStep.fromJson)
              .toList() ??
          const [],
      trackingUrl: json['trackingUrl'] as String?,
      reference: json['reference'] as String?,
      deliveredAt: DateTime.tryParse(json['deliveredAt'] as String? ?? ''),
      onHold: json['onHold'] as bool? ?? false,
      cancelled: json['cancelled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'courier': courier,
        'trackingNumber': trackingNumber,
        'status': status,
        if (shipmentDate != null) 'shipmentDate': shipmentDate!.toIso8601String(),
        if (provider != null) 'provider': provider,
        if (providerStatus != null) 'providerStatus': providerStatus,
        if (steps.isNotEmpty) 'steps': steps.map((s) => s.toJson()).toList(),
        if (trackingUrl != null) 'trackingUrl': trackingUrl,
        if (reference != null) 'reference': reference,
        if (deliveredAt != null) 'deliveredAt': deliveredAt!.toIso8601String(),
        if (onHold) 'onHold': true,
        if (cancelled) 'cancelled': true,
      };
}

/// The viewer's own order on a piece (`viewerOrder` on `GET /api/pieces/:id`, FRONTEND_HANDOFF
/// 8.4): the collector's purchase or the artist's sale; null for everyone else.
class PieceViewerOrder {
  const PieceViewerOrder({
    required this.id,
    required this.side,
    required this.status,
    this.deliveryType,
    this.shipment,
  });

  final String id;

  /// `buyer` or `seller`.
  final String side;
  final String status;
  final String? deliveryType;
  final OrderShipment? shipment;

  bool get isSeller => side == 'seller';

  static PieceViewerOrder? maybeFrom(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'] as String?;
    if (id == null || id.isEmpty) return null;
    final shipment = raw['shipment'];
    return PieceViewerOrder(
      id: id,
      side: raw['side'] as String? ?? 'buyer',
      status: raw['status'] as String? ?? 'paid',
      deliveryType: raw['deliveryType'] as String?,
      shipment: shipment is Map<String, dynamic> ? OrderShipment.fromJson(shipment) : null,
    );
  }

  /// As an [Order], for the delivery card.
  Order toOrder() => Order(
        id: id,
        status: status,
        artworkCents: 0,
        shippingCents: 0,
        taxCents: 0,
        totalCents: 0,
        shipment: shipment,
        deliveryType: deliveryType,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'side': side,
        'status': status,
        if (deliveryType != null) 'deliveryType': deliveryType,
        if (shipment != null) 'shipment': shipment!.toJson(),
      };
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
    this.fromAuction = false,
    this.insuranceCents = 0,
    this.deliveryType,
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

  /// An auction win rather than a fixed-price sale (B34).
  final bool fromAuction;

  /// The insurance part of [shippingCents] (Phase 8); 0 without.
  final int insuranceCents;

  /// `curbside` or `white_glove` (Phase 8); null for flat-rate or pickup orders.
  final String? deliveryType;

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
      fromAuction: json['fromAuction'] as bool? ?? false,
      insuranceCents: (json['insuranceCents'] as num?)?.toInt() ?? 0,
      deliveryType: json['deliveryType'] as String?,
    );
  }

  String get artworkDisplay => '\$${(artworkCents / 100).toStringAsFixed(2)}';
  String get shippingDisplay => '\$${(shippingCents / 100).toStringAsFixed(2)}';
  String get taxDisplay => '\$${(taxCents / 100).toStringAsFixed(2)}';
  String get totalDisplay => '\$${(totalCents / 100).toStringAsFixed(2)}';
}
