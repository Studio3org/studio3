import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/address.dart';
import 'package:studio3/models/collect_checkout.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/theme/studio_type.dart';
import 'package:studio3/widgets/piece_detail/collect_shipping_method_sheet.dart';
import 'package:studio3/widgets/studio/studio_button.dart';
import 'package:studio3/widgets/studio/studio_select_row.dart';
import 'package:studio3/widgets/studio/studio_switch.dart';

import 'golden_harness.dart';

/// `BuyShipping` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 7). The golden at the end is
/// for the crop comparison (`NEW_UI_GOLDENS=1 ... --update-goldens`).
const _address = Address(
  id: 'a1',
  firstName: 'Alex',
  lastName: 'Smith',
  phone: '2145550142',
  line1: '1234 Lovers Ln',
  city: 'Dallas',
  state: 'TX',
  zip: '75225',
);

const _methods = [
  CollectShippingMethod(
    id: 'std',
    title: 'Crated, standard',
    duration: 'Ships in 7 to 10 days',
    priceCents: 18000,
  ),
  CollectShippingMethod(
    id: 'wg',
    title: 'Crated, white glove',
    duration: 'Delivered and unpacked by appointment',
    priceCents: 42000,
  ),
];

Widget _sheet() =>
    const CollectShippingMethodSheet(pieceId: 'p1', address: _address, debugMethods: _methods);

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: Scaffold(
    body: Align(alignment: Alignment.topCenter, child: home),
  ),
);

void _phone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });

  testWidgets('Ship to, Change, delivery select rows with prices, partner line, Continue', (
    tester,
  ) async {
    _phone(tester, const Size(390, 844));
    await tester.pumpWidget(_app(_sheet()));
    await tester.pump();
    final c = StudioColors.light;

    expect(find.text('Shipping'), findsOneWidget);
    expect(find.text('Ship to'), findsOneWidget);
    expect(find.text('Alex Smith, 1234 Lovers Ln'), findsOneWidget);
    expect(find.text('Dallas, TX 75225', findRichText: true), findsOneWidget);
    expect(tester.widget<Text>(find.text('Change')).style!.color, c.textSecondary);
    expect(find.text('Delivery'), findsOneWidget);

    final rows = tester.widgetList<StudioSelectRow>(find.byType(StudioSelectRow)).toList();
    expect(rows.map((r) => r.title), ['Crated, standard', 'Crated, white glove']);
    expect(rows.first.selected, isTrue);
    expect(rows.first.titleSize, 17);
    expect(rows.first.subtitleSize, 13);
    final price = tester.widget<Text>(find.text(r'$180.00'));
    expect(price.style!.color, c.textPrimary);
    expect(tester.widget<Text>(find.text(r'$420.00')).style!.color, c.textTertiary);
    expect(find.byType(Radio<String>), findsNothing);

    // No insurance today: no switch, no coverage tooltip.
    expect(find.byType(StudioSwitch), findsNothing);
    expect(find.textContaining('€1,000'), findsNothing);

    expect(
      find.text('Quotes come from our fine art shipping partner and include crating.'),
      findsOneWidget,
    );
    final button = find.widgetWithText(StudioButton, 'Continue');
    expect(tester.getSize(button).height, 54);
    expect(tester.widget<StudioButton>(button).onPressed, isNotNull);
  });

  testWidgets('choosing another option moves the line and returns it', (tester) async {
    _phone(tester, const Size(390, 844));
    CollectShippingSelection? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => picked = await showModalBottomSheet<CollectShippingSelection>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _sheet(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crated, white glove'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(r'$420.00')).style!.color, StudioColors.light.textPrimary);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(picked?.method.id, 'wg');
    expect(picked?.address.id, 'a1');
  });

  testWidgets('dark and the smallest phone render without overflow', (tester) async {
    _phone(tester, const Size(375, 667));
    await tester.pumpWidget(_app(_sheet(), dark: true));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(find.text('Delivery')).style!.color, StudioColors.dark.textPrimary);
    expect(StudioType.label13().fontSize, 13);
  });

  testWidgets('BuyShipping golden', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(_sheet()));
    await tester.pump();
    // Let the selection line finish drawing in.
    await tester.pump(const Duration(milliseconds: 400));
    final shipTo = tester.getRect(find.text('Ship to'));
    final lastRow = tester.getRect(find.byType(StudioSelectRow).last);
    File('build/new_ui/BuyShipping_positions.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'shipToTop': shipTo.top, 'rowsBottom': lastRow.bottom}));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/BuyShipping.png'));
    await checkAcceptance(tester);
  }, skip: Platform.environment['NEW_UI_GOLDENS'] == null);
}
