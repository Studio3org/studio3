import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/feed_item.dart';
import 'package:studio3/models/series_summary.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/home_feed_page.dart';
import 'package:studio3/screens/reels_page.dart' show routeObserver;
import 'package:studio3/screens/series_view_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/home_feed/home_feed_widgets.dart';

import 'golden_harness.dart';

/// The home feed page end to end (`Main`, docs/new-ui/NEW_UI_EXECUTION_PLAN.md Phase 5): the
/// real `HomeFeedStore` and `FeedService` against a fake server — paging, the Available tab,
/// coming back from a piece, a failed first load, a Scene's shape, the series row.

Map<String, dynamic> _piece(String id, {String? state = 'available', bool forSale = true}) => {
  'type': 'piece',
  'id': id,
  'title': 'Piece $id',
  'mediaUrl': '',
  'isForSale': forSale,
  'status': state == 'collected' ? 'sold' : 'live',
  'listingState': ?state,
  'author': {'username': 'amara', 'name': 'Amara Osei'},
};

class _Fake implements HttpClientAdapter {
  /// cursor ('' for the first) → the page.
  final pages = <String, Map<String, dynamic>>{};
  final feedRequests = <String>[];
  var failFirst = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    if (options.uri.path == '/api/feed/for-you') {
      final cursor = options.uri.queryParameters['cursor'] ?? '';
      feedRequests.add(cursor);
      if (cursor.isEmpty && failFirst > 0) {
        failFirst--;
        return _json({'success': false, 'message': 'down'}, 500);
      }
      return _json({'success': true, 'data': pages[cursor] ?? {'items': [], 'nextCursor': null}}, 200);
    }
    return _json({'success': false, 'message': 'no route'}, 404);
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

late _Fake _server;

Widget _home(HomeFeedStore store) => MaterialApp(
  theme: AppTheme.light,
  navigatorObservers: [routeObserver],
  home: HomePage(store: store),
);

Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}

Iterable<String> _shownTitles(WidgetTester tester) => tester
    .widgetList<FeedPieceCard>(find.byType(FeedPieceCard, skipOffstage: false))
    .map((c) => c.item.title ?? '');

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
    ApiClient.instance.debugUseAdapter(_server);
  });

  testWidgets('scrolling to the end asks for the next page with its cursor', (tester) async {
    setBoardViewport(tester);
    _server.pages[''] = {
      'items': [for (var i = 1; i <= 6; i++) _piece('a$i')],
      'nextCursor': 'c2',
    };
    _server.pages['c2'] = {
      'items': [for (var i = 1; i <= 3; i++) _piece('b$i')],
      'nextCursor': null,
    };
    final store = HomeFeedStore();
    await tester.pumpWidget(_home(store));
    await _settle(tester);
    expect(_server.feedRequests, ['']);
    await tester.fling(find.byType(ListView), const Offset(0, -6000), 3000);
    await _settle(tester);
    expect(_server.feedRequests, ['', 'c2']);
    expect(store.apiItems.map((i) => i.id), [for (var i = 1; i <= 6; i++) 'a$i', 'b1', 'b2', 'b3']);
    // The last page has no cursor: nothing more is asked for.
    await tester.fling(find.byType(ListView), const Offset(0, -6000), 3000);
    await _settle(tester);
    expect(_server.feedRequests, ['', 'c2']);
    store.dispose();
  });

  testWidgets('Available shows what can be collected now, and loads pages until there is some', (tester) async {
    setBoardViewport(tester);
    _server.pages[''] = {
      'items': [
        _piece('sold', state: 'collected'), // still isForSale on the server
        _piece('nfs', state: null, forSale: false),
        _piece('open'),
      ],
      'nextCursor': 'c2',
    };
    _server.pages['c2'] = {
      'items': [
        {..._piece('bid', state: 'auction_live'), 'listingType': 'auction'},
        _piece('won', state: 'auction_ended'),
      ],
      'nextCursor': null,
    };
    final store = HomeFeedStore();
    await tester.pumpWidget(_home(store));
    await _settle(tester);
    // All: three full-height pieces already fill the screen.
    expect(_server.feedRequests, ['']);

    // Available has one piece on page 1, too few to scroll, so it fetches the next page itself.
    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Available').last);
    await _settle(tester);
    expect(_server.feedRequests, ['', 'c2']);
    expect(_shownTitles(tester).toList(), ['Piece open', 'Piece bid']);
    store.dispose();
  });

  testWidgets('coming back from a piece keeps the pages already scrolled through', (tester) async {
    setBoardViewport(tester);
    _server.pages[''] = {
      'items': [for (var i = 1; i <= 6; i++) _piece('a$i')],
      'nextCursor': 'c2',
    };
    _server.pages['c2'] = {
      'items': [for (var i = 1; i <= 6; i++) _piece('b$i')],
      'nextCursor': null,
    };
    final store = HomeFeedStore();
    await tester.pumpWidget(_home(store));
    await _settle(tester);
    await tester.fling(find.byType(ListView), const Offset(0, -6000), 3000);
    await _settle(tester);
    expect(store.apiItems, hasLength(12));

    // Open something, then come back while far down the feed.
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('piece'))));
    await tester.pumpAndSettle();
    nav.pop();
    await _settle(tester);
    expect(store.apiItems, hasLength(12));
    expect(_server.feedRequests.where((c) => c.isEmpty), hasLength(1));

    // Back at the top, coming back refreshes.
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await tester.pump();
    nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('piece'))));
    await tester.pumpAndSettle();
    nav.pop();
    await _settle(tester);
    expect(_server.feedRequests.where((c) => c.isEmpty), hasLength(2));
    store.dispose();
  });

  testWidgets("a failed first load says so, with Try again", (tester) async {
    setBoardViewport(tester);
    _server.failFirst = 1;
    _server.pages[''] = {
      'items': [_piece('a1')],
      'nextCursor': null,
    };
    final store = HomeFeedStore();
    await tester.pumpWidget(_home(store));
    await _settle(tester);
    expect(find.text("Couldn't load your feed"), findsOneWidget);
    expect(find.text('No feed items yet'), findsNothing);
    await tester.tap(find.text('Try again'));
    await _settle(tester);
    expect(find.text('Piece a1'), findsOneWidget);
    store.dispose();
  });

  testWidgets('a landscape Scene keeps its shape; a piece is 3:4', (tester) async {
    setBoardViewport(tester, height: 1600);
    final scene = FeedItem.fromJson(const {
      'type': 'post',
      'id': 's1',
      'mediaUrl': '',
      'mediaType': 'image',
      'mediaAspectRatio': '16:9',
      'caption': 'In the studio',
      'author': {'username': 'amara', 'name': 'Amara Osei'},
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            children: [
              FeedPieceCard(item: scene, onTap: () {}),
              FeedPieceCard(item: FeedItem.fromJson(_piece('p1')), onTap: () {}),
            ],
          ),
        ),
      ),
    );
    final ratios = tester.widgetList<AspectRatio>(find.byType(AspectRatio)).map((a) => a.aspectRatio).toList();
    expect(ratios, [173 / 130, 3 / 4]);
  });

  testWidgets('the series row opens the series, not the profile', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: FeedSeriesRow(
              artistName: 'Amara Osei',
              artistUsername: 'amara',
              series: PieceSeriesInfo(
                id: 'series-1',
                name: 'Paper Planes',
                pieceIds: const ['a', 'b', 'c'],
                previewPieces: const [SeriesPreviewPiece(id: 'a', title: 'Paper Planes I')],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('See all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final page = tester.widget<SeriesViewPage>(find.byType(SeriesViewPage));
    expect((page.seriesId, page.initialName, page.initialPieceCount), ('series-1', 'Paper Planes', 3));
  });

  testWidgets('golden: Main', (tester) async {
    setBoardViewport(tester, height: 3000);
    Map<String, dynamic> piece(String id, String name, String? title, {String? state, int photos = 1, Map<String, dynamic>? series}) => {
      ..._piece(id, state: state, forSale: state != null),
      'title': title,
      'author': {'username': name.toLowerCase().split(' ').first, 'name': name},
      if (photos > 1) 'images': [for (var i = 0; i < photos; i++) {'mediaUrl': 'https://example.test/$id-$i.jpg'}],
      'series': ?series,
    };
    _server.pages[''] = {
      'items': [
        piece('p1', 'Amara Osei', 'Bodies in Color', state: 'available'),
        piece('p2', 'Cedric Okafor', 'Companion Bloom', photos: 4),
        piece(
          'p3',
          'Daisy Smith',
          null,
          photos: 4,
          series: {
            'id': 'series-1',
            'name': 'Paper Planes',
            'pieceIds': ['a', 'b', 'c', 'd', 'e'],
            'previewPieces': [
              {'id': 'a', 'title': 'Paper Planes I'},
              {'id': 'b', 'title': 'Paper Planes II'},
            ],
          },
        ),
        piece('p4', 'Cedric Okafor', '[Piece title]', state: 'available'),
      ],
      'nextCursor': null,
    };
    final store = HomeFeedStore();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        navigatorObservers: [routeObserver],
        home: HomePage(
          store: store,
          debugFeedEvent: StudioEvent(
            id: 'ev1',
            title: '[Event name]',
            startsAt: DateTime(2037, 10, 29, 20, 51),
            endsAt: DateTime(2037, 10, 29, 23, 51),
            venueName: 'Dec on Dragon',
            description: '[One line on what the night is]',
            artists: const [
              EventPerson(username: 'amara', name: 'Amara Osei'),
              EventPerson(username: 'cedric', name: 'Cedric Okafor'),
              EventPerson(username: 'daisy', name: 'Daisy Smith'),
              EventPerson(username: 'eli', name: 'Eli'),
              EventPerson(username: 'fay', name: 'Fay'),
              EventPerson(username: 'gus', name: 'Gus'),
            ],
          ),
        ),
      ),
    );
    await _settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/Main.png'));
    await checkAcceptance(tester);
    store.dispose();
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
