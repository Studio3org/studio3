import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/address.dart';
import 'package:studio3/models/auction.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/collect_checkout.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/models/listing_details.dart';
import 'package:studio3/models/order.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/services/bid_service.dart' show SavedCard;
import 'package:studio3/models/shipping_quote.dart';
import 'package:studio3/models/user_profile.dart';
import 'package:studio3/screens/address_form_page.dart';
import 'package:studio3/screens/available_piece_detail_page.dart';
import 'package:studio3/screens/edit_piece_page.dart';
import 'package:studio3/screens/list_piece_flow.dart';
import 'package:studio3/screens/order_detail_page.dart';
import 'package:studio3/screens/selling_settings_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/api_exception.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/cache_service.dart';
import 'package:studio3/services/engagement_store.dart';
import 'package:studio3/services/post_publish_service.dart';
import 'package:studio3/services/push_router_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/piece_detail/collect_piece_sheet.dart';
import 'package:studio3/widgets/piece_detail/collect_shipping_method_sheet.dart';
import 'package:studio3/widgets/piece_detail/collected_bar.dart';
import 'package:studio3/widgets/piece_detail/shipping_quote_ready.dart';
import 'package:studio3/widgets/selling/pickup_address.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Phase 8 (FRONTEND_HANDOFF 8.1–8.4, plan Step 6): Convelio listing fields, the pickup address,
/// the piece page estimate, checkout with a live quote (pending, errors, flat fallback, pickup),
/// and tracking on the order. Against a fake server.

typedef _Req = ({String method, String path, Object? body, Map<String, dynamic> query});

class _Fake implements HttpClientAdapter {
  final requests = <_Req>[];

  /// `METHOD /path` → a list of (status, json) answered in turn; the last one repeats.
  final routes = <String, List<(int, Object)>>{};

  void on(String key, Object data, {int status = 200}) =>
      routes[key] = [(status, status < 300 ? {'success': true, 'data': data} : data)];

  void then(String key, Object data, {int status = 200}) =>
      (routes[key] ??= []).add((status, status < 300 ? {'success': true, 'data': data} : data));

  Iterable<_Req> to(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path, body: options.data, query: options.uri.queryParameters));
    final answers = routes['${options.method} $path'];
    var status = 200;
    Object json = {
      'success': true,
      'data': {'items': <Object>[], 'nextCursor': null},
    };
    if (answers != null && answers.isNotEmpty) {
      final (s, j) = answers.length > 1 ? answers.removeAt(0) : answers.first;
      status = s;
      json = j;
    } else if (options.method != 'GET') {
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

late _Fake _server;
final _launched = <String>[];

const _address = Address(
  id: 'a1',
  firstName: 'Jordan',
  lastName: 'Lee',
  phone: '2145550100',
  line1: '1 Main St',
  city: 'Dallas',
  state: 'TX',
  zip: '75201',
  isDefault: true,
);

Map<String, dynamic> _addressJson({String phone = '2145550100'}) => {
  'id': 'a1',
  'firstName': 'Jordan',
  'lastName': 'Lee',
  'phone': phone,
  'line1': '1 Main St',
  'city': 'Dallas',
  'state': 'TX',
  'zip': '75201',
  'country': 'US',
  'isDefault': true,
};

Map<String, dynamic> _quoteJson({String id = 'q1', String speed = 'regular_speed', bool pending = false}) => {
  'id': id,
  'status': pending ? 'processing' : 'created',
  'pending': pending,
  'speed': speed,
  'deliveryType': 'curbside',
  'insurance': true,
  'shippingCents': pending ? null : 34000,
  'insuranceCents': pending ? null : 2500,
  'totalShippingCents': pending ? null : 36500,
  'currency': 'USD',
  'reference': 'QVO-1',
};

const _liveOptions = {
  'methods': <Object>[],
  'live': true,
  'speeds': ['regular_speed', 'express'],
  'deliveryTypes': ['curbside', 'white_glove'],
  'insuranceDefault': true,
};

const _flatOptions = {
  'methods': [
    {'id': 'standard', 'cents': 18000},
    {'id': 'express', 'cents': 32000},
  ],
  'live': false,
};

Map<String, dynamic> _orderJson(String status, {Map<String, dynamic>? shipment, int insurance = 0}) => {
  'id': 'o1',
  'status': status,
  'artworkCents': 350000,
  'shippingCents': 36500,
  'insuranceCents': insurance,
  'deliveryType': 'curbside',
  'taxCents': 28875,
  'totalCents': 415375,
  'items': [
    {'pieceId': 'p1', 'priceCents': 350000, 'quantity': 1},
  ],
  'shippingAddress': _addressJson(),
  'shipment': ?shipment,
};

Map<String, dynamic> _shipment({String reached = 'in_transit', bool onHold = false}) {
  const keys = ['booked', 'picked_up', 'in_transit', 'out_for_delivery', 'delivered'];
  final at = keys.indexOf(reached);
  return {
    'provider': 'convelio',
    'providerStatus': onHold ? 'on_hold' : 'freight_in_transit',
    'status': 'in_transit',
    'courier': 'Convelio',
    'trackingNumber': 'CVO-123',
    'trackingUrl': 'https://track.example.test/CVO-123',
    'reference': 'CVO-123',
    'onHold': onHold,
    'cancelled': false,
    'steps': [
      for (var i = 0; i < keys.length; i++) {'key': keys[i], 'done': i <= at},
    ],
  };
}

const _item = FeedPreviewItem(
  id: 'p1',
  imageSeeds: [1],
  title: 'Bodies in Color',
  medium: 'Oil',
  year: 2025,
  dimensions: '24 × 36 in',
  story: '',
  handle: '@amara',
  authorUsername: 'amara',
  isAvailable: true,
  aspectRatio: FeedAspectRatio.portrait3x4,
  authorName: 'Amara Osei',
  priceCents: 350000,
  status: 'live',
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
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

Finder _button(String label) => find.widgetWithText(StudioButton, label);
StudioButton _buttonWidget(WidgetTester tester, String label) => tester.widget<StudioButton>(_button(label).last);

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: home,
    ),
  ),
);

/// A button that opens [open] and keeps what it returned.
class _Runner extends StatelessWidget {
  const _Runner(this.open);

  final Future<void> Function(BuildContext context) open;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: TextButton(onPressed: () => open(context), child: const Text('open'))));
}

final _files = Directory.systemTemp.createTempSync('studio3_convelio');

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

  setUp(() {
    _server = _Fake();
    _launched.clear();
    ApiClient.instance.debugUseAdapter(_server);
    AuthSession.instance.accessToken = 'token';
    AuthSession.instance.user = const AuthUser(
      username: 'jordanlee',
      name: 'Jordan Lee',
      email: 'jordan@email.com',
      onboardingComplete: true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        final args = call.arguments as Map;
        _launched.add(args['url'] as String);
        return true;
      },
    );
  });
  tearDown(() async {
    AuthSession.instance.accessToken = null;
    AuthSession.instance.user = null;
    EngagementStore.instance.clear();
    CollectShippingMethodSheet.pendingQuoteAddresses.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      null,
    );
    await CacheService.instance.clearAll();
  });

  group('models', () {
    test('piece: shipping fields, shippingReady and viewerOrder survive the cache', () {
      final piece = PieceSummary.fromJson({
        'id': 'p1',
        'title': 'T',
        'isForSale': true,
        'shippingItemType': 'fine_art.painting',
        'shippingPacking': 'wood_crated',
        'shippingMaterials': ['glass'],
        'shippingReady': {
          'ready': false,
          'missing': ['packed length', 'pickup address'],
        },
        'viewerOrder': {'id': 'o1', 'side': 'buyer', 'status': 'shipped', 'deliveryType': 'curbside', 'shipment': _shipment()},
      });
      expect(piece.shippingReady!.line, 'To ship, add: packed length, pickup address.');
      final again = PieceSummary.fromJson(piece.toJson());
      expect(again.shippingItemType, 'fine_art.painting');
      expect(again.shippingPacking, 'wood_crated');
      expect(again.shippingMaterials, ['glass']);
      expect(again.viewerOrder!.shipment!.steps, hasLength(5));
      final item = FeedPreviewItem.fromCacheJson(FeedPreviewItem.fromPieceSummary(piece).toJson());
      expect(item.shippingReady!.missing, ['packed length', 'pickup address']);
      expect(item.viewerOrder!.id, 'o1');
      expect(item.viewerOrder!.toOrder().shipment!.currentStepKey, 'in_transit');
    });

    test('order: insurance and delivery type; shipment steps and tracking', () {
      final order = Order.fromJson(_orderJson('shipped', shipment: _shipment(onHold: true), insurance: 2500));
      expect(order.insuranceCents, 2500);
      expect(order.deliveryType, 'curbside');
      expect(order.shipment!.trackingUrl, 'https://track.example.test/CVO-123');
      expect(order.shipment!.onHold, isTrue);
    });

    test('a phone the courier can call', () {
      expect(isValidPhone('(214) 555-0100'), isTrue);
      expect(isValidPhone('12145550100'), isTrue);
      expect(isValidPhone('+44 20 7946 0958'), isTrue);
      expect(isValidPhone('5550100'), isFalse);
      expect(isValidPhone('+1234'), isFalse);
      expect(isValidPhone(''), isFalse);
    });

    test('the selection sends a quote, a flat method, or pickup', () {
      const quote = ShippingQuote(id: 'q1', totalShippingCents: 36500, shippingCents: 34000, insuranceCents: 2500);
      expect(const CollectShippingSelection(address: _address, quote: quote).orderFields, {'quoteId': 'q1'});
      expect(
        const CollectShippingSelection(
          address: _address,
          method: CollectShippingMethod(id: 'standard', title: 'S', duration: '', priceCents: 1),
        ).orderFields,
        {'shippingMethod': 'standard'},
      );
      expect(const CollectShippingSelection(address: _address, pickup: true).orderFields, {'shippingMethod': 'pickup'});
    });

    test('a listing refusal naming the pickup address', () {
      expect(
        mentionsPickupAddress(
          'To sell this piece, add its package weight, pickup address (Settings, Selling). The courier prices shipping on them.',
        ),
        isTrue,
      );
      expect(mentionsPickupAddress('Medium is required for sale listings.'), isFalse);
    });

    test('shipping_quote_ready push carries its quote', () {
      final d = PushRouterService.destinationFor({
        'type': 'shipping_quote_ready',
        'targetType': 'piece',
        'targetId': 'p1',
        'quoteId': 'q9',
      });
      expect(d.id, 'p1');
      expect(d.quoteId, 'q9');
      // Without a quote: just the piece.
      expect(
        PushRouterService.destinationFor({'type': 'shipping_quote_ready', 'targetType': 'piece', 'targetId': 'p1'}).quoteId,
        isNull,
      );
    });
  });

  group('listing fields', () {
    test('saveDraft sends the packed size in cm, weight, value and the courier choices', () {
      final body = PostPublishService.pieceBody(
        const PostDraft(
          postType: 'piece',
          imagePaths: ['x'],
          isForSale: true,
          listingDetails: ListingDetails(
            priceUsd: 3600,
            weight: 10,
            packageLength: 30,
            packageWidth: 40,
            packageHeight: 5,
            declaredValueUsd: 4000,
            shippingItemType: 'fine_art.painting',
            shippingPacking: 'not_packed',
            shippingMaterials: ['framed_glass'],
          ),
        ),
        [
          {'mediaUrl': 'u', 'mediaAspectRatio': '3:4'},
        ],
      );
      expect(body['packageLengthCm'], closeTo(76.2, 0.001));
      expect(body['packageWidthCm'], closeTo(101.6, 0.001));
      expect(body['packageHeightCm'], closeTo(12.7, 0.001));
      expect(body['weightKg'], closeTo(4.536, 0.001));
      expect(body['declaredValueCents'], 400000);
      expect(body['shippingItemType'], 'fine_art.painting');
      expect(body['shippingPacking'], 'not_packed');
      expect(body['shippingMaterials'], ['framed_glass']);
    });

    test('not for sale sends none of it', () {
      final body = PostPublishService.pieceBody(
        const PostDraft(postType: 'piece', imagePaths: ['x'], listingDetails: ListingDetails(packageLength: 3)),
        [
          {'mediaUrl': 'u'},
        ],
      );
      expect(body.containsKey('packageLengthCm'), isFalse);
    });

    testWidgets('List it later sends them; a pickup-address refusal offers the screen', (tester) async {
      setBoardViewport(tester);
      final patches = <Map<String, dynamic>>[];
      var refuse = true;
      await tester.pumpWidget(
        _app(
          ListPricingPage(
            piece: const PieceSummary(id: 'p1', title: 'Bodies in Color', dimensions: '24x36 in'),
            details: const ListLaterDetails(
              dimensions: '24x36x1.5 in',
              weightKg: 3.629,
              framing: 'Unframed',
              shipping: {'packageLengthCm': 76.2, 'packageWidthCm': 101.6, 'packageHeightCm': 12.7, 'shippingPacking': 'wood_crated'},
            ),
            quote: (cents) async =>
                CommissionQuote(priceCents: cents, netCents: cents, commissionBps: 0, reducedRate: false),
            update: (id, body) async {
              patches.add(body);
              if (refuse) {
                throw ApiException(
                  'To sell this piece, add its pickup address (Settings, Selling). The courier prices shipping on them.',
                  statusCode: 400,
                );
              }
              return PieceSummary(id: id, title: 'Bodies in Color', isForSale: true, status: 'live');
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), '3600');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('List it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(patches.single, containsPair('packageLengthCm', 76.2));
      expect(patches.single, containsPair('shippingPacking', 'wood_crated'));
      expect(find.textContaining('add its pickup address'), findsOneWidget);
      expect(find.text('Pickup address'), findsOneWidget);
      refuse = false;
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('Edit piece: packed weight and size go with a listed piece; the refusal links the pickup address', (
      tester,
    ) async {
      setBoardViewport(tester, height: 2400);
      _server.on(
        'PATCH /api/pieces/p1',
        {'success': false, 'message': 'To sell this piece, add its pickup address (Settings, Selling).'},
        status: 400,
      );
      await tester.pumpWidget(
        _app(
          const EditPiecePage(
            piece: PieceSummary(
              id: 'p1',
              title: 'Bodies in Color',
              isForSale: true,
              priceCents: 350000,
              status: 'live',
              packageLengthCm: 76.2,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Packed size'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      final weight = find.descendant(
        of: find.byWidgetPredicate((w) => w is StudioUnderlineField && w.label == 'Weight'),
        matching: find.byType(TextField),
      );
      await tester.enterText(weight, '10');
      final cells = find.byType(TextField);
      final count = tester.widgetList(cells).length;
      // Packed L (prefilled), W, H come right after the weight.
      final weightIndex = tester.widgetList(cells).toList().indexOf(tester.widget(weight));
      expect(count, greaterThan(weightIndex + 3));
      await tester.enterText(cells.at(weightIndex + 2), '40');
      await tester.enterText(cells.at(weightIndex + 3), '5');
      await tester.pump();
      await _tap(tester, find.text('Save'));
      final patch = _server.to('PATCH', '/api/pieces/p1').single.body! as Map;
      expect(patch['packageLengthCm'], closeTo(76.2, 0.001));
      expect(patch['packageWidthCm'], closeTo(101.6, 0.001));
      expect(patch['packageHeightCm'], closeTo(12.7, 0.001));
      expect(patch['weightKg'], closeTo(4.536, 0.001));
      expect(find.textContaining('add its pickup address'), findsOneWidget);
      expect(find.text('Pickup address'), findsOneWidget);
    });
  });

  group('pickup address', () {
    testWidgets('Selling: the row shows the city or Add; picking one PUTs it; a 400 is toasted', (tester) async {
      setBoardViewport(tester);
      _server.on('GET /api/user/me/pickup-address', {'pickupAddress': null});
      _server.on('GET /api/user/me/addresses', [_addressJson()]);
      _server.on('PUT /api/user/me/pickup-address', {
        'success': false,
        'message': 'Add a phone number to this address: the courier calls it to arrange pickup.',
      }, status: 400);
      _server.then('PUT /api/user/me/pickup-address', {'pickupAddress': _addressJson()});
      await tester.pumpWidget(_app(const SellingSettingsPage(debugSellerTerms: SellerTerms())));
      await _settle(tester);
      expect(find.text('Pickup address'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);

      await _tap(tester, find.text('Pickup address'));
      expect(find.text('Pickup address'), findsWidgets);
      await _tap(tester, _button('Save and continue'));
      expect(_server.to('PUT', '/api/user/me/pickup-address').first.body, {'addressId': 'a1'});
      expect(
        find.text('Add a phone number to this address: the courier calls it to arrange pickup.'),
        findsOneWidget,
      );
      expect(find.text('Add'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));

      await _tap(tester, find.text('Pickup address'));
      await _tap(tester, _button('Save and continue'));
      expect(find.text('Dallas'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('an older server: no row', (tester) async {
      setBoardViewport(tester);
      _server.on('GET /api/user/me/pickup-address', {'success': false, 'message': 'Not found'}, status: 404);
      await tester.pumpWidget(_app(const SellingSettingsPage(debugSellerTerms: SellerTerms())));
      await _settle(tester);
      expect(find.text('Pickup address'), findsNothing);
    });
  });

  group('piece page', () {
    Map<String, dynamic> piece({Map<String, dynamic> extra = const {}}) => {
      'id': 'p1',
      'title': 'Bodies in Color',
      'status': 'live',
      'isForSale': true,
      'priceCents': 350000,
      'listingState': 'available',
      'mediaUrl': '',
      'author': {'username': 'amara', 'name': 'Amara Osei'},
      ...extra,
    };

    testWidgets('a buyer sees the shipping estimate, from their default address', (tester) async {
      setBoardViewport(tester, height: 1400);
      _server.on('GET /api/pieces/p1', piece());
      _server.on('GET /api/user/me/addresses', [_addressJson()]);
      _server.on('GET /api/pieces/p1/shipping-estimate', {
        'available': true,
        'source': 'table',
        'lowCents': 25000,
        'highCents': 60000,
        'currency': 'USD',
        'live': true,
      });
      await tester.pumpWidget(_app(const AvailablePieceDetailPage(item: _item)));
      await _settle(tester);
      final call = _server.to('GET', '/api/pieces/p1/shipping-estimate').single;
      expect(call.query, {'zip': '75201', 'state': 'TX'});
      expect(find.text('Shipping'), findsOneWidget);
      expect(find.text(r'About $250–$600'), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('no row when the artist has not added the size', (tester) async {
      setBoardViewport(tester, height: 1400);
      _server.on('GET /api/pieces/p1', piece());
      _server.on('GET /api/pieces/p1/shipping-estimate', {
        'available': false,
        'missing': ['weight'],
        'live': true,
      });
      await tester.pumpWidget(_app(const AvailablePieceDetailPage(item: _item)));
      await _settle(tester);
      expect(_server.to('GET', '/api/pieces/p1/shipping-estimate'), hasLength(1));
      expect(find.textContaining('About '), findsNothing);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('the artist sees what is missing to ship, and no estimate', (tester) async {
      setBoardViewport(tester, height: 1400);
      AuthSession.instance.user = const AuthUser(username: 'amara', name: 'Amara Osei', email: 'a@x.test');
      _server.on(
        'GET /api/pieces/p1',
        piece(
          extra: {
            'shippingReady': {
              'ready': false,
              'missing': ['packed length', 'pickup address'],
            },
          },
        ),
      );
      await tester.pumpWidget(_app(const AvailablePieceDetailPage(item: _item)));
      await _settle(tester);
      expect(find.text('To ship, add: packed length, pickup address.'), findsOneWidget);
      expect(_server.to('GET', '/api/pieces/p1/shipping-estimate'), isEmpty);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('a collected piece uses its viewerOrder for the delivery card', (tester) async {
      setBoardViewport(tester, height: 1400);
      _server.on(
        'GET /api/pieces/p1',
        piece(
          extra: {
            'status': 'sold',
            'listingState': 'collected',
            'viewerOrder': {'id': 'o1', 'side': 'buyer', 'status': 'shipped', 'shipment': _shipment(reached: 'out_for_delivery')},
          },
        ),
      );
      await tester.pumpWidget(_app(AvailablePieceDetailPage(item: _item.copyWith(status: 'sold'))));
      await _settle(tester);
      expect(find.byType(PieceDeliveryCard), findsOneWidget);
      expect(find.text('Out for delivery'), findsWidgets);
      expect(_server.to('GET', '/api/user/me/orders'), isEmpty);
      await tester.pump(const Duration(seconds: 11));
    });
  });

  group('checkout', () {
    Future<CollectShippingSelection?> openMethods(WidgetTester tester, {VoidCallback? onMessageArtist}) async {
      CollectShippingSelection? picked;
      setBoardViewport(tester, height: 1100);
      await tester.pumpWidget(
        _app(
          _Runner(
            (context) async => picked = await CollectShippingMethodSheet.show(
              context,
              pieceId: 'p1',
              address: _address,
              onMessageArtist: onMessageArtist,
            ),
          ),
        ),
      );
      await _tap(tester, find.text('open'));
      return picked;
    }

    testWidgets('live: speed, delivery, insurance; the quote with its shipping and insurance; '
        'a changed choice quotes again', (tester) async {
      _server.on('GET /api/pieces/p1/shipping-quote', _liveOptions);
      _server.on('POST /api/pieces/p1/shipping-quotes', _quoteJson(), status: 201);
      CollectShippingSelection? picked;
      setBoardViewport(tester, height: 1100);
      await tester.pumpWidget(
        _app(
          _Runner(
            (context) async =>
                picked = await CollectShippingMethodSheet.show(context, pieceId: 'p1', address: _address),
          ),
        ),
      );
      await _tap(tester, find.text('open'));
      for (final t in ['Speed', 'Regular', 'Express', 'Delivery', 'Curbside', 'White-glove', 'Insurance']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      expect(find.text('Standard Shipping'), findsNothing);
      expect(find.byType(StudioSwitch), findsOneWidget);
      final first = _server.to('POST', '/api/pieces/p1/shipping-quotes').single;
      expect(first.body, {'addressId': 'a1', 'speed': 'regular_speed', 'deliveryType': 'curbside', 'insurance': true});
      expect(find.text(r'$340.00'), findsOneWidget);
      expect(find.text(r'$25.00'), findsOneWidget);
      expect(_buttonWidget(tester, 'Continue').onPressed, isNotNull);

      // Express drops the quote; Get a quote asks again.
      _server.on('POST /api/pieces/p1/shipping-quotes', _quoteJson(id: 'q2', speed: 'express'), status: 201);
      await _tap(tester, find.text('Express'));
      expect(_button('Get a quote'), findsOneWidget);
      await _tap(tester, find.byWidgetPredicate((w) => w is StudioSwitch));
      await _tap(tester, _button('Get a quote'));
      final second = _server.to('POST', '/api/pieces/p1/shipping-quotes').last;
      expect(second.body, {'addressId': 'a1', 'speed': 'express', 'deliveryType': 'curbside', 'insurance': false});
      await _tap(tester, _button('Continue'));
      expect(picked!.quote!.id, 'q2');
      expect(picked!.method, isNull);
      expect(picked!.title, 'Express · Curbside');
    });

    testWidgets('flat tiers when Convelio is off: no quote is asked', (tester) async {
      _server.on('GET /api/pieces/p1/shipping-quote', _flatOptions);
      await openMethods(tester);
      expect(find.text('Standard Shipping'), findsOneWidget);
      expect(find.text('Speed'), findsNothing);
      expect(_server.to('POST', '/api/pieces/p1/shipping-quotes'), isEmpty);
    });

    testWidgets('pending: priced by hand, we will notify; Continue stays off', (tester) async {
      _server.on('GET /api/pieces/p1/shipping-quote', _liveOptions);
      _server.on('POST /api/pieces/p1/shipping-quotes', _quoteJson(pending: true), status: 201);
      await openMethods(tester);
      expect(find.text("Shipping quote on its way — we'll notify you"), findsOneWidget);
      expect(_buttonWidget(tester, 'Continue').onPressed, isNull);
      expect(CollectShippingMethodSheet.pendingQuoteAddresses['q1']?.id, 'a1');
    });

    for (final (status, message) in [
      (409, "Live shipping quotes aren't switched on yet."),
      (503, "Shipping isn't set up yet."),
    ]) {
      testWidgets('$status "$message": the flat tiers instead', (tester) async {
        _server.on('GET /api/pieces/p1/shipping-quote', _liveOptions);
        _server.then('GET /api/pieces/p1/shipping-quote', _flatOptions);
        _server.on('POST /api/pieces/p1/shipping-quotes', {'success': false, 'message': message}, status: status);
        await openMethods(tester);
        expect(_server.to('GET', '/api/pieces/p1/shipping-quote'), hasLength(2));
        expect(find.text('Standard Shipping'), findsOneWidget);
        expect(find.text('Speed'), findsNothing);
        expect(_buttonWidget(tester, 'Continue').onPressed, isNotNull);
      });
    }

    testWidgets("the artist's 409: shown, with Message the artist", (tester) async {
      _server.on('GET /api/pieces/p1/shipping-quote', _liveOptions);
      const message = "The artist needs to add this piece's packed length, weight before it can ship.";
      _server.on('POST /api/pieces/p1/shipping-quotes', {'success': false, 'message': message}, status: 409);
      var messaged = 0;
      await openMethods(tester, onMessageArtist: () => messaged++);
      expect(find.text(message), findsOneWidget);
      await _tap(tester, _button('Message the artist'));
      expect(messaged, 1);
      expect(find.byType(CollectShippingMethodSheet), findsNothing);
    });

    testWidgets("the buyer's contact details: the address editor, then a fresh quote", (tester) async {
      _server.on('GET /api/pieces/p1/shipping-quote', _liveOptions);
      _server.on(
        'POST /api/pieces/p1/shipping-quotes',
        {'success': false, 'message': "The buyer's contact details need: phone."},
        status: 409,
      );
      _server.then('POST /api/pieces/p1/shipping-quotes', _quoteJson(), status: 201);
      _server.on('PATCH /api/user/me/addresses/a1', _addressJson(phone: '2145550199'));
      _server.on('GET /api/user/me/addresses', [_addressJson(phone: '2145550199')]);
      await openMethods(tester);
      expect(find.byType(AddressFormPage), findsOneWidget);
      await _tap(tester, _button('Save address'));
      expect(_server.to('PATCH', '/api/user/me/addresses/a1'), hasLength(1));
      expect(find.byType(AddressFormPage), findsNothing);
      expect(_server.to('POST', '/api/pieces/p1/shipping-quotes'), hasLength(2));
      expect(find.text(r'$340.00'), findsOneWidget);
    });

    Future<void> openCheckout(
      WidgetTester tester, {
      CollectShippingSelection? shipping,
      AuctionSummary? auction,
    }) async {
      setBoardViewport(tester, height: 1100);
      await tester.pumpWidget(
        _app(
          _Runner(
            (context) => showStudioSheet<void>(
              context: context,
              builder: (_) => CollectPieceSheet(
                item: _item,
                auction: auction,
                initialShipping: shipping,
                debugCard: auction == null ? null : const SavedCard(id: 'pm1', brand: 'visa', last4: '4242'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    const quote = ShippingQuote(
      id: 'q1',
      speed: 'regular_speed',
      deliveryType: 'white_glove',
      shippingCents: 34000,
      insuranceCents: 2500,
      totalShippingCents: 36500,
    );

    testWidgets('the summary shows shipping and insurance; collect sends the quote, not a method', (tester) async {
      _server.on('POST /api/pieces/p1/collect', _orderJson('pending_payment'));
      _server.on('POST /api/orders/o1/confirm', _orderJson('paid'));
      await openCheckout(tester, shipping: const CollectShippingSelection(address: _address, quote: quote));
      expect(find.text('Regular · White-glove · Dallas, TX'), findsOneWidget);
      expect(find.text(r'$340.00'), findsOneWidget);
      expect(find.text('Insurance'), findsOneWidget);
      expect(find.text(r'$25.00'), findsOneWidget);
      await _tap(tester, _button('Collect this piece'));
      expect(_server.to('POST', '/api/pieces/p1/collect').single.body, {'addressId': 'a1', 'quoteId': 'q1'});
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('flat shipping: no Insurance line', (tester) async {
      await openCheckout(
        tester,
        shipping: const CollectShippingSelection(
          address: _address,
          method: CollectShippingMethod(id: 'standard', title: 'Standard Shipping', duration: '', priceCents: 18000),
        ),
      );
      expect(find.text('Insurance'), findsNothing);
    });

    const won = AuctionSummary(
      auctionId: 'au1',
      status: 'awaiting_payment',
      startingBidCents: 100000,
      bidCount: 3,
      minNextBidCents: 0,
      isWinner: true,
      winningBidCents: 350000,
    );

    testWidgets('auction checkout sends the quote', (tester) async {
      _server.on('POST /api/pieces/p1/auction-checkout', {..._orderJson('paid'), 'balanceDueCents': 0});
      _server.on('GET /api/orders/o1', _orderJson('paid'));
      await openCheckout(tester, auction: won, shipping: const CollectShippingSelection(address: _address, quote: quote));
      await _tap(tester, _button('Pay and collect'));
      expect(_server.to('POST', '/api/pieces/p1/auction-checkout').single.body, {'addressId': 'a1', 'quoteId': 'q1'});
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('pickup at the event: a billing address, no quote, shippingMethod pickup', (tester) async {
      _server.on('GET /api/user/me/addresses', [_addressJson()]);
      _server.on('POST /api/pieces/p1/auction-checkout', {..._orderJson('paid'), 'balanceDueCents': 0});
      _server.on('GET /api/orders/o1', _orderJson('paid'));
      const pickupWin = AuctionSummary(
        auctionId: 'au1',
        status: 'awaiting_payment',
        startingBidCents: 100000,
        bidCount: 3,
        minNextBidCents: 0,
        isWinner: true,
        winningBidCents: 350000,
        deliveryMode: 'pickup',
      );
      await openCheckout(tester, auction: pickupWin);
      await _tap(tester, find.text('Add a delivery address'));
      expect(find.text('Billing address'), findsOneWidget);
      await _tap(tester, _button('Save and continue'));
      expect(find.byType(CollectShippingMethodSheet), findsNothing);
      expect(_server.to('GET', '/api/pieces/p1/shipping-quote'), isEmpty);
      expect(find.text('Pickup at the event · Dallas, TX'), findsOneWidget);
      await _tap(tester, _button('Pay and collect'));
      expect(
        _server.to('POST', '/api/pieces/p1/auction-checkout').single.body,
        {'addressId': 'a1', 'shippingMethod': 'pickup'},
      );
      await tester.pump(const Duration(seconds: 11));
    });
    testWidgets('shipping_quote_ready: the piece, then checkout on the quote', (tester) async {
      setBoardViewport(tester, height: 1100);
      _server.on('GET /api/pieces/p1', {
        'id': 'p1',
        'title': 'Bodies in Color',
        'status': 'live',
        'isForSale': true,
        'priceCents': 350000,
        'listingState': 'available',
        'mediaUrl': '',
        'author': {'username': 'amara', 'name': 'Amara Osei'},
      });
      _server.on('GET /api/shipping-quotes/q1', {..._quoteJson(), 'status': 'ready'});
      _server.on('GET /api/user/me/addresses', [_addressJson()]);
      await tester.pumpWidget(
        _app(_Runner((context) => openShippingQuoteReady(context, pieceId: 'p1', quoteId: 'q1'))),
      );
      await _tap(tester, find.text('open'));
      await _settle(tester);
      expect(find.byType(AvailablePieceDetailPage), findsOneWidget);
      expect(find.byType(CollectPieceSheet), findsOneWidget);
      expect(find.text('Regular · Curbside · Dallas, TX'), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });
  });

  group('tracking', () {
    test('the 5 Convelio steps on the 4 dots', () {
      OrderShipment at(String key) => OrderShipment.fromJson(_shipment(reached: key));
      expect(PieceDelivery.trackerStep(at('booked')), 1);
      expect(PieceDelivery.trackerStep(at('picked_up')), 2);
      expect(PieceDelivery.trackerStep(at('in_transit')), 2);
      expect(PieceDelivery.trackerStep(at('out_for_delivery')), 2);
      expect(PieceDelivery.trackerStep(at('delivered')), 3);
      expect(
        PieceDelivery.trackerStep(const OrderShipment(courier: 'X', trackingNumber: '1', status: 'in_transit')),
        isNull,
      );
    });

    test('on hold goes in the label slot', () {
      final order = Order.fromJson(_orderJson('shipped', shipment: _shipment(onHold: true)));
      final card = PieceDelivery.fromOrder(order, forArtist: false, artistName: 'Amara Osei')!;
      expect(card.label, 'On hold');
      expect(card.labelLate, isTrue);
      expect(card.step, 2);
    });

    testWidgets('order detail: the tracker, the reference, Track shipment, the Insurance line', (tester) async {
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(
        _app(
          OrderDetailPage(
            orderId: 'o1',
            debugOrder: Order.fromJson(_orderJson('shipped', shipment: _shipment(), insurance: 2500)),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(DeliveryTracker), findsOneWidget);
      expect(find.text('CVO-123'), findsOneWidget);
      expect(find.text('Insurance'), findsOneWidget);
      expect(find.text(r'$25.00'), findsOneWidget);
      expect(find.text(r'$340.00'), findsOneWidget);
      await _tap(tester, _button('Track shipment'));
      expect(_launched, ['https://track.example.test/CVO-123']);
    });

    testWidgets('an older order: no Shipping section', (tester) async {
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(
        _app(
          OrderDetailPage(
            orderId: 'o1',
            debugOrder: Order.fromJson(
              _orderJson('shipped', shipment: {'courier': 'UPS', 'trackingNumber': '1Z', 'status': 'in_transit'}),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(DeliveryTracker), findsNothing);
      expect(_button('Track shipment'), findsNothing);
      expect(find.text('Insurance'), findsNothing);
    });

    testWidgets('delivered: Confirm received, the 7-day line, Report an issue', (tester) async {
      setBoardViewport(tester, height: 1400);
      _server.on('POST /api/orders/o1/confirm-received', _orderJson('completed', shipment: _shipment(reached: 'delivered')));
      await tester.pumpWidget(
        _app(
          OrderDetailPage(
            orderId: 'o1',
            debugOrder: Order.fromJson(_orderJson('awaiting_confirmation', shipment: _shipment(reached: 'delivered'))),
          ),
        ),
      );
      await tester.pump();
      expect(_buttonWidget(tester, 'Confirm received').variant, StudioButtonVariant.primary);
      expect(find.text('or it completes automatically in 7 days'), findsOneWidget);
      expect(_buttonWidget(tester, 'Report an issue').variant, StudioButtonVariant.outline);
      await _tap(tester, _button('Confirm received'));
      expect(_server.to('POST', '/api/orders/o1/confirm-received'), hasLength(1));
      expect(_button('Confirm received'), findsNothing);
      await tester.pump(const Duration(seconds: 11));
    });
  });
}
