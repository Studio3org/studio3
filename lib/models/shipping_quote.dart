/// A shipping method option returned by GET /api/pieces/:id/shipping-quote.
class ShippingMethodQuote {
  const ShippingMethodQuote({required this.id, required this.cents});

  final String id;
  final int cents;

  factory ShippingMethodQuote.fromJson(Map<String, dynamic> json) {
    return ShippingMethodQuote(
      id: json['id'] as String? ?? '',
      cents: (json['cents'] as num?)?.toInt() ?? 0,
    );
  }

  String get priceDisplay => '\$${(cents / 100).toStringAsFixed(2)}';

  String get title {
    switch (id) {
      case 'standard':
        return 'Standard Shipping';
      case 'express':
        return 'Express Shipping';
      case 'overnight':
        return 'Overnight Shipping';
      case 'free':
        return 'Free Shipping';
      default:
        return id;
    }
  }

  String get duration {
    switch (id) {
      case 'standard':
        return '4 - 6 Business Days';
      case 'express':
        return '2 - 3 Business Days';
      case 'overnight':
        return 'Next Business Day';
      case 'free':
        return '7 - 10 Business Days';
      default:
        return '';
    }
  }
}

/// `GET /api/pieces/:id/shipping-quote` (FRONTEND_HANDOFF 8.0): [live] when Convelio prices
/// shipping on this server (pick speed, delivery and insurance, then POST a quote); otherwise
/// the flat [methods] as before.
class ShippingOptions {
  const ShippingOptions({
    this.live = false,
    this.methods = const [],
    this.speeds = const ['regular_speed', 'express'],
    this.deliveryTypes = const ['curbside', 'white_glove'],
    this.insuranceDefault = true,
  });

  final bool live;
  final List<ShippingMethodQuote> methods;
  final List<String> speeds;
  final List<String> deliveryTypes;
  final bool insuranceDefault;

  factory ShippingOptions.fromJson(Map<String, dynamic> json) {
    List<String>? strings(Object? raw) {
      final list = (raw as List?)?.whereType<String>().toList();
      return list == null || list.isEmpty ? null : list;
    }

    return ShippingOptions(
      live: json['live'] as bool? ?? false,
      methods: (json['methods'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ShippingMethodQuote.fromJson)
              .toList() ??
          const [],
      speeds: strings(json['speeds']) ?? const ['regular_speed', 'express'],
      deliveryTypes: strings(json['deliveryTypes']) ?? const ['curbside', 'white_glove'],
      insuranceDefault: json['insuranceDefault'] as bool? ?? true,
    );
  }

  static String speedLabel(String speed) => switch (speed) {
        'regular_speed' => 'Regular',
        'express' => 'Express',
        _ => speed,
      };

  static String deliveryLabel(String type) => switch (type) {
        'curbside' => 'Curbside',
        'white_glove' => 'White-glove',
        _ => type,
      };
}

/// A Convelio shipping quote (`POST /api/pieces/:id/shipping-quotes`, FRONTEND_HANDOFF 8.3).
/// [pending] while Convelio prices it by hand (the prices are null until it's ready).
class ShippingQuote {
  const ShippingQuote({
    required this.id,
    this.status = 'created',
    this.pending = false,
    this.speed = 'regular_speed',
    this.deliveryType = 'curbside',
    this.insurance = true,
    this.shippingCents,
    this.insuranceCents,
    this.totalShippingCents,
    this.currency = 'USD',
    this.reference,
    this.expiresAt,
  });

  final String id;

  /// `created`, `processing`, `ready`, `expired`, `used` or `failed`.
  final String status;
  final bool pending;
  final String speed;
  final String deliveryType;
  final bool insurance;
  final int? shippingCents;
  final int? insuranceCents;
  final int? totalShippingCents;
  final String currency;
  final String? reference;
  final DateTime? expiresAt;

  /// Priced and usable for an order.
  bool get isPriced => !pending && totalShippingCents != null && (status == 'created' || status == 'ready');

  /// "Regular · Curbside".
  String get title =>
      '${ShippingOptions.speedLabel(speed)} · ${ShippingOptions.deliveryLabel(deliveryType)}';

  factory ShippingQuote.fromJson(Map<String, dynamic> json) {
    int? cents(Object? v) => v is num ? v.toInt() : null;
    return ShippingQuote(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'created',
      pending: json['pending'] as bool? ?? false,
      speed: json['speed'] as String? ?? 'regular_speed',
      deliveryType: json['deliveryType'] as String? ?? 'curbside',
      insurance: json['insurance'] as bool? ?? true,
      shippingCents: cents(json['shippingCents']),
      insuranceCents: cents(json['insuranceCents']),
      totalShippingCents: cents(json['totalShippingCents']),
      currency: json['currency'] as String? ?? 'USD',
      reference: json['reference'] as String?,
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
    );
  }
}

/// The piece page's shipping range (`GET /api/pieces/:id/shipping-estimate`, 8.2); null
/// prices when [available] is false.
class ShippingEstimate {
  const ShippingEstimate({required this.available, this.lowCents, this.highCents});

  final bool available;
  final int? lowCents;
  final int? highCents;

  bool get showable => available && lowCents != null && highCents != null;

  factory ShippingEstimate.fromJson(Map<String, dynamic> json) => ShippingEstimate(
        available: json['available'] as bool? ?? false,
        lowCents: (json['lowCents'] as num?)?.toInt(),
        highCents: (json['highCents'] as num?)?.toInt(),
      );
}
