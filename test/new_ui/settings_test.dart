import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/address.dart';
import 'package:studio3/models/follow_request.dart';
import 'package:studio3/models/order.dart';
import 'package:studio3/models/saved_card.dart';
import 'package:studio3/models/user_profile.dart';
import 'package:studio3/screens/account_settings_page.dart';
import 'package:studio3/screens/delete_account_page.dart';
import 'package:studio3/screens/follow_requests_page.dart';
import 'package:studio3/screens/my_orders_page.dart';
import 'package:studio3/screens/my_sales_page.dart';
import 'package:studio3/screens/payment_shipping_page.dart';
import 'package:studio3/screens/privacy_settings_page.dart';
import 'package:studio3/screens/profile_settings_page.dart';
import 'package:studio3/screens/selling_settings_page.dart';
import 'package:studio3/services/api_exception.dart';
import 'package:studio3/services/payout_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/utils/app_clock.dart';
import 'package:studio3/utils/app_version.dart';
import 'package:studio3/widgets/inbox/follow_requests_body.dart';
import 'package:studio3/widgets/orders/order_list_row.dart';
import 'package:studio3/widgets/settings_tile.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Flow 12, Settings (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 17.10): `Settings` and
/// `SettingsAccount`.
Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

const _notPaid = PayoutStatus(onboarded: false, payoutsEnabled: false, canListForSale: false);

Widget _settings({bool seller = true, PayoutStatus? payout = _notPaid}) =>
    ProfileSettingsPage(debugSeller: seller, debugName: 'Jordan Lee', debugPayout: payout);

const _jordan = UserProfile(username: 'jordan', name: 'Jordan Lee', email: 'jordan@email.com');

Order _sale(
  String id,
  String status, {
  required int cents,
  required DateTime at,
  String? payout,
  OrderShipment? shipment,
  String? title,
  bool fromAuction = false,
}) => Order(
  id: id,
  status: status,
  artworkCents: cents,
  shippingCents: 0,
  taxCents: 0,
  totalCents: cents,
  items: [
    OrderItem(
      pieceId: 'p-$id',
      priceCents: cents,
      quantity: 1,
      piece: title == null ? null : OrderPiece(id: 'p-$id', title: title),
    ),
  ],
  createdAt: at,
  payoutStatus: payout,
  shipment: shipment,
  fromAuction: fromAuction,
);

/// The board's art rows: Pack it for pickup (their move), Waiting for payment (an auction),
/// Delivered · paid out. The ticket row waits on B22.
final _sales = [
  _sale('1', 'paid', cents: 350000, at: DateTime(2026, 11, 2), title: 'Bodies in Color I'),
  _sale('2', 'pending_payment', cents: 130000, at: DateTime(2026, 11, 1), title: 'Quiet Hours', fromAuction: true),
  _sale('3', 'completed', cents: 90000, at: DateTime(2026, 10, 18), payout: 'released', title: 'Paper Planes III'),
];

Widget _salesPage({void Function(String pieceId)? onOpenPiece}) =>
    MySalesPage(debugSales: _sales, debugOpenPiece: onOpenPiece);

/// The board's art rows: Shipped, Delivered (an auction win), Refunded. The ticket row waits
/// on B22.
final _purchases = [
  _sale('1', 'shipped', cents: 350000, at: DateTime(2026, 11, 2), title: 'Bodies in Color I'),
  _sale('2', 'completed', cents: 130000, at: DateTime(2026, 10, 12), title: 'Quiet Hours', fromAuction: true),
  _sale('3', 'refunded', cents: 90000, at: DateTime(2026, 9, 30), title: 'Paper Planes III'),
];

const _visa = SavedCard(id: 'pm_1', brand: 'visa', last4: '4242', expMonth: 8, expYear: 2030);

const _home = Address(
  id: 'a1',
  label: 'Home',
  firstName: 'Jordan',
  lastName: 'Lee',
  phone: '2145550100',
  line1: '4521 Lovers Ln',
  city: 'Dallas',
  state: 'TX',
  zip: '75225',
  isDefault: true,
);

const _studio = Address(
  id: 'a2',
  firstName: 'Jordan',
  lastName: 'Lee',
  phone: '2145550100',
  line1: '12 Elm St',
  line2: 'Unit 4',
  city: 'Austin',
  state: 'TX',
  zip: '78701',
);

Widget _privacy({
  bool private = false,
  bool seller = false,
  List<String> requests = const ['a', 'b', 'c'],
  bool? collectionPrivate,
}) =>
    PrivacySettingsPage(
      debugProfile: UserProfile(
        username: 'jordan',
        name: 'Jordan Lee',
        profileVisibility: private ? 'private' : 'public',
        collectionPrivate: collectionPrivate,
      ),
      debugSeller: seller,
      debugRequests: requests,
      debugBlocked: 1,
    );

final _requestsNow = DateTime(2026, 11, 6, 12);

/// The board's three, given oldest first: the page shows them newest first.
final _followRequests = [
  FollowRequest(username: 'mariabruno', name: 'Maria Bruno', requestedAt: _requestsNow.subtract(const Duration(days: 3))),
  FollowRequest(username: 'daisysmith', name: 'Daisy Smith', requestedAt: _requestsNow.subtract(const Duration(hours: 2))),
  FollowRequest(username: 'cedric', name: 'Cedric Okafor', requestedAt: _requestsNow.subtract(const Duration(days: 1))),
];

/// The board's three, as the server's deletion check sends them (B34): a running auction, a
/// piece on its way, a payout not paid yet.
const _boardCheck = DeletionCheck(
  canDelete: false,
  blockers: [
    DeletionBlocker(kind: 'running_auction', message: 'An auction of yours has bids. Wait for it to close.'),
    DeletionBlocker(kind: 'shipping_purchase', message: 'A piece you bought is still on its way.'),
    DeletionBlocker(kind: 'pending_payout', message: 'Money is still on its way to you.'),
  ],
);

Widget _purchasesPage() => MyOrdersPage(debugOrders: _purchases);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });

  group('Settings', () {
    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('sections, rows, Payouts in red, Delete in red, the version (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        setBoardViewport(tester, height: 1400);
        await tester.pumpWidget(_app(_settings(), dark: dark));
        await tester.pump();

        for (final label in ['ACCOUNT', 'SELLING', 'BUYING', 'APP', 'HELP']) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.style!.fontFamily, contains('Mono'));
          expect((text.style!.fontSize, text.style!.color), (11, c.textTertiary));
        }
        final rows = tester.widgetList<SettingsRow>(find.byType(SettingsRow)).map((r) => r.label).toList();
        expect(rows, [
          'Account', 'Series',
          'Seller profile', 'Sales', 'Insights', 'Payouts',
          'Purchases', 'Payment and shipping',
          'Notifications', 'Privacy', 'Appearance',
          'Help', 'Terms and policies',
          'Log out', 'Delete account',
        ]);
        final account = tester.widget<Text>(find.text('Account').first);
        expect((account.style!.fontSize, account.style!.color), (16, c.textPrimary));
        expect(tester.widget<Text>(find.text('Jordan Lee')).style!.color, c.textSecondary);
        expect(find.text('On'), findsOneWidget);
        expect(find.text('Orders, auction wins and tickets'), findsOneWidget);
        expect(tester.widget<Text>(find.text('Finish setup')).style!.color, c.alert);
        expect(tester.widget<Text>(find.text('Delete account')).style!.color, c.alert);
        expect(tester.widget<Text>(find.text('Log out')).style!.color, c.textPrimary);
        final version = tester.widget<Text>(find.text('Studio 3 · $kAppVersion'));
        expect(version.style!.fontFamily, contains('Mono'));
        expect(find.text('Start selling'), findsNothing);
        expect(tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor, c.background);
      });
    }

    testWidgets('not a seller: one Start selling row', (tester) async {
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(_app(_settings(seller: false)));
      await tester.pump();
      expect(find.text('Start selling'), findsOneWidget);
      for (final row in ['Seller profile', 'Sales', 'Insights', 'Payouts']) {
        expect(find.text(row), findsNothing);
      }
    });

    testWidgets('Payouts paid out: no Finish setup', (tester) async {
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(
        _app(_settings(payout: const PayoutStatus(onboarded: true, payoutsEnabled: true, canListForSale: true))),
      );
      await tester.pump();
      expect(find.text('Payouts'), findsOneWidget);
      expect(find.text('Finish setup'), findsNothing);
    });

    testWidgets('Appearance opens Light / Dark', (tester) async {
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(_app(_settings()));
      await tester.pump();
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      expect(find.text('Light'), findsWidgets);
      expect(find.text('Dark'), findsOneWidget);
    });

    test('the version matches pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(pubspec)!.group(1);
      expect(kAppVersion, version);
    });
  });

  group('Account', () {
    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('name, email, phone (Add), password, log out everywhere (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        setBoardViewport(tester);
        await tester.pumpWidget(_app(const AccountSettingsPage(debugProfile: _jordan), dark: dark));
        await tester.pump();
        final rows = tester.widgetList<SettingsRow>(find.byType(SettingsRow)).toList();
        expect(rows.map((r) => (r.label, r.value)), [
          ('Name', 'Jordan Lee'),
          ('Email', 'jordan@email.com'),
          ('Phone', 'Add'),
          ('Password', 'Change'),
          ('Log out of all devices', null),
        ]);
        expect(rows.last.chevron, isFalse);
        final note = tester.widget<Text>(find.text('Changing your email sends a code to the new address first.'));
        expect((note.style!.fontSize, note.style!.color), (12, c.textSecondary));
      });
    }

    testWidgets('Name in a sheet: Save only once it changed', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const AccountSettingsPage(debugProfile: _jordan)));
      await tester.pump();
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      StudioButton save() => tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Save'));
      expect(save().onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Jordan A. Lee');
      await tester.pump();
      expect(save().onPressed, isNotNull);
      await tester.enterText(find.byType(TextField), '  ');
      await tester.pump();
      expect(save().onPressed, isNull);
    });

    testWidgets('Phone: optional, so an empty phone can be saved to remove it', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(const AccountSettingsPage(
          debugProfile: UserProfile(username: 'jordan', name: 'Jordan Lee', phone: '+1 214 555 0100'),
        )),
      );
      await tester.pump();
      expect(find.text('+1 214 555 0100'), findsOneWidget);
      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      expect(find.text('Optional. Leave it empty to remove it.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Save')).onPressed, isNotNull);
    });

    testWidgets('Log out of all devices asks first', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const AccountSettingsPage(debugProfile: _jordan)));
      await tester.pump();
      await tester.tap(find.text('Log out of all devices'));
      await tester.pumpAndSettle();
      expect(find.text('Log out of all devices?'), findsOneWidget);
      await tester.tap(find.widgetWithText(StudioButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Log out of all devices?'), findsNothing);
    });
  });

  group('Selling', () {
    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('on, seller terms, turn off (${dark ? 'dark' : 'light'})', (tester) async {
        setBoardViewport(tester);
        await tester.pumpWidget(_app(const SellingSettingsPage(), dark: dark));
        await tester.pump();
        expect(find.text('Seller profile is on'), findsOneWidget);
        final dot = tester.widget<Container>(
          find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).shape == BoxShape.circle),
        );
        expect((dot.decoration! as BoxDecoration).color, c.available);
        expect(find.text('STUDIO'), findsOneWidget);
        final rows = tester.widgetList<SettingsRow>(find.byType(SettingsRow)).toList();
        expect(rows.map((r) => (r.label, r.subtitle, r.chevron)), [
          ('Seller terms', 'Includes fees', true),
          ('Turn off seller profile', 'Your listings and auctions without bids will come down.', false),
        ]);
        // The pickup address waits on B31 (on hold).
        expect(find.text('Studio address'), findsNothing);
      });
    }

    testWidgets('turning off asks first, then closes saying so', (tester) async {
      setBoardViewport(tester);
      var calls = 0;
      final results = <Object?>[];
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => results.add(await Navigator.push<bool>(
              context,
              MaterialPageRoute<bool>(builder: (_) => SellingSettingsPage(debugTurnOff: () async => calls++)),
            )),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn off seller profile'));
      await tester.pumpAndSettle();
      expect(find.text('Turn off seller profile?'), findsOneWidget);
      await tester.tap(find.widgetWithText(StudioButton, 'Turn off'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(results, [true]);
      // The "Seller profile is off" toast.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets("the server's reason stays on the page", (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(SellingSettingsPage(
        debugTurnOff: () async => throw ApiException('Remove your active listings before disabling seller mode.'),
      )));
      await tester.tap(find.text('Turn off seller profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(StudioButton, 'Turn off'));
      await tester.pumpAndSettle();
      expect(find.text('Remove your active listings before disabling seller mode.'), findsOneWidget);
      expect(find.text('Seller profile is on'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('Sales', () {
    setUp(() => appNow = () => DateTime(2026, 11, 6, 10));
    tearDown(() => appNow = DateTime.now);

    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('rows: title, next step (red on their move), type · amount · date (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        setBoardViewport(tester);
        await tester.pumpWidget(_app(_salesPage(), dark: dark));
        await tester.pump();

        expect(find.text('Sales'), findsOneWidget);
        final rows = tester.widgetList<OrderListRow>(find.byType(OrderListRow)).toList();
        expect(rows.map((r) => r.title), ['Bodies in Color I', 'Quiet Hours', 'Paper Planes III']);
        expect(rows.map((r) => r.step), ['Pack it for pickup', 'Waiting for payment', 'Delivered · paid out']);
        expect(rows.map((r) => r.urgent), [true, false, false]);
        expect(rows.map((r) => r.meta), [
          'SOLD · \$3,500 · Nov 2',
          'AUCTION · \$1,300 · Nov 1',
          'SOLD · \$900 · Oct 18',
        ]);

        expect(tester.widget<Text>(find.text('Pack it for pickup')).style!.color, c.alert);
        expect(tester.widget<Text>(find.text('Waiting for payment')).style!.color, c.textSecondary);
        final title = tester.widget<Text>(find.text('Quiet Hours')).style!;
        expect((title.fontSize, title.fontWeight), (15, FontWeight.w500));
        final meta = tester.widget<Text>(find.text('AUCTION · \$1,300 · Nov 1')).style!;
        expect(meta.fontFamily, contains('Mono'));
        expect((meta.fontSize, meta.color), (11, c.textTertiary));
        expect(tester.getSize(find.byType(ClipRRect).first), const Size(48, 64));
        // Tickets wait on B22: no filter yet.
        expect(find.text('Tickets'), findsNothing);
      });
    }

    test('next step for each state of a sale', () {
      final at = DateTime(2026, 11, 2);
      ({String text, bool urgent}) step(String status, {String? payout, String? ship}) => saleStep(
        _sale(
          'x',
          status,
          cents: 100,
          at: at,
          payout: payout,
          shipment: ship == null ? null : OrderShipment(courier: 'DHL', trackingNumber: '1', status: ship),
        ),
      );
      expect(step('paid'), (text: 'Pack it for pickup', urgent: true));
      expect(step('paid', ship: 'label_created'), (text: 'Pack it for pickup', urgent: true));
      expect(step('paid', ship: 'in_transit').text, 'On its way');
      expect(step('shipped').text, 'On its way');
      expect(step('awaiting_confirmation').text, 'Delivered · waiting on the collector');
      expect(step('completed', payout: 'released').text, 'Delivered · paid out');
      expect(step('completed', payout: 'pending').text, 'Delivered · payout on the way');
      expect(step('pending_payment').text, 'Waiting for payment');
      expect(step('refunded').text, 'Refunded');
      expect(step('disputed').text, 'Issue reported');
    });

    test('dates outside this year carry the year', () {
      expect(orderRowDate(DateTime(2026, 3, 4)), 'Mar 4');
      expect(orderRowDate(DateTime(2025, 12, 30)), 'Dec 30, 2025');
      expect(orderRowDate(null), '');
    });

    testWidgets('no sales: the empty state', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const MySalesPage(debugSales: [])));
      await tester.pump();
      expect(find.text('No sales yet'), findsOneWidget);
    });
  });

  group('Purchases', () {
    setUp(() => appNow = () => DateTime(2026, 11, 6, 10));
    tearDown(() => appNow = DateTime.now);

    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('rows: title, where it is, type · date; the footnote (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        setBoardViewport(tester);
        await tester.pumpWidget(_app(_purchasesPage(), dark: dark));
        await tester.pump();

        expect(find.text('Purchases'), findsOneWidget);
        final rows = tester.widgetList<OrderListRow>(find.byType(OrderListRow)).toList();
        expect(rows.map((r) => r.title), ['Bodies in Color I', 'Quiet Hours', 'Paper Planes III']);
        expect(rows.map((r) => r.step), ['Shipped', 'Delivered', 'Refunded']);
        expect(rows.map((r) => r.urgent), [false, false, false]);
        expect(rows.map((r) => r.meta), ['COLLECTED · Nov 2', 'AUCTION WIN · Oct 12', 'COLLECTED · Sep 30']);
        final note = tester.widget<Text>(find.text('Tap an order for its receipt and tracking.')).style!;
        expect((note.fontSize, note.color), (12, c.textSecondary));
        expect(find.text('Tickets'), findsNothing);
      });
    }

    test('where each purchase is', () {
      final at = DateTime(2026, 11, 2);
      String step(String status, {String? ship}) => purchaseStep(
        _sale(
          'x',
          status,
          cents: 100,
          at: at,
          shipment: ship == null ? null : OrderShipment(courier: 'DHL', trackingNumber: '1', status: ship),
        ),
      );
      expect(step('pending_payment'), 'Payment pending');
      expect(step('paid'), 'Being packed');
      expect(step('paid', ship: 'in_transit'), 'Shipped');
      expect(step('shipped'), 'Shipped');
      expect(step('awaiting_confirmation'), 'Delivered · confirm you got it');
      expect(step('completed'), 'Delivered');
      expect(step('refunded'), 'Refunded');
      expect(step('cancelled'), 'Cancelled');
    });

    testWidgets('a piece that no longer exists: Untitled', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(MyOrdersPage(debugOrders: [_sale('1', 'shipped', cents: 350000, at: DateTime(2026, 11, 2))])),
      );
      await tester.pump();
      expect(find.text('Untitled'), findsOneWidget);
      expect(find.text('COLLECTED · Nov 2'), findsOneWidget);
    });
  });

  group('Payment and shipping', () {
    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('cards, Add payment method, addresses with the default, Add address (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        setBoardViewport(tester);
        await tester.pumpWidget(
          _app(const PaymentShippingPage(debugCards: [_visa], debugAddresses: [_home, _studio]), dark: dark),
        );
        await tester.pump();

        expect(find.text('Payment and shipping'), findsOneWidget);
        for (final label in ['PAYMENT', 'SHIPPING']) {
          final text = tester.widget<Text>(find.text(label));
          expect((text.style!.fontSize, text.style!.color), (11, c.textTertiary));
        }
        final rows = tester.widgetList<SettingsRow>(find.byType(SettingsRow)).toList();
        expect(rows.map((r) => r.label), [
          'Visa ending 4242',
          'Add payment method',
          'Home',
          'Jordan Lee',
          'Add address',
        ]);
        expect(rows[2].subtitle, '4521 Lovers Ln, Dallas, TX 75225');
        expect(rows[2].value, 'Default');
        expect(rows[3].subtitle, '12 Elm St, Unit 4, Austin, TX 78701');
        expect(rows[3].value, isNull);
        // The default card waits on the payment hold.
        expect(rows[0].value, isNull);
        expect(find.textContaining('auction wins'), findsNothing);
      });
    }

    testWidgets('the Shipping info icon shows where purchases go', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const PaymentShippingPage(debugCards: [], debugAddresses: [_home])));
      await tester.pump();
      expect(find.text('Where your purchases are delivered.'), findsNothing);
      expect(tester.widget<StudioInfoButton>(find.byType(StudioInfoButton)).semanticLabel, 'What is this address for?');
      await tester.tap(find.byType(StudioInfoButton));
      await tester.pump();
      expect(find.text('Where your purchases are delivered.'), findsOneWidget);
    });

    testWidgets('a card asks before it is removed', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const PaymentShippingPage(debugCards: [_visa], debugAddresses: [])));
      await tester.pump();
      await tester.tap(find.text('Visa ending 4242'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Visa ending 4242?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Visa ending 4242'), findsOneWidget);
    });

    testWidgets('an address opens Edit, Set as default (not on the default), Delete', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const PaymentShippingPage(debugCards: [], debugAddresses: [_home, _studio])));
      await tester.pump();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Set as default'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
      Navigator.of(tester.element(find.text('Edit'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jordan Lee'));
      await tester.pumpAndSettle();
      expect(find.text('Set as default'), findsOneWidget);
    });

    test('card and address names', () {
      expect(savedCardName(const SavedCard(id: 'x', last4: '1111')), 'Card ending 1111');
      expect(savedCardName(const SavedCard(id: 'x', brand: 'amex')), 'Amex');
      expect(addressName(_studio), 'Jordan Lee');
      expect(addressLine(_home), '4521 Lovers Ln, Dallas, TX 75225');
    });
  });

  group('Privacy', () {
    for (final dark in [false, true]) {
      testWidgets('rows, counts and the switch (${dark ? 'dark' : 'light'})', (tester) async {
        setBoardViewport(tester);
        await tester.pumpWidget(_app(_privacy(), dark: dark));
        await tester.pump();

        expect(find.text('Privacy'), findsOneWidget);
        final rows = tester.widgetList<SettingsRow>(find.byType(SettingsRow)).toList();
        expect(rows.map((r) => r.label), [
          'Private account',
          'Follow requests',
          'Who can message you',
          'Blocked accounts',
          'See your profile as others do',
          'My reports',
          'Privacy policy',
        ]);
        expect(rows[0].subtitle, 'Only approved followers see your profile');
        expect(rows[0].chevron, isFalse);
        expect(rows.map((r) => r.value).take(4), [null, '3', 'Everyone', '1']);
        expect(tester.widget<StudioSwitch>(find.byType(StudioSwitch)).value, isFalse);
        // Private Collection waits on B34, Hidden pieces on B32.
        expect(find.text('Private Collection'), findsNothing);
        expect(find.text('Hidden pieces'), findsNothing);
      });
    }

    testWidgets('a seller profile stays public', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_privacy(seller: true)));
      await tester.pump();
      await tester.tap(find.byType(StudioSwitch));
      await tester.pump();
      expect(find.text('Seller profiles stay public, since listings are.'), findsOneWidget);
      expect(tester.widget<StudioSwitch>(find.byType(StudioSwitch)).value, isFalse);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('going public asks first, then approves everyone waiting', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_privacy(private: true)));
      await tester.pump();
      expect(tester.widget<StudioSwitch>(find.byType(StudioSwitch)).value, isTrue);
      await tester.tap(find.byType(StudioSwitch));
      await tester.pumpAndSettle();
      expect(find.text('Make your account public?'), findsOneWidget);
      expect(find.text('The 3 people waiting to follow you will be approved.'), findsOneWidget);
      await tester.tap(find.text('Make public'));
      await tester.pumpAndSettle();
      expect(tester.widget<StudioSwitch>(find.byType(StudioSwitch)).value, isFalse);
      final requests = tester.widgetList<SettingsRow>(find.byType(SettingsRow)).elementAt(1);
      expect(requests.value, isNull);
    });

    testWidgets('going private with no one waiting needs no question', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_privacy(requests: const [])));
      await tester.pump();
      await tester.tap(find.text('Private account'));
      await tester.pumpAndSettle();
      expect(find.text('Make your account public?'), findsNothing);
      expect(tester.widget<StudioSwitch>(find.byType(StudioSwitch)).value, isTrue);
    });

    testWidgets('Who can message you: Everyone, People you follow, No one', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_privacy()));
      await tester.pump();
      await tester.tap(find.text('Who can message you'));
      await tester.pumpAndSettle();
      expect(find.text('People you follow'), findsOneWidget);
      await tester.tap(find.text('No one'));
      await tester.pumpAndSettle();
      final row = tester.widgetList<SettingsRow>(find.byType(SettingsRow)).elementAt(2);
      expect(row.value, 'No one');
    });
  });

  group('Follow requests', () {
    setUp(() => appNow = () => _requestsNow);
    tearDown(() => appNow = DateTime.now);

    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('newest first, 44 avatars, age in Mono, Approve then Decline, the footnote (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        setBoardViewport(tester);
        await tester.pumpWidget(_app(FollowRequestsPage(debugRequests: _followRequests), dark: dark));
        await tester.pump();

        expect(find.text('Follow requests'), findsOneWidget);
        final names = tester.widgetList<FollowRequestRow>(find.byType(FollowRequestRow)).map((r) => r.request.name);
        expect(names, ['Daisy Smith', 'Cedric Okafor', 'Maria Bruno']);
        expect(tester.widgetList<StudioAvatar>(find.byType(StudioAvatar)).map((a) => a.size), everyElement(44));
        expect(find.text('@daisysmith · 2h', findRichText: true), findsOneWidget);
        expect(find.text('@cedric · 1d', findRichText: true), findsOneWidget);
        final buttons = tester
            .widgetList<StudioButton>(
              find.descendant(of: find.byType(FollowRequestRow).first, matching: find.byType(StudioButton)),
            )
            .toList();
        expect(buttons.map((b) => b.label), ['Approve', 'Decline']);
        expect(buttons.map((b) => b.filled), [true, false]);
        final note = tester.widget<Text>(find.text("They aren't told if you decline.")).style!;
        expect((note.fontSize, note.color), (12, c.textSecondary));
      });
    }

    testWidgets('no requests: the empty state, no footnote', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const FollowRequestsPage(debugRequests: [])));
      await tester.pump();
      expect(find.text('No follow requests'), findsOneWidget);
      expect(find.text("They aren't told if you decline."), findsNothing);
    });

    test('ages', () {
      final now = DateTime(2026, 11, 6, 12);
      expect(requestAge(now, now), 'now');
      expect(requestAge(now.subtract(const Duration(minutes: 12)), now), '12m');
      expect(requestAge(now.subtract(const Duration(hours: 2)), now), '2h');
      expect(requestAge(now.subtract(const Duration(days: 3)), now), '3d');
      expect(requestAge(now.subtract(const Duration(days: 15)), now), '2w');
    });
  });

  group('Delete account', () {
    setUp(() => appNow = () => DateTime(2026, 11, 6, 10));
    tearDown(() => appNow = DateTime.now);

    test("the server's check: canDelete and each blocker's message", () {
      final check = DeletionCheck.fromJson({
        'canDelete': false,
        'blockers': [
          {
            'kind': 'hosted_event_tickets',
            'count': 1,
            'message': "You're hosting an event with tickets sold. Cancel it first (everyone is refunded).",
          },
          {'kind': 'fee_debt', 'count': 1, 'amountCents': 420, 'message': 'You owe card fees from an event you cancelled.'},
        ],
      });
      expect(check.canDelete, isFalse);
      expect(check.blockers.map((b) => b.kind), ['hosted_event_tickets', 'fee_debt']);
      expect(check.blockers.last.amountCents, 420);
      expect(DeletionCheck.fromJson({'canDelete': true, 'blockers': <Object>[]}).canDelete, isTrue);
    });

    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('in progress: Finish these first, the rows, Delete account off (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        setBoardViewport(tester);
        await tester.pumpWidget(_app(const DeleteAccountPage(debugCheck: _boardCheck), dark: dark));
        await tester.pump();
        final title = tester.widget<Text>(find.text('Finish these first')).style!;
        expect((title.fontSize, title.fontWeight, title.color), (24, FontWeight.w500, c.textPrimary));
        expect(find.text('Your account can be deleted once nothing is in progress.'), findsOneWidget);
        final rows = tester.widgetList<SettingsRow>(find.byType(SettingsRow)).toList();
        expect(rows.map((r) => r.label), [
          'An auction of yours has bids. Wait for it to close.',
          'A piece you bought is still on its way.',
          'Money is still on its way to you.',
        ]);
        // The server's words, as they are; nothing to open.
        expect(rows.map((r) => (r.onTap, r.chevron)), everyElement((null, false)));
        expect(
          find.text('Removes your profile, pieces, Scenes and messages. Sale records are kept as the law requires.'),
          findsOneWidget,
        );
        expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Delete account')).onPressed, isNull);
      });
    }

    testWidgets('nothing in progress: Delete account asks for DELETE and the password', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const DeleteAccountPage(debugCheck: DeletionCheck(canDelete: true))));
      await tester.pump();
      expect(find.text('Finish these first'), findsNothing);
      expect(find.text('Delete your account?'), findsOneWidget);
      await tester.tap(find.widgetWithText(StudioButton, 'Delete account'));
      await tester.pumpAndSettle();
      expect(find.text('Type DELETE to confirm.'), findsOneWidget);
      StudioButton confirm() => tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Delete account').last);
      expect(confirm().onPressed, isNull);
      await tester.enterText(find.byType(TextField).first, 'delete');
      await tester.pump();
      expect(confirm().onPressed, isNull);
      await tester.enterText(find.byType(TextField).last, 'secret');
      await tester.pump();
      expect(confirm().onPressed, isNotNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('Private Collection (B34): between Who can message you and Blocked accounts, a switch', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(_privacy()));
    await tester.pump();
    expect(find.text('Private Collection'), findsNothing, reason: 'not shown until the server has it');

    await tester.pumpWidget(_app(_privacy(collectionPrivate: false)));
    await tester.pump();
    expect(find.text('Only you see the pieces you own'), findsOneWidget);
    final ys = ['Who can message you', 'Private Collection', 'Blocked accounts']
        .map((l) => tester.getTopLeft(find.text(l)).dy)
        .toList();
    expect(ys, [...ys]..sort());
    final toggle = find.byWidgetPredicate((w) => w is StudioSwitch && w.semanticLabel == 'Private Collection');
    expect(tester.widget<StudioSwitch>(toggle).value, isFalse);
    await tester.tap(find.text('Private Collection'));
    await tester.pump();
    expect(tester.widget<StudioSwitch>(toggle).value, isTrue);
  });

  group('goldens', () {
    final skip = Platform.environment['NEW_UI_GOLDENS'] != '1';
    testWidgets('Settings', (tester) async {
      setBoardViewport(tester, height: 1120);
      await tester.pumpWidget(_app(_settings()));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/Settings.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('SettingsSelling', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const SellingSettingsPage()));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/SettingsSelling.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('SettingsSales', (tester) async {
      appNow = () => DateTime(2026, 11, 6, 10);
      addTearDown(() => appNow = DateTime.now);
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_salesPage()));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/SettingsSales.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('SettingsPurchases', (tester) async {
      appNow = () => DateTime(2026, 11, 6, 10);
      addTearDown(() => appNow = DateTime.now);
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_purchasesPage()));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/SettingsPurchases.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('SettingsPayment', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const PaymentShippingPage(debugCards: [_visa], debugAddresses: [_home])));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/SettingsPayment.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('SettingsPrivacy', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_privacy()));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/SettingsPrivacy.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('SettingsFollowRequests', (tester) async {
      appNow = () => _requestsNow;
      addTearDown(() => appNow = DateTime.now);
      setBoardViewport(tester);
      await tester.pumpWidget(_app(FollowRequestsPage(debugRequests: _followRequests)));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/SettingsFollowRequests.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('SettingsDelete', (tester) async {
      appNow = () => DateTime(2026, 11, 6, 10);
      addTearDown(() => appNow = DateTime.now);
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const DeleteAccountPage(debugCheck: _boardCheck)));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/SettingsDelete.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('SettingsAccount', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const AccountSettingsPage(debugProfile: _jordan)));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/SettingsAccount.png'));
      await checkAcceptance(tester);
    }, skip: skip);
  });
}
