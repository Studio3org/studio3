import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/screens/available_piece_detail_page.dart';
import 'package:studio3/screens/conversation_thread_page.dart';
import 'package:studio3/screens/event_detail_page.dart';
import 'package:studio3/screens/piece_detail_page.dart';
import 'package:studio3/screens/profile_page.dart';
import 'package:studio3/screens/profile/profile_all_series_page.dart';
import 'package:studio3/screens/profile/widgets/profile_tabs.dart';
import 'package:studio3/screens/profile/widgets/profile_upcoming_show.dart';
import 'package:studio3/screens/series_view_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/cache_service.dart';
import 'package:studio3/services/chat_socket_service.dart';
import 'package:studio3/services/engagement_store.dart';
import 'package:studio3/theme/app_theme.dart';

import 'golden_harness.dart';

/// Flow regression 19.2, profiles: own, other, private (docs/new-ui/NEW_UI_EXECUTION_PLAN.md),
/// in light and dark: the real profile page against a fake server, signed in as jordanlee.

Map<String, dynamic> _piece(String id, String title, String author, {bool forSale = false}) => {
  'id': id,
  'title': title,
  'status': 'live',
  'isForSale': forSale,
  'priceCents': forSale ? 350000 : null,
  'listingState': forSale ? 'available' : null,
  'mediaUrl': '',
  'author': {'username': author, 'name': author},
};

/// Amara's show in five days (BACKEND_CHANGES B27).
Map<String, dynamic> _show() {
  final starts = DateTime.now().add(const Duration(days: 5));
  return {
    'id': 'ev1',
    'title': 'Bodies in Color: the show',
    'status': 'published',
    'startsAt': starts.toUtc().toIso8601String(),
    'endsAt': starts.add(const Duration(hours: 3)).toUtc().toIso8601String(),
    'venueName': 'Dec on Dragon',
    'hostUsername': 'amara',
    'hostName': 'Amara Osei',
    'capacity': 20,
    'rsvpCount': 4,
    'spotsLeft': 16,
  };
}

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path})>[];

  /// Whether Amara's profile has an Upcoming show.
  var amaraShow = false;

  /// Whether your own account sells (the Insights chart on the cover).
  var meSeller = false;

  Iterable<({String method, String path})> to(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  Iterable<({String method, String path})> under(String prefix) =>
      requests.where((r) => r.path.startsWith(prefix));

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path));
    Object json = {'success': true, 'data': {}};
    switch ('${options.method} $path') {
      // Your own account.
      case 'GET /api/user/me':
        json = {
          'success': true,
          'data': {
            'username': 'jordanlee',
            'name': 'Jordan Lee',
            'bio': 'Painter in Dallas.',
            'profileVisibility': 'public',
            'followersCount': 12,
            'followingCount': 30,
            'piecesCount': 1,
            'sellerEnabled': meSeller,
            'profileMediums': ['Painting', 'Mixed media'],
          },
        };
      case 'GET /api/user/me/seller/analytics':
        json = {'success': true, 'data': {'savesCount': 412, 'likesCount': 90, 'inquiriesCount': 7, 'salesCount': 3}};
      case 'GET /api/users/jordanlee/pieces':
        json = {'success': true, 'data': [_piece('j1', 'Morning Light', 'jordanlee')]};
      // Someone public.
      case 'GET /api/user/amara':
        json = {
          'success': true,
          'data': {
            'username': 'amara',
            'name': 'Amara Osei',
            'bio': 'Oil on canvas.',
            'profileVisibility': 'public',
            'followersCount': 120,
            'followingCount': 8,
            'piecesCount': 1,
            'isFollowing': false,
            'upcomingEvent': amaraShow ? _show() : null,
          },
        };
      case 'GET /api/events/ev1':
        json = {'success': true, 'data': _show()};
      // A collector with no pieces, and what they bought (BACKEND_CHANGES B37).
      case 'GET /api/user/tomi':
        json = {
          'success': true,
          'data': {
            'username': 'tomi',
            'name': 'Tomi Adeyemi',
            'role': 'collector',
            'profileVisibility': 'public',
            'followersCount': 3,
            'followingCount': 40,
            'piecesCount': 0,
            'collectedCount': 2,
            'artistsCount': 2,
            'savesCount': 18,
          },
        };
      case 'GET /api/users/tomi/collection':
        json = {
          'success': true,
          'data': [
            {
              'id': 'c1',
              'title': 'Night Walks',
              'status': 'sold',
              'isForSale': false,
              'mediaUrl': '',
              'author': {'username': 'amara', 'name': 'Amara Osei'},
            },
            {
              'id': 'c2',
              'title': 'Harbour',
              'status': 'sold',
              'isForSale': false,
              'mediaUrl': '',
              'author': {'username': 'cedric', 'name': 'Cedric Okafor'},
            },
          ],
        };
      case 'GET /api/pieces/c1':
        json = {
          'success': true,
          'data': {
            'id': 'c1',
            'title': 'Night Walks',
            'status': 'sold',
            'isForSale': false,
            'mediaUrl': '',
            'author': {'username': 'amara', 'name': 'Amara Osei'},
          },
        };
      case 'GET /api/users/amara/series':
        json = {
          'success': true,
          'data': [
            {'id': 's1', 'name': 'Night Walks', 'pieceCount': 8},
            {'id': 's2', 'name': 'Harbour Days', 'pieceCount': 3},
          ],
        };
      case 'GET /api/users/amara/pieces':
        json = {'success': true, 'data': [_piece('a1', 'Bodies in Color', 'amara', forSale: true)]};
      case 'GET /api/pieces/a1':
        json = {'success': true, 'data': _piece('a1', 'Bodies in Color', 'amara', forSale: true)};
      case 'POST /api/users/amara/follow':
        json = {'success': true, 'data': {'following': true, 'requested': false}};
      case 'DELETE /api/users/amara/follow':
        json = {'success': true, 'data': {'following': false, 'requested': false}};
      // Someone private you don't follow: the header only (no counts).
      case 'GET /api/user/esi':
        json = {
          'success': true,
          'data': {'username': 'esi', 'name': 'Esi Owusu', 'profileVisibility': 'private'},
        };
      case 'POST /api/users/esi/follow':
        json = {'success': true, 'data': {'following': false, 'requested': true}};
      case 'DELETE /api/users/esi/follow':
        json = {'success': true, 'data': {'following': false, 'requested': false}};
      // Someone private, once the server sends the rest of the header (BACKEND_CHANGES B36).
      case 'GET /api/user/kofi':
        json = {
          'success': true,
          'data': {
            'username': 'kofi',
            'name': 'Kofi Mensah',
            'profileVisibility': 'private',
            'bio': 'Collecting work from Dallas artists.',
            'followingCount': 14,
            'collectedCount': 6,
            'artistsCount': 4,
            'savesCount': 32,
            'role': 'collector',
            'messagePermission': 'everyone',
          },
        };
      default:
        if (options.method == 'GET') {
          json = {
            'success': true,
            'data': {'items': <Object>[], 'nextCursor': null},
          };
        }
    }
    return ResponseBody.fromString(
      jsonEncode(json),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

late _Fake _server;

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
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first, warnIfMissed: false);
  await _settle(tester);
}

/// A header action (Edit profile, Share, Message, Follow / Following / Requested) by its word.
Finder _button(String label) => find.text(label);

/// The route under the profile, so a pushed profile has somewhere to go back to.
Widget _app(Widget page, {required bool dark}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  routes: {
    '/edit-profile': (_) => const Scaffold(body: Text('Edit profile page')),
    '/profile-settings': (_) => const Scaffold(body: Text('Settings page')),
  },
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester, Widget page, {required bool dark}) async {
  await tester.pumpWidget(_app(page, dark: dark));
  await tester.tap(find.text('open'));
  await _settle(tester);
}

/// This file's own folder for the app's files (created once): test files run side by side and
/// must not share the cache.
final _files = Directory.systemTemp.createTempSync('studio3_flow_profiles');

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => _files.path,
    );
  });

  setUp(() async {
    _server = _Fake();
    ApiClient.instance.debugUseAdapter(_server);
    await CacheService.instance.clearAll();
    AuthSession.instance.accessToken = 'token';
    AuthSession.instance.user = const AuthUser(
      username: 'jordanlee',
      name: 'Jordan Lee',
      email: 'jordan@email.com',
      onboardingComplete: true,
    );
  });
  tearDown(() async {
    ChatSocketService.instance.disconnect();
    AuthSession.instance.accessToken = null;
    AuthSession.instance.user = null;
    EngagementStore.instance.clear();
    await CacheService.instance.clearAll();
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('own profile ($theme): your name, bio and counts, your pieces, Edit profile and Settings', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1200);
      await _open(tester, const ProfilePage(), dark: dark);

      expect(_server.to('GET', '/api/user/me'), isNotEmpty);
      expect(find.text('Jordan Lee'), findsWidgets);
      expect(find.text('Painter in Dallas.'), findsOneWidget);
      // Pieces is the board's grid for everyone: the 3:4 picture with its title under it.
      expect(find.text('Morning Light'), findsOneWidget);
      expect(_server.to('GET', '/api/users/jordanlee/pieces'), isNotEmpty);
      // Your own: Edit profile and Share, no Follow or Message.
      expect(_button('Edit profile'), findsOneWidget);
      expect(_button('Follow'), findsNothing);
      expect(_button('Message'), findsNothing);
      await _tap(tester, _button('Edit profile'));
      expect(find.text('Edit profile page'), findsOneWidget);
      Navigator.of(tester.element(find.text('Edit profile page'))).pop();
      await _settle(tester);
      // The cover's gear (`ProfileOwn`, in place of More) opens Settings; no Insights chart
      // for someone who doesn't sell.
      expect(find.bySemanticsLabel('More options'), findsNothing);
      expect(find.bySemanticsLabel('Insights'), findsNothing);
      await _tap(tester, find.bySemanticsLabel('Settings'));
      expect(find.text('Settings page'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('your own seller profile ($theme): the chart left of the gear opens Insights', (tester) async {
      _server.meSeller = true;
      setBoardViewport(tester, height: 1200);
      await _open(tester, const ProfilePage(), dark: dark);

      // `ProfileSeller`: the mediums line under the username (B31).
      expect(find.text('Painting · Mixed media'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Painting · Mixed media')).dy,
        greaterThan(tester.getTopLeft(find.text('@jordanlee')).dy),
      );

      final gear = tester.getRect(find.bySemanticsLabel('Settings'));
      final chart = tester.getRect(find.bySemanticsLabel('Insights'));
      expect(gear.size, const Size(44, 44));
      expect(chart.size, const Size(44, 44));
      expect(gear.right, 390 - 8);
      expect(chart.right, 390 - 52);
      expect(chart.top, gear.top);

      await _tap(tester, find.bySemanticsLabel('Insights'));
      expect(_server.to('GET', '/api/user/me/seller/analytics'), hasLength(1));
      expect(find.text('Your insights'), findsOneWidget);
      expect(find.text('412'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('someone else ($theme): their profile and pieces, Follow / Following, Message, a piece opens', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1200);
      await _open(tester, const ProfilePage(username: 'amara'), dark: dark);

      expect(_server.to('GET', '/api/user/amara'), isNotEmpty);
      expect(find.text('Amara Osei'), findsWidgets);
      expect(find.text('Oil on canvas.'), findsOneWidget);
      expect(_server.to('GET', '/api/users/amara/pieces'), isNotEmpty);
      expect(_button('Edit profile'), findsNothing);

      // Follow, then unfollow.
      await _tap(tester, _button('Follow'));
      expect(_server.to('POST', '/api/users/amara/follow'), hasLength(1));
      expect(_button('Following'), findsOneWidget);
      await _tap(tester, _button('Following'));
      expect(_server.to('DELETE', '/api/users/amara/follow'), hasLength(1));
      expect(_button('Follow'), findsOneWidget);

      // A piece in the grid opens its page (Bodies in Color, for sale).
      await _tap(tester, find.text('Bodies in Color'));
      expect(find.byType(AvailablePieceDetailPage), findsOneWidget);
      expect(tester.widget<AvailablePieceDetailPage>(find.byType(AvailablePieceDetailPage)).item.id, 'a1');
      expect(find.byType(PieceDetailPage), findsNothing);
      Navigator.of(tester.element(find.byType(AvailablePieceDetailPage))).pop();
      await _settle(tester);

      // Message opens a chat with them.
      await _tap(tester, _button('Message'));
      expect(find.byType(ConversationThreadPage), findsOneWidget);
      expect(tester.widget<ConversationThreadPage>(find.byType(ConversationThreadPage)).otherPartyUsername, 'amara');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Upcoming show ($theme, B27): the card between the bio and the stats opens the show; '
        'Tickets opens Choose tickets', (tester) async {
      _server.amaraShow = true;
      setBoardViewport(tester, height: 1200);
      await _open(tester, const ProfilePage(username: 'amara'), dark: dark);

      final card = find.byType(ProfileUpcomingShow);
      expect(card, findsOneWidget);
      expect(find.text('UPCOMING SHOW'), findsOneWidget);
      expect(find.text('Bodies in Color: the show'), findsOneWidget);
      expect(find.textContaining('Dec on Dragon · '), findsOneWidget);
      expect(tester.getTopLeft(find.text('Oil on canvas.')).dy, lessThan(tester.getTopLeft(card).dy));
      expect(tester.getBottomLeft(card).dy, lessThan(tester.getTopLeft(find.text('saves')).dy));
      // Tickets: a 44 target.
      expect(tester.getSize(find.bySemanticsLabel('Tickets')).height, greaterThanOrEqualTo(44));

      await _tap(tester, find.text('Bodies in Color: the show'));
      expect(find.byType(EventDetailPage), findsOneWidget);
      expect(tester.widget<EventDetailPage>(find.byType(EventDetailPage)).openTickets, isFalse);
      Navigator.of(tester.element(find.byType(EventDetailPage))).pop();
      await _settle(tester);

      await _tap(tester, find.bySemanticsLabel('Tickets'));
      expect(tester.widget<EventDetailPage>(find.byType(EventDetailPage)).openTickets, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('no Upcoming show ($theme) when nothing is coming up', (tester) async {
      setBoardViewport(tester, height: 1200);
      await _open(tester, const ProfilePage(username: 'amara'), dark: dark);

      expect(find.byType(ProfileUpcomingShow), findsNothing);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('a private profile ($theme): locked, nothing else read; Follow asks (Requested), tap again withdraws', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1200);
      await _open(tester, const ProfilePage(username: 'esi'), dark: dark);

      expect(find.text('Esi Owusu'), findsWidgets);
      expect(find.text('This account is private'), findsOneWidget);
      expect(find.text('Follow to see their pieces, Scenes and Collection.'), findsOneWidget);
      expect(_server.under('/api/users/esi/'), isEmpty, reason: 'no pieces, Scenes or series are asked for');
      // `ProfilePrivate`: nothing the server didn't send (no zeros), and Follow alone fills the
      // row (Message only when the owner takes messages from everyone).
      expect(find.textContaining('followers'), findsNothing);
      expect(find.textContaining(' following'), findsNothing);
      expect(find.text('collected'), findsNothing);
      expect(_button('Message'), findsNothing);
      expect(
        tester.getSize(find.ancestor(of: _button('Follow'), matching: find.byType(Expanded)).first).width,
        390 - 40,
      );

      // `ProfileRequested`: the outlined Requested, and the line says how to take it back.
      await _tap(tester, _button('Follow'));
      expect(_server.to('POST', '/api/users/esi/follow'), hasLength(1));
      expect(_button('Requested'), findsOneWidget);
      expect(find.text('This account is private'), findsOneWidget);
      expect(find.text('Esi will see your request. Tap Requested to cancel it.'), findsOneWidget);
      await _tap(tester, _button('Requested'));
      expect(_server.to('DELETE', '/api/users/esi/follow'), hasLength(1));
      expect(_button('Follow'), findsOneWidget);
      expect(find.text('Follow to see their pieces, Scenes and Collection.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('a private profile with the full header ($theme, B36): following, bio, stats, Message', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1200);
      await _open(tester, const ProfilePage(username: 'kofi'), dark: dark);

      expect(find.text('This account is private'), findsOneWidget);
      expect(find.text('14 following'), findsOneWidget);
      expect(find.textContaining('followers'), findsNothing);
      expect(find.text('Collecting work from Dallas artists.'), findsOneWidget);
      // A private account's stats are a collector's: collected · artists · saves.
      expect(find.text('6'), findsOneWidget);
      expect(find.text('collected'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('artists'), findsOneWidget);
      expect(find.text('32'), findsOneWidget);
      expect(_button('Message'), findsOneWidget);
      expect(_button('Follow'), findsOneWidget);
      expect(_server.under('/api/users/kofi/'), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('no Series tab ($theme): series are the shelf on Pieces; a card and See all open them', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1400);
      await _open(tester, const ProfilePage(username: 'amara'), dark: dark);

      // Tabs are Pieces and Scenes (Collect for a seller); no Series.
      final tabs = find.byType(ProfileTabs);
      expect(find.descendant(of: tabs, matching: find.text('Pieces')), findsOneWidget);
      expect(find.descendant(of: tabs, matching: find.text('Scenes')), findsOneWidget);
      expect(find.descendant(of: tabs, matching: find.text('Series')), findsNothing);

      // The shelf comes with Pieces, without opening anything else.
      expect(_server.to('GET', '/api/users/amara/series'), hasLength(1));
      expect(find.text('Series'), findsOneWidget);
      expect(find.text('Night Walks'), findsOneWidget);
      expect(find.text('8 pieces'), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Night Walks, 8 pieces'));
      expect(find.byType(SeriesViewPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(SeriesViewPage))).pop();
      await _settle(tester);

      await _tap(tester, find.byKey(const Key('profile-series-see-all')));
      expect(find.byType(ProfileAllSeriesPage), findsOneWidget);
      expect(find.text('Night Walks'), findsOneWidget);
      expect(find.text('Harbour Days'), findsOneWidget);
      await _tap(tester, find.text('Harbour Days'));
      expect(find.byType(SeriesViewPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Collection ($theme): a collector with no pieces opens on it; title and artist, no price', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1400);
      await _open(tester, const ProfilePage(username: 'tomi'), dark: dark);

      // `ProfileCollector` stats: collected · artists · saves.
      final stats = ['collected', 'artists', 'saves'].map((l) => tester.getTopLeft(find.text(l)).dx).toList();
      expect(stats, [...stats]..sort());

      // `ProfileCollector`: Pieces, Scenes, Collection, and it opens on Collection.
      final tabs = find.byType(ProfileTabs);
      expect(tester.widget<ProfileTabs>(tabs).currentTab, 'collection');
      expect(_server.to('GET', '/api/users/tomi/collection'), hasLength(1));
      expect(find.text('Night Walks'), findsOneWidget);
      expect(find.text('Amara Osei'), findsOneWidget);
      expect(find.text('Harbour'), findsOneWidget);
      expect(find.text('Cedric Okafor'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing, reason: 'never prices');
      expect(find.text('Collected'), findsNothing, reason: 'no chips');

      // Two columns 16 apart, 20 under the tabs; 3:4 tiles.
      final first = tester.getRect(find.bySemanticsLabel('Night Walks, by Amara Osei'));
      final second = tester.getRect(find.bySemanticsLabel('Harbour, by Cedric Okafor'));
      expect(first.top, second.top);
      expect(second.left - first.right, 16);
      expect(first.top - tester.getRect(tabs).bottom, 20);
      final picture = tester.getSize(find.descendant(
        of: find.bySemanticsLabel('Night Walks, by Amara Osei'),
        matching: find.byType(AspectRatio),
      ));
      expect(picture.width / picture.height, closeTo(167 / 223, 0.001));

      // Pieces is empty for them: nothing, not an empty message.
      await _tap(tester, find.descendant(of: tabs, matching: find.text('Pieces')));
      expect(find.text('No pieces yet'), findsNothing);
      await _tap(tester, find.descendant(of: tabs, matching: find.text('Collection')));
      await _tap(tester, find.bySemanticsLabel('Night Walks, by Amara Osei'));
      expect(find.byType(PieceDetailPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Collection ($theme): everyone has the tab; nothing bought shows nothing', (tester) async {
      setBoardViewport(tester, height: 1200);
      await _open(tester, const ProfilePage(), dark: dark);

      final tabs = find.byType(ProfileTabs);
      expect(tester.widget<ProfileTabs>(tabs).currentTab, 'pieces');
      await _tap(tester, find.descendant(of: tabs, matching: find.text('Collection')));
      expect(_server.to('GET', '/api/users/jordanlee/collection'), hasLength(1));
      expect(tester.widget<ProfileTabs>(tabs).currentTab, 'collection');
      expect(find.byType(AspectRatio), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
    });
  }
}
