/// What paid tickets cost once the server has priced the order (`EvCheckout`): sales tax and
/// the total on top of the full ticket prices. Buyers never pay a fee (`HandoffPipeline`); the
/// server prices it so the app never works out tax itself (BACKEND_CHANGES B22).
class EventOrderQuote {
  const EventOrderQuote({
    required this.taxCents,
    required this.totalCents,
    this.refundPolicy,
  });

  final int taxCents;
  final int totalCents;

  /// The host's refund terms in one line: "Refunds up to 24 hours before the event."
  final String? refundPolicy;

  factory EventOrderQuote.fromJson(Map<String, dynamic> json) => EventOrderQuote(
    taxCents: (json['taxCents'] as num?)?.toInt() ?? 0,
    totalCents: (json['totalCents'] as num?)?.toInt() ?? 0,
    refundPolicy: json['refundPolicy'] as String?,
  );
}

/// An order placed for tickets: its id, the payment to confirm with Stripe, and where it
/// stands (B22).
class EventOrder {
  const EventOrder({
    required this.id,
    this.clientSecret,
    this.status,
    this.holdExpiresAt,
    this.devMode = false,
    this.totalCents,
  });

  final String id;

  /// Null when nothing is left to pay.
  final String? clientSecret;

  /// `pending_payment` while Stripe is still to confirm, `paid` once the tickets are issued
  /// (a free order, or a development server without Stripe). Null on an older server.
  final String? status;

  /// The tickets are held until this time while the payment is pending.
  final DateTime? holdExpiresAt;

  /// A development server without Stripe marked a paid order paid without a payment.
  final bool devMode;
  final int? totalCents;

  /// The tickets are issued already, so there is nothing to wait for.
  bool get isPaid => status == 'paid' || status == 'partly_refunded';

  factory EventOrder.fromJson(Map<String, dynamic> json) => EventOrder(
    id: json['id'] as String? ?? json['orderId'] as String? ?? '',
    clientSecret: json['clientSecret'] as String?,
    status: json['status'] as String?,
    holdExpiresAt: DateTime.tryParse(json['holdExpiresAt'] as String? ?? '')?.toLocal(),
    devMode: json['devMode'] as bool? ?? false,
    totalCents: (json['totalCents'] as num?)?.toInt(),
  );
}

/// Which wallets can take this order's or ticket's passes (B25). Both false until the
/// server has the wallet's credentials.
class EventWalletPasses {
  const EventWalletPasses({this.apple = false, this.google = false});

  final bool apple;
  final bool google;

  static EventWalletPasses? maybeFrom(Object? raw) => raw is Map<String, dynamic>
      ? EventWalletPasses(apple: raw['apple'] as bool? ?? false, google: raw['google'] as bool? ?? false)
      : null;
}

/// An order as the buyer polls it after paying (`GET /api/events/:id/orders/:orderId`).
/// The poll carries `id`, not `orderId`.
class EventOrderStatus {
  const EventOrderStatus({
    required this.id,
    required this.status,
    this.ticketCount = 0,
    this.refundable = false,
    this.refundableUntil,
    this.refundedCents = 0,
    this.totalCents,
    this.taxCents,
    this.subtotalCents,
    this.walletPasses,
    this.walletPassAvailable = false,
  });

  final String id;

  /// `pending_payment` · `paid` · `expired` · `cancelled` · `failed` · `refunded` ·
  /// `partly_refunded`.
  final String status;

  /// Tickets that still admit someone.
  final int ticketCount;
  final bool refundable;
  final DateTime? refundableUntil;
  final int refundedCents;
  final int? totalCents;
  final int? taxCents;

  /// The ticket prices before tax.
  final int? subtotalCents;
  final EventWalletPasses? walletPasses;
  final bool walletPassAvailable;

  bool get isPending => status == 'pending_payment';
  bool get isPaid => status == 'paid' || status == 'partly_refunded';

  factory EventOrderStatus.fromJson(Map<String, dynamic> json) => EventOrderStatus(
    id: json['id'] as String? ?? json['orderId'] as String? ?? '',
    status: json['status'] as String? ?? '',
    ticketCount: (json['ticketCount'] as num?)?.toInt() ?? 0,
    refundable: json['refundable'] as bool? ?? false,
    refundableUntil: DateTime.tryParse(json['refundableUntil'] as String? ?? '')?.toLocal(),
    refundedCents: (json['refundedCents'] as num?)?.toInt() ?? 0,
    totalCents: (json['totalCents'] as num?)?.toInt(),
    taxCents: (json['taxCents'] as num?)?.toInt(),
    subtotalCents: (json['subtotalCents'] as num?)?.toInt(),
    walletPasses: EventWalletPasses.maybeFrom(json['walletPasses']),
    walletPassAvailable: json['walletPassAvailable'] as bool? ?? false,
  );
}

/// One admission (`EvTicket`): its own QR code, scanned in once at the door.
class EventTicket {
  const EventTicket({
    required this.id,
    required this.code,
    required this.typeName,
    this.number,
    this.scannedAt,
    this.orderId,
    this.eventId,
    this.status,
    this.refundable = false,
    this.walletPasses,
    this.walletPassAvailable = false,
  });

  final String id;

  /// What the QR code holds.
  final String code;
  final String typeName;

  /// The short number printed under the code ("S3-T-8KQ2"); the code itself when absent.
  final String? number;

  /// Set once it has been scanned in.
  final DateTime? scannedAt;

  /// The order it came in (null on an older server).
  final String? orderId;
  final String? eventId;

  /// `valid` or `checked_in`.
  final String? status;
  final bool refundable;
  final EventWalletPasses? walletPasses;
  final bool walletPassAvailable;

  String get label => number?.isNotEmpty == true ? number! : code;

  factory EventTicket.fromJson(Map<String, dynamic> json) => EventTicket(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        typeName: json['ticketTypeName'] as String? ?? json['typeName'] as String? ?? 'Ticket',
        number: json['number'] as String?,
        scannedAt: DateTime.tryParse(json['scannedAt'] as String? ?? '')?.toLocal(),
        orderId: json['orderId'] as String?,
        eventId: json['eventId'] as String?,
        status: json['status'] as String?,
        refundable: json['refundable'] as bool? ?? false,
        walletPasses: EventWalletPasses.maybeFrom(json['walletPasses']),
        walletPassAvailable: json['walletPassAvailable'] as bool? ?? false,
      );
}
