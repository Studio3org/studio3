import 'dart:async';

import 'api_client.dart';
import 'auth_session.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

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

  static const _statusKey = 'payout.status';

  /// Live status, always awaiting the network and never falling back to
  /// cache — for the call sites that gate a real action (listing a piece,
  /// the payout screen itself) and must not act on a stale answer.
  ///
  /// Still writes through to the cache: its result is the freshest anyone
  /// has, so Profile settings should pick it up rather than keep showing
  /// an older one.
  Future<PayoutStatus> getStatus() async {
    final json = await _api.get('/api/artists/connect/status', auth: true);
    final status = _parseStatus(json);
    unawaited(CacheService.instance.write(_statusKey, json));
    return status;
  }

  /// Cache-first payout status.
  ///
  /// Worth caching even though it is a fast call: the setting it drives is
  /// rendered the instant Profile settings opens, and a screen that has to
  /// wait for the network before it knows whether payouts are set up will
  /// show *something* wrong in the meantime. Cached here, the answer is
  /// already known on every visit after the first and only the first-ever
  /// load has to render an unknown state.
  ///
  /// Safe across accounts: `AuthSession.clear()` wipes the whole cache on
  /// logout, so a second account on the device can never read the first
  /// one's status.
  Future<PayoutStatus> getStatusCached({
    bool forceRefresh = false,
    void Function(PayoutStatus fresh)? onBackgroundUpdate,
  }) {
    return CacheService.instance.fetchWithCache<PayoutStatus>(
      key: _statusKey,
      ttl: const Duration(minutes: 5),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw const CacheMiss(_statusKey);
        }
        return _api.get('/api/artists/connect/status', auth: true);
      },
      parse: _parseStatus,
      onBackgroundUpdate: onBackgroundUpdate,
    );
  }

  /// Synchronous read for seeding a screen before its first frame.
  PayoutStatus? peekStatusCached() {
    return CacheService.instance.peekCache<PayoutStatus>(
      key: _statusKey,
      parse: _parseStatus,
    );
  }

  /// Dropped when the answer is known to have changed — finishing (or
  /// abandoning) onboarding, and leaving seller mode.
  Future<void> invalidateStatus() =>
      CacheService.instance.invalidate(_statusKey);

  PayoutStatus _parseStatus(Map<String, dynamic> json) {
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
