import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'api_config.dart';

/// Shareable-link URLs.
///
/// PLACEHOLDER: `webBaseUrl` defaults to `https://studio-3.co`, which is not
/// yet a real, publicly-hosted domain. Android App Links / iOS Universal
/// Links will not verify until `.env`'s `NEXT_PUBLIC_APP_URL` (and the
/// well-known files in `app/public/.well-known/`, the Android intent-filter
/// host, and the iOS associated-domains entitlement) are all updated to
/// match the real production domain.
///
/// The actual link people share/copy/paste (`pieceUrl`/`seriesUrl`) points at
/// the backend's `/share/...` pages instead of straight at `webBaseUrl` — the
/// backend is a real deployed server today (unlike the web app, which is a
/// client-rendered SPA), so it can serve real Open Graph tags for link
/// previews in WhatsApp/iMessage/Slack/etc., then redirect an actual visitor
/// on to the pretty `webBaseUrl` page. See `src/modules/share` in the backend.
abstract final class AppLinkConfig {
  static const String _placeholderWebUrl = 'https://studio-3.co';
  static const String _deployedApiUrl = 'https://studio3-backend.onrender.com';

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

  /// The backend origin to build share links against — same "don't share a
  /// dead local URL" guard as [webBaseUrl].
  static String get shareBaseUrl {
    final base = ApiConfig.baseUrl;
    final uri = Uri.tryParse(base);
    final host = uri?.host ?? '';
    if (uri == null || host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
      return _deployedApiUrl;
    }
    return base;
  }

  // UNRESOLVED: these links are built against the API origin
  // (studio3-backend.onrender.com), but the app's associated domain — in
  // ios/Runner/Runner.entitlements and the Android intent filters — is studio-3.co. Apple
  // and Android only honour a Universal/App Link on a domain the app is associated with,
  // so a shared link currently opens the web interstitial even on a device that has the
  // app installed. The paths now match; the host does not.
  //
  // Two ways out, and it is a deployment decision, not a code one:
  //   1. Serve the backend's /share/* routes from studio-3.co, so one domain covers both
  //      the OG preview and the link association. Cleanest.
  //   2. Add the API origin to the associated domains and serve
  //      /.well-known/apple-app-site-association from the backend too.
  //
  // This blocks the event QR flow, which encodes exactly these URLs.
  static String pieceUrl(String id) => '$shareBaseUrl/share/piece/$id';

  static String seriesUrl(String id) => '$shareBaseUrl/share/series/$id';
}
