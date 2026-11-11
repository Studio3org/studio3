import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/event_order.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/event_checkout_page.dart';
import 'package:studio3/screens/event_confirmed_page.dart';
import 'package:studio3/screens/event_detail_page.dart';
import 'package:studio3/screens/host/host_event_page.dart';
import 'package:studio3/screens/host/host_manage_page.dart';
import 'package:studio3/screens/host/host_ticket_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/events/event_detail_widgets.dart';
import 'package:studio3/widgets/events/event_tickets_sheet.dart';
import 'package:studio3/widgets/host/host_widgets.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Phase 3 of the backend handoff (ticketing core, B22): ticket types on the host's Tickets
/// step, age limit and Public on Details, the refund policy, saving types as a diff, paying with
/// a poll until the tickets are issued, and free ticket types ordered rather than RSVP'd.
final _now = DateTime(2037, 11, 10, 10);

class _FakeServer implements HttpClientAdapter {
  final requests = <({String method, String path, Map<String, dynamic>? body})>[];

  /// `METHOD path` → the statuses it answers before it works, in order.
  final failing = <String, List<(int, String)>>{};

  /// `METHOD path` → which call (1-based, counted from when it is set) answers 500, once.
  final failOnNth = <String, int>{};
  final _seen = <String, int>{};

  /// What the order poll answers, one per call; the last one repeats.
  List<String> pollStatuses = ['paid'];
  int polls = 0;

  /// The order POST's status and secret.
  String orderStatus = 'pending_payment';
  String? clientSecret = 'cs_test';

  final types = <Map<String, dynamic>>[];
  var _nextType = 1;

  Iterable<Map<String, dynamic>?> bodies(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).map((r) => r.body);

  int count(String method, String path) => requests.where((r) => r.method == method && r.path == path).length;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : null;
    final key = '${options.method} $path';
    requests.add((method: options.method, path: path, body: body));
    if (failOnNth.containsKey(key)) {
      final n = _seen[key] = (_seen[key] ?? 0) + 1;
      if (n == failOnNth[key]) {
        failOnNth.remove(key);
        return _json({'success': false, 'message': 'The server is busy. Try again.'}, 500);
      }
    }
    final fails = failing[key];
    if (fails != null && fails.isNotEmpty) {
      final (status, message) = fails.removeAt(0);
      return _json({'success': false, 'message': message}, status);
    }
    Object? data;
    if (options.method == 'POST' && path == '/api/events/ev1/ticket-types') {
      final id = 'new${_nextType++}';
      types.add({...body!, 'id': id});
      data = {'id': id, 'ticketTypes': types};
    } else if (options.method == 'PATCH' && path.startsWith('/api/events/ev1/ticket-types/')) {
      final id = path.split('/').last;
      final i = types.indexWhere((t) => t['id'] == id);
      if (i >= 0) types[i] = {...types[i], ...body!};
      data = {'ticketTypes': types};
    } else if (options.method == 'DELETE' && path.startsWith('/api/events/ev1/ticket-types/')) {
      final id = path.split('/').last;
      types.removeWhere((t) => t['id'] == id);
      data = {'ticketTypes': types, 'result': 'deleted'};
    } else {
      switch (key) {
        case 'POST /api/events/ev1/orders':
          data = {
            'id': 'o1',
            'orderId': 'o1',
            'clientSecret': clientSecret,
            'status': orderStatus,
            'totalCents': 2706,
            'holdExpiresAt': '2037-11-10T10:10:00Z',
          };
        case 'GET /api/events/ev1/orders/o1':
          final status = pollStatuses[polls < pollStatuses.length ? polls : pollStatuses.length - 1];
          polls++;
          data = {
            'id': 'o1',
            'eventId': 'ev1',
            'status': status,
            'ticketCount': 1,
            'walletPasses': {'apple': false, 'google': true},
            'walletPassAvailable': true,
          };
        case 'POST /api/events/ev1/rsvp':
          data = {'going': true, 'rsvpCount': 5, 'spotsLeft': 15, 'isFull': false};
        case 'PATCH /api/events/ev1':
          data = {..._eventJson, ...body!};
        case 'PUT /api/events/ev1/people':
          data = _eventJson;
        case 'POST /api/events/ev1/publish':
          data = {..._eventJson, 'status': 'published'};
        default:
          return _json({'success': false, 'message': 'no route $key'}, 404);
      }
    }
    return _json({'success': true, 'data': data}, options.method == 'POST' ? 201 : 200);
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

const _eventJson = <String, dynamic>{
  'id': 'ev1',
  'title': 'Inside the Mind of an Artist',
  'startsAt': '2037-11-21T20:00:00',
  'endsAt': '2037-11-21T22:00:00',
  'status': 'draft',
};

late _FakeServer _server;

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 120));
  }
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 350));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder, {int rounds = 6}) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester, rounds: rounds);
}

const _ga = EventTicketType(id: 'ga', name: 'General Admission', quantity: 100, sold: 0, hostNetCents: 0, left: 100);
const _vip = EventTicketType(
  id: 'vip',
  name: 'VIP',
  priceCents: 2500,
  includes: 'Early entry',
  quantity: 20,
  sold: 3,
  hostNetCents: 2300,
  left: 17,
);
const _early = EventTicketType(id: 'early', name: 'Early bird', priceCents: 1500, quantity: 10, sold: 0, hostNetCents: 1380);

StudioEvent _hosted({List<EventTicketType> types = const [_ga, _vip, _early], String refund = '7d'}) => StudioEvent(
  id: 'ev1',
  title: 'Inside the Mind of an Artist',
  startsAt: DateTime(2037, 11, 21, 20),
  endsAt: DateTime(2037, 11, 21, 22),
  status: 'published',
  category: 'gallery_walk',
  coverMediaUrl: 'https://example.com/flyer.jpg',
  timezoneName: 'CST',
  venueName: 'Dec on Dragon',
  address: '1414 Dragon St, Dallas, TX 75201',
  isHost: true,
  ticketTypes: types,
  refundPolicy: refund,
  ageLimit: '21',
  visibility: 'link',
);

final _buyerEvent = StudioEvent(
  id: 'ev1',
  title: 'Inside the Mind of an Artist',
  startsAt: DateTime(2037, 11, 21, 20),
  endsAt: DateTime(2037, 11, 21, 22),
  venueName: 'Dec on Dragon',
  ticketTypes: const [
    EventTicketType(id: 'free1', name: 'Community', left: 50, perOrderLimit: 4, onSale: true),
    EventTicketType(id: 'vip', name: 'VIP', priceCents: 2500, left: 3, onSale: true),
    EventTicketType(id: 'later', name: 'Door', priceCents: 900, onSale: false),
  ],
);

/// Opens checkout and shows how it ended.
class _CheckoutHost extends StatefulWidget {
  const _CheckoutHost();

  @override
  State<_CheckoutHost> createState() => _CheckoutHostState();
}

class _CheckoutHostState extends State<_CheckoutHost> {
  EventCheckoutResult? result;
  bool done = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async {
          final r = await Navigator.of(context).push<EventCheckoutResult>(
            MaterialPageRoute(
              builder: (_) => EventCheckoutPage(
                event: _buyerEvent,
                choice: EventTicketChoice({_buyerEvent.ticketTypes[1]: 1}),
                debugQuote: const EventOrderQuote(taxCents: 206, totalCents: 2706),
                debugEmail: 'jordan@email.com',
                pollEvery: const Duration(milliseconds: 100),
                pollFor: const Duration(milliseconds: 1000),
              ),
            ),
          );
          setState(() {
            result = r;
            done = true;
          });
        },
        child: Text(
          done
              ? 'result: ${result?.outcome.name} ${result?.orderId} ${result?.order?.status} pending=${result?.pending}'
              : 'open',
        ),
      ),
    ),
  );
}

Widget _app(Widget home) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  home: home,
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('ticketing3').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  late AuthUser? wasUser;
  late String? wasToken;
  late bool wasSeller;
  setUp(() {
    _server = _FakeServer();
    ApiClient.instance.debugUseAdapter(_server);
    wasUser = AuthSession.instance.user;
    wasToken = AuthSession.instance.accessToken;
    wasSeller = AuthSession.instance.sellerEnabled;
    AuthSession.instance.sellerEnabled = true;
    AuthSession.instance.user = const AuthUser(username: 'sarah', name: 'Sarah Osmei', email: 's@example.test');
    AuthSession.instance.accessToken = 'token';
  });
  tearDown(() {
    AuthSession.instance.user = wasUser;
    AuthSession.instance.accessToken = wasToken;
    AuthSession.instance.sellerEnabled = wasSeller;
  });

  group('models', () {
    test('ticket types: the host view, and the body the endpoints take', () {
      final t = EventTicketType.fromJson(const {
        'id': 't1',
        'name': 'VIP',
        'priceCents': 2500,
        'includes': 'Drinks',
        'left': 7,
        'perOrderLimit': 4,
        'saleStartsAt': null,
        'saleEndsAt': '2037-11-21T18:00:00+00:00',
        'onSale': true,
        'soldOut': false,
        'quantity': 10,
        'sold': 3,
        'hostNetCents': 2300,
        'closed': false,
        'waiting': 2,
        'sortOrder': 1,
      });
      expect((t.quantity, t.sold, t.hostNetCents, t.waiting, t.sortOrder), (10, 3, 2300, 2, 1));
      expect((t.onSale, t.soldOut, t.closed), (true, false, false));
      expect(t.saleEndsAt!.toUtc(), DateTime.utc(2037, 11, 21, 18));
      expect(t.toJson(), {
        'name': 'VIP',
        'priceCents': 2500,
        'includes': 'Drinks',
        'quantity': 10,
        'perOrderLimit': 4,
        'saleStartsAt': null,
        'saleEndsAt': '2037-11-21T18:00:00.000Z',
        'sortOrder': 1,
      });
      expect(EventTicketType.fromJson(const {'id': 'x', 'name': 'A', 'left': 0}).isSoldOut, isTrue);
    });

    test('orders, the poll and tickets', () {
      final order = EventOrder.fromJson(const {'orderId': 'o1', 'clientSecret': null, 'status': 'paid', 'devMode': true});
      expect((order.id, order.isPaid, order.devMode), ('o1', true, true));
      final poll = EventOrderStatus.fromJson(const {
        'id': 'o1',
        'status': 'pending_payment',
        'ticketCount': 2,
        'refundable': true,
        'walletPasses': {'apple': true, 'google': false},
        'walletPassAvailable': true,
      });
      expect((poll.id, poll.isPending, poll.ticketCount, poll.walletPasses!.apple), ('o1', true, 2, true));
      final ticket = EventTicket.fromJson(const {
        'id': 'k1',
        'code': 'QR',
        'orderId': 'o1',
        'eventId': 'ev1',
        'status': 'valid',
        'refundable': true,
        'walletPasses': {'apple': false, 'google': true},
        'walletPassAvailable': true,
      });
      expect((ticket.orderId, ticket.eventId, ticket.status, ticket.walletPasses!.google), ('o1', 'ev1', 'valid', true));
      expect(EventTicket.fromJson(const {'id': 'k', 'code': 'Q'}).walletPasses, isNull);
    });

    test('events: refund policy, age limit, visibility; copyWith keeps them', () {
      final e = StudioEvent.fromJson(const {
        'id': 'ev1',
        'title': 'T',
        'startsAt': '2037-11-21T20:00:00Z',
        'endsAt': '2037-11-21T22:00:00Z',
        'refundPolicy': '24h',
        'refundPolicyText': 'Refunds up to 24 hours before the event.',
        'ageLimit': '18',
        'visibility': 'link',
        'rescheduledAt': '2037-11-01T10:00:00Z',
      });
      expect((e.refundPolicy, e.ageLimit, e.visibility, e.isLinkOnly), ('24h', '18', 'link', true));
      expect(e.rescheduledAt, isNotNull);
      final copy = e.copyWith(saved: true);
      expect((copy.refundPolicy, copy.refundPolicyText, copy.ageLimit, copy.visibility), (
        '24h',
        'Refunds up to 24 hours before the event.',
        '18',
        'link',
      ));
      expect(StudioEvent.fromJson(e.toJson()).ageLimit, '18');
    });

    test('buyer prices leave out types that are not on sale', () {
      expect(eventTicketRange(_buyerEvent.ticketOptions), r'Free to $25');
      expect(eventTicketRange(const [EventTicketType(id: 'a', name: 'A', priceCents: 900, onSale: false)]), r'$9');
    });
  });

  group('buying', () {
    testWidgets('after paying, checkout waits for the tickets, then hands back the order', (tester) async {
      _server.pollStatuses = ['pending_payment', 'pending_payment', 'paid'];
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const _CheckoutHost()));
      await _tap(tester, find.text('open'));
      await tester.tap(_button(r'Confirm and pay $27.06'));
      await tester.pump();
      // Still paying while it polls.
      expect(tester.widget<StudioButton>(_button(r'Confirm and pay $27.06')).loading, isTrue);
      await _settle(tester, rounds: 10);
      expect(_server.bodies('POST', '/api/events/ev1/orders').single, {
        'items': [
          {'ticketTypeId': 'vip', 'quantity': 1},
        ],
      });
      expect(_server.polls, 3);
      expect(find.text('result: paid o1 paid pending=false'), findsOneWidget);
    });

    testWidgets('a free order or a development server is done at once: no poll', (tester) async {
      _server
        ..orderStatus = 'paid'
        ..clientSecret = null;
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const _CheckoutHost()));
      await _tap(tester, find.text('open'));
      await _tap(tester, _button(r'Confirm and pay $27.06'));
      expect(_server.count('GET', '/api/events/ev1/orders/o1'), 0);
      expect(find.text('result: paid o1 null pending=false'), findsOneWidget);
    });

    testWidgets('an order that expired says so and stays on checkout', (tester) async {
      _server.pollStatuses = ['pending_payment', 'expired'];
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const _CheckoutHost()));
      await _tap(tester, find.text('open'));
      await _tap(tester, _button(r'Confirm and pay $27.06'), rounds: 10);
      expect(find.byType(EventCheckoutPage), findsOneWidget);
      expect(
        find.text('Your 10 minutes to pay ran out, so the tickets went back on sale. Please try again.'),
        findsOneWidget,
      );
      expect(tester.widget<StudioButton>(_button(r'Confirm and pay $27.06')).loading, isFalse);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('no answer in time: confirmed, the tickets will appear shortly', (tester) async {
      _server.pollStatuses = ['pending_payment'];
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const _CheckoutHost()));
      await _tap(tester, find.text('open'));
      await _tap(tester, _button(r'Confirm and pay $27.06'), rounds: 16);
      expect(find.text('result: paid o1 null pending=true'), findsOneWidget);
    });

    testWidgets('the confirmation for a pending order and for an RSVP that issued a ticket', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          EventConfirmedPage(
            event: _buyerEvent,
            choice: EventTicketChoice({_buyerEvent.ticketTypes[1]: 1}),
            email: 'jordan@email.com',
            orderId: 'o1',
            pending: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Your tickets will appear shortly. We'll also email them to jordan@email.com."), findsOneWidget);
      expect(_button('View tickets'), findsOneWidget);

      // An RSVP on a B22 server: the event says the viewer holds a ticket.
      final rsvp = StudioEvent(
        id: 'ev1',
        title: 'T',
        startsAt: DateTime(2037, 11, 21, 20),
        endsAt: DateTime(2037, 11, 21, 22),
        ticketCount: 1,
      );
      await tester.pumpWidget(
        _app(EventConfirmedPage(event: rsvp, choice: EventTicketChoice({rsvp.ticketOptions.single: 1}))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your 1 ticket is saved here.'), findsOneWidget);
      expect(_button('View tickets'), findsOneWidget);
    });

    testWidgets('free ticket types are ordered, not RSVP\'d; the order id reaches the confirmation', (tester) async {
      _server
        ..orderStatus = 'paid'
        ..clientSecret = null;
      setBoardViewport(tester);
      await tester.pumpWidget(_app(EventDetailPage(event: _buyerEvent, debugDetail: _buyerEvent)));
      await tester.pump();
      // The bar's price leaves out the Door type, which isn't on sale yet.
      expect(find.text(r'Free to $25'), findsOneWidget);
      await _tap(tester, _button('Get tickets'));
      await tester.tap(find.bySemanticsLabel('One more Community'));
      await tester.tap(find.bySemanticsLabel('One more Community'));
      await tester.pump();
      await _tap(tester, _button('Reserve'), rounds: 8);
      expect(_server.count('POST', '/api/events/ev1/rsvp'), 0);
      expect(_server.bodies('POST', '/api/events/ev1/orders').single, {
        'items': [
          {'ticketTypeId': 'free1', 'quantity': 2},
        ],
      });
      expect(find.byType(EventConfirmedPage), findsOneWidget);
      expect(tester.widget<EventConfirmedPage>(find.byType(EventConfirmedPage)).orderId, 'o1');
      expect(_button('View tickets'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('an event with no ticket types still RSVPs; "rsvp" never goes to /orders', (tester) async {
      final rsvpEvent = StudioEvent(
        id: 'ev1',
        title: 'Open studio',
        startsAt: DateTime(2037, 11, 21, 20),
        endsAt: DateTime(2037, 11, 21, 22),
        spotsLeft: 16,
      );
      setBoardViewport(tester);
      await tester.pumpWidget(_app(EventDetailPage(event: rsvpEvent, debugDetail: rsvpEvent)));
      await tester.pump();
      await _tap(tester, _button('Get tickets'));
      await _tap(tester, _button('Reserve'), rounds: 8);
      expect(_server.bodies('POST', '/api/events/ev1/rsvp').single, {'going': true});
      expect(_server.count('POST', '/api/events/ev1/orders'), 0);
      expect(find.byType(EventConfirmedPage), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('hosting', () {
    testWidgets('Tickets: the event\'s types as cards, what the host receives, the refund policy', (tester) async {
      setBoardViewport(tester, height: 1100);
      await tester.pumpWidget(_app(HostEventPage(editing: _hosted(), debugNow: _now, debugStep: 1)));
      await tester.pump();
      expect(tester.widget<HostOptionRows<bool>>(find.byType(HostOptionRows<bool>)).value, isTrue);
      expect(find.text('VIP'), findsOneWidget);
      expect(find.text(r'$25 · 20 available'), findsOneWidget);
      expect(find.text('Early entry'), findsOneWidget);
      expect(find.text(r'You receive $23 per ticket'), findsOneWidget);
      expect(find.text('Free · 100 available'), findsOneWidget);
      expect(find.text('+ Add ticket type'), findsOneWidget);
      expect(find.text('Refund policy'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);
    });

    testWidgets('Review lists the types, the refund policy, the age limit and link only', (tester) async {
      setBoardViewport(tester, height: 1100);
      await tester.pumpWidget(_app(HostEventPage(editing: _hosted(), debugNow: _now, debugStep: 3)));
      await tester.pump();
      expect(find.text(r'VIP · $25 · 20 available'), findsOneWidget);
      expect(find.text('Refunds: 7 days'), findsOneWidget);
      expect(find.text('21+ · Link only'), findsOneWidget);
    });

    testWidgets('Ticket type page: name, Free or Paid with a price, a sold type keeps its price', (tester) async {
      HostTicketEdit? popped;
      setBoardViewport(tester, height: 1200);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => popped = await HostTicketPage.openType(context, type: _vip, canRemove: true),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text("This ticket has sold, so its price can't change. Add a new ticket type instead."), findsOneWidget);
      expect(find.text(r'You receive $23 per ticket'), findsOneWidget);
      expect(find.text('3 sold or held'), findsOneWidget);
      expect(find.text('Remove ticket type'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'VIP'), 'VIP lounge');
      await tester.pump();
      await tester.tap(_button('Save ticket type'));
      await tester.pumpAndSettle();
      expect(popped!.type!.name, 'VIP lounge');
      expect(popped!.type!.priceCents, 2500);
      expect(popped!.type!.id, 'vip');

      // A new type: Paid needs at least $0.50.
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => popped = await HostTicketPage.openType(context, isNew: true),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Student');
      await tester.tap(find.text('Paid'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '0.00'), '0.25');
      await tester.pump();
      expect(tester.widget<StudioButton>(_button('Save ticket type')).onPressed, isNull);
      await tester.enterText(find.byType(TextField).at(1), '12.50');
      await tester.pump();
      await tester.tap(_button('Save ticket type'));
      await tester.pumpAndSettle();
      expect((popped!.type!.name, popped!.type!.priceCents, popped!.type!.id), ('Student', 1250, ''));
    });

    testWidgets('Paid tickets without a seller profile asks to set one up first', (tester) async {
      AuthSession.instance.sellerEnabled = false;
      setBoardViewport(tester, height: 1000);
      await tester.pumpWidget(_app(HostEventPage(debugNow: _now, debugStep: 1)));
      await tester.pump();
      await tester.tap(find.text('Paid tickets'));
      await tester.pumpAndSettle();
      expect(find.text('Turn on selling first'), findsOneWidget);
      expect(find.byType(HostTicketPage), findsNothing);
    });

    testWidgets('saving sends only what changed: delete, patch, add, before publishing', (tester) async {
      _server.types.addAll([
        {'id': 'ga', 'name': 'General Admission', 'priceCents': 0, 'quantity': 100},
        {'id': 'vip', 'name': 'VIP', 'priceCents': 2500, 'quantity': 20},
        {'id': 'early', 'name': 'Early bird', 'priceCents': 1500, 'quantity': 10},
      ]);
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(_app(HostEventPage(editing: _hosted(), debugNow: _now, debugStep: 1)));
      await tester.pump();

      // GA: 100 → 120.
      await _tap(tester, find.text('General Admission'));
      await tester.enterText(find.widgetWithText(TextField, '100'), '120');
      await tester.pump();
      await _tap(tester, _button('Save ticket type'));
      expect(find.text('Free · 120 available'), findsOneWidget);

      // Early bird: removed.
      await _tap(tester, find.text('Early bird'));
      await _tap(tester, find.text('Remove ticket type'));
      await _tap(tester, find.text('Remove').last);
      expect(find.text('Early bird'), findsNothing);

      // Student: added, free, no cap.
      await _tap(tester, find.text('+ Add ticket type'));
      await tester.enterText(find.byType(TextField).first, 'Student');
      await tester.pump();
      await _tap(tester, _button('Save ticket type'));
      expect(find.text('Student'), findsOneWidget);

      await _tap(tester, _button('Save and continue'));
      await _tap(tester, _button('Save and continue'));
      await _tap(tester, _button('Save changes'), rounds: 12);

      final event = _server.bodies('PATCH', '/api/events/ev1').single!;
      expect((event['ageLimit'], event['visibility'], event['refundPolicy']), ('21', 'link', '7d'));
      expect(_server.count('DELETE', '/api/events/ev1/ticket-types/early'), 1);
      expect(_server.bodies('PATCH', '/api/events/ev1/ticket-types/ga').single, {'quantity': 120});
      expect(_server.count('PATCH', '/api/events/ev1/ticket-types/vip'), 0);
      final added = _server.bodies('POST', '/api/events/ev1/ticket-types').single!;
      expect((added['name'], added['priceCents'], added['quantity']), ('Student', 0, null));
      expect(find.byType(HostEventPage), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a save that fails part way is tried again without adding a type twice', (tester) async {
      final draft = StudioEvent(
        id: 'ev1',
        title: 'Inside the Mind of an Artist',
        startsAt: DateTime(2037, 11, 21, 20),
        endsAt: DateTime(2037, 11, 21, 22),
        status: 'draft',
        category: 'gallery_walk',
        coverMediaUrl: 'https://example.com/flyer.jpg',
        venueName: 'Dec on Dragon',
        address: '1414 Dragon St',
        isHost: true,
      );
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(_app(HostEventPage(editing: draft, debugNow: _now, debugStep: 1)));
      await tester.pump();

      // Paid tickets: the first type opens at once, Paid.
      await _tap(tester, find.text('Paid tickets'));
      expect(find.byType(HostTicketPage), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, '0.00'), '25');
      await tester.pump();
      await _tap(tester, _button('Save ticket type'));
      await _tap(tester, find.text('+ Add ticket type'));
      await tester.enterText(find.byType(TextField).first, 'Student');
      await tester.pump();
      await _tap(tester, _button('Save ticket type'));

      // Refund policy: shown once a type is paid.
      await _tap(tester, find.text('Refund policy'));
      await _tap(tester, find.text('24 hours'));
      await _tap(tester, _button('Done'));

      await _tap(tester, _button('Save and continue'));
      await _tap(tester, _button('Save and continue'));
      // The first type is added, the second fails; the event isn't published.
      _server.failOnNth['POST /api/events/ev1/ticket-types'] = 2;
      await _tap(tester, _button('Publish event'), rounds: 12);
      expect(find.text('The server is busy. Try again.'), findsOneWidget);
      expect(_server.count('POST', '/api/events/ev1/publish'), 0);

      await tester.pump(const Duration(seconds: 5));
      await _tap(tester, _button('Publish event'), rounds: 12);
      final posted = _server.bodies('POST', '/api/events/ev1/ticket-types').map((b) => b!['name']).toList();
      expect(posted, ['General Admission', 'Student', 'Student']);
      expect(_server.types.map((t) => t['name']), ['General Admission', 'Student']);
      expect(_server.count('POST', '/api/events/ev1/publish'), 1);
      expect(_server.bodies('PATCH', '/api/events/ev1').last!['refundPolicy'], '24h');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a 403 on a paid type opens seller setup for the host', (tester) async {
      _server.failing['POST /api/events/ev1/ticket-types'] = [
        (403, 'Set up your seller profile to sell paid tickets, so we can pay you.'),
      ];
      setBoardViewport(tester, height: 1400);
      final e = _hosted(types: const []);
      await tester.pumpWidget(_app(HostEventPage(editing: e, debugNow: _now, debugStep: 1)));
      await tester.pump();
      await _tap(tester, find.text('Paid tickets'));
      await tester.enterText(find.widgetWithText(TextField, '0.00'), '25');
      await tester.pump();
      await _tap(tester, _button('Save ticket type'));
      await _tap(tester, _button('Save and continue'));
      await _tap(tester, _button('Save and continue'));
      await _tap(tester, _button('Save changes'), rounds: 10);
      expect(find.text('Turn on selling first'), findsOneWidget);
      expect(find.byType(HostEventPage), findsOneWidget);
    });

    testWidgets('Manage event lists the real ticket types', (tester) async {
      setBoardViewport(tester, height: 1600);
      final e = _hosted(types: const [_ga, _vip, EventTicketType(id: 'x', name: 'Door', priceCents: 900, left: 0, sold: 5, quantity: 5)]);
      await tester.pumpWidget(_app(HostManagePage(event: e, debugEvent: e, debugNow: _now)));
      await tester.pump();
      expect(find.text('General Admission'), findsOneWidget);
      expect(find.text('0 of 100'), findsOneWidget);
      expect(find.text('3 of 20'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Sold out')).style!.color, StudioColors.light.alert);
    });
  });
}
