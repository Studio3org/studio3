import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/address.dart';
import 'package:studio3/models/collect_checkout.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/theme/studio_type.dart';
import 'package:studio3/widgets/piece_detail/collect_piece_sheet.dart';
import 'package:studio3/widgets/studio/studio_button.dart';
import 'package:studio3/widgets/studio/studio_sheet.dart';

import 'golden_harness.dart';

/// `BuyCheckoutEmpty` / `BuyCheckoutReady` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 7).
const _item = FeedPreviewItem(
  id: 'p1',
  imageSeeds: [1],
  title: 'Bodies in Color',
  medium: 'Oil',
  year: 2025,
  dimensions: '24 × 36 in',
  story: '',
  handle: '@amarasart',
  isAvailable: true,
  aspectRatio: FeedAspectRatio.portrait3x4,
  authorName: 'Amara Osei',
  priceCents: 350000,
);

const _shipping = CollectShippingSelection(
  address: Address(
    id: 'a1',
    firstName: 'Jordan',
    lastName: 'Lee',
    phone: '5550100',
    line1: '1 Main St',
    city: 'Dallas',
    state: 'TX',
    zip: '75201',
  ),
  method: CollectShippingMethod(
    id: 'std',
    title: 'Crated, standard',
    duration: '7–10 days',
    priceCents: 18000,
  ),
);

Future<void> _open(
  WidgetTester tester, {
  CollectShippingSelection? shipping,
  CollectPaymentMethod? payment,
  bool dark = false,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showStudioSheet<void>(
              context: context,
              builder: (_) => CollectPieceSheet(
                item: _item,
                initialShipping: shipping,
                initialPayment: payment,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // The thumbnail's loading shimmer never settles; the sheet is up after its slide-in.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

StudioButton _collect(WidgetTester tester) =>
    tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Collect this piece'));

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });

  testWidgets('empty: header, summary, rows with placeholders, dashes, disabled button', (
    tester,
  ) async {
    await _open(tester);
    final c = StudioColors.light;

    expect(find.byType(StudioSheetGrabber), findsOneWidget);
    final title = tester.widget<Text>(find.text('Checkout'));
    expect(title.style!.fontSize, 16);
    expect(title.style!.fontWeight, StudioType.medium);

    // 64 × 85 thumbnail, title 16/500, artist 13, price 14.
    expect(
      find.byWidgetPredicate((w) => w is SizedBox && w.width == 64 && w.height == 85),
      findsOneWidget,
    );
    expect(tester.widget<Text>(find.text('Bodies in Color')).style!.fontSize, 16);
    expect(tester.widget<Text>(find.text('Amara Osei')).style!.fontSize, 13);
    expect(tester.widget<Text>(find.text(r'$3,500')).style!.fontSize, 14);
    expect(find.text(r'$3,500.00'), findsOneWidget); // Artwork, with cents

    for (final placeholder in ['Add a delivery address', 'Add a payment method']) {
      final text = tester.widget<Text>(find.text(placeholder));
      expect(text.style!.fontSize, 15);
      expect(text.style!.color, c.textPlaceholder);
    }

    expect(find.text('Order summary'), findsOneWidget);
    expect(find.text('Artwork'), findsOneWidget);
    expect(find.text('Sales tax'), findsOneWidget); // fixed price too, never "Tax" (`BuyCheckoutEmpty`)
    expect(find.text('Tax'), findsNothing);
    // Shipping, Sales tax and Total wait for an address, in Mono.
    final dashes = tester.widgetList<Text>(find.text('–')).toList();
    expect(dashes, hasLength(3));
    for (final dash in dashes) {
      expect(dash.style!.fontFamily, StudioType.geistMono);
    }
    expect(find.text('Shipping and tax are added once you enter an address.'), findsOneWidget);
    // No Insurance or Fees: the app has neither.
    expect(find.text('Insurance'), findsNothing);
    expect(find.text('Fees'), findsNothing);

    expect(find.text('All sales are final. See terms', findRichText: true), findsOneWidget);
    expect(_collect(tester).onPressed, isNull);
    expect(tester.getSize(find.widgetWithText(StudioButton, 'Collect this piece')).height, 54);
  });

  testWidgets('ready: values in Ink, full breakdown, Collect enabled', (tester) async {
    await _open(tester, shipping: _shipping, payment: CollectPaymentMethod.card);
    expect(find.text('Crated, standard · Dallas, TX'), findsOneWidget);
    expect(find.text('Credit / Debit card'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Crated, standard · Dallas, TX')).style!.color,
      StudioColors.light.textPrimary,
    );
    expect(find.text('–'), findsNothing);
    expect(find.text(r'$180.00'), findsOneWidget); // shipping
    expect(find.text(r'$288.75'), findsOneWidget); // tax (8.25 %, as before)
    final total = tester.widget<Text>(find.text(r'$3,968.75'));
    expect(total.style!.fontSize, 15);
    expect(total.style!.fontWeight, StudioType.medium);
    expect(find.text('Shipping and tax are added once you enter an address.'), findsNothing);
    expect(_collect(tester).onPressed, isNotNull);
  });

  testWidgets('as before, Collect enables once shipping is set, even without payment', (
    tester,
  ) async {
    await _open(tester, shipping: _shipping);
    expect(find.text('Add a payment method'), findsOneWidget);
    expect(_collect(tester).onPressed, isNotNull);
  });

  testWidgets('dark and the smallest phone render without overflow', (tester) async {
    await _open(tester, dark: true);
    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(find.text('Checkout')).style!.color, StudioColors.dark.textPrimary);
    await _open(tester, size: const Size(375, 667));
    expect(tester.takeException(), isNull);
  });
}
