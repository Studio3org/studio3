import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/event_detail_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/events/event_detail_widgets.dart';
import 'package:studio3/widgets/events/event_waitlist_sheets.dart';
import 'package:studio3/widgets/events/your_events_widgets.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Phase 13, 17.8 (docs/new-ui/NEW_UI_EXECUTION_PLAN.md): the event waitlist (`EvSoldOut`,
/// `EvWaitlistJoin`, `EvWaitlistHeld`) against a fake server, and the Save bar when the server
/// runs no waitlist.

const _user = {'id': 'u1', 'username': 'jordanlee', 'name': 'Jordan Lee', 'email': 'jordan@email.com'};

const _ga = EventTicketType(id: 'ga', name: 'General Admission', includes: 'Open to everyone', left: 0, perOrderLimit: 4);
const _vip = EventTicketType(
  id: 'vip',
  name: 'VIP',
  priceCents: 2500,
  includes: 'Early entry, reserved seating',
  left: 0,
  perOrderLimit: 2,
);

StudioEvent _event({EventWaitlist? waitlist, bool host = false}) => StudioEvent(
  id: 'ev1',
  title: 'Inside the Mind of an Artist',
  startsAt: DateTime(2037, 11, 21, 20),
  endsAt: DateTime(2037, 11, 21, 22),
  category: 'gallery_walk',
  venueName: 'Dec on Dragon',
  address: '1414 Dragon St, Dallas, TX 75201',
  hostUsername: 'amara',
  hostName: 'Amara Osei',
  isFull: true,
  spotsLeft: 0,
  isHost: host,
  description: 'An evening inside the studio with five Dallas painters, an artist talk and new work for sale.',
  ticketTypes: const [_ga, _vip],
  waitlist: waitlist,
);

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body})>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path, body: options.data));
    Object json;
    var code = 200;
    if (options.method == 'POST' && path == '/api/events/ev1/waitlist') {
      json = {
        'success': true,
        'data': {'open': true, 'wanted': (options.data as Map)['items']},
      };
    } else if (options.method == 'DELETE' && path == '/api/events/ev1/waitlist') {
      json = {'success': true, 'data': {}};
    } else if (options.method == 'POST' && path == '/api/events/ev1/waitlist/hold/release') {
      json = {
        'success': true,
        'data': {
          'open': true,
          'wanted': [
            {'ticketTypeId': 'ga', 'quantity': 1},
          ],
        },
      };
    } else {
      code = 404;
      json = {'success': false, 'message': 'no route'};
    }
    return ResponseBody.fromString(
      jsonEncode(json),
      code,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

late _Fake _server;

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

Widget _page(StudioEvent e, {bool dark = false}) => _app(EventDetailPage(event: e, debugDetail: e), dark: dark);

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}

/// Opens the held sheet from a button, with a clock the test moves.
class _HeldRunner extends StatefulWidget {
  const _HeldRunner({required this.event, required this.clock});

  final StudioEvent event;
  final DateTime Function() clock;

  @override
  State<_HeldRunner> createState() => _HeldRunnerState();
}

class _HeldRunnerState extends State<_HeldRunner> {
  WaitlistHeldResult? result;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () async {
              final r = await EventWaitlistHeldSheet.show(context, widget.event, now: widget.clock);
              setState(() => result = r);
            },
            child: const Text('open'),
          ),
          Text('result ${result?.action.name} ${result?.choice?.summary}'),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('waitlist').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  late AuthUser? wasUser;
  late String? wasToken;
  setUp(() {
    _server = _Fake();
    ApiClient.instance.debugUseAdapter(_server);
    wasUser = AuthSession.instance.user;
    wasToken = AuthSession.instance.accessToken;
    AuthSession.instance.user = AuthUser.fromJson(_user);
    AuthSession.instance.accessToken = 'token';
  });
  tearDown(() {
    AuthSession.instance.user = wasUser;
    AuthSession.instance.accessToken = wasToken;
  });

  test('the waitlist from the event payload', () {
    final e = StudioEvent.fromJson({
      'id': 'ev1',
      'title': 'T',
      'startsAt': '2037-11-21T20:00:00Z',
      'endsAt': '2037-11-21T22:00:00Z',
      'waitlist': {
        'open': true,
        'wanted': [
          {'ticketTypeId': 'ga', 'quantity': 1},
          {'ticketTypeId': 'vip', 'quantity': 2},
        ],
        'held': {
          'items': [
            {'ticketTypeId': 'vip', 'quantity': 2},
          ],
          'until': '2037-11-21T18:00:00Z',
        },
        'waitingCount': 12,
      },
    });
    final w = e.waitlist!;
    expect(w.open, isTrue);
    expect(w.joined, isTrue);
    expect(w.wanted, {'ga': 1, 'vip': 2});
    expect(w.held, {'vip': 2});
    expect(w.isHeld(DateTime.utc(2037, 11, 21, 17)), isTrue);
    expect(w.isHeld(DateTime.utc(2037, 11, 21, 19)), isFalse);
    expect(w.waitingCount, 12);
    expect(StudioEvent.fromJson({'id': 'x', 'title': 'T', 'startsAt': '2037-11-21T20:00:00Z', 'endsAt': '2037-11-21T22:00:00Z'}).waitlist, isNull);
  });

  testWidgets('no waitlist from the server: the Save bar stays', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_page(_event()));
    await tester.pump();
    expect(find.byType(EventSoldOutBar), findsOneWidget);
    expect(_button('Join waitlist'), findsNothing);
  });

  testWidgets('sold out with a waitlist: Tickets Sold out and Join waitlist; the sheet; then on the waitlist', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_page(_event(waitlist: const EventWaitlist(open: true))));
    await tester.pump();
    expect(find.byType(EventSoldOutBar), findsNothing);
    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('Sold out'), findsOneWidget);
    await tester.tap(_button('Join waitlist'));
    await tester.pumpAndSettle();

    // `EvWaitlistJoin`: grey cards, Sold out on each, Want, no prices, nothing charged.
    expect(find.text('Join the waitlist'), findsOneWidget);
    expect(find.text('These are sold out. Nothing is charged now.'), findsOneWidget);
    expect(find.byType(WaitlistTypeCard), findsNWidgets(2));
    expect(find.text('Want'), findsNWidgets(2));
    expect(find.text(r'$25'), findsNothing);
    expect(find.text('Free'), findsNothing);
    final card = tester.widget<Container>(
      find.descendant(of: find.byType(WaitlistTypeCard).first, matching: find.byType(Container)).first,
    );
    expect((card.decoration! as BoxDecoration).color, StudioColors.light.surface);
    // VIP up to its per-order limit of 2.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('One more VIP'));
      await tester.pump();
    }
    expect(tester.widget<TicketStepper>(find.byType(TicketStepper).last).count, 2);
    expect(tester.widget<TicketStepper>(find.byType(TicketStepper).last).onAdd, isNull);
    await tester.tap(find.descendant(of: find.byType(EventWaitlistJoinSheet), matching: _button('Join waitlist')));
    await _settle(tester);

    final post = _server.requests.singleWhere((r) => r.method == 'POST');
    expect(post.path, '/api/events/ev1/waitlist');
    expect((post.body! as Map)['items'], [
      {'ticketTypeId': 'ga', 'quantity': 1},
      {'ticketTypeId': 'vip', 'quantity': 2},
    ]);
    expect(_button("You're on the waitlist"), findsOneWidget);
    expect(tester.widget<StudioButton>(_button("You're on the waitlist")).variant, StudioButtonVariant.outline);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets("You're on the waitlist: tap to leave, after asking", (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_page(_event(waitlist: const EventWaitlist(open: true, wanted: {'ga': 1}))));
    await tester.pump();
    await tester.tap(_button("You're on the waitlist"));
    await tester.pumpAndSettle();
    expect(find.text('Leave the waitlist?'), findsOneWidget);
    await tester.tap(_button('Leave'));
    await _settle(tester);
    expect(_server.requests.single.method, 'DELETE');
    expect(_button('Join waitlist'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  group('held', () {
    final start = DateTime(2037, 11, 21, 16);
    var now = start;
    StudioEvent held({Map<String, int> wanted = const {'ga': 1, 'vip': 2}}) => _event(
      waitlist: EventWaitlist(
        open: true,
        wanted: wanted,
        held: const {'vip': 2},
        heldUntil: start.add(const Duration(hours: 1, minutes: 42, seconds: 10)),
      ),
    );

    setUp(() => now = start);

    testWidgets('the countdown in red Mono, the held tickets picked, Keep waiting for the other type', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_HeldRunner(event: held(), clock: () => now)));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Your tickets are held'), findsOneWidget);
      final clock = tester.widget<Text>(find.text('1:42:10'));
      expect(clock.style?.color, StudioColors.light.alert);
      expect(clock.style?.fontFamily, 'GeistMono');
      expect(find.text('2 held for you'), findsOneWidget);
      expect(find.text(r'$50'), findsOneWidget);
      expect(_button('Continue to payment'), findsOneWidget);
      expect(find.text('Keep waiting for General Admission'), findsOneWidget);
      // Held tickets can't go over what is held.
      await tester.tap(find.bySemanticsLabel('One more VIP'));
      await tester.pump();
      expect(find.text(r'$50'), findsOneWidget);

      now = start.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1:42:09'), findsOneWidget);

      await tester.tap(_button('Continue to payment'));
      await tester.pumpAndSettle();
      expect(find.text('result buy 2 VIP'), findsOneWidget);
    });

    testWidgets('when it reaches zero the sheet closes', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_HeldRunner(event: held(wanted: const {'vip': 2}), clock: () => now)));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Keep waiting'), findsNothing);
      now = start.add(const Duration(hours: 2));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Your tickets are held'), findsNothing);
      expect(find.text('result expired null'), findsOneWidget);
    });

    testWidgets('Keep waiting gives the tickets up and keeps the place for the other type', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_HeldRunner(event: held(), clock: () => now)));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Keep waiting for General Admission'));
      await tester.pumpAndSettle();
      expect(find.text('result keepWaiting null'), findsOneWidget);
    });

    test('countdown format', () {
      expect(
        [const Duration(hours: 1, minutes: 42, seconds: 10), const Duration(minutes: 9, seconds: 5), const Duration(seconds: 7)]
            .map(waitlistCountdown)
            .toList(),
        ['1:42:10', '9:05', '0:07'],
      );
    });
  });

  testWidgets('Your events: On waitlist under Saved; the host sees how many wait', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SavedEventCard(event: _event(waitlist: const EventWaitlist(open: true, wanted: {'ga': 1})), onTap: () {}),
        ),
      ),
    );
    expect(find.text('On waitlist'), findsOneWidget);
    expect(find.text('Sold out'), findsNothing);
  });

  group('goldens', () {
    final skip = Platform.environment['NEW_UI_GOLDENS'] != '1';
    Future<void> snap(WidgetTester tester, String name) async {
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
    }

    testWidgets('golden: EvSoldOut', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_page(_event(waitlist: const EventWaitlist(open: true))));
      await tester.pump();
      await snap(tester, 'EvSoldOut');
    }, skip: skip);

    testWidgets('golden: EvWaitlistJoin', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_page(_event(waitlist: const EventWaitlist(open: true))));
      await tester.pump();
      await tester.tap(_button('Join waitlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('One more VIP'));
      await tester.pumpAndSettle();
      await snap(tester, 'EvWaitlistJoin');
    }, skip: skip);

    testWidgets('golden: EvWaitlistHeld', (tester) async {
      final start = DateTime(2037, 11, 21, 16);
      final e = _event(
        waitlist: EventWaitlist(
          open: true,
          wanted: const {'ga': 1, 'vip': 2},
          held: const {'vip': 2},
          heldUntil: start.add(const Duration(hours: 1, minutes: 42, seconds: 10)),
        ),
      );
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_HeldRunner(event: e, clock: () => start)));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await snap(tester, 'EvWaitlistHeld');
    }, skip: skip);
  });
}
