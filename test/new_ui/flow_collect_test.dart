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
import 'package:studio3/screens/address_form_page.dart';
import 'package:studio3/screens/available_piece_detail_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/cache_service.dart';
import 'package:studio3/services/engagement_store.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/piece_detail/collect_order_confirmation_sheet.dart';
import 'package:studio3/widgets/piece_detail/collect_payment_sheet.dart';
import 'package:studio3/widgets/piece_detail/collect_piece_sheet.dart';
import 'package:studio3/widgets/piece_detail/collect_shipping_method_sheet.dart';
import 'package:studio3/widgets/piece_detail/collect_shipping_sheet.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Flow regression 19.2, piece page → collect → address → shipping → payment → confirmation
/// (docs/new-ui/NEW_UI_EXECUTION_PLAN.md), in light and dark: the real piece page and checkout
/// sheets against a fake server, signed in as jordanlee with no saved address yet.
///
/// Payment is not charged in the app yet (Stripe pending, plan 0.3): the method is picked and
/// shown, and a debug build confirms the order with the server's test-mode confirm, as before.

Map<String, dynamic> _pieceJson() => {
  'id': 'p1',
  'title': 'Bodies in Color',
  'status': 'live',
  'isForSale': true,
  'priceCents': 350000,
  'listingState': 'available',
  'mediaUrl': '',
  'author': {'username': 'amara', 'name': 'Amara Osei', 'isFollowing': false},
};

Map<String, dynamic> _orderJson(String status) => {
  'id': 'o1',
  'buyerId': 'u-jordan',
  'sellerId': 'u-amara',
  'status': status,
  'shippingMethod': 'express',
  'artworkCents': 350000,
  'shippingCents': 32000,
  'taxCents': 28875,
  'totalCents': 410875,
  'items': [
    {'pieceId': 'p1', 'priceCents': 350000, 'quantity': 1},
  ],
  'devMode': true,
  'createdAt': DateTime.utc(2026, 11, 6, 15).toIso8601String(),
  'updatedAt': DateTime.utc(2026, 11, 6, 15).toIso8601String(),
};

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body, String? auth})>[];
  final addresses = <Map<String, dynamic>>[];
  var failCollect = 0;

  Iterable<({String method, String path, Object? body, String? auth})> to(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path, body: options.data, auth: options.headers['Authorization'] as String?));
    Object json = {'success': true, 'data': {}};
    var status = 200;
    switch ('${options.method} $path') {
      case 'GET /api/pieces/p1':
        json = {'success': true, 'data': _pieceJson()};
      case 'GET /api/user/me/addresses':
        json = {'success': true, 'data': addresses};
      case 'POST /api/user/me/addresses':
        final saved = {...(options.data as Map<String, dynamic>), 'id': 'a1', 'isDefault': true};
        addresses.add(saved);
        json = {'success': true, 'data': saved};
      case 'GET /api/pieces/p1/shipping-quote':
        json = {
          'success': true,
          'data': {
            'methods': [
              {'id': 'standard', 'cents': 18000},
              {'id': 'express', 'cents': 32000},
            ],
          },
        };
      case 'POST /api/pieces/p1/collect':
        if (failCollect > 0) {
          failCollect--;
          status = 409;
          json = {'success': false, 'message': 'Someone is checking out this piece right now.'};
        } else {
          json = {'success': true, 'data': _orderJson('pending_payment')};
        }
      case 'POST /api/orders/o1/confirm':
        json = {'success': true, 'data': _orderJson('paid')};
      default:
        if (options.method == 'GET') {
          json = {
            'success': true,
            'data': {'items': <Object>[], 'nextCursor': null},
          };
        } else {
          status = 404;
          json = {'success': false, 'message': 'no route'};
        }
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

const _item = FeedPreviewItem(
  id: 'p1',
  imageSeeds: [1],
  title: 'Bodies in Color',
  medium: 'Oil on canvas',
  year: 2025,
  dimensions: '24 × 36 in',
  story: 'Skin as light rather than surface.',
  handle: '@amara',
  authorUsername: 'amara',
  authorName: 'Amara Osei',
  isAvailable: true,
  aspectRatio: FeedAspectRatio.portrait3x4,
  priceCents: 350000,
  status: 'live',
);

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

Finder _button(String label) => find.widgetWithText(StudioButton, label);

StudioButton _buttonWidget(WidgetTester tester, String label) => tester.widget<StudioButton>(_button(label).last);

Future<void> _type(WidgetTester tester, String label, String text) async {
  final field = find.descendant(of: find.widgetWithText(StudioUnderlineField, label), matching: find.byType(TextField));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

/// The checkout summary's value for [label] ("Artwork", "Shipping", "Sales tax", "Total").
String _summary(WidgetTester tester, String label) {
  final row = find.ancestor(of: find.text(label).last, matching: find.byType(Row)).first;
  final texts = tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))).toList();
  return texts.last.data!;
}

Widget _app({required bool dark}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  routes: {'/orders': (_) => const Scaffold(body: Text('Purchases page'))},
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: const AvailablePieceDetailPage(item: _item),
    ),
  ),
);

/// This file's own folder for the app's files (created once): test files run side by side and
/// must not share the cache.
final _files = Directory.systemTemp.createTempSync('studio3_flow_collect');

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
    ApiClient.instance.debugUseAdapter(_server);
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
    EngagementStore.instance.clear();
    await CacheService.instance.clearAll();
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('collect ($theme): checkout, a new address, express shipping, Apple Pay, a refused '
        'collect, then the confirmation and Purchases', (tester) async {
      setBoardViewport(tester, height: 1000);
      await tester.pumpWidget(_app(dark: dark));
      await _settle(tester);

      // The piece page: Collect opens checkout, nothing chosen yet.
      await _tap(tester, _button('Collect'));
      expect(find.byType(CollectPieceSheet), findsOneWidget);
      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Add a delivery address'), findsOneWidget);
      expect(find.text('Add a payment method'), findsOneWidget);
      expect(_summary(tester, 'Artwork'), r'$3,500.00');
      expect(_summary(tester, 'Total'), '–');
      expect(find.text('Shipping and tax are added once you enter an address.'), findsOneWidget);
      expect(_buttonWidget(tester, 'Collect this piece').onPressed, isNull);

      // Shipping: no saved address, so add one.
      await _tap(tester, find.text('Add a delivery address'));
      expect(find.byType(CollectShippingSheet), findsOneWidget);
      expect(_server.to('GET', '/api/user/me/addresses'), hasLength(1));
      expect(find.text('No saved addresses yet. Add one to continue.'), findsOneWidget);
      expect(_buttonWidget(tester, 'Save and continue').onPressed, isNull);
      await _tap(tester, find.text('Add a new address'));
      expect(find.byType(AddressFormPage), findsOneWidget);

      await _type(tester, 'First name', 'Jordan');
      await _type(tester, 'Last name', 'Lee');
      await _type(tester, 'Street address', '4521 Lovers Ln');
      await _type(tester, 'City', 'Dallas');
      await _tap(tester, find.widgetWithText(StudioUnderlineField, 'State'));
      await _tap(tester, find.text('TX'));
      await _type(tester, 'ZIP', '75225');
      await _type(tester, 'Phone', '2145550100');
      await _tap(tester, _button('Save address'));
      final created = _server.to('POST', '/api/user/me/addresses').single;
      expect(created.auth, 'Bearer token');
      expect(created.body, containsPair('line1', '4521 Lovers Ln'));
      expect(created.body, containsPair('state', 'TX'));
      expect(created.body, containsPair('zip', '75225'));
      expect(find.byType(AddressFormPage), findsNothing);

      // Back on the address list: the new one is chosen.
      expect(find.text('Jordan Lee'), findsOneWidget);
      expect(_buttonWidget(tester, 'Save and continue').onPressed, isNotNull);
      await _tap(tester, _button('Save and continue'));

      // The shipping quotes for this piece, to that address.
      expect(find.byType(CollectShippingMethodSheet), findsOneWidget);
      expect(_server.to('GET', '/api/pieces/p1/shipping-quote'), hasLength(1));
      expect(find.text('Ship to'), findsOneWidget);
      expect(find.text('Jordan Lee, 4521 Lovers Ln'), findsOneWidget);
      expect(find.text('Standard Shipping'), findsOneWidget);
      await _tap(tester, find.text('Express Shipping'));
      await _tap(tester, _button('Continue'));

      // Checkout now has the address and the full breakdown.
      expect(find.byType(CollectShippingMethodSheet), findsNothing);
      expect(find.text('Express Shipping · Dallas, TX'), findsOneWidget);
      expect(_summary(tester, 'Shipping'), r'$320.00');
      expect(_summary(tester, 'Sales tax'), r'$288.75');
      expect(_summary(tester, 'Total'), r'$4,108.75');
      expect(_buttonWidget(tester, 'Collect this piece').onPressed, isNotNull);

      // Payment: Apple Pay.
      await _tap(tester, find.text('Add a payment method'));
      expect(find.byType(CollectPaymentSheet), findsOneWidget);
      await _tap(tester, find.text('Apple Pay'));
      await _tap(tester, _button('Save and next'));
      expect(find.text('Apple Pay'), findsOneWidget);

      // A collect the server refuses says why and keeps checkout, ready to try again.
      _server.failCollect = 1;
      await _tap(tester, _button('Collect this piece'));
      expect(find.text('Someone is checking out this piece right now.'), findsOneWidget);
      expect(find.byType(CollectPieceSheet), findsOneWidget);
      expect(_server.to('POST', '/api/orders/o1/confirm'), isEmpty);
      expect(_buttonWidget(tester, 'Collect this piece').onPressed, isNotNull);
      await tester.pump(const Duration(seconds: 5));

      // Then it goes: the order with the address and method, then the confirm.
      await _tap(tester, _button('Collect this piece'));
      final collects = _server.to('POST', '/api/pieces/p1/collect').toList();
      expect(collects, hasLength(2));
      expect(collects.last.body, {'addressId': 'a1', 'shippingMethod': 'express'});
      expect(collects.last.auth, 'Bearer token');
      expect(_server.to('POST', '/api/orders/o1/confirm'), hasLength(1));

      // The confirmation.
      expect(find.byType(CollectPieceSheet), findsNothing);
      expect(find.byType(CollectOrderConfirmationSheet), findsOneWidget);
      expect(find.text('Bodies in Color is yours'), findsOneWidget);
      expect(find.text('By Amara Osei.'), findsOneWidget);
      expect(find.text('Test mode — no real payment was captured.'), findsOneWidget);
      await _tap(tester, _button('View your orders'));
      expect(find.byType(CollectOrderConfirmationSheet), findsNothing);
      expect(find.text('Purchases page'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
    });
  }

  testWidgets('a saved address is chosen already; Change on the shipping step goes back to the list', (
    tester,
  ) async {
    _server.addresses.add({
      'id': 'a9',
      'label': 'Studio',
      'firstName': 'Jordan',
      'lastName': 'Lee',
      'phone': '2145550100',
      'line1': '12 Elm St',
      'city': 'Austin',
      'state': 'TX',
      'zip': '78701',
      'isDefault': true,
    });
    setBoardViewport(tester, height: 1000);
    await tester.pumpWidget(_app(dark: false));
    await _settle(tester);
    await _tap(tester, _button('Collect'));
    await _tap(tester, find.text('Add a delivery address'));
    expect(find.text('Studio'), findsOneWidget);
    expect(_buttonWidget(tester, 'Save and continue').onPressed, isNotNull);
    await _tap(tester, _button('Save and continue'));
    expect(find.text('Jordan Lee, 12 Elm St'), findsOneWidget);
    await _tap(tester, find.text('Change'));
    expect(find.byType(CollectShippingSheet), findsOneWidget);
    await _tap(tester, _button('Save and continue'));
    // Standard is chosen first.
    await _tap(tester, _button('Continue'));
    expect(find.text('Standard Shipping · Austin, TX'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 11));
  });
}
