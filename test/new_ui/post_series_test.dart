import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/series_summary.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/create_flow/create_series_dialog.dart';
import 'package:studio3/widgets/create_flow/series_picker_sheet.dart';
import 'package:studio3/widgets/studio/studio_button.dart';
import 'package:studio3/widgets/studio/studio_select_row.dart';
import 'package:studio3/widgets/studio/studio_sheet.dart';

/// Series picker, no board (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 8).
Widget _host(Future<Object?> Function(BuildContext) open, void Function(Object?) onResult,
        {bool dark = false}) =>
    MaterialApp(
      key: UniqueKey(),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => onResult(await open(context)),
            child: const Text('open'),
          ),
        ),
      ),
    );

final _series = [
  SeriesSummary.fromJson({'id': 's1', 'name': 'Bodies in Color', 'pieceCount': 3}),
  SeriesSummary.fromJson({'id': 's2', 'name': 'Night Studies', 'pieceCount': 1}),
];

Finder _row(String title) =>
    find.byWidgetPredicate((w) => w is StudioListRow && w.title == title);

void main() {
  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    testWidgets('sheet: None, series with counts, current one selected, New series (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      Object? result;
      await tester.pumpWidget(
        _host(
          (context) => showStudioSheet<SeriesPickerResult>(
            context: context,
            builder: (_) => SeriesPickerSheet(selectedSeriesId: 's1', debugSeries: _series),
          ),
          (r) => result = r,
          dark: dark,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(StudioSheetGrabber), findsOneWidget);
      expect(tester.widget<Text>(find.text('Series')).style!.color, c.textPrimary);
      expect(tester.widget<StudioListRow>(_row('None')).selected, isFalse);
      expect(tester.widget<StudioListRow>(_row('Bodies in Color')).selected, isTrue);
      expect(find.text('3 pieces'), findsOneWidget);
      expect(find.text('1 piece'), findsOneWidget);
      expect(find.text('New series'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);

      await tester.tap(_row('Night Studies'));
      await tester.pumpAndSettle();
      final picked = result! as SeriesPickerResult;
      expect((picked.selectedSeriesId, picked.displayLabel), ('s2', 'Night Studies'));
    });
  }

  testWidgets('New series asks for a name; Create stays off until there is one', (
    tester,
  ) async {
    Object? result;
    await tester.pumpWidget(
      _host(
        (context) => showStudioSheet<SeriesPickerResult>(
          context: context,
          builder: (_) => SeriesPickerSheet(debugSeries: _series),
        ),
        (r) => result = r,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.widget<StudioListRow>(_row('None')).selected, isTrue);
    await tester.tap(find.text('New series'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateSeriesDialog), findsOneWidget);
    final create = find.widgetWithText(StudioButton, 'Create');
    expect(tester.widget<StudioButton>(create).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '  Paper Planes ');
    await tester.pump();
    await tester.tap(create);
    await tester.pumpAndSettle();
    final picked = result! as SeriesPickerResult;
    expect((picked.newSeriesName, picked.hasSelection), ('Paper Planes', true));
  });
}
