import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_user.dart';
import 'cache_service.dart';
import 'engagement_store.dart';
import 'saved_content_store.dart';

class AuthSession {
  AuthSession._();
  static final AuthSession instance = AuthSession._();

  static const _tokenKey = 'access_token';
  static const _userKey = 'auth_user';
  static const _rememberedUsernameKey = 'remembered_username';
  static const _sellerKey = 'seller_enabled';

  SharedPreferences? _prefs;
  String? accessToken;
  AuthUser? user;
  bool sellerEnabled = false;

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void notifyListeners() {
    for (final l in List<VoidCallback>.from(_listeners)) {
      l();
    }
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    accessToken = _prefs!.getString(_tokenKey);
    final userJson = _prefs!.getString(_userKey);
    if (userJson != null) {
      user = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    }
    sellerEnabled = _prefs!.getBool(_sellerKey) ?? user?.sellerEnabled ?? false;
  }

  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  bool get isOnboarded => user?.onboardingComplete ?? false;

  String? get rememberedUsername => _prefs?.getString(_rememberedUsernameKey);

  /// Login identifier saved by "Remember me" (username or email).
  String? get rememberedLoginIdentifier => rememberedUsername;

  Future<void> saveSession({
    required String token,
    required AuthUser authUser,
    bool? seller,
  }) async {
    accessToken = token;
    user = authUser;
    sellerEnabled = seller ?? authUser.sellerEnabled;
    await _prefs?.setString(_tokenKey, token);
    await _prefs?.setString(_userKey, jsonEncode(authUser.toJson()));
    await _prefs?.setBool(_sellerKey, sellerEnabled);
    // A prior session's cached profile can still be within its TTL if this
    // login follows one that ended without a clean logout (app killed,
    // etc.) — invalidate it so this session always fetches a live profile.
    await CacheService.instance.invalidate('user.me');
    notifyListeners();
  }

  Future<void> updateToken(String token) async {
    accessToken = token;
    await _prefs?.setString(_tokenKey, token);
    notifyListeners();
  }

  Future<void> updateUser(AuthUser authUser) async {
    user = authUser;
    sellerEnabled = authUser.sellerEnabled;
    await _prefs?.setString(_userKey, jsonEncode(authUser.toJson()));
    await _prefs?.setBool(_sellerKey, authUser.sellerEnabled);
    notifyListeners();
  }

  Future<void> updateUserFromJson(Map<String, dynamic> json) async {
    final current = user;
    if (current == null) return;
    final merged = AuthUser(
      username: json['username'] as String? ?? current.username,
      name: json['name'] as String? ?? current.name,
      email: json['email'] as String? ?? current.email,
      emailVerified: json['emailVerified'] as bool? ?? current.emailVerified,
      // Monotonic: never let a server payload un-set a locally-completed
      // onboarding flag (see the matching guard in UserService).
      onboardingComplete:
          current.onboardingComplete ||
          (json['onboardingComplete'] as bool? ?? false),
      role: json['role'] as String? ?? current.role,
      sellerEnabled:
          json['sellerEnabled'] as bool? ??
          json['isSeller'] as bool? ??
          current.sellerEnabled,
      profilePhotoUrl:
          json['profilePhotoUrl'] as String? ?? current.profilePhotoUrl,
    );
    await updateUser(merged);
  }

  Future<void> setSellerEnabled(bool enabled) async {
    sellerEnabled = enabled;
    await _prefs?.setBool(_sellerKey, enabled);
    if (user != null) {
      await updateUser(user!.copyWith(sellerEnabled: enabled));
    } else {
      notifyListeners();
    }
  }

  Future<void> saveRememberedUsername(String identifier) async {
    await _prefs?.setString(_rememberedUsernameKey, identifier);
  }

  Future<void> saveRememberedLoginIdentifier(String identifier) =>
      saveRememberedUsername(identifier);

  Future<void> clearRememberedUsername() async {
    await _prefs?.remove(_rememberedUsernameKey);
  }

  Future<void> clear() async {
    accessToken = null;
    user = null;
    sellerEnabled = false;
    await _prefs?.remove(_tokenKey);
    await _prefs?.remove(_userKey);
    await _prefs?.remove(_sellerKey);
    // Prevent a second account on this device from seeing the previous
    // account's cached feed/addresses/saved items.
    await CacheService.instance.clearAll();
    await SavedContentStore.instance.clearLocal();
    EngagementStore.instance.clear();
    notifyListeners();
  }
}
