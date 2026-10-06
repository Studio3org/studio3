import '../models/auth_user.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_session.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _api = ApiClient.instance;
  final _session = AuthSession.instance;

  Future<void> generateOtp(String email) async {
    await _api.post('/api/auth/otp/generate', body: {'email': email.trim()});
  }

  Future<void> resendOtp(String email) async {
    await _api.post('/api/auth/otp/resend', body: {'email': email.trim()});
  }

  /// Check-only verification — does not create an account. The real,
  /// single-use check still happens server-side inside [register].
  Future<void> verifyOtp(String email, String otp) async {
    await _api.post(
      '/api/auth/otp/verify',
      body: {'email': email.trim(), 'otp': otp},
    );
  }

  Future<UsernameCheckResult> checkUsername(
    String username, {
    bool forCurrentUser = false,
  }) async {
    final query = <String, String>{'username': username.trim()};
    if (forCurrentUser) query['for_user_id'] = 'me';
    final json = await _api.get(
      '/api/auth/username/check',
      query: query,
      auth: forCurrentUser,
    );
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return UsernameCheckResult.fromJson(data);
  }

  Future<AuthUser> register({
    required String username,
    required String name,
    required String email,
    required String password,
    required String otp,
    String? phone,
  }) async {
    final body = <String, dynamic>{
      'username': username.trim(),
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'otp': otp,
    };
    final trimmedPhone = phone?.trim();
    if (trimmedPhone != null && trimmedPhone.isNotEmpty) {
      body['phone'] = trimmedPhone;
    }
    final json = await _api.post('/api/auth/register', body: body);
    return _persistAuthResponse(json);
  }

  Future<AuthUser> login({
    required String identifier,
    required String password,
  }) async {
    final json = await _api.post('/api/auth/login', body: {
      'username': identifier.trim(),
      'password': password,
    });
    return _persistAuthResponse(json);
  }

  Future<void> forgetPassword(String email) async {
    await _api.post('/api/auth/forget-password', body: {'email': email.trim()});
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _api.post('/api/auth/reset-password', body: {
      'token': token.trim(),
      'newPassword': newPassword,
    });
  }

  Future<void> logout() async {
    try {
      await _api.post('/api/auth/logout');
    } on ApiException {
      // Clear local session even if server logout fails.
    }
    await _session.clear();
  }

  Future<void> logoutAllDevices() async {
    try {
      await _api.post('/api/auth/logout-all', auth: true);
    } on ApiException {
      // Clear local session even if server logout fails.
    }
    await _session.clear();
  }

  Future<AuthUser> _persistAuthResponse(Map<String, dynamic> json) async {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final token = data['accessToken'] as String?;
    final userJson = data['user'] as Map<String, dynamic>?;
    if (token == null || userJson == null) {
      throw ApiException('Invalid auth response from server');
    }
    final user = AuthUser.fromJson(userJson);
    await _session.saveSession(token: token, authUser: user);
    return user;
  }
}
