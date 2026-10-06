import 'dart:async';

import '../models/auth_user.dart';
import '../models/piece_summary.dart';
import '../models/user_profile.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_session.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

class UserService {
  UserService._();
  static final UserService instance = UserService._();

  final _api = ApiClient.instance;
  final _session = AuthSession.instance;

  Future<UserProfile> getMe() async {
    final json = await _api.get('/api/user/me', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    final profile = UserProfile.fromJson(data);
    await _syncSessionFromProfile(profile, data);
    return profile;
  }

  /// Cache-first own-profile fetch — short TTL since profile fields can
  /// change from other devices/sessions.
  Future<UserProfile> getMeCached({
    bool forceRefresh = false,
    void Function(UserProfile fresh)? onBackgroundUpdate,
  }) {
    return CacheService.instance.fetchWithCache<UserProfile>(
      key: 'user.me',
      ttl: const Duration(minutes: 2),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw const CacheMiss('user.me');
        }
        return _api.get('/api/user/me', auth: true);
      },
      parse: (json) {
        final data = _api.extractData(json) as Map<String, dynamic>;
        final profile = UserProfile.fromJson(data);
        unawaited(_syncSessionFromProfile(profile, data));
        return profile;
      },
      onBackgroundUpdate: onBackgroundUpdate,
    );
  }

  Future<UserProfile> getPublicProfile(String username) async {
    final json = await _api.get('/api/user/$username');
    final data = _api.extractData(json) as Map<String, dynamic>;
    return UserProfile.fromJson(data);
  }

  Future<UserProfile> updateMe({
    String? name,
    String? bio,
    String? location,
    String? pronouns,
    String? profilePhotoUrl,
    String? coverPhotoUrl,
    double? latitude,
    double? longitude,
    String? bannerAutoRule,
    String? messagePermission,
    String? profileVisibility,
    bool updateBannerTarget = false,
    String? bannerTargetType,
    String? bannerTargetId,
  }) async {
    if ((latitude == null) != (longitude == null)) {
      throw ApiException('latitude and longitude must be sent together');
    }
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (bio != null) body['bio'] = bio;
    if (location != null) body['location'] = location;
    if (pronouns != null) body['pronouns'] = pronouns;
    if (profilePhotoUrl != null) body['profilePhotoUrl'] = profilePhotoUrl;
    if (coverPhotoUrl != null) body['coverPhotoUrl'] = coverPhotoUrl;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (bannerAutoRule != null) body['bannerAutoRule'] = bannerAutoRule;
    if (messagePermission != null) body['messagePermission'] = messagePermission;
    if (profileVisibility != null) body['profileVisibility'] = profileVisibility;
    // Backend requires bannerTargetType/Id sent together (both null clears
    // the manual pin) — only include them when the caller explicitly wants
    // to change the pin, since plain nullable params can't tell "unset" from
    // "don't touch".
    if (updateBannerTarget) {
      body['bannerTargetType'] = bannerTargetType;
      body['bannerTargetId'] = bannerTargetId;
    }
    final json = await _api.patch('/api/user/me', body: body);
    final data = _api.extractData(json) as Map<String, dynamic>;
    final profile = UserProfile.fromJson(data);
    await _syncSessionFromProfile(profile, data);
    await CacheService.instance.invalidate('user.me');
    return profile;
  }

  /// Authenticated password change — distinct from the unauthenticated
  /// email-token forgot/reset flow in `AuthService`. Revokes the caller's
  /// other active sessions on success (not the current one).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final json = await _api.patch('/api/user/me/password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    // The backend revokes every session (including this one) and reissues
    // a fresh session/token pair for this request — pick it up so this
    // device stays logged in instead of getting logged out on its own
    // next API call.
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final token = data['accessToken'] as String?;
    final userJson = data['user'] as Map<String, dynamic>?;
    if (token != null && userJson != null) {
      await _session.saveSession(
        token: token,
        authUser: AuthUser.fromJson(userJson),
      );
    }
  }

  /// Step 1 of authenticated email change: sends an OTP to [newEmail].
  Future<void> requestEmailChange(String newEmail) async {
    await _api.post(
      '/api/user/me/email/request-change',
      body: {'newEmail': newEmail},
      auth: true,
    );
  }

  /// Step 2: verifies the OTP and swaps the account email.
  Future<String> confirmEmailChange({
    required String newEmail,
    required String otp,
  }) async {
    final json = await _api.post(
      '/api/user/me/email/confirm-change',
      body: {'newEmail': newEmail, 'otp': otp},
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    final email = data['email'] as String? ?? newEmail;
    final user = _session.user;
    if (user != null) {
      await _session.updateUser(user.copyWith(email: email));
    }
    await CacheService.instance.invalidate('user.me');
    return email;
  }

  /// Partial, deep-merged update of push/daily-digest notification settings.
  Future<NotificationPreferences> updateNotificationPreferences({
    Map<String, bool>? push,
    bool? dailyDigestEnabled,
    String? dailyDigestTime,
  }) async {
    final body = <String, dynamic>{};
    if (push != null) body['push'] = push;
    if (dailyDigestEnabled != null || dailyDigestTime != null) {
      body['dailyDigest'] = {
        if (dailyDigestEnabled != null) 'enabled': dailyDigestEnabled,
        if (dailyDigestTime != null) 'time': dailyDigestTime,
      };
    }
    final json = await _api.patch(
      '/api/user/me/notification-preferences',
      body: body,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    final prefsJson =
        data['notificationPreferences'] as Map<String, dynamic>? ?? data;
    await CacheService.instance.invalidate('user.me');
    return NotificationPreferences.fromJson(prefsJson);
  }

  Future<UserProfile> changeUsername(String username) async {
    final json = await _api.patch(
      '/api/user/me/username',
      body: {'username': username},
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    final profile = UserProfile.fromJson(data);
    await _syncSessionFromProfile(profile, data);
    return profile;
  }

  Future<void> setRole(String role) async {
    await _api.patch('/api/user/me/role', body: {'role': role});
    final user = _session.user;
    if (user != null) {
      await _session.updateUser(user.copyWith(role: role));
    }
  }

  Future<void> setOnboardingPreferences({
    required List<String> mediums,
    required List<String> styles,
    required List<String> themes,
  }) async {
    await _api.post(
      '/api/user/me/onboarding/preferences',
      body: {'mediums': mediums, 'styles': styles, 'themes': themes},
      auth: true,
    );
  }

  Future<void> setOnboardingPhotos({
    String? profilePhotoUrl,
    String? coverPhotoUrl,
    bool skip = false,
  }) async {
    if (skip) {
      await _api.post(
        '/api/user/me/onboarding/photos',
        body: {'skip': true},
        auth: true,
      );
      return;
    }
    final body = <String, dynamic>{};
    if (profilePhotoUrl != null) body['profilePhotoUrl'] = profilePhotoUrl;
    if (coverPhotoUrl != null) body['coverPhotoUrl'] = coverPhotoUrl;
    await _api.post('/api/user/me/onboarding/photos', body: body, auth: true);
  }

  Future<void> completeOnboarding() async {
    await _api.post('/api/user/me/onboarding/complete', auth: true);
    final user = _session.user;
    if (user != null) {
      await _session.updateUser(user.copyWith(onboardingComplete: true));
    }
  }

  Future<SellerStatus> getSellerStatus() async {
    final json = await _api.get('/api/user/me/seller', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    final status = SellerStatus.fromJson(data);
    await _session.setSellerEnabled(status.enabled);
    return status;
  }

  Future<SellerStatus> enableSeller({
    required String location,
    bool useProfileLocation = false,
  }) async {
    final json = await _api.post(
      '/api/user/me/seller/enable',
      body: {'location': location, 'useProfileLocation': useProfileLocation},
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    final status = SellerStatus.fromJson(data);
    await _session.setSellerEnabled(true);
    return status;
  }

  Future<void> disableSeller() async {
    await _api.post('/api/user/me/seller/disable', auth: true);
    await _session.setSellerEnabled(false);
  }

  Future<SellerAnalytics> getSellerAnalytics() async {
    final json = await _api.get('/api/user/me/seller/analytics', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    return SellerAnalytics.fromJson(data);
  }

  Future<List<PieceSummary>> getSavedPieces() async {
    try {
      final json = await _api.get('/api/user/me/saved/pieces', auth: true);
      return _api
          .extractList(json)
          .map(PieceSummary.fromJson)
          .toList();
    } catch (_) {
      final profile = await getMe();
      return profile.savedPieces;
    }
  }

  /// Cache-first saved pieces (Saved page) — cold-start instant paint.
  Future<List<PieceSummary>> getSavedPiecesCached({
    bool forceRefresh = false,
    void Function(List<PieceSummary> fresh)? onBackgroundUpdate,
  }) {
    const key = 'saved.pieces';
    return CacheService.instance.fetchWithCache<List<PieceSummary>>(
      key: key,
      ttl: const Duration(minutes: 3),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw const CacheMiss(key);
        }
        return _api.get('/api/user/me/saved/pieces', auth: true);
      },
      parse: (json) => _api.extractList(json).map(PieceSummary.fromJson).toList(),
      onBackgroundUpdate: onBackgroundUpdate,
    );
  }

  List<PieceSummary>? peekSavedPiecesCached() {
    return CacheService.instance.peekCache<List<PieceSummary>>(
      key: 'saved.pieces',
      parse: (json) => _api.extractList(json).map(PieceSummary.fromJson).toList(),
    );
  }

  Future<void> _syncSessionFromProfile(
    UserProfile profile,
    Map<String, dynamic> data,
  ) async {
    final user = _session.user;
    if (user == null) return;
    await _session.updateUser(user.copyWith(
      username: profile.username,
      name: profile.name,
      email: profile.email ?? user.email,
      // Monotonic: once onboarding is complete locally, never let a
      // subsequent profile fetch un-set it — a backend read that lands
      // just after `onboarding/complete` returns can otherwise still
      // reflect the pre-completion state and bounce the user right back
      // to the onboarding flow.
      onboardingComplete: user.onboardingComplete || profile.onboardingComplete,
      role: profile.role,
      sellerEnabled: profile.sellerEnabled,
      profilePhotoUrl: profile.profilePhotoUrl,
    ));
    await _session.setSellerEnabled(profile.sellerEnabled);
  }
}
