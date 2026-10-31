import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/feed_item.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/models/post_summary.dart';
import 'package:studio3/screens/behind_the_work_page.dart';
import 'package:studio3/screens/series_view_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/cache_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Phase 13, 17.7 (docs/new-ui/NEW_UI_EXECUTION_PLAN.md): the series page and Behind the
/// work, See all, against a fake server.

const _viewer = {'id': 'u1', 'username': 'jordanlee', 'name': 'Jordan Lee', 'email': 'jordan@email.com'};
const _artist = {'id': 'u2', 'username': 'amarasart', 'name': 'Amara Osei', 'email': 'amara@email.com'};

final _endsAt = DateTime.now().toUtc().add(const Duration(hours: 6, minutes: 30));

Map<String, dynamic> _piece(String id, String title, String created, Map<String, dynamic> extra) => {
  'id': id,
  'title': title,
  'mediaUrl': '',
  'createdAt': created,
  'author': {'username': 'amarasart', 'name': 'Amara Osei'},
  ...extra,
};

List<Map<String, dynamic>> _seriesPieces() => [
  _piece('p1', 'Bodies in Color I', '2026-10-20T10:00:00Z', {'status': 'live', 'isForSale': true, 'priceCents': 350000, 'listingState': 'available'}),
  _piece('p2', 'Bodies in Color II', '2026-10-18T10:00:00Z', {'status': 'sold', 'isForSale': true, 'listingState': 'collected'}),
  _piece('p3', 'Bodies in Color III', '2026-10-16T10:00:00Z', {'status': 'live', 'isForSale': false}),
  _piece('p4', 'Bodies in Color IV', '2026-10-14T10:00:00Z', {
    'status': 'live',
    'isForSale': true,
    'listingType': 'auction',
    'listingState': 'auction_live',
    'highestBidCents': 130000,
    'auctionEndsAt': _endsAt.toIso8601String(),
  }),
  _piece('p5', 'Old draft', '2026-10-25T10:00:00Z', {'status': 'draft'}),
];

Map<String, dynamic> _scene(String id, String name, {String? linked, String caption = '', bool video = true}) => {
  'type': 'post',
  'id': id,
  'caption': caption,
  'mediaUrl': '',
  'mediaType': video ? 'video' : 'image',
  'author': {'username': name.toLowerCase().replaceAll(' ', ''), 'name': name},
  'linkedPieceIds': [?linked],
};

class _Fake implements HttpClientAdapter {
  final requests = <String>[];
  List<Map<String, dynamic>> feed = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add(path);
    Object json;
    var code = 200;
    if (path == '/api/series/s1') {
      json = {
        'success': true,
        'data': {
          'id': 's1',
          'name': 'Bodies in Color',
          'description':
              'A study of skin under colored light. Each piece started from the same pose, painted at a different hour, so the color does the talking instead of the figure.',
          'pieceCount': 5,
          'pieceIds': ['p1', 'p2', 'p3', 'p4', 'p5'],
          'pieces': _seriesPieces(),
          'author': {'username': 'amarasart', 'name': 'Amara Osei'},
        },
      };
    } else if (path == '/api/users/amarasart/posts') {
      json = {
        'success': true,
        'data': [
          _scene('s-a', 'Amara Osei', linked: 'p1'),
          _scene('s-b', 'Amara Osei', linked: 'p2'),
          _scene('s-c', 'Amara Osei', linked: 'elsewhere'),
          _scene('s-d', 'Amara Osei', linked: 'p4', video: false),
        ],
      };
    } else if (path == '/api/user/amarasart') {
      json = {
        'success': true,
        'data': {'username': 'amarasart', 'name': 'Amara Osei', 'isFollowing': false},
      };
    } else if (path == '/api/feed/explore') {
      json = {'success': true, 'data': {'items': feed, 'nextCursor': null}};
    } else if (path.startsWith('/api/pieces/')) {
      json = {
        'success': true,
        'data': _piece(path.split('/').last, 'Linked', '2026-10-01T00:00:00Z', {'status': 'live'}),
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
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 300));
}

/// Lets the image cache's cleanup timer run out before the test ends.
Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 11));
}

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: home,
    ),
  ),
);

FeedItem _shelfItem(String id, String name, {String caption = ''}) =>
    FeedItem.post(PostSummary(id: id, mediaType: 'video', authorName: name, authorUsername: name.toLowerCase(), caption: caption));

void main() {
  setUpAll(() async {
    await loadStudioFonts();
    dotenv.loadFromString(envString: '', isOptional: true);
    final tmp = Directory.systemTemp.createTempSync('browse').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  late AuthUser? wasUser;
  late String? wasToken;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheService.instance.clearAll();
    _server = _Fake();
    ApiClient.instance.debugUseAdapter(_server);
    wasUser = AuthSession.instance.user;
    wasToken = AuthSession.instance.accessToken;
    AuthSession.instance.user = AuthUser.fromJson(_viewer);
    AuthSession.instance.accessToken = 'token';
  });
  tearDown(() {
    AuthSession.instance.user = wasUser;
    AuthSession.instance.accessToken = wasToken;
  });

  group('Series page', () {
    testWidgets('header, Follow, description, pieces newest first with their status', (tester) async {
      setBoardViewport(tester, height: 1500);
      await tester.pumpWidget(_app(const SeriesViewPage(seriesId: 's1')));
      await _settle(tester);

      expect(find.text('SERIES · 4 PIECES'), findsOneWidget);
      expect(find.text('Bodies in Color'), findsOneWidget);
      expect(find.text('Amara Osei'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Edit series'), findsNothing);
      expect(find.textContaining('A study of skin'), findsOneWidget);
      // Someone else's draft is not shown.
      expect(find.text('Old draft'), findsNothing);
      expect(find.text(r'Available · $3,500'), findsOneWidget);
      expect(find.byType(StudioStatusChip), findsOneWidget);
      expect(find.text('Collected'), findsOneWidget);
      expect(find.textContaining(r'Bid $1,300 · 6h'), findsOneWidget);
      // Not for sale: no chip, no line.
      expect(find.text('Not for sale'), findsNothing);
      // Newest first.
      final y1 = tester.getTopLeft(find.text('Bodies in Color I')).dy;
      final y3 = tester.getTopLeft(find.text('Bodies in Color III')).dy;
      expect(y1, lessThan(y3));
      // Behind this series: Scenes linked to its pieces only.
      expect(find.text('Behind this series'), findsOneWidget);
      expect(find.bySemanticsLabel('Scene'), findsNWidgets(3));
      await _drain(tester);
    });

    testWidgets('Available keeps pieces people can buy', (tester) async {
      setBoardViewport(tester, height: 1500);
      await tester.pumpWidget(_app(const SeriesViewPage(seriesId: 's1')));
      await _settle(tester);
      await tester.tap(find.text('Available'));
      await tester.pump();
      expect(find.text('Bodies in Color I'), findsOneWidget);
      expect(find.text('Bodies in Color IV'), findsOneWidget);
      expect(find.text('Bodies in Color II'), findsNothing);
      expect(find.text('Bodies in Color III'), findsNothing);
      await _drain(tester);
    });

    testWidgets('the artist sees Edit series in place of Follow', (tester) async {
      AuthSession.instance.user = AuthUser.fromJson(_artist);
      setBoardViewport(tester, height: 1500);
      await tester.pumpWidget(_app(const SeriesViewPage(seriesId: 's1')));
      await _settle(tester);
      expect(find.text('Edit series'), findsOneWidget);
      expect(find.text('Follow'), findsNothing);
      // Their own draft stays visible to them.
      expect(find.text('Old draft'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('dark follows the theme', (tester) async {
      setBoardViewport(tester, height: 1500);
      await tester.pumpWidget(_app(const SeriesViewPage(seriesId: 's1'), dark: true));
      await _settle(tester);
      expect(tester.widget<Text>(find.text('Bodies in Color')).style?.color, StudioColors.dark.textPrimary);
      expect(tester.takeException(), isNull);
      await _drain(tester);
    });
  });

  group('Behind the work', () {
    testWidgets('the shelf order first, then more Scenes; artist strips and linked thumbnails', (tester) async {
      _server.feed = [
        _scene('a', 'Amara Osei', linked: 'p9'),
        _scene('new', 'Daisy Smith'),
      ];
      setBoardViewport(tester, height: 1220);
      await tester.pumpWidget(
        _app(BehindTheWorkPage(initialItems: [_shelfItem('a', 'Amara Osei'), _shelfItem('b', 'Cedric Okafor')])),
      );
      await _settle(tester);
      expect(find.text('Behind the work'), findsOneWidget);
      expect(find.text('Studios, process, and art out in the world.'), findsOneWidget);
      final cards = tester.widgetList<BehindTheWorkCard>(find.byType(BehindTheWorkCard)).map((c) => c.item.id);
      expect(cards, ['a', 'b', 'new']);
      expect(find.text('Cedric Okafor'), findsOneWidget);
      expect(find.bySemanticsLabel('Back to Explore'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('search looks at Scenes only (caption and artist)', (tester) async {
      setBoardViewport(tester, height: 1220);
      await tester.pumpWidget(
        _app(
          BehindTheWorkPage(
            initialItems: [
              _shelfItem('a', 'Amara Osei', caption: 'Priming the big canvas'),
              _shelfItem('b', 'Cedric Okafor', caption: 'Kiln day'),
            ],
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.bySemanticsLabel('Search Behind the work'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'kiln');
      await tester.pump();
      expect(find.byType(BehindTheWorkCard), findsOneWidget);
      expect(find.text('Cedric Okafor'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'nothing like this');
      await tester.pump();
      expect(find.text('No Scenes match'), findsOneWidget);
      await _drain(tester);
    });
  });

  testWidgets('status line for an auction with no bids uses the starting bid', (tester) async {
    final piece = PieceSummary.fromJson(
      _piece('x', 'X', '2026-10-01T00:00:00Z', {
        'status': 'live',
        'isForSale': true,
        'listingType': 'auction',
        'listingState': 'auction_live',
        'startingBidCents': 50000,
      }),
    );
    await tester.pumpWidget(_app(Scaffold(body: SeriesPieceStatus(piece: piece))));
    expect(find.text(r'Bid $500'), findsOneWidget);
  });

  group('goldens', () {
    final skip = Platform.environment['NEW_UI_GOLDENS'] != '1';
    Future<void> snap(WidgetTester tester, String name) async {
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
      await checkAcceptance(tester);
      await _drain(tester);
    }

    testWidgets('golden: SeriesPage', (tester) async {
      setBoardViewport(tester, height: 1500);
      await tester.pumpWidget(_app(const SeriesViewPage(seriesId: 's1')));
      await _settle(tester);
      await snap(tester, 'SeriesPage');
    }, skip: skip);

    testWidgets('golden: BehindTheWork', (tester) async {
      _server.feed = [
        for (final (id, name) in [('a', 'Amara Osei'), ('b', 'Cedric Okafor'), ('c', 'Daisy Smith'), ('d', 'Jordan Lee'), ('e', 'Cedric Okafor'), ('f', 'Amara Osei')])
          _scene(id, name, linked: id == 'a' || id == 'b' || id == 'e' ? 'p1' : null, video: id != 'c' && id != 'e'),
      ];
      setBoardViewport(tester, height: 1220);
      await tester.pumpWidget(_app(const BehindTheWorkPage()));
      await _settle(tester);
      await snap(tester, 'BehindTheWork');
    }, skip: skip);
  });
}
