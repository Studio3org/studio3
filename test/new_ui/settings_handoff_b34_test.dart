import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/order.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/models/user_profile.dart';
import 'package:studio3/screens/account_settings_page.dart';
import 'package:studio3/screens/delete_account_page.dart';
import 'package:studio3/screens/my_sales_page.dart';
import 'package:studio3/screens/profile/widgets/profile_collection_grid.dart';
import 'package:studio3/screens/selling_settings_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/piece_service.dart';
import 'package:studio3/services/report_service.dart';
import 'package:studio3/services/user_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/content_actions_sheet.dart';
import 'package:studio3/widgets/orders/order_list_row.dart';
import 'package:studio3/widgets/piece_detail/hide_from_collection.dart';
import 'package:studio3/widgets/settings_tile.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// The backend handoff's Phase 2A (order rows carry their piece, log out of all other devices,
/// the reduced rate's end date) and Phase 6 (going public, turning selling off, the deletion
/// check, Hide from my Collection, the seller terms) against a fake server.

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Map<String, dynamic> query})>[];

  Iterable<({String method, String path, Map<String, dynamic> query})> to(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path, query: options.queryParameters));
    Object json = {'success': true, 'data': {}};
    var code = 200;
    switch ('${options.method} $path') {
      case 'POST /api/auth/logout-all':
        json = {'success': true, 'message': 'Logged out of all other devices.', 'data': {}};
      case 'GET /api/user/me/deletion-check':
        json = {
          'success': true,
          'data': {
            'canDelete': false,
            'blockers': [
              {'kind': 'bidding', 'count': 1, 'message': "You're bidding on an auction that hasn't finished."},
            ],
          },
        };
      case 'GET /api/user/me/seller-terms':
        json = {
          'success': true,
          'data': {
            'artCommissionBps': 1500,
            'artCommissionPercent': 15.0,
            'ticketFeeBps': 800,
            'ticketFeePercent': 8.0,
            'reducedRate': true,
            'reducedRateUntil': '2027-06-01T00:00:00+00:00',
            'buyersPayFees': false,
            'termsVersion': '1',
            'termsUrl': '/terms',
          },
        };
      case 'POST /api/user/me/seller/disable':
        json = {
          'success': true,
          'data': {'sellerEnabled': false, 'cancelledAuctions': 1, 'delisted': 2, 'skipped': 0},
        };
      case 'POST /api/collection/p1/hide':
        json = {'success': true, 'message': 'Hidden from your Collection.', 'data': {'pieceId': 'p1', 'hidden': true}};
      case 'DELETE /api/collection/p1/hide':
        json = {'success': true, 'message': 'Back in your Collection.', 'data': {'pieceId': 'p1', 'hidden': false}};
      case 'POST /api/collection/p2/hide':
        code = 404;
        json = {'success': false, 'message': "That piece isn't in your Collection."};
      case 'GET /api/users/jordanlee/collection':
        final all = options.queryParameters['includeHidden'] == '1';
        json = {
          'success': true,
          'data': [
            {'id': 'p1', 'title': 'Quiet Hours', if (all) 'hidden': false},
            if (all) {'id': 'p3', 'title': 'Dune', 'hidden': true},
          ],
        };
    }
    return ResponseBody.fromString(jsonEncode(json), code, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

late _Fake _server;

Widget _app(Widget home) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  home: home,
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '.',
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _server = _Fake();
    ApiClient.instance.debugUseAdapter(_server);
    AuthSession.instance.accessToken = 'token';
    AuthSession.instance.user = AuthUser.fromJson(const {'id': 'u1', 'username': 'jordanlee', 'name': 'Jordan Lee'});
  });
  tearDown(() {
    AuthSession.instance.accessToken = null;
    AuthSession.instance.user = null;
  });

  group('2A.1 order rows carry their piece', () {
    test('items[0].piece and fromAuction are read; a deleted piece is null', () {
      final order = Order.fromJson({
        'id': 'o1',
        'status': 'paid',
        'artworkCents': 50000,
        'fromAuction': true,
        'items': [
          {
            'pieceId': 'p1',
            'priceCents': 50000,
            'quantity': 1,
            'piece': {'id': 'p1', 'title': 'Paper Planes III', 'mediaUrl': 'https://x/p.jpg', 'listingType': 'fixed'},
          },
        ],
      });
      expect(order.fromAuction, isTrue);
      final piece = orderPiece(order)!;
      expect((piece.id, piece.title, piece.mediaUrl, piece.listingType), ('p1', 'Paper Planes III', 'https://x/p.jpg', 'fixed'));
      expect(saleMeta(order), startsWith('AUCTION · \$500'));
      expect(purchaseMeta(order), startsWith('AUCTION WIN'));

      final gone = Order.fromJson({
        'id': 'o2',
        'status': 'paid',
        'items': [
          {'pieceId': 'p2', 'priceCents': 1, 'quantity': 1, 'piece': null},
        ],
      });
      expect(gone.fromAuction, isFalse);
      expect(orderPiece(gone), isNull);
      expect(orderPieceTitle(orderPiece(gone)), 'Untitled');
      expect(saleMeta(gone), startsWith('SOLD'));
    });

    test('a sale has sold once it is paid or further along', () {
      Order o(String status) => Order(id: 'x', status: status, artworkCents: 0, shippingCents: 0, taxCents: 0, totalCents: 0);
      for (final s in ['paid', 'shipped', 'awaiting_confirmation', 'completed', 'disputed']) {
        expect(saleIsSold(o(s)), isTrue, reason: s);
      }
      for (final s in ['pending_payment', 'failed', 'cancelled', 'refunded']) {
        expect(saleIsSold(o(s)), isFalse, reason: s);
      }
    });

    testWidgets('a sold sale opens its piece, read only on tap', (tester) async {
      setBoardViewport(tester);
      final opened = <String>[];
      final sales = [
        const Order(
          id: 'o1',
          status: 'paid',
          artworkCents: 350000,
          shippingCents: 0,
          taxCents: 0,
          totalCents: 350000,
          items: [OrderItem(pieceId: 'p1', priceCents: 350000, quantity: 1, piece: OrderPiece(id: 'p1', title: 'Dune'))],
        ),
      ];
      await tester.pumpWidget(_app(MySalesPage(debugSales: sales, debugOpenPiece: opened.add)));
      await tester.pump();
      expect(_server.requests, isEmpty, reason: 'no piece is read for the rows');
      await tester.tap(find.text('Dune'));
      await tester.pump();
      expect(opened, ['p1']);
    });
  });

  group('2A.2 log out of all devices keeps this phone', () {
    testWidgets('asks without "this phone included", stays, and shows the server message', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const AccountSettingsPage(debugProfile: UserProfile(username: 'jordanlee', name: 'Jordan Lee'))));
      await tester.pump();
      await tester.tap(find.text('Log out of all devices'));
      await tester.pumpAndSettle();
      expect(find.textContaining('this phone included'), findsNothing);
      expect(find.textContaining('This phone stays signed in.'), findsOneWidget);
      await tester.tap(find.widgetWithText(StudioButton, 'Log out'));
      await _settle(tester);
      expect(_server.to('POST', '/api/auth/logout-all'), hasLength(1));
      expect(find.text('Logged out of all other devices.'), findsOneWidget);
      expect(find.byType(AccountSettingsPage), findsOneWidget);
      expect(AuthSession.instance.isLoggedIn, isTrue);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  test('2A.3 the commission quote reads reducedRateUntil', () {
    final quote = CommissionQuote.fromJson({
      'priceCents': 100000,
      'netCents': 85000,
      'commissionBps': 1500,
      'reducedRate': true,
      'reducedRateUntil': '2027-06-01T00:00:00+00:00',
    });
    expect(quote.reducedRateUntil, DateTime.utc(2027, 6, 1));
    expect(CommissionQuote.fromJson({'reducedRateUntil': null}).reducedRateUntil, isNull);
  });

  group('6.2 turning off selling', () {
    test('drops the profile pieces cache', () async {
      await UserService.instance.disableSeller();
      expect(_server.to('POST', '/api/user/me/seller/disable'), hasLength(1));
      expect(AuthSession.instance.sellerEnabled, isFalse);
    });

    testWidgets('the confirm says what comes down', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(SellingSettingsPage(debugTurnOff: () async {}, debugSellerTerms: const SellerTerms())));
      await tester.tap(find.text('Turn off seller profile'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your listings and auctions without bids will come down.'), findsWidgets);
      await tester.tap(find.widgetWithText(StudioButton, 'Cancel'));
      await tester.pumpAndSettle();
    });
  });

  group('6.3 the deletion check', () {
    testWidgets("the server's list, inert, and Delete account off", (tester) async {
      // Tall enough for the loading skeleton.
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(_app(const DeleteAccountPage()));
      await _settle(tester);
      expect(_server.to('GET', '/api/user/me/deletion-check'), hasLength(1));
      expect(find.text('Finish these first'), findsOneWidget);
      final row = tester.widget<SettingsRow>(find.byType(SettingsRow));
      expect((row.label, row.onTap, row.chevron), ("You're bidding on an auction that hasn't finished.", null, false));
      expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Delete account')).onPressed, isNull);
    });
  });

  group('6.4 Hide from my Collection', () {
    testWidgets('the ⋯ sheet offers it only when given', (tester) async {
      setBoardViewport(tester);
      var hidden = 0;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => showContentActionsSheet(context, target: ReportTarget.piece('p1'), authorUsername: 'artist'),
                child: const Text('plain'),
              ),
              TextButton(
                onPressed: () => showContentActionsSheet(
                  context,
                  target: ReportTarget.piece('p1'),
                  authorUsername: 'artist',
                  onHideFromCollection: () => hidden++,
                ),
                child: const Text('collector'),
              ),
            ],
          ),
        ),
      )));
      await tester.tap(find.text('plain'));
      await tester.pumpAndSettle();
      expect(find.text('Hide from my Collection'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.text('collector'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide from my Collection'));
      await tester.pumpAndSettle();
      expect(hidden, 1);
    });

    testWidgets('hiding toasts the server message with Undo, which brings it back', (tester) async {
      setBoardViewport(tester);
      late BuildContext ctx;
      await tester.pumpWidget(_app(Builder(builder: (context) {
        ctx = context;
        return const Scaffold();
      })));
      final revision = PieceService.instance.collectionRevision.value;
      hideFromMyCollection(ctx, 'p1');
      await _settle(tester);
      expect(_server.to('POST', '/api/collection/p1/hide'), hasLength(1));
      expect(find.text('Hidden from your Collection.'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await _settle(tester);
      expect(_server.to('DELETE', '/api/collection/p1/hide'), hasLength(1));
      expect(find.text('Back in your Collection.'), findsOneWidget);
      expect(PieceService.instance.collectionRevision.value, revision + 2);

      hideFromMyCollection(ctx, 'p2');
      await _settle(tester);
      expect(find.text("That piece isn't in your Collection."), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
    });

    test('only the owner asks for hidden pieces', () async {
      final visitor = await PieceService.instance.getUserCollection('jordanlee');
      expect(visitor.map((p) => p.id), ['p1']);
      final own = await PieceService.instance.getUserCollection('jordanlee', includeHidden: true);
      expect(own.map((p) => (p.id, p.hidden)), [('p1', false), ('p3', true)]);
      expect(_server.requests.last.query, {'includeHidden': '1'});
      expect(PieceSummary.fromJson(own.last.toJson()).hidden, isTrue, reason: 'the cache keeps it');
    });

    testWidgets('a hidden piece on their own Collection: dimmed, with Unhide', (tester) async {
      setBoardViewport(tester);
      final unhidden = <String>[];
      const pieces = [
        PieceSummary(id: 'p1', title: 'Quiet Hours'),
        PieceSummary(id: 'p3', title: 'Dune', hidden: true),
      ];
      Widget grid({bool own = true}) => _app(Scaffold(
        body: CustomScrollView(
          slivers: [
            ProfileCollectionGrid(
              pieces: pieces,
              onPieceTap: (_) {},
              onUnhide: own ? (p) => unhidden.add(p.id) : null,
            ),
          ],
        ),
      ));
      await tester.pumpWidget(grid());
      await tester.pump();
      expect(find.byType(Opacity), findsOneWidget);
      expect(find.widgetWithText(StudioChip, 'Unhide'), findsOneWidget);
      await tester.tap(find.text('Unhide'));
      expect(unhidden, ['p3']);

      await tester.pumpWidget(grid(own: false));
      await tester.pump();
      expect(find.text('Unhide'), findsNothing);
    });
  });

  group('6.5 seller terms', () {
    test('the rates line from the server', () {
      expect(
        SellerTerms.fromJson({'artCommissionPercent': 15.0, 'ticketFeePercent': 8.0}).summary,
        '15% on art · 8% on tickets',
      );
      expect(SellerTerms.fromJson({'artCommissionBps': 1250, 'ticketFeeBps': 800}).summary, '12.5% on art · 8% on tickets');
      expect(SellerTerms.fromJson(const {}).summary, isNull);
    });

    testWidgets('Seller terms shows the account rates, never "founding artist"', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const SellingSettingsPage()));
      await _settle(tester);
      expect(_server.to('GET', '/api/user/me/seller-terms'), hasLength(1));
      final row = tester.widgetList<SettingsRow>(find.byType(SettingsRow)).first;
      expect((row.label, row.subtitle), ('Seller terms', '15% on art · 8% on tickets'));
      expect(find.textContaining('founding', findRichText: true), findsNothing);
    });
  });
}
