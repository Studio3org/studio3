import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/address.dart';
import 'package:studio3/models/order.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/models/saved_card.dart';
import 'package:studio3/models/user_profile.dart';
import 'package:studio3/screens/account_settings_page.dart';
import 'package:studio3/screens/my_orders_page.dart';
import 'package:studio3/screens/my_sales_page.dart';
import 'package:studio3/screens/payment_shipping_page.dart';
import 'package:studio3/screens/profile_settings_page.dart';
import 'package:studio3/screens/selling_settings_page.dart';
import 'package:studio3/services/api_exception.dart';
import 'package:studio3/services/payout_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/utils/app_clock.dart';
import 'package:studio3/utils/app_version.dart';
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
}) => Order(
  id: id,
  status: status,
  artworkCents: cents,
  shippingCents: 0,
  taxCents: 0,
  totalCents: cents,
  items: [OrderItem(pieceId: 'p-$id', priceCents: cents, quantity: 1)],
  createdAt: at,
  payoutStatus: payout,
  shipment: shipment,
);

/// The board's art rows: Pack it for pickup (their move), Waiting for payment (an auction),
/// Delivered · paid out. The ticket row waits on B22.
final _sales = [
  _sale('1', 'paid', cents: 350000, at: DateTime(2026, 11, 2)),
  _sale('2', 'pending_payment', cents: 130000, at: DateTime(2026, 11, 1)),
  _sale('3', 'completed', cents: 90000, at: DateTime(2026, 10, 18), payout: 'released'),
];

const _salePieces = {
  'p-1': PieceSummary(id: 'p-1', title: 'Bodies in Color I', status: 'sold', isForSale: true),
  'p-2': PieceSummary(id: 'p-2', title: 'Quiet Hours', status: 'reserved', listingType: 'auction'),
  'p-3': PieceSummary(id: 'p-3', title: 'Paper Planes III', status: 'sold', isForSale: true),
};

Widget _salesPage() => MySalesPage(debugSales: _sales, debugPieces: _salePieces);

/// The board's art rows: Shipped, Delivered (an auction win), Refunded. The ticket row waits
/// on B22.
final _purchases = [
  _sale('1', 'shipped', cents: 350000, at: DateTime(2026, 11, 2)),
  _sale('2', 'completed', cents: 130000, at: DateTime(2026, 10, 12)),
  _sale('3', 'refunded', cents: 90000, at: DateTime(2026, 9, 30)),
];

const _purchasePieces = {
  'p-1': PieceSummary(id: 'p-1', title: 'Bodies in Color I', status: 'sold', isForSale: true),
  'p-2': PieceSummary(id: 'p-2', title: 'Quiet Hours', status: 'sold', listingType: 'auction'),
  'p-3': PieceSummary(id: 'p-3', title: 'Paper Planes III', status: 'live', isForSale: true),
};

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

Widget _purchasesPage() => MyOrdersPage(debugOrders: _purchases, debugPieces: _purchasePieces);

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
          ('Turn off seller profile', 'Your listings come down. Pieces stay on your profile.', false),
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

    testWidgets('a piece that could not be read: Untitled', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(MyOrdersPage(debugOrders: [_purchases.first])));
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

    testWidgets('SettingsAccount', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const AccountSettingsPage(debugProfile: _jordan)));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/SettingsAccount.png'));
      await checkAcceptance(tester);
    }, skip: skip);
  });
}
