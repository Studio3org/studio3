import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/feed_item.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/models/post_summary.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/follow_button.dart';
import 'package:studio3/widgets/piece_detail/piece_comment_sheet.dart';
import 'package:studio3/widgets/reels/reel_overlay.dart';
import 'package:studio3/widgets/reels/reel_player_page.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Phase 13, 17.5 (docs/new-ui/NEW_UI_EXECUTION_PLAN.md): the Scene viewer for videos and
/// photos, the linked pieces sheet, and Scene comments, against a fake server.

const _user = {'id': 'u1', 'username': 'jordanlee', 'name': 'Jordan Lee', 'email': 'jordan@email.com'};

Map<String, dynamic> _pieceJson(String id, String title, {int? price}) => {
  'id': id,
  'title': title,
  'mediaUrl': '',
  'status': 'live',
  'isForSale': price != null,
  'priceCents': ?price,
  'author': {'username': 'amara', 'name': 'Amara Osei'},
};

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path})>[];
  List<Map<String, dynamic>> comments = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path));
    Object json;
    var code = 200;
    if (options.method == 'GET' && path == '/api/pieces/p1') {
      json = {'success': true, 'data': _pieceJson('p1', 'Bodies in Color', price: 350000)};
    } else if (options.method == 'GET' && path == '/api/pieces/p2') {
      json = {'success': true, 'data': _pieceJson('p2', 'Bodies in Color II')};
    } else if (options.method == 'GET' && path.endsWith('/comments')) {
      json = {
        'success': true,
        'data': {'items': comments, 'nextCursor': null},
      };
    } else if (options.method == 'POST' && path.endsWith('/comments')) {
      json = {
        'success': true,
        'data': {
          'id': 'c-new',
          'body': (options.data as Map)['body'],
          'user': {'username': 'jordanlee', 'name': 'Jordan Lee'},
          'createdAt': DateTime.now().toUtc().toIso8601String(),
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 350));
  }
}

FeedItem _videoScene({int comments = 18, int? saves = 214}) => FeedItem.post(
  PostSummary(
    id: 's1',
    caption: 'Late night layering on Bodies in Color. The teal came first, then everything else.',
    mediaType: 'video',
    authorName: 'Amara Osei',
    authorUsername: 'amara',
    commentCount: comments,
    saveCount: saves,
    pieceId: 'p1',
    linkedPieceIds: const ['p1'],
    linkedPiece: PieceSummary.fromJson(_pieceJson('p1', 'Bodies in Color', price: 350000)),
  ),
);

FeedItem _photoScene() => FeedItem.post(
  const PostSummary(
    id: 's2',
    caption: 'The studio before the opening. Two from the series, side by side.',
    mediaType: 'image',
    mediaAspectRatio: '3:2',
    authorName: 'Amara Osei',
    authorUsername: 'amara',
    commentCount: 18,
    saveCount: 214,
    linkedPieceIds: ['p1', 'p2'],
  ),
);

/// The boards' studio wall in plain colours.
class _Wall extends StatelessWidget {
  const _Wall({this.tall = true});

  final bool tall;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth / 390;
        final h = box.maxHeight / (tall ? 844 : 260);
        Widget block(double l, double t, double bw, double bh, int colour) => Positioned(
          left: l * w,
          top: t * h,
          width: bw * w,
          height: bh * h,
          child: ColoredBox(color: Color(colour)),
        );
        return ClipRect(
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: Color(0xFF3A3632))),
              tall ? block(0, 523, 390, 321, 0xFF6B5A4A) : block(0, 161, 390, 99, 0xFF6B5A4A),
              tall ? block(46, 118, 163, 337, 0xFF6FA3B0) : block(46, 36, 163, 104, 0xFF6FA3B0),
              tall ? block(234, 337, 85, 253, 0xFF8C3B2E) : block(234, 104, 85, 78, 0xFF8C3B2E),
              tall ? block(78, 557, 195, 42, 0xFFD9A441) : block(78, 171, 195, 13, 0xFFD9A441),
            ],
          ),
        );
      },
    );
  }
}

Widget _app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  home: MediaQuery(
    data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
    child: Scaffold(backgroundColor: Colors.black, body: home),
  ),
);

/// A video Scene as the viewer draws it, with the wall for the video.
Widget _videoStill(FeedItem item, {double progress = 0.38}) => Stack(
  fit: StackFit.expand,
  children: [
    const SceneMediaFrame(aspectRatio: 390 / 844, child: _Wall()),
    ReelOverlay(item: item, soundOn: true, onToggleSound: () {}, progress: ValueNotifier(progress)),
  ],
);

/// A 3:2 photo Scene with two photos.
Widget _photoStill(FeedItem item) => Stack(
  fit: StackFit.expand,
  children: [
    ScenePhotos(
      urls: const ['a', 'b'],
      aspectRatio: 1.5,
      pageBuilder: (context, i) => const _Wall(tall: false),
    ),
    ReelOverlay(item: item),
  ],
);

void main() {
  setUpAll(() async {
    await loadStudioFonts();
    dotenv.loadFromString(envString: '', isOptional: true);
  });

  late AuthUser? wasUser;
  late String? wasToken;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _server = _Fake();
    ApiClient.instance.debugUseAdapter(_server);
    wasUser = AuthSession.instance.user;
    wasToken = AuthSession.instance.accessToken;
    AuthSession.instance.user = AuthUser.fromJson(_user);
    AuthSession.instance.accessToken = 'token';
    sceneSoundOn.value = false;
  });
  tearDown(() {
    AuthSession.instance.user = wasUser;
    AuthSession.instance.accessToken = wasToken;
  });

  group('Scene viewer: video', () {
    testWidgets('Save and Comments with Mono counts and Share; no likes; the linked piece line', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_videoStill(_videoScene())));
      await _settle(tester);

      expect(find.text('Amara Osei'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      // The comment count is the server's, not 0.
      expect(find.text('18'), findsOneWidget);
      expect(find.text('214'), findsOneWidget);
      expect(tester.widget<Text>(find.text('18')).style?.fontFamily, 'GeistMono');
      expect(find.bySemanticsLabel('Share'), findsOneWidget);
      expect(find.text('Like'), findsNothing);
      expect(find.byWidgetPredicate((w) => w is StudioIcon && w.asset == StudioIcons.like), findsNothing);
      expect(find.text('Bodies in Color'), findsOneWidget);
      expect(find.text(r'$3,500'), findsOneWidget);
      // The caption is two lines until tapped.
      final caption = find.textContaining('Late night layering');
      expect(tester.widget<Text>(caption).maxLines, 2);
      await tester.tap(caption);
      await tester.pump();
      expect(tester.widget<Text>(caption).maxLines, isNull);
      // Top: back, sound, more.
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      expect(find.bySemanticsLabel('Sound on'), findsOneWidget);
      expect(find.bySemanticsLabel('More'), findsOneWidget);
    });

    testWidgets('no save count until the server sends one; no comment count at 0', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_videoStill(_videoScene(comments: 0, saves: null))));
      await _settle(tester);
      expect(find.text('0'), findsNothing);
      expect(find.bySemanticsLabel('Save'), findsOneWidget);
      expect(find.bySemanticsLabel('Comments'), findsOneWidget);
    });

    testWidgets('Follow is solid white with Ink text; Following is a white outline', (tester) async {
      var state = FollowState.none;
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => Center(
              child: SceneFollowButton(
                state: state,
                onPressed: () => setState(() => state = FollowState.following),
              ),
            ),
          ),
        ),
      );
      Container box() => tester.widget<Container>(
        find.ancestor(of: find.byType(Text), matching: find.byType(Container)).first,
      );
      expect((box().decoration! as BoxDecoration).color, StudioColors.galleryWhite);
      expect(tester.widget<Text>(find.text('Follow')).style?.color, StudioColors.ink);
      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(find.text('Following'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Following')).style?.color, StudioColors.galleryWhite);
      expect((box().decoration! as BoxDecoration).border, isNotNull);
    });

    testWidgets('More: Copy link, Block and Report on someone else\'s Scene', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_videoStill(_videoScene())));
      await _settle(tester);
      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      final rows = tester.widgetList<StudioActionRow>(find.byType(StudioActionRow)).map((r) => r.title);
      expect(rows, ['Copy link', 'Block @amara', 'Report Scene']);
    });

    testWidgets('More on your own Scene: Copy link and Edit Scene, no Follow', (tester) async {
      AuthSession.instance.user = AuthUser.fromJson({..._user, 'username': 'amara'});
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_videoStill(_videoScene())));
      await _settle(tester);
      expect(find.text('Follow'), findsNothing);
      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      final rows = tester.widgetList<StudioActionRow>(find.byType(StudioActionRow)).map((r) => r.title);
      expect(rows, ['Copy link', 'Edit Scene']);
    });
  });

  group('Scene viewer: photo', () {
    testWidgets('two linked pieces overlap and open the Linked pieces sheet', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_photoStill(_photoScene())));
      await _settle(tester);
      // Photos have no sound button or progress line.
      expect(find.bySemanticsLabel('Sound on'), findsNothing);
      expect(find.bySemanticsLabel('Sound off'), findsNothing);
      expect(find.text('2 linked pieces'), findsOneWidget);
      // Dots for two photos.
      expect(
        find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxWidth == 6 && w.constraints?.maxHeight == 6,
        ),
        findsNWidgets(2),
      );

      await tester.tap(find.text('2 linked pieces'));
      await tester.pumpAndSettle();
      expect(find.text('Linked pieces'), findsOneWidget);
      expect(find.text('In this Scene'), findsNothing);
      expect(find.text('Bodies in Color'), findsOneWidget);
      expect(find.text(r'$3,500'), findsOneWidget);
      expect(find.text('Bodies in Color II'), findsOneWidget);
      expect(find.text('Not for sale'), findsOneWidget);
      expect(find.text('Amara Osei'), findsNWidgets(3));
    });

    test('ratios', () {
      expect(parseSceneAspect('3:4'), 0.75);
      expect(parseSceneAspect('9:16'), 9 / 16);
      expect(parseSceneAspect(null), isNull);
      expect(parseSceneAspect('x'), isNull);
    });
  });

  group('Scene comments', () {
    void seed() {
      final now = DateTime.now().toUtc();
      String ago(Duration d) => now.subtract(d).toIso8601String();
      _server.comments = [
        {
          'id': 'c1',
          'body': 'The teal underneath makes the whole thing glow. How many layers is this?',
          'user': {'username': 'jordan', 'name': 'Jordan Lee'},
          'createdAt': ago(const Duration(hours: 2)),
        },
        {
          'id': 'c2',
          'body': '@Jordan Lee around nine. I let each one dry overnight.',
          'user': {'username': 'amara', 'name': 'Amara Osei'},
          'createdAt': ago(const Duration(hours: 1)),
        },
        {
          'id': 'c3',
          'body': 'Watching this at 2am is so calming',
          'user': {'username': 'daisy', 'name': 'Daisy Smith'},
          'createdAt': ago(const Duration(minutes: 45)),
        },
        {
          'id': 'c4',
          'body': 'Need to see this one in person',
          'user': {'username': 'cedric', 'name': 'Cedric Okafor'},
          'createdAt': ago(const Duration(minutes: 20)),
        },
      ];
    }

    Widget opener({ValueChanged<int>? onCount}) => Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => PieceCommentSheet.show(
            context,
            contentId: 's1',
            isScene: true,
            commentCount: 18,
            artistUsername: 'amara',
            overMedia: true,
            onCountChanged: onCount,
          ),
          child: const Text('open'),
        ),
      ),
    );

    testWidgets('title with the count, Artist label, Mono times, Reply fills @name', (tester) async {
      seed();
      setBoardViewport(tester);
      await tester.pumpWidget(_app(opener()));
      await tester.tap(find.text('open'));
      await _settle(tester);

      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('Artist'), findsOneWidget);
      expect(find.text('2h'), findsOneWidget);
      expect(tester.widget<Text>(find.text('2h')).style?.fontFamily, 'GeistMono');
      expect(find.text('Reply'), findsNWidgets(4));
      expect(find.text('Add a comment'), findsOneWidget);
      // No likes on comments.
      expect(find.byWidgetPredicate((w) => w is StudioIcon && w.asset == StudioIcons.like), findsNothing);

      await tester.tap(find.text('Reply').first);
      await tester.pump();
      expect(find.text('@Jordan Lee '), findsOneWidget);
    });

    testWidgets('press and hold someone else\'s comment to report it', (tester) async {
      seed();
      setBoardViewport(tester);
      await tester.pumpWidget(_app(opener()));
      await tester.tap(find.text('open'));
      await _settle(tester);
      await tester.longPress(find.text('Watching this at 2am is so calming'));
      await tester.pumpAndSettle();
      expect(find.text('Report comment'), findsOneWidget);
      expect(find.text('Block @daisy'), findsOneWidget);
    });

    testWidgets('posting adds one to the count', (tester) async {
      seed();
      int? count;
      setBoardViewport(tester);
      await tester.pumpWidget(_app(opener(onCount: (c) => count = c)));
      await tester.tap(find.text('open'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'So good');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send'));
      await _settle(tester);
      expect(count, 19);
      expect(find.text('19'), findsOneWidget);
      expect(find.text('So good'), findsOneWidget);
    });
  });

  group('goldens', () {
    final skip = Platform.environment['NEW_UI_GOLDENS'] != '1';
    Future<void> snap(WidgetTester tester, String name) async {
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
      await checkAcceptance(tester);
    }

    testWidgets('golden: SceneViewer', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_videoStill(_videoScene())));
      await _settle(tester);
      await snap(tester, 'SceneViewer');
    }, skip: skip);

    testWidgets('golden: SceneViewerPhoto', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_photoStill(_photoScene())));
      await _settle(tester);
      await snap(tester, 'SceneViewerPhoto');
    }, skip: skip);

    testWidgets('golden: ScenePiecesSheet', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_photoStill(_photoScene())));
      await _settle(tester);
      await tester.tap(find.text('2 linked pieces'));
      await tester.pumpAndSettle();
      await snap(tester, 'ScenePiecesSheet');
    }, skip: skip);

    testWidgets('golden: SceneComments', (tester) async {
      final now = DateTime.now().toUtc();
      String ago(Duration d) => now.subtract(d).toIso8601String();
      _server.comments = [
        {'id': 'c1', 'body': 'The teal underneath makes the whole thing glow. How many layers is this?', 'user': {'username': 'jordan', 'name': 'Jordan Lee'}, 'createdAt': ago(const Duration(hours: 2))},
        {'id': 'c2', 'body': '@Jordan Lee around nine. I let each one dry overnight.', 'user': {'username': 'amara', 'name': 'Amara Osei'}, 'createdAt': ago(const Duration(hours: 1))},
        {'id': 'c3', 'body': 'Watching this at 2am is so calming', 'user': {'username': 'daisy', 'name': 'Daisy Smith'}, 'createdAt': ago(const Duration(minutes: 45))},
        {'id': 'c4', 'body': 'Need to see this one in person', 'user': {'username': 'cedric', 'name': 'Cedric Okafor'}, 'createdAt': ago(const Duration(minutes: 20))},
      ];
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Stack(
              fit: StackFit.expand,
              children: [
                const _Wall(),
                Center(
                  child: TextButton(
                    onPressed: () => PieceCommentSheet.show(
                      context,
                      contentId: 's1',
                      isScene: true,
                      commentCount: 18,
                      artistUsername: 'amara',
                      overMedia: true,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
      await snap(tester, 'SceneComments');
    }, skip: skip);
  });
}
