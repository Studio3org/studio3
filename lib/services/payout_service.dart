import 'api_client.dart';
import 'auth_session.dart';

/// An artist's Stripe Connect payout-setup state.
class PayoutStatus {
  const PayoutStatus({
    required this.onboarded,
    required this.payoutsEnabled,
    required this.canListForSale,
    this.chargesEnabled = false,
    this.stripeAccountId,
    this.requirementsDue = const [],
    this.disabledReason,
  });

  final bool onboarded;
  final bool payoutsEnabled;
  final bool chargesEnabled;
  final String? stripeAccountId;

  /// Work can only be listed for sale once we can actually pay the artist.
  /// Backend: payouts_enabled AND the transfers capability being active. Not
  /// chargesEnabled — artists are recipient-only accounts and never accept a
  /// charge, so that stays false even when everything is in order.
  final bool canListForSale;

  /// What Stripe still needs from the artist (ID document, bank details, …).
  /// Empty on a first-time account — that still means setup is needed.
  final List<String> requirementsDue;
  final String? disabledReason;

  bool get needsAction => !canListForSale;

  factory PayoutStatus.fromJson(Map<String, dynamic> json) {
    return PayoutStatus(
      onboarded: json['onboarded'] as bool? ?? false,
      payoutsEnabled: json['payoutsEnabled'] as bool? ?? false,
      chargesEnabled: json['chargesEnabled'] as bool? ?? false,
      canListForSale: json['canListForSale'] as bool? ?? false,
      stripeAccountId: json['stripeAccountId'] as String?,
      requirementsDue:
          (json['requirementsDue'] as List?)?.whereType<String>().toList() ?? const [],
      disabledReason: json['disabledReason'] as String?,
    );
  }
}

/// Stripe Connect onboarding for artists — the setup that lets them be paid
/// when their work sells.
class PayoutService {
  PayoutService._();
  static final PayoutService instance = PayoutService._();

  final _api = ApiClient.instance;

  /// Returns a Stripe-hosted onboarding URL to open in a browser.
  ///
  /// These links are single-use and expire within minutes, so always request a
  /// fresh one immediately before opening it rather than caching.
  Future<String> startOnboarding() async {
    final json = await _api.post('/api/artists/connect', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    return data['onboardingUrl'] as String;
  }

  Future<PayoutStatus> getStatus() async {
    final json = await _api.get('/api/artists/connect/status', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    final status = PayoutStatus.fromJson(data);
    AuthSession.instance.setCanListForSale(status.canListForSale);
    return status;
  }

  /// Short-lived link to the artist's own Stripe dashboard, where they can see
  /// their payouts.
  Future<String> dashboardUrl() async {
    final json = await _api.get('/api/artists/connect/dashboard', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    return data['url'] as String;
  }
}
