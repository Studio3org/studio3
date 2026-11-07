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
import 'package:studio3/models/feed_item.dart';
import 'package:studio3/models/post_image_transform.dart';
import 'package:studio3/models/post_summary.dart';
import 'package:studio3/screens/drafts_page.dart';
import 'package:studio3/screens/post_create_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/drafts_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/utils/app_destination.dart';
import 'package:studio3/widgets/piece_detail/piece_comment_sheet.dart';
import 'package:studio3/widgets/reels/reel_overlay.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Scenes and drafts (BACKEND_CHANGES B33) through the real widgets and services against a
/// fake server, in light and dark: the viewer takes its linked pieces and save count from the
/// Scene, shares the Scene's own link, and the artist turns comments off; comments are
/// deleted by their writer or the artist; Drafts lists Scenes with a failed publish; a Scene
/// that saved but failed to post waits in Drafts.

const _me = {'id': 'u1', 'username': 'jordanlee', 'name': 'Jordan Lee', 'email': 'jordan@email.com'};

Map<String, dynamic> _piece(String id, String title, {int? price}) => {
  'id': id,
  'title': title,
  'mediaUrl': '',
  'status': 'live',
  'isForSale': price != null,
  'priceCents': ?price,
  'author': {'username': 'amara', 'name': 'Amara Osei'},
};

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body})>[];
  List<Map<String, dynamic>> comments = [];
  List<Map<String, dynamic>> drafts = [];

  /// The drafts list: false answers 404 (a server without it).
  bool hasDrafts = true;

  Iterable<({String method, String path, Object? body})> where(String method, [String? path]) =>
      requests.where((r) => r.method == method && (path == null || r.path == path));

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : null;
    requests.add((method: options.method, path: path, body: body));
    Object json = {'success': true, 'data': {}};
    var code = 200;
    final key = '${options.method} $path';
    if (key == 'GET /api/user/me/drafts') {
      if (hasDrafts) {
        json = {'success': true, 'data': {'items': drafts}};
      } else {
        code = 404;
        json = {'success': false, 'message': 'no route'};
      }
    } else if (key == 'GET /api/users/jordanlee/pieces') {
      json = {'success': true, 'data': drafts.where((d) => d['type'] == 'piece').toList()};
    } else if (options.method == 'GET' && path.endsWith('/comments')) {
      json = {'success': true, 'data': {'items': comments, 'nextCursor': null}};
    } else if (options.method == 'DELETE' && path.startsWith('/api/comments/')) {
      json = {'success': true, 'data': {'deleted': true, 'commentCount': 3}};
    } else if (options.method == 'PATCH' && path.startsWith('/api/posts/')) {
      json = {
        'success': true,
        'data': {'id': path.split('/').last, 'mediaUrl': '', 'mediaType': 'image', ...?body},
      };
    } else if (options.method == 'PATCH' && path.startsWith('/api/pieces/')) {
      json = {'success': true, 'data': _piece(path.split('/').last, 'x')..addAll({...?body})};
    } else if (options.method == 'GET' && path.startsWith('/api/pieces/')) {
      json = {'success': true, 'data': _piece(path.split('/').last, 'Fetched one by one')};
    } else if (options.method == 'GET' && path == '/api/posts/s1') {
      json = {'success': true, 'data': _sceneJson()};
    } else if (options.method == 'GET') {
      json = {'success': true, 'data': {'items': <Object>[], 'nextCursor': null}};
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

Map<String, dynamic> _sceneJson({bool commentsOff = false, String author = 'amara'}) => {
  'type': 'post',
  'id': 's1',
  'caption': 'The studio before the opening.',
  'mediaUrl': 'https://cdn.test/1.jpg',
  'mediaUrls': ['https://cdn.test/1.jpg', 'https://cdn.test/2.jpg', 'https://cdn.test/3.jpg'],
  'mediaType': 'image',
  'commentCount': 4,
  'saveCount': 12,
  'commentsOff': commentsOff,
  'author': {'username': author, 'name': 'Amara Osei'},
  'linkedPieceIds': ['p1', 'p2'],
  'linkedPieces': [_piece('p1', 'Bodies in Color', price: 350000), _piece('p2', 'Bodies in Color II')],
};

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 350));
  }
}

var _dark = false;

Widget _app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: _dark ? AppTheme.dark : AppTheme.light,
  routes: {'/drafts': (_) => const DraftsPage()},
  home: Scaffold(body: home),
);

Widget _viewer(Map<String, dynamic> json) =>
    ColoredBox(color: Colors.black, child: ReelOverlay(item: FeedItem.fromJson(json)));

Future<void> _openMore(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('More'));
  await tester.pumpAndSettle();
}

List<String> _actionRows(WidgetTester tester) =>
    tester.widgetList<StudioActionRow>(find.byType(StudioActionRow)).map((r) => r.title).toList();

late String _photo;

void main() {
  final clipboard = <String>[];

  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final dir = Directory.systemTemp.createTempSync('studio3_flow_scenes_b33');
    final photo = img.Image(width: 300, height: 400)..clear(img.ColorRgb8(0x6F, 0xA3, 0xB0));
    _photo = (File('${dir.path}/scene.png')..writeAsBytesSync(img.encodePng(photo))).path;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _server = _Fake();
    ApiClient.instance.debugUseAdapter(_server);
    AuthSession.instance.user = AuthUser.fromJson(_me);
    AuthSession.instance.accessToken = 'token';
    clipboard.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') clipboard.add((call.arguments as Map)['text'] as String);
        return null;
      },
    );
  });
  tearDown(() {
    AuthSession.instance.user = null;
    AuthSession.instance.accessToken = null;
  });

  test('a photo Scene shows every photo; an older payload shows its one', () {
    expect(FeedItem.fromJson(_sceneJson()).imageUrls, hasLength(3));
    final older = Map<String, dynamic>.from(_sceneJson())..remove('mediaUrls');
    expect(FeedItem.fromJson(older).imageUrls, ['https://cdn.test/1.jpg']);
  });

  test('a Scene link and a Scene notification open the Scene', () {
    expect(AppDestination.fromSegments(['post', 's1']).type, AppDestinationType.scene);
    expect(AppDestination.fromTarget('post', 's1').type, AppDestinationType.scene);
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('the viewer ($theme): linked pieces and the save count from the Scene, its own link',
        (tester) async {
      _dark = dark;
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_viewer(_sceneJson())));
      await _settle(tester);

      expect(find.text('12'), findsOneWidget, reason: 'the save count');
      expect(find.text('2 linked pieces'), findsOneWidget);
      expect(_server.where('GET').where((r) => r.path.startsWith('/api/pieces/')), isEmpty,
          reason: 'the pieces came with the Scene');

      await _openMore(tester);
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(clipboard.single, endsWith('/share/post/s1'));
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('the viewer ($theme): an older Scene fetches its linked pieces one by one', (tester) async {
      _dark = dark;
      setBoardViewport(tester);
      final older = Map<String, dynamic>.from(_sceneJson())..remove('linkedPieces');
      await tester.pumpWidget(_app(_viewer(older)));
      await _settle(tester);

      expect(_server.where('GET').map((r) => r.path), containsAll(['/api/pieces/p1', '/api/pieces/p2']));
    });

    testWidgets('the artist ($theme) turns comments off from More, and the sheet says so', (tester) async {
      _dark = dark;
      AuthSession.instance.user = AuthUser.fromJson({..._me, 'username': 'amara'});
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_viewer(_sceneJson())));
      await _settle(tester);

      await _openMore(tester);
      expect(_actionRows(tester), ['Copy link', 'Edit Scene', 'Turn off comments']);
      await tester.tap(find.text('Turn off comments'));
      await _settle(tester);
      final patch = _server.where('PATCH', '/api/posts/s1').single;
      expect(patch.body, {'commentsOff': true});
      expect(find.text('Comments turned off'), findsOneWidget);

      await _openMore(tester);
      expect(_actionRows(tester), contains('Turn on comments'));
      Navigator.of(tester.element(find.text('Turn on comments'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(RegExp('Comments')).first);
      await _settle(tester);
      expect(find.text('Comments are off'), findsOneWidget);
      expect(find.text('Add a comment'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
    });

    group('comments ($theme)', () {
      setUp(() {
        final now = DateTime.now().toUtc().toIso8601String();
        _server.comments = [
          {'id': 'c-mine', 'body': 'Mine to take back', 'user': {'username': 'jordanlee', 'name': 'Jordan Lee'}, 'createdAt': now},
          {'id': 'c-daisy', 'body': 'Watching this at 2am', 'user': {'username': 'daisy', 'name': 'Daisy Smith'}, 'createdAt': now},
        ];
      });

      Widget opener({ValueChanged<int>? onCount}) => Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => PieceCommentSheet.show(
              context,
              contentId: 's1',
              isScene: true,
              commentCount: 4,
              artistUsername: 'amara',
              onCountChanged: onCount,
            ),
            child: const Text('open'),
          ),
        ),
      );

      testWidgets('hold your own comment to delete it; the count is the server\'s', (tester) async {
        _dark = dark;
        int? count;
        setBoardViewport(tester);
        await tester.pumpWidget(_app(opener(onCount: (c) => count = c)));
        await tester.tap(find.text('open'));
        await _settle(tester);

        await tester.longPress(find.text('Mine to take back'));
        await tester.pumpAndSettle();
        expect(_actionRows(tester), ['Delete comment']);
        await tester.tap(find.text('Delete comment'));
        await _settle(tester);

        expect(_server.where('DELETE').single.path, '/api/comments/c-mine');
        expect(find.text('Mine to take back'), findsNothing);
        expect(count, 3);
      });

      testWidgets('someone else\'s comment: Block and Report, no Delete', (tester) async {
        _dark = dark;
        setBoardViewport(tester);
        await tester.pumpWidget(_app(opener()));
        await tester.tap(find.text('open'));
        await _settle(tester);

        await tester.longPress(find.text('Watching this at 2am'));
        await tester.pumpAndSettle();
        expect(_actionRows(tester), ['Block @daisy', 'Report comment']);
      });

      testWidgets('the artist can delete anyone\'s comment', (tester) async {
        _dark = dark;
        AuthSession.instance.user = AuthUser.fromJson({..._me, 'username': 'amara'});
        setBoardViewport(tester);
        await tester.pumpWidget(_app(opener()));
        await tester.tap(find.text('open'));
        await _settle(tester);

        await tester.longPress(find.text('Watching this at 2am'));
        await tester.pumpAndSettle();
        expect(_actionRows(tester), ['Delete comment', 'Block @daisy', 'Report comment']);
        await tester.tap(find.text('Delete comment'));
        await _settle(tester);
        expect(_server.where('DELETE').single.path, '/api/comments/c-daisy');
        expect(find.text('Watching this at 2am'), findsNothing);
      });
    });

    group('Drafts ($theme)', () {
      void seed() {
        _server.drafts = [
          {
            'type': 'post',
            'id': 's9',
            'caption': 'Studio, late night',
            'mediaUrl': '',
            'mediaType': 'image',
            'status': 'draft',
            'publishFailed': true,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
          {
            'type': 'post',
            'id': 's8',
            'mediaUrl': '',
            'mediaType': 'image',
            'status': 'draft',
            'updatedAt': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String(),
          },
          {
            'type': 'piece',
            'id': 'd1',
            'title': 'Portrait Dream',
            'mediaUrl': '',
            'status': 'draft',
            'medium': 'Oil',
            'dimensions': '24x36 in',
            'createdAt': '2026-10-01T10:00:00Z',
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
        ];
      }

      testWidgets('Scenes with pieces; the failed line from the server; Scenes filters', (tester) async {
        _dark = dark;
        seed();
        setBoardViewport(tester);
        await tester.pumpWidget(_app(const DraftsPage()));
        await _settle(tester);

        expect(find.text('Studio, late night'), findsOneWidget);
        expect(find.text('Untitled Scene'), findsOneWidget);
        expect(find.text("Didn't publish. Tap to try again."), findsOneWidget);
        expect(find.textContaining('SCENE · Today'), findsOneWidget);
        expect(find.textContaining('SCENE · Yesterday'), findsOneWidget);
        expect(find.textContaining('PIECE · Today'), findsOneWidget, reason: 'the last edit, not the first save');
        expect(tester.getSize(find.byType(ClipRRect).first), const Size(40, 71));

        await tester.tap(find.text('Scenes'));
        await tester.pump();
        expect(find.text('Portrait Dream'), findsNothing);
        expect(find.text('Untitled Scene'), findsOneWidget);
        await tester.tap(find.text('Pieces'));
        await tester.pump();
        expect(find.text('Studio, late night'), findsNothing);
        expect(find.text('Portrait Dream'), findsOneWidget);
      });

      testWidgets('tapping a failed Scene posts it; a ready one asks first', (tester) async {
        _dark = dark;
        seed();
        setBoardViewport(tester);
        await tester.pumpWidget(_app(const DraftsPage()));
        await _settle(tester);

        await tester.tap(find.text('Studio, late night'));
        await _settle(tester);
        expect(_server.where('PATCH', '/api/posts/s9').single.body, {'status': 'live'});
        expect(find.text('Studio, late night'), findsNothing);

        await tester.tap(find.text('Untitled Scene'));
        await tester.pumpAndSettle();
        expect(find.text('Post this Scene?'), findsOneWidget);
        await tester.tap(find.byWidgetPredicate((w) => w is StudioButton && w.label == 'Post'));
        await _settle(tester);
        expect(_server.where('PATCH', '/api/posts/s8').single.body, {'status': 'live'});
        expect(find.text('Untitled Scene'), findsNothing);
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('swiping a Scene away deletes the Scene', (tester) async {
        _dark = dark;
        seed();
        setBoardViewport(tester);
        await tester.pumpWidget(_app(const DraftsPage()));
        await _settle(tester);

        await tester.drag(find.text('Untitled Scene'), const Offset(-500, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.byWidgetPredicate((w) => w is StudioButton && w.label == 'Delete'));
        await _settle(tester);
        expect(_server.where('DELETE').single.path, '/api/posts/s8');
      });

      testWidgets('a server without the drafts list: piece drafts only', (tester) async {
        _dark = dark;
        seed();
        _server.hasDrafts = false;
        setBoardViewport(tester);
        await tester.pumpWidget(_app(const DraftsPage()));
        await _settle(tester);

        expect(find.text('Portrait Dream'), findsOneWidget);
        expect(find.text('Untitled Scene'), findsNothing);
      });
    });

    testWidgets('a Scene that saved but failed to post ($theme): Saved as draft, Go to drafts, and the '
        'server hears it', (tester) async {
      _dark = dark;
      setBoardViewport(tester);
      var calls = 0;
      await tester.pumpWidget(
        _app(
          PostCreatePage(
            postType: 'scene',
            imagePaths: [_photo],
            transforms: [PostImageTransform()],
            previewImageIndex: 0,
            onClose: () {},
            publisher: PostPublisher(
              saveDraft: (_) async => throw UnimplementedError(),
              goLive: (_) async => throw UnimplementedError(),
              postScene: (_) async {
                calls++;
                return const PostSummary(id: 's5', status: 'draft');
              },
              sceneGoLive: (_) async => throw Exception('offline'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Post'));
      await _settle(tester);

      expect(find.text("Couldn't post"), findsOneWidget);
      expect(find.textContaining('Your Scene is saved as a draft'), findsOneWidget);
      expect(find.text('Go to drafts'), findsOneWidget);
      expect(await DraftsService.instance.failedIds(), {'s5'});
      expect(_server.where('PATCH', '/api/posts/s5').single.body, {'publishFailed': true});

      await tester.tap(find.text('Try again'));
      await _settle(tester);
      expect(calls, 1, reason: 'trying again only takes the saved Scene live');
    });
  }
}
