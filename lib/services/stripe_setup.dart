import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// Stripe for cards (bidding: `BidVerify`; paying the rest of an auction order). The
/// publishable key comes from `STRIPE_PUBLISHABLE_KEY` in `.env`; without it card entry is
/// off and the app says so.
abstract final class StripeSetup {
  static bool _ready = false;

  /// True once a publishable key was applied.
  static bool get ready => _ready;

  @visibleForTesting
  static set debugReady(bool value) => _ready = value;

  static Future<void> init() async {
    final key = dotenv.maybeGet('STRIPE_PUBLISHABLE_KEY')?.trim() ?? '';
    if (key.isEmpty) return;
    try {
      Stripe.publishableKey = key;
      await Stripe.instance.applySettings();
      _ready = true;
    } catch (e) {
      debugPrint('Stripe unavailable: $e');
    }
  }
}
