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

  // Production API (AWS). The old Render host no longer responds — release builds
  // pointed there can't load anything.
  static const String _deployedBaseUrl = 'https://api.studio-3.co';

  /// Full URL override, e.g. `--dart-define=API_BASE_URL=https://api.example.com`
  static const String _baseUrlOverride =
      String.fromEnvironment('API_BASE_URL');

  /// Host-only override, e.g. `--dart-define=API_HOST=10.0.2.2`
  static const String _hostOverride = String.fromEnvironment('API_HOST');

  static String get baseUrl => resolve(
        baseUrlOverride: _baseUrlOverride,
        hostOverride: _hostOverride,
        release: kReleaseMode,
        fromEnv: kReleaseMode ? null : dotenv.env['NEXT_PUBLIC_API_URL'],
      );

  /// Whether [url] only works on the developer's own machine or network.
  @visibleForTesting
  static bool isLocal(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ||
        host == 'localhost' ||
        host.startsWith('127.') ||
        host.startsWith('10.') ||
        host.startsWith('192.168.') ||
        host.endsWith('.local');
  }

  /// A release build (what TestFlight and the App Store get) never talks to a local or
  /// plain-http server, whatever it was built with. `flutter run --dart-define=API_BASE_URL=…`
  /// for a simulator is saved into ios/Flutter/Generated.xcconfig, and an Xcode archive made
  /// afterwards silently inherits it: on 22 Nov that shipped a build pointed at
  /// localhost:9100, which every phone reported as "Can't reach the server".
  @visibleForTesting
  static String resolve({
    required String baseUrlOverride,
    required String hostOverride,
    required bool release,
    String? fromEnv,
  }) {
    if (release) {
      final ok = baseUrlOverride.startsWith('https://') && !isLocal(baseUrlOverride);
      return ok ? baseUrlOverride : _deployedBaseUrl;
    }
    if (baseUrlOverride.isNotEmpty) return baseUrlOverride;
    if (hostOverride.isNotEmpty) return 'http://$hostOverride:$port';
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return _deployedBaseUrl;
  }

}
