import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/address.dart';
import 'package:studio3/models/order.dart';
import 'package:studio3/screens/my_orders_page.dart';
import 'package:studio3/screens/my_sales_page.dart';
import 'package:studio3/screens/order_detail_page.dart';
import 'package:studio3/screens/seller_analytics_page.dart';
import 'package:studio3/screens/terms_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/glass_card.dart';
import 'package:studio3/widgets/offline_state.dart';
import 'package:studio3/widgets/orders/order_row.dart';
import 'package:studio3/widgets/studio/studio.dart';
import 'package:studio3/widgets/studio_loading.dart';

import 'golden_harness.dart';

/// Phase 10 (no board): orders, sales, order detail, seller analytics, terms, and the shared
/// loading / offline / card widgets (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 14).
Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

Order _order(String status) => Order(
  id: 'abcd1234ef',
  status: status,
  artworkCents: 350000,
  shippingCents: 4500,
  taxCents: 28875,
  totalCents: 383375,
  items: const [OrderItem(pieceId: 'p1', priceCents: 350000, quantity: 1)],
  shippingAddress: const Address(
    id: 'a1',
    firstName: 'Jordan',
    lastName: 'Lee',
    phone: '5550100',
    line1: '1414 Dragon St',
    city: 'Dallas',
    state: 'TX',
    zip: '75201',
  ),
);

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });

  test('status words', () {
    expect(orderStatusLabel('pending_payment'), 'Pending payment');
    final c = StudioColors.light;
    expect(orderStatusColor(c, 'completed'), c.positive);
    expect(orderStatusColor(c, 'cancelled'), c.textTertiary);
    expect(orderStatusColor(c, 'paid'), c.textSecondary);
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    final theme = dark ? 'dark' : 'light';

    testWidgets('order row: Order #id in Mono, items and total, status ($theme)', (tester) async {
      await tester.pumpWidget(
        _app(Scaffold(body: OrderRow(order: _order('completed'), onTap: () {})), dark: dark),
      );
      expect(find.text('1 item · \$3833.75'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Completed')).style!.color, c.positive);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('order detail: status, address, summary, seller actions ($theme)', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(OrderDetailPage(orderId: 'x', isSeller: true, debugOrder: _order('paid')), dark: dark),
      );
      await tester.pump();
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, c.background);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('SHIPPING ADDRESS'), findsOneWidget);
      expect(find.text('Dallas, TX 75201'), findsOneWidget);
      expect(find.text('\$3833.75'), findsOneWidget);
      expect(tester.widget<StudioButton>(_button('Mark as shipped')).variant, StudioButtonVariant.primary);
      expect(tester.widget<StudioButton>(_button('Cancel order')).variant, StudioButtonVariant.outline);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('seller analytics: four Mono counts on Surface ($theme)', (tester) async {
      await tester.pumpWidget(
        _app(const SellerAnalyticsPage(savesCount: 12, likesCount: 40, salesCount: 3), dark: dark),
      );
      expect(find.text('Your insights'), findsOneWidget);
      expect(tester.widget<Text>(find.text('12')).style!.fontFamily, contains('Mono'));
      expect(find.text('—'), findsOneWidget); // inquiries unknown
    });

    testWidgets('loading, offline and the card follow the theme ($theme)', (tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Column(
              children: [
                const SizedBox(height: 120, child: StudioLoadingOverlay()),
                const Expanded(child: OfflineState()),
                GlassCard(child: const Text('card')),
              ],
            ),
          ),
          dark: dark,
        ),
      );
      final overlay = tester.widget<ColoredBox>(
        find.descendant(of: find.byType(StudioLoadingOverlay), matching: find.byType(ColoredBox)).first,
      );
      expect(overlay.color, c.background);
      expect(find.byType(StudioEmptyState), findsOneWidget);
      expect(find.text("You're offline"), findsOneWidget);
      final card = tester.widget<Container>(
        find.ancestor(of: find.text('card'), matching: find.byType(Container)).first,
      );
      expect((card.decoration! as BoxDecoration).color, c.card);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  }

  testWidgets('a buyer can cancel a paid order; nothing to do once shipped', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(OrderDetailPage(orderId: 'x', debugOrder: _order('paid'))));
    await tester.pump();
    expect(_button('Cancel order'), findsOneWidget);
    await tester.pumpWidget(_app(OrderDetailPage(orderId: 'x', debugOrder: _order('shipped'))));
    await tester.pump();
    expect(find.byType(StudioButton), findsNothing);
  });

  testWidgets('My orders and My sales: empty states after the request fails', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(const MySalesPage()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    expect(find.text('My sales'), findsOneWidget);
    expect(find.text('No sales yet'), findsOneWidget);

    await tester.pumpWidget(_app(const MyOrdersPage()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    expect(find.text('My orders'), findsOneWidget);
    expect(find.byType(StudioEmptyState), findsOneWidget);
  });

  testWidgets('terms page on tokens', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(const TermsPage(), dark: true));
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, StudioColors.dark.background);
  });
}
