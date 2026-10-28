import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/screens/available_piece_detail_page.dart';
import 'package:studio3/screens/reels_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/blocked_authors_store.dart';
import 'package:studio3/services/engagement_store.dart';
import 'package:studio3/services/saved_content_store.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/utils/profile_navigation.dart';
import 'package:studio3/widgets/piece_detail/piece_comment_sheet.dart';
import 'package:studio3/widgets/reels/reel_overlay.dart';
import 'package:studio3/widgets/reels/reel_player_page.dart';
import 'package:studio3/widgets/studio/studio.dart';
// The video plugin's own seam for a stand-in player (it comes with video_player).
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'golden_harness.dart';

/// Flow regression 19.2, Reels (docs/new-ui/NEW_UI_EXECUTION_PLAN.md), in light and dark: the
/// real Reels page, player and Scene viewer controls against a fake server and a stand-in video
/// player. Signed in as jordanlee.

Map<String, dynamic> _video(String id, String author, String name, {Map<String, dynamic>? piece, int? saves}) => {
  'type': 'post',
  'id': id,
  'caption': 'Scene $id',
  'mediaType': 'video',
  'mediaUrl': 'https://cdn.test/$id.mp4',
  'mediaAspectRatio': '9:16',
  'commentCount': 2,
  'saveCount': ?saves,
  if (piece != null) 'linkedPieceId': piece['id'],
  'piece': ?piece,
  'author': {'username': author, 'name': name},
};

final _piece = {
  'id': 'p1',
  'title': 'Bodies in Color',
  'mediaUrl': '',
  'status': 'live',
  'isForSale': true,
  'listingState': 'available',
  'priceCents': 350000,
  'author': {'username': 'kofi', 'name': 'Kofi Mensah'},
};

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Map<String, String> query, String? auth})>[];
  List<Map<String, dynamic>> firstPage = [];

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
      case 'GET /api/feed/explore':
        final second = query['cursor'] == 'c2';
        json = {
          'success': true,
          'data': {
            'items': second
                ? [_video('v4', 'ama', 'Ama Boateng'), _video('v5', 'kofi', 'Kofi Mensah')]
                : firstPage,
            'nextCursor': second ? null : 'c2',
          },
        };
      case 'GET /api/posts/v3/comments':
        json = {
          'success': true,
          'data': {'items': [], 'nextCursor': null},
        };
      case 'POST /api/users/kofi/follow':
        json = {'success': true, 'data': {'following': true, 'requested': false}};
      case 'POST /api/posts/v3/save' || 'DELETE /api/posts/v3/save' || 'POST /api/users/kofi/block':
        break;
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

/// A stand-in video player: every video is 9:16 and 10 s long; [broken] ones fail to load.
class _FakeVideo extends VideoPlayerPlatform {
  final urls = <int, String>{};
  final playing = <int, bool>{};
  final volume = <int, double>{};
  final looping = <int, bool>{};
  final disposed = <int>{};
  final broken = <String>{};
  final _events = <int, StreamController<VideoEvent>>{};
  var _next = 0;

  /// Players still open, by video URL.
  Map<String, int> get live => {
    for (final e in urls.entries)
      if (!disposed.contains(e.key)) e.value: e.key,
  };

  int player(String id) => live['https://cdn.test/$id.mp4']!;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) => _create(dataSource.uri!);

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) => _create(options.dataSource.uri!);

  Future<int?> _create(String url) async {
    final id = _next++;
    urls[id] = url;
    final events = _events[id] = StreamController<VideoEvent>();
    scheduleMicrotask(() {
      if (broken.contains(url)) {
        events.addError(PlatformException(code: 'VideoError', message: 'cannot open'));
      } else {
        events.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 10),
            size: const Size(1080, 1920),
          ),
        );
      }
    });
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    playing[playerId] = false;
  }

  @override
  Future<void> play(int playerId) async => playing[playerId] = true;

  @override
  Future<void> pause(int playerId) async => playing[playerId] = false;

  @override
  Future<void> setVolume(int playerId, double volume) async => this.volume[playerId] = volume;

  @override
  Future<void> setLooping(int playerId, bool looping) async => this.looping[playerId] = looping;

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => const Duration(seconds: 2);

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int playerId) => ColoredBox(key: ValueKey('video $playerId'), color: const Color(0xFF223344));

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => buildView(options.playerId);
}

late _Fake _server;
late _FakeVideo _video_;
final _shared = <String>[];
final _clipboard = <String>[];
var _backs = 0;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 350));
  }
}

Finder _control(String label) =>
    find.byWidgetPredicate((w) => w is Semantics && (w.properties.label == label || (w.properties.label?.startsWith('$label, ') ?? false)));

String? _labelOf(WidgetTester tester, String prefix) => tester
    .widgetList<Semantics>(find.byWidgetPredicate((w) => w is Semantics && (w.properties.label?.startsWith(prefix) ?? false)))
    .first
    .properties
    .label;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder.first, warnIfMissed: false);
  await _settle(tester);
}

/// The Scene on screen.
String _current(WidgetTester tester) =>
    tester.widgetList<ReelPlayerPage>(find.byType(ReelPlayerPage)).firstWhere((p) => p.isActive).item.id;

Future<void> _swipeUp(WidgetTester tester) async {
  await tester.fling(find.byType(PageView), const Offset(0, -500), 1500);
  await _settle(tester);
}

Widget _app({required bool dark}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  navigatorObservers: [routeObserver],
  home: ReelsPage(onBack: () => _backs++),
  routes: {
    '/profile': (context) {
      final args = parseProfileRouteArgs(ModalRoute.of(context)?.settings.arguments);
      return Scaffold(body: Text('profile @${args?.username}'));
    },
  },
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => '.');
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), (call) async {
      _shared.add((call.arguments as Map)['text'] as String);
      return 'dev.fluttercommunity.plus/share/success';
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') _clipboard.add((call.arguments as Map)['text'] as String);
      return null;
    });
  });

  setUp(() {
    _server = _Fake()
      ..firstPage = [
        _video('v1', 'ama', 'Ama Boateng'),
        _video('v2', 'esi', 'Esi Owusu'),
        _video('v3', 'kofi', 'Kofi Mensah', piece: _piece, saves: 214),
      ];
    _video_ = _FakeVideo();
    VideoPlayerPlatform.instance = _video_;
    ApiClient.instance.debugUseAdapter(_server);
    _shared.clear();
    _clipboard.clear();
    _backs = 0;
    sceneSoundOn.value = false;
    AuthSession.instance.accessToken = 'token';
    AuthSession.instance.user = const AuthUser(
      username: 'jordanlee',
      name: 'Jordan Lee',
      email: 'jordan@email.com',
      onboardingComplete: true,
    );
  });
  tearDown(() async {
    AuthSession.instance.accessToken = null;
    AuthSession.instance.user = null;
    BlockedAuthorsStore.instance.clear();
    EngagementStore.instance.clear();
    await SavedContentStore.instance.clearLocal();
    sceneSoundOn.value = false;
  });

  /// Ends the test with every player closed and the toast and image timers run out.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  }

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('Reels ($theme): plays muted, sound stays on, tap pauses, swiping plays the next and loads more', (
      tester,
    ) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(dark: dark));
      await _settle(tester);

      // Video Scenes, asked for as the account.
      final load = _server.to('GET', '/api/feed/explore').single;
      expect(load.query, {'medium': 'video'});
      expect(load.auth, 'Bearer token');

      // The first plays, looped and muted; only the one on screen has a player.
      expect(_current(tester), 'v1');
      final v1 = _video_.player('v1');
      expect(_video_.live.keys, ['https://cdn.test/v1.mp4']);
      expect(_video_.playing[v1], isTrue);
      expect(_video_.looping[v1], isTrue);
      expect(_video_.volume[v1], 0);
      expect(find.byKey(ValueKey('video $v1')), findsOneWidget);

      // Sound on.
      await _tap(tester, _control('Sound off'));
      expect(_video_.volume[v1], 1);
      expect(_control('Sound on'), findsOneWidget);

      // A tap pauses (the play mark shows), another plays.
      await _tap(tester, find.byKey(ValueKey('video $v1')));
      expect(_video_.playing[v1], isFalse);
      expect(find.byWidgetPredicate((w) => w is StudioIcon && w.asset == StudioIcons.play), findsOneWidget);
      await _tap(tester, find.byKey(ValueKey('video $v1')));
      expect(_video_.playing[v1], isTrue);
      expect(find.byWidgetPredicate((w) => w is StudioIcon && w.asset == StudioIcons.play), findsNothing);

      // Swipe: the next plays, the last one's player closes, sound stays on.
      await _swipeUp(tester);
      expect(_current(tester), 'v2');
      final v2 = _video_.player('v2');
      expect(_video_.disposed, contains(v1));
      expect(_video_.playing[v2], isTrue);
      expect(_video_.volume[v2], 1);

      // Two from the end, the next page comes in with the cursor (once).
      final more = _server.to('GET', '/api/feed/explore').toList();
      expect(more, hasLength(2));
      expect(more.last.query, {'medium': 'video', 'cursor': 'c2'});
      await _swipeUp(tester);
      expect(_current(tester), 'v3');
      expect(_server.to('GET', '/api/feed/explore'), hasLength(2));
      await _swipeUp(tester);
      expect(_current(tester), 'v4');
      await _swipeUp(tester);
      expect(_current(tester), 'v5');

      // Back leaves the viewer.
      await _tap(tester, _control('Back'));
      expect(_backs, 1);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    testWidgets('Reels ($theme): Follow, Save, Comments, Share, Copy link, the linked piece, the artist, Block', (
      tester,
    ) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(dark: dark));
      await _settle(tester);
      await _swipeUp(tester);
      await _swipeUp(tester);
      expect(_current(tester), 'v3');
      final v3 = _video_.player('v3');

      // Follow.
      await _tap(tester, find.widgetWithText(SceneFollowButton, 'Follow'));
      expect(_server.to('POST', '/api/users/kofi/follow').single.auth, 'Bearer token');
      expect(find.widgetWithText(SceneFollowButton, 'Following'), findsOneWidget);

      // Save and unsave, with the count.
      expect(_labelOf(tester, 'Save'), 'Save, 214');
      await _tap(tester, _control('Save'));
      expect(_server.to('POST', '/api/posts/v3/save'), hasLength(1));
      expect(_labelOf(tester, 'Saved'), 'Saved, 215');
      await _tap(tester, _control('Saved'));
      expect(_server.to('DELETE', '/api/posts/v3/save'), hasLength(1));
      expect(_labelOf(tester, 'Save'), 'Save, 214');

      // Comments open over the video.
      await _tap(tester, _control('Comments'));
      expect(find.byType(PieceCommentSheet), findsOneWidget);
      expect(_server.to('GET', '/api/posts/v3/comments'), hasLength(1));
      Navigator.of(tester.element(find.byType(PieceCommentSheet))).pop();
      await _settle(tester);

      // Share sends the Scene with its piece's link; More → Copy link copies that link.
      await _tap(tester, _control('Share'));
      expect(_shared.single, startsWith('A Scene by Kofi Mensah on Studio 3\n\nScene v3\n\n'));
      expect(_shared.single, endsWith('/piece/p1'));
      await _tap(tester, _control('More'));
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('Block @kofi'), findsOneWidget);
      expect(find.text('Report Scene'), findsOneWidget);
      expect(find.text('Edit Scene'), findsNothing);
      await _tap(tester, find.text('Copy link'));
      expect(_clipboard.single, _shared.single.split('\n\n').last);
      expect(find.text('Link copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      // The linked piece opens its page, and the video stops underneath until back.
      await _tap(tester, _control('Bodies in Color'));
      expect(tester.widget<AvailablePieceDetailPage>(find.byType(AvailablePieceDetailPage)).item.id, 'p1');
      expect(ModalRoute.of(tester.element(find.byType(ReelsPage, skipOffstage: false)))!.isCurrent, isFalse);
      expect(_video_.disposed, contains(v3));
      Navigator.of(tester.element(find.byType(ReelsPage, skipOffstage: false))).pop();
      await _settle(tester);
      expect(_current(tester), 'v3');
      final v3Again = _video_.player('v3');
      expect(v3Again, isNot(v3));
      expect(_video_.playing[v3Again], isTrue);

      // The artist's name opens their profile.
      await _tap(tester, find.text('Kofi Mensah'));
      expect(find.text('profile @kofi'), findsOneWidget);
      expect(_video_.disposed, contains(v3Again));
      Navigator.of(tester.element(find.text('profile @kofi'))).pop();
      await _settle(tester);

      // Block: asks first, then their Scenes leave the viewer.
      await _tap(tester, _control('More'));
      await _tap(tester, find.text('Block @kofi'));
      expect(find.text('Block @kofi?'), findsOneWidget);
      await _tap(tester, find.widgetWithText(StudioButton, 'Block'));
      expect(_server.to('POST', '/api/users/kofi/block'), hasLength(1));
      expect(find.text('Blocked @kofi'), findsOneWidget);
      final shown = tester.widgetList<ReelPlayerPage>(find.byType(ReelPlayerPage, skipOffstage: false)).map((p) => p.item.authorUsername);
      expect(shown, isNot(contains('kofi')));
      expect(_current(tester), isNot('v3'));
      expect(tester.takeException(), isNull);
      await finish(tester);
    });
  }

  testWidgets('your own Scene: Edit Scene in More, no Follow, no Block', (tester) async {
    setBoardViewport(tester);
    _server.firstPage = [_video('v9', 'jordanlee', 'Jordan Lee')];
    await tester.pumpWidget(_app(dark: false));
    await _settle(tester);
    expect(find.byType(SceneFollowButton), findsNothing);
    await _tap(tester, _control('More'));
    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('Edit Scene'), findsOneWidget);
    expect(find.textContaining('Block'), findsNothing);
    expect(find.text('Report Scene'), findsNothing);
    await finish(tester);
  });

  testWidgets('a video that will not load says so; no videos at all says so', (tester) async {
    setBoardViewport(tester);
    _video_.broken.add('https://cdn.test/v1.mp4');
    await tester.pumpWidget(_app(dark: false));
    // The failed player closes before the page says so; that takes a few more turns.
    for (var i = 0; i < 4; i++) {
      await _settle(tester);
    }
    expect(find.byWidgetPredicate((w) => w is StudioIcon && w.semanticLabel == 'Video unavailable'), findsOneWidget);
    expect(_video_.live, isEmpty);
    await tester.pumpWidget(const SizedBox());

    _server.firstPage = [];
    await tester.pumpWidget(_app(dark: true));
    await _settle(tester);
    expect(find.text('No scene videos yet'), findsOneWidget);
    await finish(tester);
  });
}
