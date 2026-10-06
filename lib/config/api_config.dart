import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Backend base URL — read from `.env`'s `NEXT_PUBLIC_API_URL` at runtime
/// in debug/profile only. Release builds always use the deployed HTTPS API
/// so emulator `.env` hosts like `10.0.2.2` never ship to production.
///
/// Override any build with `--dart-define=API_HOST=<host>` (uses port [port])
/// or `--dart-define=API_BASE_URL=https://...` for a full URL.
abstract final class ApiConfig {
  static const int port = 9000;

  static const String _deployedBaseUrl =
      'https://studio3-backend.onrender.com';

  /// Full URL override, e.g. `--dart-define=API_BASE_URL=https://api.example.com`
  static const String _baseUrlOverride =
      String.fromEnvironment('API_BASE_URL');

  /// Host-only override, e.g. `--dart-define=API_HOST=10.0.2.2`
  static const String _hostOverride = String.fromEnvironment('API_HOST');

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    if (_hostOverride.isNotEmpty) return 'http://$_hostOverride:$port';
    // Never trust local `.env` emulator URLs in release/store builds.
    if (kReleaseMode) return _deployedBaseUrl;
    final fromEnv = dotenv.env['NEXT_PUBLIC_API_URL'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return _deployedBaseUrl;
  }
}
