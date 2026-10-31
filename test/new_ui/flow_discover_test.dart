import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/feed_item.dart';
import 'package:studio3/screens/available_piece_detail_page.dart';
import 'package:studio3/screens/explore_page.dart';
import 'package:studio3/screens/reels_page.dart' show routeObserver;
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/utils/profile_navigation.dart';
import 'package:studio3/utils/slide_up_page_route.dart';
import 'package:studio3/widgets/explore/explore_browse.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Flow regression 19.2, sixth point (docs/new-ui/NEW_UI_EXECUTION_PLAN.md): Discover search,
/// chips and nearby sellers, in light and dark, through the real Explore page and its services
/// against a fake server and the phone's GPS. Signed in (search and Follow need an account).

Map<String, dynamic> _piece(String id, String title, String medium, {String author = 'kofi'}) => {
  'type': 'piece',
  'id': id,
  'title': title,
  'mediaUrl': '',
  'isForSale': true,
  'status': 'live',
  'listingState': 'available',
  'medium': medium,
  'author': {'username': author, 'name': author == 'amara' ? 'Amara Osei' : 'Kofi Studio'},
};

Map<String, dynamic> _scene(String id) => {
  'type': 'post',
  'id': id,
  'caption': 'In the studio $id',
  'mediaType': 'video',
  'mediaUrl': '',
  'mediaAspectRatio': '9:16',
  'author': {'username': 'kofi', 'name': 'Kofi Studio'},
};

Map<String, dynamic> _seller(String username, String name, double km) => {
  'username': username,
  'name': name,
  'distanceKm': km,
  'isFollowing': false,
};

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Map<String, String> query, String? auth})>[];
  var failFollow = 0;

  /// When set, the first page says there is more (cursor c2) and c2 brings three more pieces.
  var paged = false;

  Iterable<({String method, String path, Map<String, String> query, String? auth})> to(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    final query = options.uri.queryParameters;
    requests.add((method: options.method, path: path, query: query, auth: options.headers['Authorization'] as String?));
    Object json = {'success': true, 'data': {}};
    var status = 200;
    switch ('${options.method} $path') {
      case 'GET /api/feed/explore' when query['cursor'] == 'c2':
        json = {
          'success': true,
          'data': {
            'items': [for (var i = 8; i <= 10; i++) _piece('p$i', 'Later $i', 'Ink')],
            'nextCursor': null,
          },
        };
      case 'GET /api/feed/explore':
        json = {
          'success': true,
          'data': {
            'items': [
              _piece('p1', 'Bodies in Color', 'Painting', author: 'amara'),
              _piece('p2', 'Harmattan', 'Painting'),
              _piece('p3', 'Red Earth', 'Painting'),
              _piece('p4', 'Salt Road', 'Painting', author: 'amara'),
              _piece('p5', 'Lens One', 'Photography'),
              _piece('p6', 'Lens Two', 'Photography'),
              _piece('p7', 'Lens Three', 'Photography'),
              for (var i = 1; i <= 6; i++) _scene('s$i'),
            ],
            'nextCursor': paged ? 'c2' : null,
          },
        };
      case 'GET /api/users/nearby':
        json = {
          'success': true,
          'data': [
            _seller('kofi', 'Kofi Mensah', 1.2),
            _seller('ama', 'Ama Boateng', 2.4),
            _seller('esi', 'Esi Owusu', 3.1),
            _seller('yaw', 'Yaw Darko', 4.0),
            _seller('jordanlee', 'Jordan Lee', 0.1), // the viewer
            _seller('nana', 'Nana Adjei', 6.3),
          ],
        };
      case 'GET /api/conversations/search-users':
        final q = query['q'];
        if (q == 'boom') {
          status = 500;
          json = {'success': false, 'message': 'search is down'};
        } else {
          json = {
            'success': true,
            'data': [
              if (q == 'amara') {'username': 'amara', 'name': 'Amara Osei'},
            ],
          };
        }
      case 'POST /api/users/kofi/follow':
        if (failFollow > 0) {
          failFollow--;
          status = 500;
          json = {'success': false, 'message': 'down'};
        } else {
          json = {'success': true, 'data': {'following': true, 'requested': false}};
        }
      case 'DELETE /api/users/kofi/follow':
        json = {'success': true, 'data': {'following': false, 'requested': false}};
      default:
        status = 404;
        json = {'success': false, 'message': 'no route'};
    }
    return ResponseBody.fromString(
      jsonEncode(json),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Pushes extends NavigatorObserver {
  final routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => routes.add(route);
}

late _Fake _server;
late _Pushes _pushes;

// Cards carry the artist as "Kofi Studio", so "Kofi Mensah" is only the nearby tile.

/// The phone's GPS: [grant] answers the permission ask; Accra when granted.
var _gpsAsks = 0;
void _mockGps({required bool Function() grant}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/geolocator'),
    (call) async => switch (call.method) {
      'checkPermission' => grant() ? 2 : 0,
      'requestPermission' => () {
        _gpsAsks++;
        return grant() ? 2 : 0;
      }(),
      'isLocationServiceEnabled' => true,
      'getCurrentPosition' => {
        'latitude': 5.6037,
        'longitude': -0.187,
        'timestamp': 0,
        'accuracy': 5.0,
        'altitude': 0.0,
        'altitude_accuracy': 0.0,
        'heading': 0.0,
        'heading_accuracy': 0.0,
        'speed': 0.0,
        'speed_accuracy': 0.0,
      },
      _ => null,
    },
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 350));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

Widget _app({required bool dark}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  navigatorObservers: [routeObserver, _pushes],
  home: const ExplorePage(),
  routes: {
    '/profile': (context) {
      final args = parseProfileRouteArgs(ModalRoute.of(context)?.settings.arguments);
      return Scaffold(body: Text('profile @${args?.username}'));
    },
  },
);

/// The page's own (vertical) scroll.
final _page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

// The chip row scrolls sideways; a chip out of view is still there.
Finder _chip(String label) =>
    find.ancestor(of: find.text(label, skipOffstage: false), matching: find.byType(StudioChip, skipOffstage: false));
bool _chipOn(WidgetTester tester, String label) => tester.widget<StudioChip>(_chip(label)).selected;

/// What "Browse everything" shows, or null when it isn't there.
List<FeedItem>? _browse(WidgetTester tester) {
  final grid = find.byType(ExploreBrowseGrid, skipOffstage: false);
  return grid.evaluate().isEmpty ? null : tester.widget<ExploreBrowseGrid>(grid).items;
}

Finder _artistFollow(String name) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(ExploreArtistTile)),
  matching: find.byWidgetPredicate((w) => w is Text && (w.data == 'Follow' || w.data == 'Following')),
);

Future<void> _back(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '.',
    );
  });

  setUp(() {
    _server = _Fake();
    _pushes = _Pushes();
    _gpsAsks = 0;
    ApiClient.instance.debugUseAdapter(_server);
    AuthSession.instance.accessToken = 'token';
    AuthSession.instance.user = const AuthUser(
      username: 'jordanlee',
      name: 'Jordan Lee',
      email: 'jordan@email.com',
      onboardingComplete: true,
    );
  });
  tearDown(() {
    AuthSession.instance.accessToken = null;
    AuthSession.instance.user = null;
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('Discover ($theme): shelves, All / Pieces / Scenes, medium chips, nearby artists and Follow', (
      tester,
    ) async {
      setBoardViewport(tester);
      _mockGps(grant: () => true);
      await tester.pumpWidget(_app(dark: dark));
      await _settle(tester);

      // Loaded as the account; shelves from what came back.
      expect(_server.to('GET', '/api/feed/explore').single.auth, 'Bearer token');
      expect(find.text('Available now'), findsOneWidget);
      expect(find.text('Behind the work'), findsOneWidget);
      expect(_browse(tester), hasLength(13));

      // Nearby sellers: asked for where the phone is.
      final nearby = _server.to('GET', '/api/users/nearby').single;
      expect(nearby.query, {'lat': '5.6037', 'lng': '-0.187'});
      await tester.scrollUntilVisible(find.text('Artists to know'), 300, scrollable: _page);
      await tester.pump();
      expect(find.text('Kofi Mensah'), findsOneWidget);
      expect(find.text('1.2 km away'), findsOneWidget);
      // The viewer is in the row, with no Follow on their own tile.
      await tester.dragUntilVisible(find.text('Jordan Lee'), find.byType(ListView).last, const Offset(-200, 0));
      await tester.pump();
      expect(_artistFollow('Jordan Lee'), findsNothing);
      await tester.dragUntilVisible(find.text('Kofi Mensah'), find.byType(ListView).last, const Offset(200, 0));
      await tester.pump();

      // Follow: a failure says so and stays Follow; then Follow, then Following → Follow.
      _server.failFollow = 1;
      await _tap(tester, _artistFollow('Kofi Mensah'));
      expect(find.text('Could not update follow'), findsOneWidget);
      expect(tester.widget<Text>(_artistFollow('Kofi Mensah')).data, 'Follow');
      await tester.pump(const Duration(seconds: 3)); // the toast
      await _tap(tester, _artistFollow('Kofi Mensah'));
      expect(_server.to('POST', '/api/users/kofi/follow'), hasLength(2));
      expect(_server.to('POST', '/api/users/kofi/follow').last.auth, 'Bearer token');
      expect(tester.widget<Text>(_artistFollow('Kofi Mensah')).data, 'Following');
      await _tap(tester, _artistFollow('Kofi Mensah'));
      expect(_server.to('DELETE', '/api/users/kofi/follow'), hasLength(1));
      expect(tester.widget<Text>(_artistFollow('Kofi Mensah')).data, 'Follow');

      // An artist opens their profile.
      await _tap(tester, find.text('Ama Boateng'));
      expect(find.text('profile @ama'), findsOneWidget);
      await _back(tester);

      // Chips: All is on; Pieces and Scenes narrow the grid and the shelves.
      await tester.scrollUntilVisible(_chip('All'), -300, scrollable: _page);
      await tester.pump();
      expect(_chipOn(tester, 'All'), isTrue);
      await _tap(tester, _chip('Pieces'));
      expect(_chipOn(tester, 'Pieces'), isTrue);
      expect(_chipOn(tester, 'All'), isFalse);
      expect(_browse(tester)!.map((i) => i.id), ['p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7']);
      expect(find.text('Behind the work'), findsNothing);
      await _tap(tester, _chip('Scenes'));
      expect(_browse(tester)!.every((i) => i.type == FeedItemType.post), isTrue);
      expect(_browse(tester), hasLength(6));
      expect(find.text('Available now'), findsNothing);
      await _tap(tester, _chip('All'));
      expect(_browse(tester), hasLength(13));

      // Medium chips come from the pieces loaded, most common first; a second tap clears one.
      final labels = tester.widgetList<StudioChip>(find.byType(StudioChip, skipOffstage: false)).map((c) => c.label).toList();
      expect(labels.sublist(0, 5), ['All', 'Pieces', 'Scenes', 'Painting', 'Photography']);
      await _tap(tester, _chip('Photography'));
      expect(_browse(tester)!.map((i) => i.id), ['p5', 'p6', 'p7']);
      await _tap(tester, _chip('Pieces'));
      expect(_browse(tester)!.map((i) => i.id), ['p5', 'p6', 'p7'], reason: 'Pieces and a medium together');
      await _tap(tester, _chip('Scenes'));
      expect(_browse(tester), isNull);
      expect(find.text('Nothing to explore yet.'), findsOneWidget);
      await _tap(tester, _chip('All'));
      await _tap(tester, _chip('Photography'));
      expect(_chipOn(tester, 'Photography'), isFalse);
      expect(_browse(tester), hasLength(13));
      // Nothing above asked the server again: the chips filter what was loaded.
      expect(_server.to('GET', '/api/feed/explore'), hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11)); // the image cache's clean-up timer
    });

    testWidgets('Discover search ($theme): people and pieces, no match, a failed search, clearing', (tester) async {
      setBoardViewport(tester);
      _mockGps(grant: () => true);
      await tester.pumpWidget(_app(dark: dark));
      await _settle(tester);
      final field = find.byType(TextField);

      // People from the server (after the pause in typing) and pieces from the page.
      await tester.enterText(field, 'amara');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_server.to('GET', '/api/conversations/search-users'), isEmpty, reason: 'waits for typing to pause');
      await tester.pump(const Duration(milliseconds: 300));
      await _settle(tester);
      final search = _server.to('GET', '/api/conversations/search-users').single;
      expect(search.query, {'q': 'amara'});
      expect(search.auth, 'Bearer token');
      expect(find.text('People'), findsOneWidget);
      expect(find.text('@amara'), findsOneWidget);
      expect(find.text('Pieces'), findsWidgets);
      expect(find.text('Bodies in Color'), findsOneWidget);
      expect(find.text('Salt Road'), findsOneWidget);
      expect(find.text('Harmattan'), findsNothing);
      expect(find.text('Available now'), findsNothing, reason: 'search replaces the shelves');

      await _tap(tester, find.text('@amara'));
      expect(find.text('profile @amara'), findsOneWidget);
      await _back(tester);

      // A piece opens its page.
      await tester.tap(find.text('Salt Road'));
      await tester.pump();
      final opened = _pushes.routes.last;
      expect(opened, isA<SlideUpPageRoute<void>>());
      final page = (opened as SlideUpPageRoute<void>).page;
      expect(page, isA<AvailablePieceDetailPage>());
      expect((page as AvailablePieceDetailPage).item.id, 'p4');
      Navigator.of(tester.element(find.byType(ExplorePage, skipOffstage: false))).pop();
      await _settle(tester);

      // Pieces only, by title.
      await tester.enterText(field, 'lens');
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester);
      expect(find.text('People'), findsNothing);
      expect(find.text('Lens One'), findsOneWidget);
      expect(find.text('Lens Three'), findsOneWidget);

      // Nothing at all.
      await tester.enterText(field, 'zzz');
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester);
      expect(find.text('Nothing matches "zzz"'), findsOneWidget);

      // A failed search says so.
      await tester.enterText(field, 'boom');
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester);
      expect(find.textContaining('Search failed'), findsOneWidget);

      // Clearing brings the shelves back.
      await tester.enterText(field, '');
      await _settle(tester);
      expect(find.textContaining('Search failed'), findsNothing);
      expect(find.text('Available now'), findsOneWidget);
      expect(_browse(tester), hasLength(13));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
    });
  }

  testWidgets('scrolling to the end of Browse everything adds the next page, once', (tester) async {
    setBoardViewport(tester);
    _mockGps(grant: () => true);
    _server.paged = true;
    await tester.pumpWidget(_app(dark: false));
    await _settle(tester);
    expect(_browse(tester), hasLength(13));
    for (var i = 0; i < 3; i++) {
      await tester.fling(_page, const Offset(0, -4000), 3000);
      await _settle(tester);
    }
    final loads = _server.to('GET', '/api/feed/explore').toList();
    expect(loads.map((r) => r.query['cursor']), [null, 'c2']);
    expect(loads.last.auth, 'Bearer token');
    expect(_browse(tester)!.map((i) => i.id).skip(13), ['p8', 'p9', 'p10']);
    // The new pieces' medium joins the chips.
    expect(tester.widgetList<StudioChip>(find.byType(StudioChip, skipOffstage: false)).map((c) => c.label), contains('Ink'));
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('nearby sellers with location off: the prompt asks again, and allowing shows the artists', (
    tester,
  ) async {
    setBoardViewport(tester);
    var allowed = false;
    _mockGps(grant: () => allowed);
    await tester.pumpWidget(_app(dark: false));
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('Enable location to discover nearby sellers'), 300, scrollable: _page);
    expect(_server.to('GET', '/api/users/nearby'), isEmpty);
    expect(find.text('Artists to know'), findsNothing);
    expect(_gpsAsks, 1);

    allowed = true;
    await _tap(tester, find.text('Enable location to discover nearby sellers'));
    expect(_server.to('GET', '/api/users/nearby'), hasLength(1));
    expect(find.text('Enable location to discover nearby sellers'), findsNothing);
    await tester.scrollUntilVisible(find.text('Artists to know'), 300, scrollable: _page);
    expect(find.text('Kofi Mensah'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
  });
}
