import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/collect_checkout.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/piece_detail/collect_payment_sheet.dart';
import 'package:studio3/widgets/studio/studio_button.dart';
import 'package:studio3/widgets/studio/studio_select_row.dart';
import 'package:studio3/widgets/studio/studio_sheet.dart';

import 'golden_harness.dart';

/// Payment picker (no board; docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 7).
Future<CollectPaymentMethod?> _open(
  WidgetTester tester, {
  bool dark = false,
  Size size = const Size(390, 844),
  Future<void> Function()? act,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  CollectPaymentMethod? picked;
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => picked = await CollectPaymentSheet.show(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  if (act != null) await act();
  return picked;
}

void main() {
  setUpAll(loadStudioFonts);

  testWidgets('board sheet, select rows (no radios, no icons), card chosen by default', (
    tester,
  ) async {
    await _open(tester);
    expect(find.byType(StudioSheetGrabber), findsOneWidget);
    expect(find.text('Payment'), findsOneWidget);
    final rows = tester.widgetList<StudioSelectRow>(find.byType(StudioSelectRow)).toList();
    expect(rows.map((r) => r.title), ['GPay', 'Apple Pay', 'Credit / Debit card']);
    expect(rows.last.selected, isTrue);
    expect(find.byType(Radio<CollectPaymentMethod>), findsNothing);
    expect(find.byType(Icon), findsNothing);
    expect(tester.getSize(find.widgetWithText(StudioButton, 'Save and next')).height, 54);
  });

  testWidgets('choosing Apple Pay returns it', (tester) async {
    late Future<CollectPaymentMethod?> result;
    CollectPaymentMethod? picked;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                result = CollectPaymentSheet.show(context);
                result.then((v) => picked = v);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple Pay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and next'));
    await tester.pumpAndSettle();
    expect(picked, CollectPaymentMethod.applePay);
  });

  testWidgets('dark and the smallest phone render without overflow', (tester) async {
    await _open(tester, dark: true, size: const Size(375, 667));
    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(find.text('Payment')).style!.color, StudioColors.dark.textPrimary);
  });
}
