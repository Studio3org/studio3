import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Public web app URL — used to build shareable/deep-linkable piece URLs
/// (`{webBaseUrl}/piece/{id}`).
///
/// PLACEHOLDER: defaults to `https://studio-3.co`, which is not yet a real,
/// publicly-hosted domain. Android App Links / iOS Universal Links will not
/// verify until `.env`'s `NEXT_PUBLIC_APP_URL` (and the well-known files in
/// `app/public/.well-known/`, the Android intent-filter host, and the iOS
/// associated-domains entitlement) are all updated to match the real
/// production domain.
abstract final class AppLinkConfig {
  static const String _placeholderWebUrl = 'https://studio-3.co';

  static String get webBaseUrl {
    final fromEnv = dotenv.env['NEXT_PUBLIC_APP_URL'];
    if (fromEnv == null || fromEnv.isEmpty) return _placeholderWebUrl;
    // A local dev value (e.g. http://localhost:3000) isn't reachable from
    // another device tapping a shared link, so fall back to the placeholder
    // production domain rather than sharing a dead link.
    final uri = Uri.tryParse(fromEnv);
    if (uri == null || uri.host == 'localhost' || uri.host == '127.0.0.1') {
      return _placeholderWebUrl;
    }
    return fromEnv;
  }

  static String pieceUrl(String id) => '$webBaseUrl/piece/$id';
}
