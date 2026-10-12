class AuthUser {
  const AuthUser({
    required this.username,
    required this.name,
    required this.email,
    this.emailVerified = false,
    this.onboardingComplete = false,
    this.role,
    this.sellerEnabled = false,
    this.profilePhotoUrl,
    this.termsVersion,
    this.currentTermsVersion,
  });

  final String username;
  final String name;
  final String email;
  final bool emailVerified;
  final bool onboardingComplete;
  final String? role;
  final bool sellerEnabled;
  final String? profilePhotoUrl;

  /// Terms of Use (EULA) version this account last agreed to — null for
  /// accounts that predate the terms.
  final String? termsVersion;

  /// The version the server currently requires. Null on payloads from an
  /// older backend, in which case nothing is enforced client-side.
  final String? currentTermsVersion;

  /// True when the account must (re-)agree to the Terms of Use before using
  /// account features — see `TermsAcceptanceGate`.
  bool get needsTermsAcceptance =>
      currentTermsVersion != null && termsVersion != currentTermsVersion;

  AuthUser copyWith({
    String? username,
    String? name,
    String? email,
    bool? emailVerified,
    bool? onboardingComplete,
    String? role,
    bool? sellerEnabled,
    String? profilePhotoUrl,
    String? termsVersion,
    String? currentTermsVersion,
  }) {
    return AuthUser(
      username: username ?? this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      role: role ?? this.role,
      sellerEnabled: sellerEnabled ?? this.sellerEnabled,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      termsVersion: termsVersion ?? this.termsVersion,
      currentTermsVersion: currentTermsVersion ?? this.currentTermsVersion,
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      username: json['username'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      emailVerified: json['emailVerified'] as bool? ?? false,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      role: json['role'] as String?,
      sellerEnabled: json['sellerEnabled'] as bool? ??
          json['isSeller'] as bool? ??
          false,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      termsVersion: json['termsVersion'] as String?,
      currentTermsVersion: json['currentTermsVersion'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'name': name,
        'email': email,
        'emailVerified': emailVerified,
        'onboardingComplete': onboardingComplete,
        'role': role,
        'sellerEnabled': sellerEnabled,
        'profilePhotoUrl': profilePhotoUrl,
        'termsVersion': termsVersion,
        'currentTermsVersion': currentTermsVersion,
      };
}

class UsernameCheckResult {
  const UsernameCheckResult({
    required this.available,
    this.normalized,
    this.reason,
    this.message,
    this.suggestions = const [],
  });

  final bool available;
  final String? normalized;
  final String? reason;
  final String? message;
  final List<String> suggestions;

  factory UsernameCheckResult.fromJson(Map<String, dynamic> json) {
    return UsernameCheckResult(
      available: json['available'] as bool? ?? false,
      normalized: json['normalized'] as String?,
      reason: json['reason'] as String?,
      message: json['message'] as String?,
      suggestions: (json['suggestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
