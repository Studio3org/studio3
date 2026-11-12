import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/event_check_in.dart';
import 'package:studio3/models/event_order.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/event_ticket_page.dart';
import 'package:studio3/screens/host/host_cancel_page.dart';
import 'package:studio3/screens/host/host_reschedule_page.dart';
import 'package:studio3/screens/host/host_scanner_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/offline_check_in.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Phase 4 of the backend handoff: the buyer's refund, check-in at the door (online and
/// offline, with signed codes), the cancel preview and reschedule.
const _eventId = 'e0000000-0000-4000-8000-000000000001';
const _otherEvent = 'e0000000-0000-4000-8000-000000000002';
const _t1 = 'a0000000-0000-4000-8000-000000000001';
const _t2 = 'a0000000-0000-4000-8000-000000000002';
const _gone = 'a0000000-0000-4000-8000-0000000000ff';

final _event = StudioEvent(
  id: _eventId,
  title: 'Inside the Mind of an Artist',
  startsAt: DateTime(2037, 11, 21, 20),
  endsAt: DateTime(2037, 11, 21, 22),
  status: 'published',
  venueName: 'Dec on Dragon',
  rsvpCount: 62,
  isHost: true,
  ageLimit: '21',
  ticketTypes: const [EventTicketType(id: 'vip', name: 'VIP', priceCents: 2500)],
);

List<int> _uuid(String id) {
  final hex = id.replaceAll('-', '');
  return [for (var i = 0; i < 32; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)];
}

/// A code as the server makes it: `S3T1.` + unpadded base64url of 0x01, ticket, event, signature.
Future<String> _code(SimpleKeyPair keys, String ticketId, String eventId) async {
  final payload = [0x01, ..._uuid(ticketId), ..._uuid(eventId)];
  final signature = await Ed25519().sign(payload, keyPair: keys);
  return 'S3T1.${base64Url.encode([...payload, ...signature.bytes]).replaceAll('=', '')}';
}

Map<String, dynamic> _ticket(String id, String number, {String status = 'valid', String name = 'Ana Ruiz'}) => {
  'id': id,
  'number': number,
  'ticketTypeName': 'VIP',
  'holderName': name,
  'position': 1,
  'of': 2,
  'status': status,
  if (status == 'checked_in') 'checkedInAt': '2037-11-21T20:14:00+00:00',
};

class _Server implements HttpClientAdapter {
  final requests = <({String method, String path, Map<String, dynamic>? body})>[];

  /// method + path → (status, data or message).
  final routes = <String, (int, Object?)>{};

  /// Paths that fail as if the phone were offline.
  final offline = <String>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : null;
    requests.add((method: options.method, path: path, body: body));
    if (offline.any(path.contains)) {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    }
    final route = routes['${options.method} $path'];
    if (route == null) return _json({'success': false, 'message': 'no route'}, 404);
    final (status, data) = route;
    if (status >= 400) return _json({'success': false, 'message': data}, status);
    return _json({'success': true, 'data': data}, status);
  }

  Iterable<Map<String, dynamic>?> bodies(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).map((r) => r.body);

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

late _Server _server;
late MemoryCheckInStore _store;

/// Lets requests through the fake server finish (real async) and the frames that follow.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _app(Widget home) =>
    MaterialApp(key: UniqueKey(), debugShowCheckedModeBanner: false, theme: AppTheme.light, home: home);

void main() {
  late SimpleKeyPair keys;
  late String publicKey;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('phase4').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
    keys = await Ed25519().newKeyPair();
    publicKey = base64.encode((await keys.extractPublicKey()).bytes);
  });

  String? wasToken;
  setUp(() {
    _server = _Server();
    ApiClient.instance.debugUseAdapter(_server);
    wasToken = AuthSession.instance.accessToken;
    AuthSession.instance.accessToken = 'token';
    _store = MemoryCheckInStore();
    OfflineCheckIn.instance.debugStore = _store;
  });
  tearDown(() {
    AuthSession.instance.accessToken = wasToken;
    OfflineCheckIn.instance.debugReset();
  });

  CheckInManifest manifest() => CheckInManifest.fromJson({
    'eventId': _eventId,
    'publicKey': publicKey,
    'codePrefix': 'S3T1.',
    'ageLimit': '21',
    'tickets': [_ticket(_t1, 'S3-T-AAAAAA'), _ticket(_t2, 'S3-T-BBBBBB', status: 'checked_in', name: 'Ben')],
    'checkedIn': 1,
    'total': 2,
  });

  group('offline codes (D3: cryptography, Ed25519)', () {
    test('a correctly signed code reads back its ticket and event', () async {
      final code = await _code(keys, _t1, _eventId);
      expect(code.startsWith('S3T1.'), isTrue);
      expect(code.contains('='), isFalse);
      final read = await TicketCode.read(code, publicKey);
      expect(read?.ticketId, _t1);
      expect(read?.eventId, _eventId);
    });

    test('a forged, truncated or foreign code is rejected', () async {
      final code = await _code(keys, _t1, _eventId);
      // Signed by someone else.
      final other = await Ed25519().newKeyPair();
      expect(await TicketCode.read(await _code(other, _t1, _eventId), publicKey), isNull);
      // A changed byte breaks the signature.
      final raw = base64Url.decode(base64Url.normalize(code.substring(5)));
      raw[3] ^= 0xff;
      expect(await TicketCode.read('S3T1.${base64Url.encode(raw).replaceAll('=', '')}', publicKey), isNull);
      // Too short, not base64, the wrong version, no prefix.
      expect(await TicketCode.read(code.substring(0, 40), publicKey), isNull);
      expect(await TicketCode.read('S3T1.***', publicKey), isNull);
      final v2 = base64Url.decode(base64Url.normalize(code.substring(5)))..[0] = 0x02;
      expect(await TicketCode.read('S3T1.${base64Url.encode(v2)}', publicKey), isNull);
      expect(await TicketCode.read('S3-T-AAAAAA', publicKey), isNull);
    });
  });

  group('offline check-in: the manifest, a local list and the queue', () {
    test('scans decide on the phone and queue; repeats read Already checked in', () async {
      final offline = OfflineCheckIn.instance;
      await offline.saveManifest(manifest());
      expect(offline.counts(_eventId), (checkedIn: 1, total: 2));

      final ok = await offline.scan(_eventId, await _code(keys, _t1, _eventId));
      expect(ok.isCheckedIn, isTrue);
      expect(ok.offline, isTrue);
      expect(ok.message, 'Checked in: Ana Ruiz, VIP (1 of 2).');
      expect(ok.checkedIn, 2);
      expect(offline.pending(_eventId), 1);

      final again = await offline.scan(_eventId, await _code(keys, _t1, _eventId));
      expect(again.isAlready, isTrue);
      expect(again.message, startsWith('Already checked in at '));
      expect(offline.pending(_eventId), 1);

      // Checked in on the server before the phone went offline.
      expect((await offline.scan(_eventId, await _code(keys, _t2, _eventId))).isAlready, isTrue);
      // Signed, but no longer in the manifest: refunded or voided.
      final gone = await offline.scan(_eventId, await _code(keys, _gone, _eventId));
      expect(gone.isInvalid, isTrue);
      expect(gone.message, 'Not a valid ticket: it was refunded or cancelled.');
      // Another event's ticket.
      final foreign = await offline.scan(_eventId, await _code(keys, _t1, _otherEvent));
      expect(foreign.message, "Not a valid ticket: it's for a different event.");
      // A made-up code and an unknown number.
      expect((await offline.scan(_eventId, 'S3T1.abcdef')).message, 'Not a valid ticket.');
      expect((await offline.scan(_eventId, 'S3-T-ZZZZZZ')).message, 'Not a valid ticket.');
      expect(offline.pending(_eventId), 1);
    });

    test('a typed ticket number works offline too, in any case', () async {
      final offline = OfflineCheckIn.instance;
      await offline.saveManifest(manifest());
      final ok = await offline.scan(_eventId, 's3-t-aaaaaa');
      expect(ok.isCheckedIn, isTrue);
      expect(offline.queue(_eventId).single.code, 's3-t-aaaaaa');
    });

    test('without a manifest it says so instead of letting anyone in', () async {
      final result = await OfflineCheckIn.instance.scan(_eventId, 'S3-T-AAAAAA');
      expect(result.isInvalid, isTrue);
      expect(result.message, contains("isn't on this phone yet"));
    });

    test('sync sends {code, scannedAt} in batches of at most 500 and empties the queue', () async {
      final offline = OfflineCheckIn.instance;
      await offline.saveManifest(
        CheckInManifest.fromJson({
          ...manifest().toJson(),
          'tickets': [for (var i = 0; i < 501; i++) _ticket('t$i', 'S3-T-N$i')],
        }),
      );
      for (var i = 0; i < 501; i++) {
        await offline.scan(_eventId, 'S3-T-N$i', at: DateTime.utc(2037, 11, 21, 20, 0, i % 60));
      }
      expect(offline.pending(_eventId), 501);
      _server.routes['POST /api/events/$_eventId/check-in/sync'] = (
        200,
        {
          'results': [
            {'code': 'S3-T-N0', 'result': 'checked_in', 'message': 'Checked in.'},
          ],
          'checkedIn': 501,
          'total': 501,
        },
      );
      final synced = await offline.sync(_eventId);
      final batches = _server.bodies('POST', '/api/events/$_eventId/check-in/sync').toList();
      expect([for (final b in batches) (b!['scans'] as List).length], [500, 1]);
      final first = (batches.first!['scans'] as List).first as Map;
      expect(first.keys.toSet(), {'code', 'scannedAt'});
      expect(first['code'], 'S3-T-N0');
      expect(DateTime.parse(first['scannedAt'] as String), DateTime.utc(2037, 11, 21, 20));
      expect(offline.pending(_eventId), 0);
      expect(synced?.checkedIn, 501);
      // The phone still knows who it let in.
      expect((await offline.scan(_eventId, 'S3-T-N7')).isAlready, isTrue);
    });

    test('a sync that cannot reach the server keeps the queue', () async {
      final offline = OfflineCheckIn.instance;
      await offline.saveManifest(manifest());
      await offline.scan(_eventId, 'S3-T-AAAAAA');
      _server.offline.add('/check-in/sync');
      expect(await offline.sync(_eventId), isNull);
      expect(offline.pending(_eventId), 1);
    });

    test('a sync the server refuses (the event stopped checking in) is dropped', () async {
      final offline = OfflineCheckIn.instance;
      await offline.saveManifest(manifest());
      await offline.scan(_eventId, 'S3-T-AAAAAA');
      _server.routes['POST /api/events/$_eventId/check-in/sync'] = (409, "This event isn't checking anyone in.");
      await offline.sync(_eventId);
      expect(offline.pending(_eventId), 0);
    });
  });

  group('HostScannerPage', () {
    Future<HostScannerPageState> open(WidgetTester tester) async {
      setBoardViewport(tester);
      _server.routes['GET /api/events/$_eventId/check-in/manifest'] = (200, manifest().toJson());
      await tester.pumpWidget(
        _app(
          HostScannerPage(
            event: _event,
            debugCamera: const ColoredBox(color: Colors.black),
          ),
        ),
      );
      await _settle(tester);
      await tester.pump();
      return tester.state<HostScannerPageState>(find.byType(HostScannerPage));
    }

    testWidgets('downloads the manifest, shows the count and the age limit', (tester) async {
      await open(tester);
      expect(_server.requests.first.path, '/api/events/$_eventId/check-in/manifest');
      expect(find.text('Check in guests'), findsOneWidget);
      expect(find.text('1/2 checked in'), findsOneWidget);
      expect(find.text('21+ event: check ID at the door.'), findsOneWidget);
      expect(find.text('Enter code'), findsOneWidget);
      expect(find.text('Guest list'), findsOneWidget);
    });

    testWidgets('each scan shows the server message in its colour; a repeat is debounced', (tester) async {
      final page = await open(tester);
      final c = StudioColors.dark;
      final code = await tester.runAsync(() => _code(keys, _t1, _eventId));
      _server.routes['POST /api/events/$_eventId/tickets/$code/check-in'] = (
        200,
        {
          'result': 'checked_in',
          'message': 'Checked in: Ana Ruiz, VIP (1 of 2).',
          'ticket': _ticket(_t1, 'S3-T-AAAAAA', status: 'checked_in'),
          'checkedIn': 2,
          'total': 2,
        },
      );
      unawaited(page.scan(code!));
      await _settle(tester);
      await tester.pump();
      expect(find.text('Checked in: Ana Ruiz, VIP (1 of 2).'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Checked in')).style!.color, c.positive);
      expect(find.text('2/2 checked in'), findsOneWidget);

      // The camera sees the same code again straight away: no second request.
      unawaited(page.scan(code));
      await _settle(tester);
      expect(_server.requests.where((r) => r.path.endsWith('/check-in') && r.method == 'POST'), hasLength(1));

      _server.routes['POST /api/events/$_eventId/tickets/S3-T-BBBBBB/check-in'] = (
        200,
        {
          'result': 'already_checked_in',
          'message': 'Already checked in at 8:14 PM CST.',
          'ticket': _ticket(_t2, 'S3-T-BBBBBB', status: 'checked_in'),
          'checkedIn': 2,
          'total': 2,
        },
      );
      unawaited(page.scan('S3-T-BBBBBB'));
      await _settle(tester);
      await tester.pump();
      expect(find.text('Already checked in at 8:14 PM CST.'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Already checked in')).style!.color, c.alert);

      _server.routes['POST /api/events/$_eventId/tickets/nope/check-in'] = (
        200,
        {'result': 'invalid', 'message': 'Not a valid ticket.', 'ticket': null, 'checkedIn': 2, 'total': 2},
      );
      unawaited(page.scan('nope'));
      await _settle(tester);
      await tester.pump();
      expect(find.text('Not valid'), findsOneWidget);
      expect(find.text('Not a valid ticket.'), findsOneWidget);
    });

    testWidgets("a 409 shows the server's message", (tester) async {
      final page = await open(tester);
      _server.routes['POST /api/events/$_eventId/tickets/S3-T-AAAAAA/check-in'] = (
        409,
        "This event isn't checking anyone in.",
      );
      unawaited(page.scan('S3-T-AAAAAA'));
      await _settle(tester);
      await tester.pump();
      expect(find.text("This event isn't checking anyone in."), findsOneWidget);
    });

    testWidgets('without the network it checks the signed code on the phone and queues it', (tester) async {
      final page = await open(tester);
      _server.offline.add('/tickets/');
      _server.offline.add('/check-in/sync');
      final code = await tester.runAsync(() => _code(keys, _t1, _eventId));
      unawaited(page.scan(code!));
      await _settle(tester);
      await tester.pump();
      expect(find.text('Checked in: Ana Ruiz, VIP (1 of 2).'), findsOneWidget);
      expect(find.text("Saved on this phone. It syncs when you're back online."), findsOneWidget);
      expect(find.text('2/2 checked in'), findsOneWidget);
      expect(find.text('1 scan to sync'), findsOneWidget);
      expect(OfflineCheckIn.instance.queue(_eventId).single.code, code);
    });

    testWidgets('Enter code sends the typed number', (tester) async {
      await open(tester);
      _server.routes['POST /api/events/$_eventId/tickets/S3-T-AAAAAA/check-in'] = (
        200,
        {'result': 'checked_in', 'message': 'Checked in: Ana Ruiz, VIP (1 of 2).', 'checkedIn': 2, 'total': 2},
      );
      await tester.tap(find.text('Enter code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'S3-T-AAAAAA');
      await tester.tap(find.widgetWithText(StudioButton, 'Check in'));
      await tester.pumpAndSettle();
      await _settle(tester);
      await tester.pump();
      expect(find.text('Checked in: Ana Ruiz, VIP (1 of 2).'), findsOneWidget);
    });
  });

  group('refund on the ticket (4.1)', () {
    const one = EventTicket(id: 'tk1', code: 'c1', typeName: 'VIP', orderId: 'o1', refundable: true);
    const two = EventTicket(id: 'tk2', code: 'c2', typeName: 'VIP', orderId: 'o1', refundable: true);

    test('the amount matches the server: price plus tax, or exactly what is left at the end', () {
      // Two $25 VIP at 8.25 % tax: subtotal 5000, tax 413, total 5413.
      const order = EventOrderStatus(
        id: 'o1',
        status: 'paid',
        ticketCount: 2,
        totalCents: 5413,
        taxCents: 413,
        subtotalCents: 5000,
      );
      expect(ticketRefundCents(order: order, unitPrices: [2500], liveInOrder: 2), 2500 + 206);
      expect(ticketRefundCents(order: order, unitPrices: [2500, 2500], liveInOrder: 2), 5413);
      // After the first refund, the last ticket gets exactly what is left.
      const after = EventOrderStatus(
        id: 'o1',
        status: 'partly_refunded',
        ticketCount: 1,
        totalCents: 5413,
        taxCents: 413,
        subtotalCents: 5000,
        refundedCents: 2706,
      );
      expect(ticketRefundCents(order: after, unitPrices: [2500], liveInOrder: 1), 2707);
      // No price for the type: an even share of what is left.
      expect(ticketRefundCents(order: order, unitPrices: [null], liveInOrder: 2), 2707);
      expect(ticketRefundCents(order: null, unitPrices: [2500], liveInOrder: 2), isNull);
    });

    testWidgets('no button when the ticket is not refundable, and no "Refunds closed" label', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          EventTicketPage(
            event: _event,
            tickets: const [EventTicket(id: 'tk1', code: 'c1', typeName: 'VIP', orderId: 'o1')],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Refund this ticket'), findsNothing);
      expect(find.textContaining('Refunds closed'), findsNothing);
    });

    testWidgets('one ticket: the confirmation names the amount, then it refunds just that ticket', (tester) async {
      setBoardViewport(tester);
      var refunded = false;
      _server.routes['GET /api/events/$_eventId/orders/o1'] = (
        200,
        {
          'id': 'o1',
          'status': 'paid',
          'ticketCount': 1,
          'totalCents': 2706,
          'taxCents': 206,
          'subtotalCents': 2500,
          'refundedCents': 0,
        },
      );
      _server.routes['POST /api/events/$_eventId/orders/o1/refund'] = (
        200,
        {
          'id': 'o1',
          'status': 'refunded',
          'refundedCents': 2706,
          'refund': {
            'status': 'refunded',
            'amountCents': 2706,
            'ticketIds': ['tk1'],
          },
        },
      );
      _server.routes['GET /api/user/me/tickets'] = (200, {'tickets': <Object>[]});
      await tester.pumpWidget(
        _app(EventTicketPage(event: _event, tickets: const [one], onRefunded: () => refunded = true)),
      );
      await tester.pump();
      await tester.tap(find.text('Refund this ticket'));
      await _settle(tester);
      await tester.pumpAndSettle();
      expect(find.text("We'll refund \$27.06 to your card. It may take a few days to appear."), findsOneWidget);
      await tester.tap(find.widgetWithText(StudioButton, 'Refund'));
      await tester.pump();
      await _settle(tester);
      await tester.pumpAndSettle();
      expect(_server.bodies('POST', '/api/events/$_eventId/orders/o1/refund').single, {
        'ticketIds': ['tk1'],
      });
      expect(refunded, isTrue);
      expect(find.text('No tickets for this event'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('several in the order: "Refund all" sends an empty body', (tester) async {
      setBoardViewport(tester);
      _server.routes['GET /api/events/$_eventId/orders/o1'] = (
        200,
        {
          'id': 'o1',
          'status': 'paid',
          'ticketCount': 2,
          'totalCents': 5413,
          'taxCents': 413,
          'subtotalCents': 5000,
          'refundedCents': 0,
        },
      );
      _server.routes['POST /api/events/$_eventId/orders/o1/refund'] = (
        200,
        {
          'id': 'o1',
          'status': 'refunded',
          'refund': {
            'status': 'refunded',
            'amountCents': 5413,
            'ticketIds': ['tk1', 'tk2'],
          },
        },
      );
      _server.routes['GET /api/user/me/tickets'] = (200, {'tickets': <Object>[]});
      await tester.pumpWidget(_app(EventTicketPage(event: _event, tickets: const [one, two])));
      await tester.pump();
      await tester.tap(find.text('Refund this ticket'));
      await _settle(tester);
      await tester.pumpAndSettle();
      expect(find.text('Refund this ticket \$27.06'), findsOneWidget);
      expect(find.text('Refund all 2 tickets \$54.13'), findsOneWidget);
      await tester.tap(find.text('Refund all 2 tickets \$54.13'));
      await tester.pump();
      await _settle(tester);
      await tester.pumpAndSettle();
      expect(_server.bodies('POST', '/api/events/$_eventId/orders/o1/refund').single, <String, dynamic>{});
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets("a 409 shows the server's message", (tester) async {
      setBoardViewport(tester);
      _server.routes['GET /api/events/$_eventId/orders/o1'] = (
        200,
        {'id': 'o1', 'status': 'paid', 'ticketCount': 1, 'totalCents': 2706},
      );
      _server.routes['POST /api/events/$_eventId/orders/o1/refund'] = (409, 'Refunds for this event have closed.');
      _server.routes['GET /api/user/me/tickets'] = (200, {'tickets': <Object>[]});
      await tester.pumpWidget(_app(EventTicketPage(event: _event, tickets: const [one])));
      await tester.pump();
      await tester.tap(find.text('Refund this ticket'));
      await _settle(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(StudioButton, 'Refund'));
      await tester.pump();
      await _settle(tester);
      await tester.pump();
      expect(find.text('Refunds for this event have closed.'), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('a rescheduled event says so on the ticket (4.4)', (tester) async {
      setBoardViewport(tester);
      final moved = _event.copyWith(
        rescheduledAt: DateTime(2037, 11, 10),
        rescheduleMessage: 'The space needs another week.',
      );
      await tester.pumpWidget(_app(EventTicketPage(event: moved, tickets: const [one])));
      await tester.pump();
      expect(find.text('Rescheduled. The space needs another week.'), findsOneWidget);
    });
  });

  group('host: cancel preview and reschedule', () {
    testWidgets('the preview fills the rows; tickets, refunds and fees only when there are any', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          HostCancelPage(
            event: _event,
            debugPreview: const EventCancelPreview(
              ticketsToVoid: 62,
              ordersToRefund: 40,
              refundTotalCents: 154300,
              cardFeesCents: 4810,
              guestsToNotify: 41,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('41 people'), findsOneWidget);
      expect(find.text('Tickets cancelled'), findsOneWidget);
      expect(find.text('\$1,543'), findsOneWidget);
      expect(find.text('Card fees you pay'), findsOneWidget);
      expect(find.text('\$48.10'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 500);
    });

    testWidgets('a failed preview falls back to the event counts', (tester) async {
      setBoardViewport(tester);
      _server.routes['GET /api/events/$_eventId/cancel-preview'] = (500, 'busy');
      await tester.pumpWidget(_app(HostCancelPage(event: _event)));
      await _settle(tester);
      await tester.pump();
      expect(_server.requests.single.path, '/api/events/$_eventId/cancel-preview');
      expect(find.text('62 people'), findsOneWidget);
      expect(find.text('Tickets cancelled'), findsNothing);
    });

    testWidgets("reschedule sends the new times and shows the server's refusal", (tester) async {
      setBoardViewport(tester, height: 900);
      _server.routes['POST /api/events/$_eventId/reschedule'] = (
        409,
        'Bidding has started on a piece at this event, so it can\'t move. Cancel the event instead, or wait until the auction closes.',
      );
      await tester.pumpWidget(_app(HostReschedulePage(event: _event, debugNow: DateTime(2037, 11, 10))));
      await tester.pump();
      // Nothing moved yet: the button waits for a new time.
      expect(
        tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Reschedule and tell guests')).onPressed,
        isNull,
      );
      await tester.tap(find.text('Date and time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('28'));
      await tester.pump();
      await tester.tap(find.widgetWithText(StudioButton, 'Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(StudioButton, 'Reschedule and tell guests'));
      await tester.pump();
      await _settle(tester);
      await tester.pump();
      final body = _server.bodies('POST', '/api/events/$_eventId/reschedule').single!;
      expect(DateTime.parse(body['startsAt'] as String).toLocal(), DateTime(2037, 11, 28, 20));
      expect(DateTime.parse(body['endsAt'] as String).toLocal(), DateTime(2037, 11, 28, 22));
      expect(body.containsKey('message'), isFalse);
      expect(find.textContaining('Bidding has started'), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
