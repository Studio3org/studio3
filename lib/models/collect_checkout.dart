import '../models/address.dart';
import '../models/shipping_quote.dart';

class CollectShippingMethod {
  const CollectShippingMethod({
    required this.id,
    required this.title,
    required this.duration,
    required this.priceCents,
  });

  final String id;
  final String title;
  final String duration;
  final int priceCents;

  String get priceDisplay => '\$${(priceCents / 100).toStringAsFixed(2)}';

  factory CollectShippingMethod.fromQuote(ShippingMethodQuote quote) {
    return CollectShippingMethod(
      id: quote.id,
      title: quote.title,
      duration: quote.duration,
      priceCents: quote.cents,
    );
  }
}

/// What checkout ships with: the address, and either a flat-rate [method] (a server without
/// Convelio), a Convelio [quote] (FRONTEND_HANDOFF 8.3), or [pickup] at the event (the address
/// is then the billing and tax address only).
class CollectShippingSelection {
  const CollectShippingSelection({
    required this.address,
    this.method,
    this.quote,
    this.pickup = false,
  });

  final Address address;
  final CollectShippingMethod? method;
  final ShippingQuote? quote;
  final bool pickup;

  /// The Shipping row's first part: "Express Shipping", "Regular · Curbside", "Pickup at the event".
  String get title => pickup ? 'Pickup at the event' : (quote?.title ?? method?.title ?? '');

  /// Shipping plus insurance.
  int get shippingCents => pickup ? 0 : (quote?.totalShippingCents ?? method?.priceCents ?? 0);

  /// The quote's insurance part, or null without one.
  int? get insuranceCents {
    final cents = quote?.insuranceCents;
    return quote != null && quote!.insurance && cents != null && cents > 0 ? cents : null;
  }

  /// What `collect` / `auction-checkout` sends besides the address: the quote, or the flat
  /// method (or `pickup`).
  Map<String, dynamic> get orderFields => {
        if (pickup)
          'shippingMethod': 'pickup'
        else if (quote != null)
          'quoteId': quote!.id
        else if (method != null)
          'shippingMethod': method!.id,
      };
}

enum CollectPaymentMethod { gpay, applePay, card }

extension CollectPaymentMethodX on CollectPaymentMethod {
  String get label {
    switch (this) {
      case CollectPaymentMethod.gpay:
        return 'GPay';
      case CollectPaymentMethod.applePay:
        return 'Apple Pay';
      case CollectPaymentMethod.card:
        return 'Credit / Debit card';
    }
  }
}
