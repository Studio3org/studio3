import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// Stripe for cards (bidding: `BidVerify`; paying the rest of an auction order). The
/// publishable key comes from `STRIPE_PUBLISHABLE_KEY` in `.env`; without it card entry is
/// off and the app says so.
///
/// Apple Pay and Google Pay are offered in PaymentSheet only when `STRIPE_MERCHANT_IDENTIFIER`
/// (the Apple merchant id, e.g. `merchant.co.studio-3`) is set too: the wallets also need the
/// Apple Pay capability in Xcode and the Google Pay meta-data in the Android manifest, which
/// are set up by hand (docs/FRONTEND_IMPLEMENTATION_PLAN.md, "Manual setup outside code").
abstract final class StripeSetup {
  static bool _ready = false;
  static String? _merchantId;

  /// True once a publishable key was applied.
  static bool get ready => _ready;

  @visibleForTesting
  static set debugReady(bool value) => _ready = value;

  /// The Apple merchant id from `.env`, or null when the wallets are off.
  static String? get merchantIdentifier => _merchantId;

  @visibleForTesting
  static set debugMerchantIdentifier(String? value) => _merchantId = value;

  /// PaymentSheet's Apple Pay, when a merchant id is configured.
  static PaymentSheetApplePay? get applePay =>
      _merchantId == null ? null : const PaymentSheetApplePay(merchantCountryCode: 'US');

  /// PaymentSheet's Google Pay, when a merchant id is configured (test mode outside release).
  static PaymentSheetGooglePay? get googlePay => _merchantId == null
      ? null
      : const PaymentSheetGooglePay(merchantCountryCode: 'US', testEnv: !kReleaseMode);

  static Future<void> init() async {
    final key = dotenv.maybeGet('STRIPE_PUBLISHABLE_KEY')?.trim() ?? '';
    if (key.isEmpty) return;
    final merchant = dotenv.maybeGet('STRIPE_MERCHANT_IDENTIFIER')?.trim() ?? '';
    try {
      Stripe.publishableKey = key;
      if (merchant.isNotEmpty) {
        Stripe.merchantIdentifier = merchant;
        _merchantId = merchant;
      }
      await Stripe.instance.applySettings();
      _ready = true;
    } catch (e) {
      debugPrint('Stripe unavailable: $e');
    }
  }
}
