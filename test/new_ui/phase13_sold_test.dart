import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/models/order.dart';
import 'package:studio3/screens/available_piece_detail_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/cache_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/piece_detail/collected_bar.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Phase 13, 17.6 (docs/new-ui/NEW_UI_EXECUTION_PLAN.md): the sold piece page for everyone,
/// for the collector (delivery card) and for the artist (pickup card), against a fake server.

const _viewer = {'id': 'u1', 'username': 'jordanlee', 'name': 'Jordan Lee', 'email': 'jordan@email.com'};
const _artist = {'id': 'u2', 'username': 'amarasart', 'name': 'Amara Osei', 'email': 'amara@email.com'};

Map<String, dynamic> _pieceJson() => {
  'id': 'p1',
  'title': 'Bodies in Color I',
  'status': 'sold',
  'isForSale': true,
  'priceCents': 350000,
  'listingState': 'collected',
  'medium': 'Oil on canvas',
  'styleTags': ['Figurative'],
  'dimensions': '24 × 36 × 1.5 in',
  'yearCreated': 2025,
  'caption':
      'Started this one trying to paint skin as light rather than surface. The teal came first, everything else had to answer to it.',
  'materials': ['Oil paint, Winsor & Newton', 'Linen canvas, Claessens', 'Filbert brushes, Rosemary & Co'],
  'framingMounting': 'Unframed',
  'mediaUrl': '',
  'author': {'username': 'amarasart', 'name': 'Amara Osei'},
};

Map<String, dynamic> _order({String status = 'shipped', Map<String, dynamic>? shipment, String piece = 'p1'}) => {
  'id': 'o1',
  'status': status,
  'items': [
    {'pieceId': piece, 'priceCents': 350000, 'quantity': 1},
  ],
  'artworkCents': 350000,
  'shippingCents': 0,
  'taxCents': 0,
  'totalCents': 350000,
  'createdAt': '2026-11-01T10:00:00Z',
  'shipment': ?shipment,
};

class _Fake implements HttpClientAdapter {
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> sales = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    Object json;
    var code = 200;
    if (options.method == 'GET' && path == '/api/pieces/p1') {
      json = {'success': true, 'data': _pieceJson()};
    } else if (options.method == 'GET' && path == '/api/user/me/orders') {
      json = {'success': true, 'data': {'items': orders, 'nextCursor': null}};
    } else if (options.method == 'GET' && path == '/api/user/me/sales') {
      json = {'success': true, 'data': {'items': sales, 'nextCursor': null}};
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

FeedPreviewItem _item() => FeedPreviewItem(
  id: 'p1',
  imageSeeds: const [1],
  title: 'Bodies in Color I',
  medium: 'Oil on canvas',
  year: 2025,
  dimensions: '24 × 36 × 1.5 in',
  story:
      'Started this one trying to paint skin as light rather than surface. The teal came first, everything else had to answer to it.',
  handle: '@amarasart',
  authorUsername: 'amarasart',
  isAvailable: true,
  aspectRatio: FeedAspectRatio.portrait3x4,
  authorName: 'Amara Osei',
  priceCents: 350000,
  status: 'sold',
  materials: const ['Oil paint, Winsor & Newton', 'Linen canvas, Claessens', 'Filbert brushes, Rosemary & Co'],
  framingNote: 'Unframed',
  styleTags: const ['Figurative'],
  seriesName: 'Bodies in Color',
  seriesThumbs: const [1, 2, 3],
  seriesPieceCount: 6,
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pump(WidgetTester tester, {double height = 1700}) async {
  setBoardViewport(tester, height: height);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: AvailablePieceDetailPage(item: _item()),
        ),
      ),
    ),
  );
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    await loadStudioFonts();
    dotenv.loadFromString(envString: '', isOptional: true);
    final tmp = Directory.systemTemp.createTempSync('sold_piece').path;
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

  group('the card from the order', () {
    Order order(Map<String, dynamic> json) => Order.fromJson(json);

    test('collector: paid, packed, on its way, delivered; gone once confirmed', () {
      PieceDelivery? card(Map<String, dynamic> json) =>
          PieceDelivery.fromOrder(order(json), forArtist: false, artistName: 'Amara Osei');
      expect(card(_order(status: 'paid'))!.step, 0);
      expect(card(_order(status: 'paid'))!.heading, 'Being packed');
      expect(card(_order(status: 'paid', shipment: {'courier': 'Convelio', 'trackingNumber': 'CV1', 'status': 'label_created'}))!.step, 1);
      final moving = card(_order(shipment: {'courier': 'Convelio', 'trackingNumber': 'CV1', 'status': 'in_transit', 'shipmentDate': '2026-11-08T12:00:00Z'}))!;
      expect(moving.step, 2);
      expect(moving.heading, 'On its way');
      expect(moving.title, 'Shipped Nov 8');
      expect(moving.detail, 'Convelio picked it up from Amara. Tracking CV1.');
      expect(moving.linkLabel, 'Message Amara');
      expect(moving.label, isNull);
      final delivered = card(_order(status: 'awaiting_confirmation'))!;
      expect(delivered.step, 3);
      expect(delivered.detail, 'Confirm you got it so Amara gets paid.');
      expect(card(_order(status: 'completed')), isNull);
      expect(card(_order(status: 'refunded')), isNull);
    });

    test('artist: pack it, label ready, picked up; gone once delivered', () {
      PieceDelivery? card(Map<String, dynamic> json) =>
          PieceDelivery.fromOrder(order(json), forArtist: true, artistName: 'Amara Osei');
      final fresh = card(_order(status: 'paid'))!;
      expect(fresh.heading, 'Pack it for pickup');
      expect(fresh.linkLabel, 'See shipping steps');
      expect(card(_order(status: 'paid', shipment: {'courier': 'Convelio', 'trackingNumber': '', 'status': 'label_created'}))!.title, 'Label ready');
      expect(card(_order(shipment: {'courier': 'Convelio', 'trackingNumber': '', 'status': 'picked_up'}))!.step, 2);
      expect(card(_order(status: 'awaiting_confirmation')), isNull);
    });
  });

  testWidgets('everyone: Collected and Message, no price, no Collect, no Details', (tester) async {
    await _pump(tester);
    expect(find.byType(CollectedButton), findsOneWidget);
    expect(find.text(r'$3,500'), findsNothing);
    expect(find.text('Collect'), findsNothing);
    expect(find.text('Details'), findsNothing);
    expect(find.text('Unframed'), findsNothing);
    expect(find.bySemanticsLabel('Message the artist'), findsOneWidget);
    expect(find.byType(PieceDeliveryCard), findsNothing);
    expect(find.bySemanticsLabel('Save'), findsOneWidget);
    // Let the page's first-load timers run out.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('collector: the delivery card in place of Collected, no Save, Message Amara', (tester) async {
    _server.orders = [
      _order(shipment: {'courier': 'Convelio', 'trackingNumber': 'CV1', 'status': 'in_transit'}),
      _order(piece: 'other'),
    ];
    await _pump(tester);
    expect(find.byType(PieceDeliveryCard), findsOneWidget);
    expect(find.byType(CollectedButton), findsNothing);
    expect(find.text('On its way'), findsWidgets);
    expect(find.text('Message Amara'), findsOneWidget);
    expect(find.bySemanticsLabel('Save'), findsNothing);
    expect(find.bySemanticsLabel('Shipped, now'), findsOneWidget);
    expect(find.bySemanticsLabel('Packed, done'), findsOneWidget);
  });

  testWidgets('collector after confirming: back to Collected with message', (tester) async {
    _server.orders = [_order(status: 'completed')];
    await _pump(tester);
    expect(find.byType(CollectedButton), findsOneWidget);
    expect(find.byType(PieceDeliveryCard), findsNothing);
  });

  testWidgets('artist: Your work, the pickup card and See shipping steps, no message button', (tester) async {
    AuthSession.instance.user = AuthUser.fromJson(_artist);
    _server.sales = [_order(status: 'paid')];
    await _pump(tester);
    expect(find.text('Your work'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
    expect(find.text('Pack it for pickup'), findsOneWidget);
    expect(find.text('See shipping steps'), findsOneWidget);
    expect(find.bySemanticsLabel('Message the artist'), findsNothing);
    expect(find.bySemanticsLabel('Label ready'), findsOneWidget);
  });

  testWidgets('dark: the card follows the theme', (tester) async {
    _server.orders = [_order(status: 'paid')];
    setBoardViewport(tester, height: 1700);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: AvailablePieceDetailPage(item: _item()),
          ),
        ),
      ),
    );
    await _settle(tester);
    final heading = tester.widget<Text>(find.text('Being packed'));
    expect(heading.style?.color, StudioColors.dark.textPrimary);
    expect(tester.takeException(), isNull);
  });

  group('goldens', () {
    final skip = Platform.environment['NEW_UI_GOLDENS'] != '1';
    Future<void> snap(WidgetTester tester, String name) async {
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
      // Let the image cache's cleanup timer run out.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 11));
    }

    testWidgets('golden: PieceCollected', (tester) async {
      await _pump(tester);
      await snap(tester, 'PieceCollected');
    }, skip: skip);

    testWidgets('golden: PieceCollectedOwner', (tester) async {
      _server.orders = [
        _order(shipment: {'courier': 'Convelio', 'trackingNumber': '', 'status': 'in_transit'}),
      ];
      await _pump(tester);
      await snap(tester, 'PieceCollectedOwner');
    }, skip: skip);

    testWidgets('golden: PieceCollectedArtist', (tester) async {
      AuthSession.instance.user = AuthUser.fromJson(_artist);
      _server.sales = [
        _order(shipment: {'courier': 'Convelio', 'trackingNumber': '', 'status': 'label_created'}),
      ];
      await _pump(tester);
      await snap(tester, 'PieceCollectedArtist');
    }, skip: skip);
  });
}
