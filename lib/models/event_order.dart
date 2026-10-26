/// What paid tickets cost once the server has priced the order (`EvCheckout`): each ticket
/// type's line, the service fee (paid tickets only), sales tax and the total. The server
/// prices it so the app never works out fees or tax itself (BACKEND_CHANGES B22).
class EventOrderQuote {
  const EventOrderQuote({
    required this.serviceFeeCents,
    required this.taxCents,
    required this.totalCents,
    this.refundPolicy,
  });

  final int serviceFeeCents;
  final int taxCents;
  final int totalCents;

  /// The host's refund terms in one line: "Refunds up to 24 hours before the event."
  final String? refundPolicy;

  factory EventOrderQuote.fromJson(Map<String, dynamic> json) => EventOrderQuote(
    serviceFeeCents: (json['serviceFeeCents'] as num?)?.toInt() ?? 0,
    taxCents: (json['taxCents'] as num?)?.toInt() ?? 0,
    totalCents: (json['totalCents'] as num?)?.toInt() ?? 0,
    refundPolicy: json['refundPolicy'] as String?,
  );
}

/// An order placed for paid tickets: its id and the payment to confirm with Stripe.
class EventOrder {
  const EventOrder({required this.id, this.clientSecret});

  final String id;

  /// Null when nothing is left to pay.
  final String? clientSecret;

  factory EventOrder.fromJson(Map<String, dynamic> json) => EventOrder(
    id: json['id'] as String? ?? json['orderId'] as String? ?? '',
    clientSecret: json['clientSecret'] as String?,
  );
}
