import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/models/order.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/theme/studio_type.dart';
import 'package:studio3/widgets/piece_detail/collect_order_confirmation_sheet.dart';
import 'package:studio3/widgets/studio/studio_button.dart';
import 'package:studio3/widgets/studio/studio_iridescent.dart';

import 'golden_harness.dart';

/// `CollectConfirm` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 7). The last test writes
/// the golden for the crop comparison (`NEW_UI_GOLDENS=1 ... --update-goldens`).
const _item = FeedPreviewItem(
  id: 'p1',
  imageSeeds: [1],
  title: 'Paper Planes I',
  medium: 'Oil',
  year: 2025,
  dimensions: '',
  story: '',
  handle: '@amarasart',
  isAvailable: true,
  aspectRatio: FeedAspectRatio.portrait3x4,
  authorName: 'Amara Osei',
);

Order _order({String status = 'paid', bool dev = false}) => Order(
  id: 'o1',
  status: status,
  artworkCents: 350000,
  shippingCents: 18000,
  taxCents: 28875,
  totalCents: 396875,
  createdAt: DateTime(2026, 10, 22, 12),
  devMode: dev,
);

Widget _host(Widget sheet, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  routes: {'/orders': (_) => const Scaffold(body: Text('My orders'))},
  home: Scaffold(
    body: Align(alignment: Alignment.topCenter, child: sheet),
  ),
);

void _phone(WidgetTester tester, Size size, {double ratio = 1}) {
  tester.view.physicalSize = size * ratio;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('collect_confirm').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  testWidgets('framed art, "[Title] is yours", artist, provenance, orders + share', (tester) async {
    _phone(tester, const Size(390, 844));
    await tester.pumpWidget(_host(CollectOrderConfirmationSheet(order: _order(), item: _item)));
    await tester.pump();

    // 204 × 272 art inside a 4 px iridescent frame.
    expect(
      find.byWidgetPredicate((w) => w is SizedBox && w.width == 204 && w.height == 272),
      findsOneWidget,
    );
    final frame = tester.widget<StudioIridescent>(find.byType(StudioIridescent).first);
    expect(frame.padding, const EdgeInsets.all(4));

    final title = tester.widget<Text>(find.text('Paper Planes I is yours'));
    expect(title.style!.fontSize, 28);
    expect(title.style!.fontWeight, StudioType.medium);
    expect(title.style!.letterSpacing, -0.5);
    expect(find.text('By Amara Osei.'), findsOneWidget);

    expect(find.text('Provenance'), findsOneWidget);
    final date = tester.widget<Text>(find.text('Oct 22, 2026'));
    expect(date.style!.fontFamily, StudioType.geistMono);
    // Only the rows the order has.
    expect(find.text('Record no.'), findsNothing);
    expect(find.text('Edition'), findsNothing);

    expect(tester.getSize(find.widgetWithText(StudioButton, 'View your orders')).height, 54);
    expect(find.widgetWithText(StudioButton, 'Share'), findsOneWidget);
    // The old order summary and Done button are gone.
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('View your orders opens My orders', (tester) async {
    _phone(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        routes: {'/orders': (_) => const Scaffold(body: Text('My orders'))},
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  CollectOrderConfirmationSheet.show(context, order: _order(), item: _item),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('View your orders'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('My orders'), findsOneWidget);
  });

  testWidgets('pending order and missing piece fall back to the old wording', (tester) async {
    _phone(tester, const Size(390, 844));
    await tester.pumpWidget(_host(CollectOrderConfirmationSheet(order: _order(status: 'pending'))));
    await tester.pump();
    expect(find.text('Order placed'), findsOneWidget);
    expect(find.widgetWithText(StudioButton, 'Share'), findsNothing);

    await tester.pumpWidget(
      _host(CollectOrderConfirmationSheet(order: _order(dev: true), item: _item)),
    );
    await tester.pump();
    expect(find.text('Test mode — no real payment was captured.'), findsOneWidget);
  });

  testWidgets('dark, reduced motion, and the smallest phone', (tester) async {
    _phone(tester, const Size(375, 667));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Scaffold(
              body: CollectOrderConfirmationSheet(order: _order(), item: _item),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Text>(find.text('Paper Planes I is yours')).style!.color,
      StudioColors.dark.textPrimary,
    );
    // Reduced motion: the iridescence holds still (the image's own loading shimmer
    // aside, nothing in the sheet animates).
    final frames = tester.widgetList(find.byType(StudioIridescent));
    expect(frames.length, greaterThanOrEqualTo(2));
  });

  testWidgets('CollectConfirm golden', (tester) async {
    // Tests draw shadows unblurred by default; the frame's soft shadow is part of the board.
    debugDisableShadows = false;
    setBoardViewport(tester);
    await tester.pumpWidget(
      _host(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
          child: CollectOrderConfirmationSheet(order: _order(), item: _item),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    final title = tester.getRect(find.text('Paper Planes I is yours'));
    final line = tester.getRect(find.text('By Amara Osei.'));
    File('build/new_ui/CollectConfirm_positions.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'titleTop': title.top, 'lineBottom': line.bottom}));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/CollectConfirm.png'));
    debugDisableShadows = true;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  }, skip: Platform.environment['NEW_UI_GOLDENS'] == null);
}
