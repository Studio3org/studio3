import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../models/feed_preview_item.dart';
import '../screens/series_view_page.dart';
import '../utils/explore_detail_route.dart';
import 'auth_session.dart';
import 'piece_service.dart';

/// Resolves incoming `https://<host>/piece/:id` and `https://<host>/series/:id`
/// links, plus Stripe Connect return/refresh (`/connect/return`,
/// `/connect/refresh`), via Android App Links / iOS Universal Links.
///
/// The host is a placeholder domain until a real production domain is
/// wired up end-to-end (see lib/config/app_link_config.dart) — until then
/// these links won't actually reach the app on a real device, but the
/// in-app resolution logic is exercised the same way once they do.
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
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'connect') {
      final action = segments[1];
      if (action == 'return' || action == 'refresh') {
        _openPayoutSetup(context);
        return;
      }
    }
    if (segments.length < 2) return;
    final id = segments[1];
    if (id.isEmpty) return;
    if (segments[0] == 'piece') {
      _openPiece(context, id);
    } else if (segments[0] == 'series') {
      _openSeries(context, id);
    }
  }

  void _openPayoutSetup(BuildContext context) {
    if (!AuthSession.instance.sellerEnabled) return;
    Navigator.pushNamed(context, '/payout-setup');
  }

  Future<void> _openPiece(BuildContext context, String id) async {
    try {
      final piece = await PieceService.instance.getById(id);
      if (!context.mounted) return;
      final preview = FeedPreviewItem.fromPieceSummary(piece);
      await openPieceDetailPreview(context, preview);
    } catch (_) {
      // Piece not found/unreachable — ignore rather than crash navigation
      // from a stale or invalid shared link.
    }
  }

  void _openSeries(BuildContext context, String id) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => SeriesViewPage(seriesId: id)),
    );
  }
}
