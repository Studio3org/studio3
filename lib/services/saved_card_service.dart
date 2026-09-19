import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../models/saved_card.dart';
import 'api_client.dart';

/// Vaulting and listing the cards a collector can bid with.
///
/// Bidding is the reason this exists. Ordinary checkout can collect a card at the moment of
/// payment because the buyer is standing there; a bid authorises money when it is placed and
/// **re-authorises it weeks later with nobody present**, so the card must be saved to a
/// Stripe customer first and referenced by id from then on.
///
/// The card number never touches this app. [addCard] hands Stripe's own sheet a SetupIntent
/// and an ephemeral key, and Stripe collects, validates and vaults the card itself. What
/// comes back is an id.
class SavedCardService {
  SavedCardService._();
  static final SavedCardService instance = SavedCardService._();

  final _api = ApiClient.instance;

  /// Cards already on file. Empty — never an error — for someone who has never bid.
  Future<List<SavedCard>> list() async {
    final json = await _api.get('/api/payments/payment-methods', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    final methods = (data['paymentMethods'] as List?) ?? const [];
    return methods
        .whereType<Map<String, dynamic>>()
        .map(SavedCard.fromJson)
        .where((card) => card.id.isNotEmpty)
        .toList();
  }

  /// Present Stripe's sheet and save whatever card the collector enters.
  ///
  /// Returns the new card, or null if they backed out — cancelling is a normal thing to do
  /// and is deliberately not an error the caller has to catch.
  ///
  /// Throws [StripeException] for a genuine failure (a declined or unusable card) and
  /// [CardSaveUnavailable] when the build has no Stripe key, which is a configuration
  /// problem rather than something the collector did.
  Future<SavedCard?> addCard({String? merchantDisplayName}) async {
    if (Stripe.publishableKey.isEmpty) {
      throw const CardSaveUnavailable();
    }

    final json = await _api.post('/api/payments/setup-intent', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    final clientSecret = data['clientSecret'] as String? ?? '';
    if (clientSecret.isEmpty) throw const CardSaveUnavailable();

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        // A SetupIntent, not a PaymentIntent: nothing is owed yet. The sheet says "save"
        // rather than "pay", which is the honest thing to show someone who is about to bid.
        setupIntentClientSecret: clientSecret,
        customerId: data['customerId'] as String?,
        customerEphemeralKeySecret: data['ephemeralKeySecret'] as String?,
        merchantDisplayName: merchantDisplayName ?? 'Studiothree',
        style: ThemeMode.light,
      ),
    );

    try {
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return null;
      rethrow;
    }

    // Stripe holds the truth about which card was saved, so the list is re-read rather than
    // assumed. Taking the newest entry is safe because the sheet has just added one.
    final cards = await list();
    return cards.isEmpty ? null : cards.last;
  }

  Future<void> remove(String paymentMethodId) async {
    await _api.delete('/api/payments/payment-methods/$paymentMethodId', auth: true);
  }
}

/// The build cannot save cards — no Stripe publishable key was compiled in.
class CardSaveUnavailable implements Exception {
  const CardSaveUnavailable();

  String get message => 'Payments are not available in this build.';

  @override
  String toString() => message;
}
