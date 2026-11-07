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
import 'package:studio3/widgets/home_feed/feed_event_card.dart';
import 'package:studio3/widgets/home_feed/home_feed_widgets.dart';
import 'package:studio3/widgets/studio/studio.dart';

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

  /// Every request's path, and the feed's `include` asks.
  final paths = <String>[];
  final includes = <String?>[];

  /// `?available=1` pages by cursor (BACKEND_CHANGES B29). Null plays a server without the
  /// filter: it answers with [pages].
  Map<String, Map<String, dynamic>>? availablePages;

  /// The cursors Available asked with ('' for the first).
  final availableRequests = <String>[];

  /// What the Events tab returns (Home's own pick when the feed has no event card).
  Map<String, dynamic>? browse;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    paths.add(options.uri.path);
    if (options.uri.path == '/api/events/browse' && browse != null) {
      return _json({'success': true, 'data': browse}, 200);
    }
    if (options.uri.path.startsWith('/api/events/ev')) {
      return _json({'success': true, 'data': _event(options.uri.pathSegments.last, 'From the detail')}, 200);
    }
    if (options.uri.path == '/api/feed/for-you' && options.uri.queryParameters['available'] == '1') {
      final cursor = options.uri.queryParameters['cursor'] ?? '';
      availableRequests.add(cursor);
      final page = (availablePages ?? pages)[cursor] ?? {'items': [], 'nextCursor': null};
      return _json({'success': true, 'data': page}, 200);
    }
    if (options.uri.path == '/api/feed/for-you') {
      final cursor = options.uri.queryParameters['cursor'] ?? '';
      feedRequests.add(cursor);
      includes.add(options.uri.queryParameters['include']);
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

/// An event card in two days at Dec on Dragon.
Map<String, dynamic> _event(String id, String title) {
  final starts = DateTime.now().toUtc().add(const Duration(days: 2));
  return {
    'id': id,
    'title': title,
    'status': 'published',
    'startsAt': starts.toIso8601String(),
    'endsAt': starts.add(const Duration(hours: 3)).toIso8601String(),
    'venueName': 'Dec on Dragon',
    'hostUsername': 'amara',
  };
}

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

  testWidgets('Available on a server without the filter: what can be collected now, loading pages until '
      'there is some', (tester) async {
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
    // Its first page, then the next one it asks for itself: two round trips.
    await _settle(tester);
    await _settle(tester);
    expect(_server.feedRequests, ['']);
    expect(_server.availableRequests, ['', 'c2']);
    expect(_shownTitles(tester).toList(), ['Piece open', 'Piece bid']);
    store.dispose();
  });

  testWidgets("Available (B29) asks the server's filter for its own pages and pages on with its cursor",
      (tester) async {
    setBoardViewport(tester);
    _server.pages[''] = {
      'items': [_piece('open'), _piece('sold', state: 'collected'), _piece('other')],
      'nextCursor': 'c2',
    };
    _server.availablePages = {
      '': {
        'items': [for (var i = 1; i <= 6; i++) _piece('v$i')],
        'nextCursor': 'v2',
      },
      'v2': {
        'items': [{..._piece('bid', state: 'auction_live'), 'listingType': 'auction'}],
        'nextCursor': null,
      },
    };
    final store = HomeFeedStore();
    await tester.pumpWidget(_home(store));
    await _settle(tester);
    expect(_server.availableRequests, isEmpty, reason: 'only once Available is opened');

    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Available').last);
    await _settle(tester);
    expect(_server.availableRequests, ['']);
    expect(_shownTitles(tester).first, 'Piece v1');
    expect(store.availableItems.map((i) => i.id), [for (var i = 1; i <= 6; i++) 'v$i']);

    await tester.fling(find.byType(ListView), const Offset(0, -6000), 3000);
    await _settle(tester);
    expect(_server.availableRequests, ['', 'v2']);
    expect(store.availableItems.last.id, 'bid');
    // All's own pages are untouched.
    expect(_server.feedRequests, ['']);
    expect(store.apiItems.map((i) => i.id), ['open', 'sold', 'other']);
    store.dispose();
  });

  testWidgets('a series row from the feed (B29): each card shows its chip, and the photo count when '
      'there is more than one', (tester) async {
    setBoardViewport(tester, height: 2400);
    _server.pages[''] = {
      'items': [
        {
          ..._piece('p1'),
          'images': [
            {'mediaUrl': 'https://example.test/1.jpg'},
            {'mediaUrl': 'https://example.test/2.jpg'},
          ],
          'series': {
            'id': 'series-1',
            'name': 'Paper Planes',
            'pieceIds': ['p1', 'p2'],
            'previewPieces': [
              {'id': 'p1', 'title': 'Paper Planes I', 'listingState': 'available', 'imageCount': 3},
              {'id': 'p2', 'title': 'Paper Planes II', 'listingState': 'collected', 'imageCount': 1},
            ],
          },
        },
      ],
      'nextCursor': null,
    };
    final store = HomeFeedStore();
    await tester.pumpWidget(_home(store));
    await _settle(tester);

    final row = find.byType(FeedSeriesRow);
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Paper Planes I')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('3')), findsOneWidget, reason: 'three photos');
    final chips = tester.widgetList<StudioStatusChip>(find.descendant(of: row, matching: find.byType(StudioStatusChip)));
    expect([for (final c in chips) (c.status, c.onImage)], [
      (StudioStatus.available, true),
      (StudioStatus.collected, true),
    ]);
    expect(find.bySemanticsLabel('Paper Planes I, Available, 3 photos'), findsOneWidget);
    // The piece itself swipes between its two photos: dots under it.
    expect(store.apiItems.single.imageUrls, hasLength(2));
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

  testWidgets("the feed's own event card (B27): asked for, after the third row, not a piece; "
      'the Events tab is not asked', (tester) async {
    setBoardViewport(tester, height: 4000);
    _server.pages[''] = {
      'items': [
        for (var i = 1; i <= 3; i++) _piece('a$i'),
        {'type': 'event', 'event': _event('ev9', 'Open Studio Night')},
        for (var i = 4; i <= 6; i++) _piece('a$i'),
      ],
      'nextCursor': null,
    };
    final store = HomeFeedStore();
    await tester.pumpWidget(_home(store));
    await _settle(tester);

    expect(_server.includes.first, 'events');
    expect(store.apiItems.map((i) => i.id), [for (var i = 1; i <= 6; i++) 'a$i'], reason: 'the event is not a piece');
    expect(store.feedEvent?.id, 'ev9');
    final card = tester.widget<FeedEventCard>(find.byType(FeedEventCard));
    expect(card.event.id, 'ev9');
    // The detail fills in the lineup; the Events tab is never asked.
    expect(_server.paths, contains('/api/events/ev9'));
    expect(_server.paths, isNot(contains('/api/events/browse')));
    // After the third piece.
    final third = tester.getTopLeft(find.byWidgetPredicate((w) => w is FeedPieceCard && w.item.id == 'a3'));
    final fourth = tester.getTopLeft(find.byWidgetPredicate((w) => w is FeedPieceCard && w.item.id == 'a4'));
    final event = tester.getTopLeft(find.byType(FeedEventCard));
    expect(event.dy, greaterThan(third.dy));
    expect(event.dy, lessThan(fourth.dy));
    store.dispose();
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('Home opened after the feed has loaded shows its event card at once', (tester) async {
    setBoardViewport(tester, height: 4000);
    _server.pages[''] = {
      'items': [
        for (var i = 1; i <= 3; i++) _piece('a$i'),
        {'type': 'event', 'event': _event('ev9', 'Open Studio Night')},
      ],
      'nextCursor': null,
    };
    final store = HomeFeedStore()..ensureInitialized();
    await tester.pumpWidget(const SizedBox());
    await _settle(tester);
    expect(store.loading, isFalse);
    await tester.pumpWidget(_home(store));
    expect(tester.takeException(), isNull);
    await _settle(tester);
    expect(tester.widget<FeedEventCard>(find.byType(FeedEventCard)).event.id, 'ev9');
    expect(_server.paths, isNot(contains('/api/events/browse')));
    store.dispose();
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('no event card in the feed (an older server): Home picks one from the Events tab', (tester) async {
    setBoardViewport(tester, height: 4000);
    _server.pages[''] = {
      'items': [for (var i = 1; i <= 6; i++) _piece('a$i')],
      'nextCursor': null,
    };
    _server.browse = {
      'today': [],
      'following': [],
      'upcoming': [_event('ev7', 'Gallery Walk')],
      'categories': [],
    };
    final store = HomeFeedStore();
    await tester.pumpWidget(_home(store));
    await _settle(tester);

    expect(store.feedEvent, isNull);
    expect(_server.paths, contains('/api/events/browse'));
    expect(tester.widget<FeedEventCard>(find.byType(FeedEventCard)).event.id, 'ev7');
    store.dispose();
    await tester.pump(const Duration(seconds: 11));
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
