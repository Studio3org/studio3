import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../utils/app_destination.dart';

/// Resolves incoming `https://<host>/piece/:id` and `https://<host>/series/:id`
/// links, plus Stripe Connect return/refresh (`/connect/return`,
/// `/connect/refresh`), via Android App Links / iOS Universal Links —
/// *and* the equivalent `studio3://piece/:id` / `studio3://series/:id` /
/// `studio3://connect/return` custom-scheme links (see the backend's
/// `src/modules/share`), which need no domain verification and so work
/// today even though the `https://` host is still a placeholder domain
/// (see lib/config/app_link_config.dart).
///
/// The two shapes parse differently: `https://host/piece/abc` puts
/// `["piece", "abc"]` in [Uri.pathSegments], but a custom-scheme URI like
/// `studio3://piece/abc` treats `piece` as the *authority* — it lands in
/// [Uri.host], with only `["abc"]` left in [Uri.pathSegments]. `_handle`
/// normalizes both into one segments list before dispatching.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  Future<void> start(BuildContext context) async {
    if (_subscription != null) return;
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null && context.mounted) _handle(context, initialUri);
    } catch (_) {
      // No initial link, or the platform channel isn't ready yet — ignore.
    }
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      if (context.mounted) _handle(context, uri);
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _handle(BuildContext context, Uri uri) {
    var segments = uri.scheme == 'studio3'
        ? [uri.host, ...uri.pathSegments]
        : uri.pathSegments;
    // Shared links point at the backend's preview route, /share/piece/<id>, which renders
    // the OG tags and an open-app interstitial. Drop that prefix so both that shape and the
    // bare /piece/<id> route to the same place — otherwise a link the app itself generated
    // would open the app and then do nothing.
    if (segments.isNotEmpty && segments.first == 'share') {
      segments = segments.sublist(1);
    }
    // Where the link goes is resolved in one shared place, so a destination reachable from a
    // link is reachable from a notification tap too — and the QR codes in the event flow,
    // which arrive here, land on exactly the same routing as everything else.
    openDestination(context, AppDestination.fromSegments(segments));
  }
}
