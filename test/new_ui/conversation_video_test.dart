import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/chat_message.dart';
import 'package:studio3/screens/chat_video_page.dart';
import 'package:studio3/screens/conversation_thread_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/media_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/utils/app_clock.dart';
import 'package:studio3/widgets/studio/studio_icon.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'golden_harness.dart';

/// Video messages in `Conversation` (BACKEND_CHANGES B11): the bubble, the full-screen
/// player, and sending one from the + against a fake server.
final _now = DateTime(2026, 10, 27, 16, 40);
const _video = 'https://cdn.test/jordan/chat/v1/original.mp4';
const _poster = 'https://cdn.test/jordan/chat/p1/original.jpg';

ChatMessage _clip({String who = 'amarasart', String? poster}) => ChatMessage(
  id: 'v',
  videoUrl: _video,
  thumbnailUrl: poster,
  senderUsername: who,
  createdAt: _now.subtract(const Duration(minutes: 5)),
);

Widget _page(List<ChatMessage> messages, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: ConversationThreadPage(
    conversationId: 'c1',
    otherPartyUsername: 'amarasart',
    otherPartyName: 'Amara Osei',
    otherPartyAvatarUrl: null,
    debugMessages: messages,
    debugMyUsername: 'jordan',
  ),
);

/// Plays nothing; reports a 10 s, 9:16 video and records play / pause.
class _FakeVideo extends VideoPlayerPlatform {
  final playing = <int, bool>{};
  final urls = <int, String>{};
  final disposed = <int>{};
  final _events = <int, StreamController<VideoEvent>>{};
  var _next = 0;

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
    scheduleMicrotask(
      () => events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 10),
          size: const Size(1080, 1920),
        ),
      ),
    );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async => disposed.add(playerId);

  @override
  Future<void> play(int playerId) async => playing[playerId] = true;

  @override
  Future<void> pause(int playerId) async => playing[playerId] = false;

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => const Duration(seconds: 2);

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int playerId) => const ColoredBox(color: Color(0xFF223344));

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => buildView(options.playerId);
}

/// The camera roll, holding one file.
class _FakePicker extends ImagePickerPlatform {
  _FakePicker(this.path);

  final String? path;
  var asked = 0;

  @override
  Future<List<XFile>> getMedia({required MediaOptions options}) async {
    asked++;
    return path == null ? const [] : [XFile(path!)];
  }
}

/// Presign (dev mode, so no upload), start a chat, then the thread with the video in it.
class _Server implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body})>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path, body: options.data));
    Object json;
    switch ('${options.method} $path') {
      case 'POST /api/media/presign':
        final video = (options.data as Map)['contentType'] == 'video/mp4';
        final url = video ? _video : _poster;
        json = {
          'success': true,
          'data': {'presignedPutUrl': url, 'url': url, 'key': 'k', 'devMode': true},
        };
      case 'GET /api/conversations/with/amarasart':
        json = {'success': true, 'data': {'conversation': null}};
      case 'POST /api/conversations':
        json = {'success': true, 'data': {'id': 'c9', 'reused': false, 'status': 'open'}};
      case 'GET /api/conversations/c9':
        json = {
          'success': true,
          'data': {
            'id': 'c9',
            'status': 'open',
            'otherParty': {'username': 'amarasart', 'name': 'Amara Osei'},
            'messages': {
              'items': [
                {
                  'id': 'm1',
                  'body': null,
                  'videoUrl': _video,
                  // No poster here: a network image would leave the image cache's timer running.
                  'thumbnailUrl': null,
                  'sender': {'username': 'jordan', 'name': 'Jordan Lee'},
                  'createdAt': _now.toUtc().toIso8601String(),
                },
              ],
              'nextCursor': null,
            },
          },
        };
      default:
        json = {'success': true, 'data': {}};
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

/// The 180 by 240 tile a video message is drawn in.
final _tile = find.byWidgetPredicate((w) => w is SizedBox && w.width == 180 && w.height == 240);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late _FakeVideo video;
  final posterAsked = <Map<Object?, Object?>>[];

  setUp(() {
    appNow = () => _now;
    video = _FakeVideo();
    VideoPlayerPlatform.instance = video;
    posterAsked.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.justsoft.xyz/video_thumbnail'),
      (call) async {
        posterAsked.add(call.arguments as Map<Object?, Object?>);
        return Uint8List.fromList(List.filled(1200, 7));
      },
    );
  });
  tearDown(() => appNow = DateTime.now);
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '.',
    );
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    testWidgets('a video is the photo tile with a play button (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_page([_clip()], dark: dark));
      await tester.pump();
      expect(find.bySemanticsLabel('Video'), findsOneWidget);
      final tile = _tile;
      expect(tile, findsOneWidget);
      expect(tester.getSize(tile), const Size(180, 240));
      // Received: on the left, at the page's 16 margin.
      expect(tester.getTopLeft(tile).dx, closeTo(16, 0.5));
      final play = find.descendant(
        of: find.byType(ConversationThreadPage),
        matching: find.byWidgetPredicate((w) => w is StudioIcon && w.asset == StudioIcons.play),
      );
      expect(play, findsOneWidget);
      expect(tester.widget<StudioIcon>(play).color, StudioColors.galleryWhite);
      final circle = tester.widget<Container>(
        find.ancestor(of: play, matching: find.byType(Container)).first,
      );
      expect((circle.decoration! as BoxDecoration).color, c.scrim);
      expect(tester.getSize(find.ancestor(of: play, matching: find.byType(Container)).first), const Size(44, 44));
    });
  }

  testWidgets('your video sits on the right', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_page([_clip(who: 'jordan')]));
    await tester.pump();
    expect(tester.getTopRight(_tile).dx, closeTo(390 - 16, 0.5));
  });

  testWidgets('tapping it plays it full screen; a tap pauses; close comes back', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_page([_clip()]));
    await tester.pump();
    await tester.tap(_tile);
    await tester.pumpAndSettle();
    expect(find.byType(ChatVideoPage), findsOneWidget);
    await _settle(tester);
    expect(video.urls.values.single, _video);
    expect(video.playing[0], isTrue);
    expect(find.byWidgetPredicate((w) => w is StudioIcon && w.asset == StudioIcons.play), findsNothing);

    await tester.tap(find.byType(ChatVideoPage));
    await _settle(tester);
    expect(video.playing[0], isFalse);
    expect(find.byWidgetPredicate((w) => w is StudioIcon && w.asset == StudioIcons.play), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatVideoPage), findsNothing);
    await _settle(tester);
    expect(video.disposed, {0});
  });

  testWidgets('the + is for a photo or a video', (tester) async {
    await tester.pumpWidget(_page(const []));
    await tester.pump();
    expect(find.bySemanticsLabel('Attach a photo or video'), findsOneWidget);
  });

  group('sending one', () {
    late Directory dir;
    late ImagePickerPlatform picker;

    setUp(() async {
      picker = ImagePickerPlatform.instance;
      dir = await Directory.systemTemp.createTemp('chat_video');
    });
    tearDown(() async {
      ImagePickerPlatform.instance = picker;
      await dir.delete(recursive: true);
    });

    Future<_Server> open(WidgetTester tester, String path) async {
      final server = _Server();
      ApiClient.instance.debugUseAdapter(server);
      final wasToken = AuthSession.instance.accessToken;
      AuthSession.instance.accessToken = 'token';
      addTearDown(() => AuthSession.instance.accessToken = wasToken);
      ImagePickerPlatform.instance = _FakePicker(path);
      setBoardViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ConversationThreadPage(
            otherPartyUsername: 'amarasart',
            otherPartyName: 'Amara Osei',
            otherPartyAvatarUrl: null,
            debugMyUsername: 'jordan',
          ),
        ),
      );
      await _settle(tester);
      return server;
    }

    testWidgets('the + sends a video with its first frame, sized for the server', (tester) async {
      final clip = File('${dir.path}/clip.mp4');
      await tester.runAsync(() => clip.writeAsBytes(List.filled(2048, 1)));
      final server = await open(tester, clip.path);

      await tester.runAsync(() async {
        await tester.tap(find.bySemanticsLabel('Attach a photo or video'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await _settle(tester);

      final presigned = [
        for (final r in server.requests)
          if (r.path == '/api/media/presign') r.body,
      ];
      expect(presigned, [
        {'purpose': 'chat', 'contentType': 'video/mp4', 'contentLength': 2048},
        {'purpose': 'chat', 'contentType': 'image/jpeg', 'contentLength': 1200},
      ]);
      expect(posterAsked.single['video'], clip.path);
      final start = server.requests.firstWhere((r) => r.method == 'POST' && r.path == '/api/conversations');
      expect(start.body, {
        'username': 'amarasart',
        'message': '',
        'videoUrl': _video,
        'thumbnailUrl': _poster,
      });
      expect(_tile, findsOneWidget);
    });

    testWidgets('a video over 100 MB is turned away before uploading', (tester) async {
      final clip = File('${dir.path}/long.mp4');
      await tester.runAsync(() async {
        final raf = await clip.open(mode: FileMode.write);
        await raf.truncate(MediaService.maxVideoBytes + 1);
        await raf.close();
      });
      final server = await open(tester, clip.path);

      await tester.runAsync(() async {
        await tester.tap(find.bySemanticsLabel('Attach a photo or video'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await _settle(tester);

      expect(find.text('Videos can be up to 100 MB'), findsOneWidget);
      expect(server.requests.where((r) => r.path == '/api/media/presign'), isEmpty);
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  test('a message reads its video and poster', () {
    final message = ChatMessage.fromJson({
      'id': 'm1',
      'videoUrl': _video,
      'thumbnailUrl': _poster,
      'createdAt': _now.toIso8601String(),
    });
    expect(message.videoUrl, _video);
    expect(message.thumbnailUrl, _poster);
    expect(ChatMessage.fromJson({'id': 'm2', 'body': 'Hi'}).videoUrl, isNull);
  });
}
