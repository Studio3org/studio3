import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/event_order.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/event_confirmed_page.dart';
import 'package:studio3/screens/event_ticket_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/api_exception.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/event_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/events/event_tickets_sheet.dart';
import 'package:studio3/widgets/events/event_wallet_button.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Phase 3A of the backend handoff (B25): Add to Google Wallet on Android and Add to Apple
/// Wallet on iOS, on the confirmation and ticket screens, only when the server's flags say so.
final _event = StudioEvent(
  id: 'ev1',
  title: 'Inside the Mind of an Artist',
  startsAt: DateTime(2037, 11, 21, 20),
  endsAt: DateTime(2037, 11, 21, 22),
  venueName: 'Dec on Dragon',
  address: '1414 Dragon St, Dallas, TX 75201',
  ticketCount: 2,
);

const _vip = EventTicketType(id: 'vip', name: 'VIP', priceCents: 2500);
const _both = EventWalletPasses(apple: true, google: true);

final _passBytes = Uint8List.fromList([0x50, 0x4b, 0x03, 0x04, 1, 2, 3]);

class _FakeServer implements HttpClientAdapter {
  final requests = <Uri>[];

  /// `platform` → (status, message) to fail with.
  final failing = <String, (int, String)>{};

  List<Map<String, dynamic>> tickets = [
    {'id': 't1', 'code': 'c1', 'ticketTypeName': 'VIP', 'orderId': 'o1', 'walletPasses': {'apple': true, 'google': true}},
    {'id': 't2', 'code': 'c2', 'ticketTypeName': 'VIP', 'orderId': 'o1', 'walletPasses': {'apple': true, 'google': true}},
  ];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final uri = options.uri;
    requests.add(uri);
    if (uri.path == '/api/user/me/tickets') return _json({'data': {'tickets': tickets}}, 200);
    if (uri.path == '/api/events/ev1/orders/o1/wallet-pass') {
      final platform = uri.queryParameters['platform']!;
      final fail = failing[platform];
      if (fail != null) return _json({'success': false, 'message': fail.$2}, fail.$1);
      if (platform == 'google') {
        return _json({'data': {'saveUrl': 'https://pay.google.com/gp/v/save/jwt-${uri.queryParameters['ticketId'] ?? 'all'}'}}, 200);
      }
      return ResponseBody.fromBytes(_passBytes, 200, headers: {
        Headers.contentTypeHeader: ['application/vnd.apple.pkpass'],
      });
    }
    return _json({'success': false, 'message': 'Not found'}, 404);
  }

  ResponseBody _json(Object json, int status) => ResponseBody.fromString(
    jsonEncode(json),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}

late _FakeServer _server;

Widget _app(Widget home) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  home: home,
);

Widget _confirmed({EventOrderStatus? order, String? orderId}) => _app(
  EventConfirmedPage(event: _event, choice: const EventTicketChoice({_vip: 2}), orderId: orderId, order: order),
);

const _ticketsWith = [
  EventTicket(id: 't1', code: 'c1', typeName: 'VIP', orderId: 'o1', walletPasses: _both),
  EventTicket(id: 't2', code: 'c2', typeName: 'VIP', orderId: 'o1', walletPasses: _both),
];

final _google = find.byKey(const ValueKey('wallet-google'));
final _apple = find.byKey(const ValueKey('wallet-apple'));

void main() {
  final launched = <Uri>[];
  final added = <List<Uint8List>>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('wallet3a').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  String? wasToken;
  setUp(() {
    _server = _FakeServer();
    ApiClient.instance.debugUseAdapter(_server);
    wasToken = AuthSession.instance.accessToken;
    AuthSession.instance.accessToken = 'token';
    launched.clear();
    added.clear();
    EventWalletButton.launcher = (url) async {
      launched.add(url);
      return true;
    };
    EventWalletButton.addApplePasses = (passes) async => added.add(passes);
  });
  tearDown(() {
    AuthSession.instance.accessToken = wasToken;
    EventWalletButton.debugReset();
    debugDefaultTargetPlatformOverride = null;
  });

  group('service', () {
    test('getBytes returns the pass, with the platform and ticket in the query', () async {
      final bytes = await EventService.instance.appleWalletPass('ev1', 'o1', ticketId: 't2');
      expect(bytes, _passBytes);
      expect(_server.requests.single.queryParameters, {'platform': 'apple', 'ticketId': 't2'});
    });

    for (final (status, message) in [
      (409, "The tickets haven't been issued yet."),
      (410, 'These tickets are no longer valid.'),
      (503, "Apple Wallet isn't set up yet."),
    ]) {
      test('getBytes decodes a $status error body to the server message', () async {
        _server.failing['apple'] = (status, message);
        await expectLater(
          EventService.instance.appleWalletPass('ev1', 'o1'),
          throwsA(isA<ApiException>().having((e) => e.message, 'message', message).having((e) => e.statusCode, 'status', status)),
        );
      });
    }

    test('googleWalletUrl returns the save link', () async {
      expect(await EventService.instance.googleWalletUrl('ev1', 'o1'), 'https://pay.google.com/gp/v/save/jwt-all');
      expect(_server.requests.single.queryParameters, {'platform': 'google'});
    });
  });

  group('EventConfirmedPage', () {
    testWidgets('no wallet flags: no wallet button, on either platform', (tester) async {
      setBoardViewport(tester);
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(_confirmed(orderId: 'o1', order: const EventOrderStatus(id: 'o1', status: 'paid')));
        await tester.pumpAndSettle();
        expect(_google, findsNothing);
        expect(_apple, findsNothing);
        expect(find.byWidgetPredicate((w) => w is StudioButton && w.label == 'Add to calendar'), findsOneWidget);
      }
      // An order polled without flags is an older server: no ticket list is fetched.
      expect(_server.requests, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android: the Google badge above Add to calendar opens the save link', (tester) async {
      setBoardViewport(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        _confirmed(orderId: 'o1', order: const EventOrderStatus(id: 'o1', status: 'paid', walletPasses: _both)),
      );
      await tester.pumpAndSettle();
      expect(_google, findsOneWidget);
      expect(_apple, findsNothing);
      expect(
        tester.getTopLeft(_google).dy,
        lessThan(tester.getTopLeft(find.byWidgetPredicate((w) => w is StudioButton && w.label == 'Add to calendar')).dy),
      );
      await tester.tap(_google);
      await tester.pumpAndSettle();
      expect(_server.requests.single.path, '/api/events/ev1/orders/o1/wallet-pass');
      expect(_server.requests.single.queryParameters, {'platform': 'google'});
      expect(launched, [Uri.parse('https://pay.google.com/gp/v/save/jwt-all')]);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('iOS: Add to Apple Wallet hands every ticket of the order to Wallet', (tester) async {
      setBoardViewport(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        _confirmed(orderId: 'o1', order: const EventOrderStatus(id: 'o1', status: 'paid', walletPasses: _both)),
      );
      await tester.pumpAndSettle();
      expect(_apple, findsOneWidget);
      expect(_google, findsNothing);
      await tester.tap(_apple);
      await tester.pumpAndSettle();
      final passes = _server.requests.where((u) => u.path.endsWith('/wallet-pass')).map((u) => u.queryParameters);
      expect(passes, [
        {'platform': 'apple', 'ticketId': 't1'},
        {'platform': 'apple', 'ticketId': 't2'},
      ]);
      expect(added.single, [_passBytes, _passBytes]);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('not polled: the flags come from my tickets on open', (tester) async {
      setBoardViewport(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(_confirmed());
      await tester.pumpAndSettle();
      expect(_server.requests.single.path, '/api/user/me/tickets');
      expect(_google, findsOneWidget);
      await tester.tap(_google);
      await tester.pumpAndSettle();
      expect(launched.single.toString(), 'https://pay.google.com/gp/v/save/jwt-all');
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('not polled, tickets without flags: nothing', (tester) async {
      setBoardViewport(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      _server.tickets = [
        {'id': 't1', 'code': 'c1', 'ticketTypeName': 'VIP', 'orderId': 'o1'},
      ];
      await tester.pumpWidget(_confirmed());
      await tester.pumpAndSettle();
      expect(_google, findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a server error is toasted as it is', (tester) async {
      setBoardViewport(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      _server.failing['google'] = (503, "Google Wallet isn't set up yet.");
      await tester.pumpWidget(
        _confirmed(orderId: 'o1', order: const EventOrderStatus(id: 'o1', status: 'paid', walletPasses: _both)),
      );
      await tester.pumpAndSettle();
      await tester.tap(_google);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text("Google Wallet isn't set up yet."), findsOneWidget);
      expect(launched, isEmpty);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('EventTicketPage', () {
    testWidgets('no flags: Directions alone', (tester) async {
      setBoardViewport(tester);
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(
          _app(
            EventTicketPage(
              event: _event,
              tickets: const [EventTicket(id: 't1', code: 'c1', typeName: 'VIP', orderId: 'o1')],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(_google, findsNothing);
        expect(_apple, findsNothing);
      }
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('iOS: Add to Apple Wallet above Directions adds the ticket on screen', (tester) async {
      setBoardViewport(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(_app(EventTicketPage(event: _event, tickets: _ticketsWith)));
      await tester.pumpAndSettle();
      expect(_apple, findsOneWidget);
      expect(_google, findsNothing);
      final directions = find.byWidgetPredicate((w) => w is StudioButton && w.label == 'Directions');
      expect(tester.getTopLeft(_apple).dy, lessThan(tester.getTopLeft(directions).dy));

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(_apple);
      await tester.pumpAndSettle();
      expect(_server.requests.single.queryParameters, {'platform': 'apple', 'ticketId': 't2'});
      expect(added.single, [_passBytes]);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android: the Google badge saves just this ticket', (tester) async {
      setBoardViewport(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(_app(EventTicketPage(event: _event, tickets: _ticketsWith)));
      await tester.pumpAndSettle();
      expect(_apple, findsNothing);
      await tester.tap(_google);
      await tester.pumpAndSettle();
      expect(_server.requests.single.queryParameters, {'platform': 'google', 'ticketId': 't1'});
      expect(launched.single.toString(), 'https://pay.google.com/gp/v/save/jwt-t1');
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a 410 is toasted as it is', (tester) async {
      setBoardViewport(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      _server.failing['apple'] = (410, 'These tickets are no longer valid.');
      await tester.pumpWidget(_app(EventTicketPage(event: _event, tickets: _ticketsWith)));
      await tester.pumpAndSettle();
      await tester.tap(_apple);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('These tickets are no longer valid.'), findsOneWidget);
      expect(added, isEmpty);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
