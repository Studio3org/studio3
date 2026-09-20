import 'package:flutter/material.dart';

import '../models/feed_preview_item.dart';
import '../screens/event_detail_page.dart';
import '../screens/order_detail_page.dart';
import '../screens/series_view_page.dart';
import '../services/auth_session.dart';
import '../services/event_service.dart';
import '../services/piece_service.dart';
import 'explore_detail_route.dart';
import 'profile_navigation.dart';

/// Where a tap should land, whatever produced it.
///
/// Three things can ask to open something in this app, and before this they each did it
/// their own way — or, in two cases, not at all:
///
/// * a **deep link** (`https://host/piece/:id`, `studio3://piece/:id`), which parses a URI;
/// * a **push notification**, which carries `targetType` / `targetId` in its data payload;
/// * a row in the **in-app notification list**, which has the same two fields already loaded.
///
/// They share a resolver so a destination added for one is reachable from all three. The QR
/// codes in the event flow arrive as deep links and land here too, which is the reason this
/// is keyed on a type and an id rather than on a URL: a notification has no URL to give.
enum AppDestinationType { piece, series, order, event, profile, payoutSetup, unknown }

class AppDestination {
  const AppDestination(this.type, [this.id]);

  final AppDestinationType type;
  final String? id;

  bool get isKnown => type != AppDestinationType.unknown && (id != null || !_needsId);

  bool get _needsId => type != AppDestinationType.payoutSetup;

  /// From a notification's `targetType` / `targetId`, as the server sends them.
  ///
  /// [actorUsername] exists because a `user` target is the one case where `targetId` is not
  /// routable: the server sends a UUID, while the profile screen is addressed by username.
  /// The actor of a follow notification *is* the profile worth opening, and the actor block
  /// carries their username — so that is what a user target resolves to, and without it the
  /// tap stays inert rather than opening the wrong person.
  ///
  /// `inquiry` deliberately resolves to nothing: inquiries were deferred to v2 and the
  /// blueprint is unregistered, so routing to a screen that cannot load would be worse than
  /// doing nothing.
  factory AppDestination.fromTarget(
    String? targetType,
    String? targetId, {
    String? actorUsername,
  }) {
    if (targetType == 'user') {
      final handle = actorUsername?.trim();
      if (handle == null || handle.isEmpty) {
        return const AppDestination(AppDestinationType.unknown);
      }
      return AppDestination(AppDestinationType.profile, handle);
    }
    if (targetId == null || targetId.isEmpty) {
      return const AppDestination(AppDestinationType.unknown);
    }
    switch (targetType) {
      case 'piece':
        return AppDestination(AppDestinationType.piece, targetId);
      case 'series':
        return AppDestination(AppDestinationType.series, targetId);
      case 'order':
        return AppDestination(AppDestinationType.order, targetId);
      case 'event':
        return AppDestination(AppDestinationType.event, targetId);
      default:
        return const AppDestination(AppDestinationType.unknown);
    }
  }

  /// From an incoming link's already-normalized path segments.
  ///
  /// Both URI shapes reduce to the same list before they get here: `https://host/piece/abc`
  /// yields `["piece", "abc"]` from [Uri.pathSegments], while `studio3://piece/abc` puts
  /// `piece` in [Uri.host] and leaves only `["abc"]` behind.
  factory AppDestination.fromSegments(List<String> segments) {
    if (segments.length >= 2 && segments[0] == 'connect') {
      final action = segments[1];
      if (action == 'return' || action == 'refresh') {
        return const AppDestination(AppDestinationType.payoutSetup);
      }
    }
    if (segments.length < 2 || segments[1].isEmpty) {
      return const AppDestination(AppDestinationType.unknown);
    }
    // A link to a profile addresses it by username, which is what the route wants — so it is
    // passed as the actor rather than as an id.
    if (segments[0] == 'profile' || segments[0] == 'u') {
      return AppDestination.fromTarget('user', null, actorUsername: segments[1]);
    }
    return AppDestination.fromTarget(segments[0], segments[1]);
  }
}

/// Navigate to [destination]. Safe to call with anything — an unknown target does nothing.
///
/// Never throws. A tap arriving from a push may reference a piece that has since been
/// delisted or an order the viewer can no longer see, and the correct behaviour there is to
/// leave them where they are rather than to crash the app they just opened.
Future<void> openDestination(BuildContext context, AppDestination destination) async {
  switch (destination.type) {
    case AppDestinationType.piece:
      await _openPiece(context, destination.id!);
    case AppDestinationType.series:
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SeriesViewPage(seriesId: destination.id!),
        ),
      );
    case AppDestinationType.order:
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => OrderDetailPage(orderId: destination.id!),
        ),
      );
    case AppDestinationType.event:
      await _openEvent(context, destination.id!);
    case AppDestinationType.profile:
      openUserProfile(context, destination.id!);
    case AppDestinationType.payoutSetup:
      if (AuthSession.instance.sellerEnabled) {
        Navigator.pushNamed(context, '/payout-setup');
      }
    case AppDestinationType.unknown:
      break;
  }
}

Future<void> _openPiece(BuildContext context, String id) async {
  try {
    final piece = await PieceService.instance.getById(id);
    if (!context.mounted) return;
    await openPieceDetailPreview(context, FeedPreviewItem.fromPieceSummary(piece));
  } catch (_) {
    // Deleted, delisted, or unreachable. Ignore rather than crash navigation from a stale
    // link or a notification about a piece that has since gone.
  }
}

Future<void> _openEvent(BuildContext context, String id) async {
  try {
    final event = await EventService.instance.getById(id);
    if (!context.mounted) return;
    openEventDetail(context, event);
  } catch (_) {
    // Cancelled, still a draft, or gone. Better to stay put than to open an error screen
    // from a link somebody shared weeks ago.
  }
}
