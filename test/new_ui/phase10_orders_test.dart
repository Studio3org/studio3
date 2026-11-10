import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/address.dart';
import 'package:studio3/models/order.dart';
import 'package:studio3/screens/my_orders_page.dart';
import 'package:studio3/screens/my_sales_page.dart';
import 'package:studio3/screens/order_detail_page.dart';
import 'package:studio3/services/api_exception.dart';
import 'package:studio3/services/push_router_service.dart';
import 'package:studio3/utils/app_destination.dart';
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
      // Shipping and completion aren't the artist's to set any more (FRONTEND_HANDOFF 2.1).
      expect(_button('Mark as shipped'), findsNothing);
      expect(_button('Mark as completed'), findsNothing);
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

  testWidgets('a buyer cancels only before payment; after it, Report an issue (FRONTEND_HANDOFF 2.1)',
      (tester) async {
    setBoardViewport(tester);
    Future<void> show(String status) async {
      await tester.pumpWidget(_app(OrderDetailPage(orderId: 'x', debugOrder: _order(status))));
      await tester.pump();
    }

    await show('pending_payment');
    expect(_button('Cancel order'), findsOneWidget);
    expect(_button('Report an issue'), findsNothing);

    for (final status in ['paid', 'shipped', 'awaiting_confirmation']) {
      await show(status);
      expect(_button('Cancel order'), findsNothing, reason: status);
      expect(tester.widget<StudioButton>(_button('Report an issue')).variant, StudioButtonVariant.outline);
    }

    for (final status in ['completed', 'disputed', 'refunded', 'cancelled']) {
      await show(status);
      expect(find.byType(StudioButton), findsNothing, reason: status);
    }
    await show('refunded');
    expect(find.text('Refunded'), findsOneWidget);
  });

  testWidgets('Report an issue asks what went wrong; Send stays off until something is typed', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(OrderDetailPage(orderId: 'x', debugOrder: _order('shipped'))));
    await tester.pump();
    await tester.tap(_button('Report an issue'));
    await tester.pumpAndSettle();
    expect(find.text("Tell us what's wrong. We'll hold the artist's payment while we sort it out."), findsOneWidget);
    expect(tester.widget<StudioButton>(_button('Send')).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'Arrived with a cracked frame');
    await tester.pump();
    expect(tester.widget<StudioButton>(_button('Send')).onPressed, isNotNull);
    await tester.tap(_button('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Report an issue'), findsOneWidget, reason: 'back on the order, nothing sent');
  });

  testWidgets("the artist cancelling a paid sale confirms first; a pending one doesn't need to", (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(OrderDetailPage(orderId: 'x', isSeller: true, debugOrder: _order('paid'))));
    await tester.pump();
    await tester.tap(_button('Cancel order'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this sale?'), findsOneWidget);
    expect(find.text('The buyer will be refunded in full and the piece goes back on sale.'), findsOneWidget);
    await tester.tap(_button('Keep sale'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this sale?'), findsNothing);
    expect(find.text('Paid'), findsOneWidget, reason: 'nothing changed');

    for (final status in ['shipped', 'awaiting_confirmation', 'completed', 'refunded']) {
      await tester.pumpWidget(_app(OrderDetailPage(orderId: 'x', isSeller: true, debugOrder: _order(status))));
      await tester.pump();
      expect(find.byType(StudioButton), findsNothing, reason: status);
    }
  });

  test('a refused cancel shows the server line, except the staff-only payout one', () {
    expect(
      cancelErrorMessage(ApiException(
        "A paid order can't be cancelled by the buyer. If something's wrong, report an issue and we'll sort it out.",
        statusCode: 403,
      )),
      startsWith("A paid order can't be cancelled"),
    );
    expect(
      cancelErrorMessage(ApiException(
        'The artist has already been paid for this order; a refund here would leave the platform out of pocket. '
        'Recover the transfer in Stripe first.',
        statusCode: 409,
      )),
      "We couldn't cancel this sale. Please contact support.",
    );
    expect(
      cancelErrorMessage(ApiException('This payment is already going through. Check back in a moment.', statusCode: 409)),
      'This payment is already going through. Check back in a moment.',
    );
  });

  test('a sale push opens the order as the artist; a purchase one as the buyer', () {
    final sale = PushRouterService.destinationFor({'type': 'sale', 'targetType': 'order', 'targetId': 'o1'});
    expect(sale.type, AppDestinationType.order);
    expect(sale.asSeller, isTrue);
    expect(
      PushRouterService.destinationFor({'type': 'order_shipped', 'side': 'seller', 'targetType': 'order', 'targetId': 'o1'})
          .asSeller,
      isTrue,
    );
    expect(
      PushRouterService.destinationFor({'type': 'order', 'targetType': 'order', 'targetId': 'o1'}).asSeller,
      isFalse,
    );
  });

  testWidgets('Purchases and Sales: empty states after the request fails', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(const MySalesPage()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('No sales yet'), findsOneWidget);

    await tester.pumpWidget(_app(const MyOrdersPage()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    expect(find.text('Purchases'), findsOneWidget);
    expect(find.byType(StudioEmptyState), findsOneWidget);
  });

  testWidgets('terms page on tokens', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(const TermsPage(), dark: true));
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, StudioColors.dark.background);
  });
}
