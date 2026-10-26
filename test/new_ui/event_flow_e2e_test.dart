import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/post_image_transform.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/event_confirmed_page.dart';
import 'package:studio3/screens/event_detail_page.dart';
import 'package:studio3/screens/event_page.dart';
import 'package:studio3/screens/host/host_cancel_page.dart';
import 'package:studio3/screens/host/host_event_page.dart';
import 'package:studio3/screens/host/host_guest_list_page.dart';
import 'package:studio3/screens/host/host_live_page.dart';
import 'package:studio3/screens/host/host_manage_page.dart';
import 'package:studio3/screens/my_events_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/location_search_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/utils/crop_cover_math.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// The whole event flow end to end through the real screens and services, with a fake server
/// in place of the network that records every request (docs/new-ui/NEW_UI_EXECUTION_PLAN.md,
/// sections 17.1 and 17.2):
///
/// - a guest: Events tab → the event → Get tickets → Reserve → You're going → Your events;
/// - a host: Details (cover, title, place, date, category, Selling) → Tickets (a cap) →
///   Lineup (a featured artist, two pieces, one for sale) → Review → Publish → live →
///   Manage → Guest list → Cancel with a message; plus a publish that fails half way and is
///   tried again, and leaving with unsaved changes.
final _now = DateTime(2037, 11, 18, 10);

Map<String, dynamic> _guestEvent({required bool going, required int count}) => {
  'id': 'ev1',
  'title': 'Inside the Mind of an Artist',
  'startsAt': '2037-11-21T20:00:00',
  'endsAt': '2037-11-21T22:00:00',
  'status': 'published',
  'category': 'gallery_walk',
  'venueName': 'Dec on Dragon',
  'address': '1414 Dragon St, Dallas, TX 75201',
  'hostUsername': 'amara',
  'hostName': 'Amara Osei',
  'capacity': 20,
  'rsvpCount': count,
  'spotsLeft': 20 - count,
  'viewerIsGoing': going,
  'description': 'An evening inside the studio with five Dallas painters.',
};

class _FakeServer implements HttpClientAdapter {
  final requests = <({String method, String path, Map<String, dynamic>? body})>[];

  /// `METHOD path` → how many more times it answers 500.
  final failing = <String, int>{};

  // The guest's side.
  var going = false;
  var count = 4;

  // The host's side.
  Map<String, dynamic>? hosted;
  final lineup = <Map<String, dynamic>>[];

  Iterable<Map<String, dynamic>?> bodies(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).map((r) => r.body);

  int count0(String method, String path) => requests.where((r) => r.method == method && r.path == path).length;

  Map<String, dynamic> _hostedNow() => {...hosted!, 'lineup': lineup};

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : null;
    final key = '${options.method} $path';
    requests.add((method: options.method, path: path, body: body));
    final fails = failing[key] ?? 0;
    if (fails > 0) {
      failing[key] = fails - 1;
      return _json({'success': false, 'message': 'The server is busy. Try again.'}, 500);
    }
    // Location search (Nominatim) shares this adapter.
    if (path == '/search') {
      return _raw([
        {
          'place_id': 1,
          'name': 'Dec on Dragon',
          'display_name': '1414 Dragon St, Dallas, TX 75201, United States',
          'lat': '32.79',
          'lon': '-96.81',
        },
      ]);
    }
    Object? data;
    switch (key) {
      // --- the guest ---
      case 'GET /api/events/browse':
        data = {
          'today': [],
          'following': [],
          'upcoming': [_guestEvent(going: going, count: count)],
          'categories': [],
        };
      case 'GET /api/events/ev1':
        data = _guestEvent(going: going, count: count);
      case 'POST /api/events/ev1/rsvp':
        final wants = body!['going'] as bool;
        if (wants != going) count += wants ? 1 : -1;
        going = wants;
        data = {'going': going, 'rsvpCount': count, 'spotsLeft': 20 - count, 'isFull': false};
      case 'GET /api/events':
        final scope = options.uri.queryParameters['scope'];
        data = {
          'events': [
            if (scope == 'going' && going) _guestEvent(going: true, count: count),
            if (scope == 'hosting' && hosted != null) _hostedNow(),
          ],
        };
      // --- the host ---
      case 'POST /api/media/presign':
        data = {'url': 'https://cdn.test/sarah/event/1', 'devMode': true};
      case 'POST /api/events':
        hosted = {...body!, 'id': 'new1', 'status': 'draft', 'isHost': true, 'rsvpCount': 0, 'saveCount': 0};
        data = _hostedNow();
      case 'PATCH /api/events/new1':
        hosted = {...hosted!, ...body!};
        data = _hostedNow();
      case 'PUT /api/events/new1/people':
        data = _hostedNow();
      case 'POST /api/events/new1/pieces':
        lineup.add({...body!, 'id': 'l${lineup.length + 1}'});
        data = lineup.last;
      case 'POST /api/events/new1/publish':
        hosted = {...hosted!, 'status': 'published'};
        data = _hostedNow();
      case 'GET /api/events/new1':
        data = {...?hosted, 'rsvpCount': 2, 'lineup': lineup};
      case 'GET /api/events/new1/attendees':
        data = {
          'attendees': [
            {'username': 'jordan', 'name': 'Jordan Lee'},
            {'username': 'kai', 'name': 'Kai Moreno'},
          ],
        };
      case 'POST /api/events/new1/cancel':
        hosted = {...hosted!, 'status': 'cancelled', 'cancellationReason': body?['reason']};
        data = _hostedNow();
      case 'GET /api/users/sarah/following':
        data = {
          'items': [
            {'username': 'maria', 'name': 'Maria Bruno'},
          ],
        };
      case 'GET /api/users/maria/pieces':
        data = [
          {'id': 'pm1', 'title': 'Quiet Hours', 'mediaUrl': ''},
        ];
      case 'GET /api/users/sarah/pieces':
        data = [
          {
            'id': 'ps1',
            'title': 'Bodies in Color',
            'mediaUrl': '',
            'isForSale': true,
            'priceCents': 350000,
            'listingState': 'available',
          },
        ];
      default:
        return _json({'success': false, 'message': 'no route $key'}, 404);
    }
    return _json({'success': true, 'data': data}, 200);
  }

  ResponseBody _json(Object json, int status) => ResponseBody.fromString(
    jsonEncode(json),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  ResponseBody _raw(Object json) => _json(json, 200);

  @override
  void close({bool force = false}) {}
}

late _FakeServer _server;
late String _cover;

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

/// Lets the fake server, file reads and image encoding finish (they need the real event loop).
Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump();
  }
  // Routes and sheets finish their transitions over a few frames.
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 350));
  }
}

/// Taps and lets whatever it starts run.
Future<void> _tap(WidgetTester tester, Finder finder, {int rounds = 6}) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester, rounds: rounds);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final dir = Directory.systemTemp.createTempSync('event_e2e');
    _cover = (File('${dir.path}/cover.png')
          ..writeAsBytesSync(img.encodePng(img.Image(width: 300, height: 400)..clear(img.ColorRgb8(90, 60, 40)))))
        .path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
  });

  late AuthUser? wasUser;
  late String? wasToken;
  setUp(() {
    _server = _FakeServer();
    ApiClient.instance.debugUseAdapter(_server);
    LocationSearchService.debugUseAdapter(_server);
    wasUser = AuthSession.instance.user;
    wasToken = AuthSession.instance.accessToken;
    AuthSession.instance.user = const AuthUser(username: 'sarah', name: 'Sarah Osmei', email: 's@example.test');
    AuthSession.instance.accessToken = 'token';
  });
  tearDown(() {
    AuthSession.instance.user = wasUser;
    AuthSession.instance.accessToken = wasToken;
  });

  testWidgets('guest: Events tab → event → Get tickets → Reserve → You\'re going → Your events', (tester) async {
    setBoardViewport(tester, height: 900);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: EventPage(debugNow: _now)),
    );
    await _settle(tester);
    expect(_server.count0('GET', '/api/events/browse'), 1);
    await _tap(tester, find.text('This week').first);

    // The event on the tab opens its page, which loads the full event.
    await _tap(tester, find.text('Inside the Mind of an Artist').first);
    expect(find.byType(EventDetailPage), findsOneWidget);
    expect(_server.count0('GET', '/api/events/ev1'), greaterThanOrEqualTo(1));
    expect(find.text('Free'), findsOneWidget);

    // Get tickets → the free ticket → Reserve.
    await _tap(tester, _button('Get tickets'));
    expect(_button('Reserve'), findsOneWidget);
    await _tap(tester, _button('Reserve'), rounds: 10);
    expect(_server.bodies('POST', '/api/events/ev1/rsvp').single, {'going': true});

    // You're going.
    expect(find.byType(EventConfirmedPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(_button('Your events'), findsOneWidget);
    await _tap(tester, _button('Your events'), rounds: 8);

    // Your events lists it under Upcoming.
    expect(find.byType(MyEventsPage), findsOneWidget);
    expect(find.text('Inside the Mind of an Artist'), findsOneWidget);
    expect(
      _server.requests.where((r) => r.path == '/api/events').length,
      greaterThanOrEqualTo(3), // going, saved, hosting
    );
    await tester.pump(const Duration(seconds: 11)); // let toasts and the image cache's cleanup timer finish
  });

  testWidgets("guest: Can't make it gives the place back", (tester) async {
    _server.going = true;
    _server.count = 5;
    setBoardViewport(tester, height: 900);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => openEventDetail(context, StudioEvent.fromJson(_guestEvent(going: true, count: 5))),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await _tap(tester, find.text('open'));
    expect(_button("You're going"), findsOneWidget);
    await _tap(tester, _button("You're going"));
    await _tap(tester, find.text("Can't make it"), rounds: 8);
    expect(_server.bodies('POST', '/api/events/ev1/rsvp').single, {'going': false});
    expect(find.text('Your place is cancelled'), findsOneWidget);
    expect(_button('Get tickets'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11)); // let toasts and the image cache's cleanup timer finish
  });

  testWidgets('host: create, publish, manage, guest list, cancel', (tester) async {
    setBoardViewport(tester, height: 1400);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HostEventPage(
          debugNow: _now,
          debugFlyer: (path: _cover, transform: PostImageTransform(aspectRatio: CropAspectRatio.ratio3x4)),
        ),
      ),
    );
    await tester.pump();

    // --- Details: Publish waits for every required field; each shows the red dot until filled.
    expect(tester.widget<StudioButton>(_button('Save and continue')).onPressed, isNull);
    expect(find.byType(StudioRequiredDot), findsNWidgets(4)); // title, location, date, category
    await tester.enterText(find.byType(TextField).at(0), 'Open Studio Night');
    await tester.enterText(find.byType(TextField).at(1), 'New work, an artist talk and drinks.');
    await tester.pump();

    // Location: the real search sheet against the fake Nominatim, worded for a venue.
    await _tap(tester, find.text('Location'));
    expect(find.text('Guests see the venue and its address on the event page.'), findsOneWidget);
    expect(find.textContaining('Only the city shows on your piece'), findsNothing);
    await tester.enterText(find.byType(TextField).last, 'Dragon St');
    await tester.pump(const Duration(milliseconds: 450));
    await _settle(tester);
    await _tap(tester, find.text('Dec on Dragon').last);
    await _tap(tester, _button('Done'));
    expect(find.text('Dec on Dragon'), findsOneWidget);

    // Date: Saturday the 21st, 7 to 9 PM by default.
    await _tap(tester, find.text('Date and time'));
    await _tap(tester, find.bySemanticsLabel('Sat, Nov 21'));
    await _tap(tester, _button('Done'));
    expect(find.textContaining('Sat, Nov 21 · 7:00 PM'), findsOneWidget);

    // Category and Event art.
    await _tap(tester, find.text('Category'));
    await _tap(tester, find.text('Gallery walk'));
    await _tap(tester, _button('Done'));
    await _tap(tester, find.text('Event art'));
    await _tap(tester, find.text('Selling'));
    await _tap(tester, _button('Done'));
    expect(find.text('Delivery'), findsOneWidget);

    expect(tester.widget<StudioButton>(_button('Save and continue')).onPressed, isNotNull);
    expect(find.byType(StudioRequiredDot), findsNothing);
    await _tap(tester, _button('Save and continue'));

    // --- Tickets: cap it at 40.
    expect(find.text('General Admission'), findsOneWidget);
    await _tap(tester, find.text('Edit'));
    await _tap(tester, find.byType(StudioSwitch));
    await tester.enterText(find.byType(TextField).last, '40');
    await tester.pump();
    await _tap(tester, _button('Save ticket type'));
    expect(find.text('Free · 40 available'), findsOneWidget);
    await _tap(tester, _button('Save and continue'));

    // --- Lineup: a featured artist from the people you follow.
    await _tap(tester, find.bySemanticsLabel('Add a featured artist'), rounds: 8);
    await _tap(tester, find.text('Maria Bruno'));
    expect(find.text('Maria'), findsOneWidget);

    // Two pieces: Maria's and the host's own (already for sale on its own).
    await _tap(tester, find.text('+ Tag a piece'), rounds: 10);
    expect(find.text('Your pieces'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Quiet Hours'));
    await _tap(tester, find.bySemanticsLabel('Bodies in Color'));
    expect(find.text('2 selected'), findsOneWidget);
    await _tap(tester, find.text('Done'));

    // Only the host's own piece can go on sale; Maria's is shown.
    expect(find.text('Only Maria Bruno can sell this piece.'), findsOneWidget);
    final forSale = find.byWidgetPredicate((w) => w is StudioChip && w.label == 'For sale');
    expect(forSale, findsOneWidget);
    await _tap(tester, forSale);
    // It is listed on its own already, so the host is asked first (HostConflict).
    expect(find.text('This will end its current listing'), findsOneWidget);
    await _tap(tester, _button('Continue'));
    expect(find.text(r'$3,500'), findsOneWidget);
    await _tap(tester, _button('Save and continue'));

    // --- Review → Publish.
    expect(find.text('Open Studio Night'), findsOneWidget);
    expect(find.text('General Admission · Free · 40 available'), findsOneWidget);
    await _tap(tester, _button('Publish event'), rounds: 14);

    // The cover was framed and uploaded, then the event made, people set, pieces added, published.
    expect(_server.count0('POST', '/api/media/presign'), 1);
    final created = _server.bodies('POST', '/api/events').single!;
    expect(created['title'], 'Open Studio Night');
    expect(created['coverMediaUrl'], 'https://cdn.test/sarah/event/1');
    expect(created['venueName'], 'Dec on Dragon');
    expect(created['category'], 'gallery_walk');
    expect(created['capacity'], 40);
    expect(DateTime.parse(created['startsAt'] as String).toLocal(), DateTime(2037, 11, 21, 19));
    expect(_server.bodies('PUT', '/api/events/new1/people').single, {
      'cohostUsernames': <String>[],
      'artistUsernames': ['maria'],
    });
    final pieces = _server.bodies('POST', '/api/events/new1/pieces').toList();
    expect(pieces.map((p) => (p!['pieceId'], p['mode'], p['priceCents'])).toSet(), {
      ('pm1', 'featured', null),
      ('ps1', 'sale', 350000),
    });
    expect(_server.count0('POST', '/api/events/new1/publish'), 1);

    // --- Live.
    expect(find.byType(HostLivePage), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Your event is live'), findsOneWidget);
    await _tap(tester, _button('Manage event'), rounds: 8);

    // --- Manage: the numbers come from the server.
    expect(find.byType(HostManagePage), findsOneWidget);
    expect(find.text('2 of 40'), findsWidgets);
    await _tap(tester, _button('Guest list'), rounds: 8);
    expect(find.byType(HostGuestListPage), findsOneWidget);
    expect(find.text('2 going'), findsOneWidget);
    expect(find.text('Jordan Lee'), findsOneWidget);
    await tester.pageBack();
    await _settle(tester);

    // --- Cancel with a message.
    await _tap(tester, find.text('Cancel event'));
    expect(find.byType(HostCancelPage), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'The space flooded. Sorry, everyone.');
    await tester.pump();
    await _tap(tester, _button('Cancel event and tell guests'), rounds: 10);
    expect(_server.bodies('POST', '/api/events/new1/cancel').single, {'reason': 'The space flooded. Sorry, everyone.'});
    expect(find.byType(HostManagePage), findsOneWidget);
    expect(find.textContaining('This event was cancelled.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11)); // let toasts and the image cache's cleanup timer finish
  });

  testWidgets('host: a publish that fails half way is tried again without doubling anything', (tester) async {
    setBoardViewport(tester, height: 1400);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HostEventPage(
          debugNow: _now,
          debugFlyer: (path: _cover, transform: PostImageTransform(aspectRatio: CropAspectRatio.ratio3x4)),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), 'Open Studio Night');
    await _tap(tester, find.text('Location'));
    await tester.enterText(find.byType(TextField).last, 'Dragon St');
    await tester.pump(const Duration(milliseconds: 450));
    await _settle(tester);
    await _tap(tester, find.text('Dec on Dragon').last);
    await _tap(tester, _button('Done'));
    await _tap(tester, find.text('Date and time'));
    await _tap(tester, find.bySemanticsLabel('Sat, Nov 21'));
    await _tap(tester, _button('Done'));
    await _tap(tester, find.text('Category'));
    await _tap(tester, find.text('Gallery walk'));
    await _tap(tester, _button('Done'));
    for (var i = 0; i < 3; i++) {
      await _tap(tester, _button('Save and continue'));
    }

    // The event is made, then publishing fails.
    _server.failing['POST /api/events/new1/publish'] = 1;
    await _tap(tester, _button('Publish event'), rounds: 14);
    expect(find.text('The server is busy. Try again.'), findsOneWidget);
    expect(find.byType(HostLivePage), findsNothing);

    // Again: the same event is updated and published; no second event, no second upload.
    await tester.pump(const Duration(seconds: 4));
    await _tap(tester, _button('Publish event'), rounds: 14);
    expect(_server.count0('POST', '/api/events'), 1);
    expect(_server.count0('PATCH', '/api/events/new1'), 1);
    expect(_server.count0('POST', '/api/media/presign'), 1);
    expect(_server.count0('POST', '/api/events/new1/publish'), 2);
    expect(find.byType(HostLivePage), findsOneWidget);
    await tester.pump(const Duration(seconds: 11)); // let toasts and the image cache's cleanup timer finish
  });

  testWidgets('host: leaving with unsaved changes asks first', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => HostEventPage.open(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await _tap(tester, find.text('open'));

    // Nothing typed: back just leaves.
    await _tap(tester, find.byTooltip('Back'));
    expect(find.byType(HostEventPage), findsNothing);

    await _tap(tester, find.text('open'));
    await tester.enterText(find.byType(TextField).first, 'Open Studio Night');
    await tester.pump();
    await _tap(tester, find.byTooltip('Back'));
    expect(find.text('Discard this event?'), findsOneWidget);
    await _tap(tester, find.text('Keep editing'));
    expect(find.byType(HostEventPage), findsOneWidget);
    expect(find.text('Open Studio Night'), findsOneWidget);

    await _tap(tester, find.byTooltip('Back'));
    await _tap(tester, find.text('Discard'));
    expect(find.byType(HostEventPage), findsNothing);
    await tester.pump(const Duration(seconds: 11)); // let toasts and the image cache's cleanup timer finish
  });

  testWidgets('host: the date sheet will not take a start that has passed', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: HostEventPage(debugNow: DateTime(2037, 11, 18, 20, 30))),
    );
    await tester.pump();
    await _tap(tester, find.text('Date and time'));
    // Today at 7 PM is already gone at 8:30 PM.
    await _tap(tester, find.bySemanticsLabel('Wed, Nov 18'));
    expect(find.text('That start time has passed. Pick a later one.'), findsOneWidget);
    expect(tester.widget<StudioButton>(_button('Done')).onPressed, isNull);
    await _tap(tester, find.bySemanticsLabel('Thu, Nov 19'));
    expect(tester.widget<StudioButton>(_button('Done')).onPressed, isNotNull);
    await tester.pump(const Duration(seconds: 11)); // let toasts and the image cache's cleanup timer finish
  });
}
