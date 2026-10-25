import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/services/push_router_service.dart';
import 'package:studio3/utils/app_destination.dart';

/// Where a tap lands, from all three sources that can produce one.
void main() {
  group('from a notification target', () {
    test('a piece target routes to the piece', () {
      final d = AppDestination.fromTarget('piece', 'p1');

      expect(d.type, AppDestinationType.piece);
      expect(d.id, 'p1');
      expect(d.isKnown, isTrue);
    });

    test('an event target routes to the event', () {
      final d = AppDestination.fromTarget('event', 'e1');

      expect(d.type, AppDestinationType.event);
      expect(d.id, 'e1');
    });

    test('an order target routes to the order', () {
      expect(
        AppDestination.fromTarget('order', 'o1').type,
        AppDestinationType.order,
      );
    });

    test('a user target routes by the actor username, not the target id', () {
      // The server sends a UUID as targetId for a user, but the profile screen is addressed
      // by username. Routing on the id would open nothing, or the wrong person.
      final d = AppDestination.fromTarget(
        'user',
        '0f4d1a8c-0000-0000-0000-000000000000',
        actorUsername: 'aria',
      );

      expect(d.type, AppDestinationType.profile);
      expect(d.id, 'aria');
    });

    test('a user target with no actor username stays inert', () {
      final d = AppDestination.fromTarget('user', 'some-uuid');

      expect(d.isKnown, isFalse,
          reason: 'better to do nothing than to open the wrong profile');
    });

    test('an inquiry target stays inert because the feature is deferred', () {
      expect(AppDestination.fromTarget('inquiry', 'i1').isKnown, isFalse);
    });

    test('a missing id stays inert', () {
      expect(AppDestination.fromTarget('piece', null).isKnown, isFalse);
      expect(AppDestination.fromTarget('piece', '').isKnown, isFalse);
    });
  });

  group('from a link', () {
    test('an https link resolves from its path segments', () {
      final d = AppDestination.fromSegments(['piece', 'abc']);

      expect(d.type, AppDestinationType.piece);
      expect(d.id, 'abc');
    });

    test('an event link resolves, which is what a shared event uses', () {
      expect(
        AppDestination.fromSegments(['event', 'e1']).type,
        AppDestinationType.event,
      );
    });

    test('a connect return opens payout setup', () {
      expect(
        AppDestination.fromSegments(['connect', 'return']).type,
        AppDestinationType.payoutSetup,
      );
      expect(
        AppDestination.fromSegments(['connect', 'refresh']).type,
        AppDestinationType.payoutSetup,
      );
    });

    test('payout setup needs no id', () {
      expect(AppDestination.fromSegments(['connect', 'return']).isKnown, isTrue);
    });

    test('a profile link routes by the username in the path', () {
      final d = AppDestination.fromSegments(['profile', 'aria']);

      expect(d.type, AppDestinationType.profile);
      expect(d.id, 'aria');
    });

    test('an unrecognised or truncated link does nothing', () {
      expect(AppDestination.fromSegments(['piece']).isKnown, isFalse);
      expect(AppDestination.fromSegments([]).isKnown, isFalse);
      expect(AppDestination.fromSegments(['nonsense', 'x']).isKnown, isFalse);
    });
  });

  group('from a push payload', () {
    test('reads the target the server now sends on every notification', () {
      // Matches _push_target in notifications_dao.py.
      final d = PushRouterService.destinationFor({
        'type': 'auction_payment_failed',
        'targetType': 'piece',
        'targetId': 'p1',
      });

      expect(d.type, AppDestinationType.piece);
      expect(d.id, 'p1');
    });

    test('a follow push routes to the follower', () {
      final d = PushRouterService.destinationFor({
        'type': 'follow',
        'targetType': 'user',
        'targetId': 'uuid-here',
        'actorUsername': 'aria',
      });

      expect(d.type, AppDestinationType.profile);
      expect(d.id, 'aria');
    });

    test('an empty payload does nothing rather than throwing', () {
      // What every non-chat push looked like before the server started populating it, and
      // what an older client build will keep sending.
      expect(PushRouterService.destinationFor({}).isKnown, isFalse);
      expect(
        PushRouterService.destinationFor({'type': 'outbid'}).isKnown,
        isFalse,
      );
    });
  });
}
