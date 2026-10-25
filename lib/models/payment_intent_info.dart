/// Stripe PaymentIntent details returned by the backend for PaymentSheet.
///
/// The client never sees or handles card data — it hands [clientSecret] to
/// Stripe's SDK, which is what keeps card details out of this app entirely.
class PaymentIntentInfo {
  const PaymentIntentInfo({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.amountCents,
  });

  final String clientSecret;
  final String paymentIntentId;
  final int amountCents;

  factory PaymentIntentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentIntentInfo(
      clientSecret: json['clientSecret'] as String,
      paymentIntentId: json['paymentIntentId'] as String? ?? '',
      amountCents: json['amountCents'] as int? ?? 0,
    );
  }
}
