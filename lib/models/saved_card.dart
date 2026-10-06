/// A card the collector has vaulted at Stripe.
///
/// Bidding needs one on file before the first bid, because a hold is authorised when the bid
/// lands and re-authorised weeks later with the bidder nowhere near their phone. There is no
/// point in that sequence at which they could be asked for a card, so it is collected up
/// front.
///
/// Nothing here is card data. Stripe's SetupIntent flow sends the number from the device
/// straight to Stripe; the app and the server only ever see an id and a last four.
class SavedCard {
  const SavedCard({
    required this.id,
    this.brand,
    this.last4,
    this.expMonth,
    this.expYear,
  });

  final String id;
  final String? brand;
  final String? last4;
  final int? expMonth;
  final int? expYear;

  /// "Visa ···· 4242", or just the last four when the brand is unknown.
  String get label {
    final dots = last4 == null ? '' : '···· $last4';
    if (brand == null || brand!.isEmpty) return dots.isEmpty ? 'Saved card' : dots;
    final name = brand![0].toUpperCase() + brand!.substring(1);
    return dots.isEmpty ? name : '$name $dots';
  }

  String? get expiryLabel {
    if (expMonth == null || expYear == null) return null;
    final month = expMonth!.toString().padLeft(2, '0');
    final year = expYear!.toString().padLeft(4, '0').substring(2);
    return '$month/$year';
  }

  /// A card Stripe will refuse before an auction that is still weeks from closing.
  bool get isExpired {
    if (expMonth == null || expYear == null) return false;
    final now = DateTime.now();
    // Cards are valid through the last day of their expiry month.
    final endOfMonth = DateTime(expYear!, expMonth! + 1, 1);
    return !endOfMonth.isAfter(now);
  }

  factory SavedCard.fromJson(Map<String, dynamic> json) => SavedCard(
        id: json['id'] as String? ?? '',
        brand: json['brand'] as String?,
        last4: json['last4'] as String?,
        expMonth: (json['expMonth'] as num?)?.toInt(),
        expYear: (json['expYear'] as num?)?.toInt(),
      );
}
