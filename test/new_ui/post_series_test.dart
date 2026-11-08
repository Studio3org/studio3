import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/models/series_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/screens/series_editor_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/create_flow/series_picker_sheet.dart';
import 'package:studio3/widgets/studio/studio_button.dart';
import 'package:studio3/widgets/studio/studio_field.dart';
import 'package:studio3/widgets/studio/studio_sheet.dart';

import 'golden_harness.dart';

/// `SeriesPicker`, `SeriesNew`, `SeriesEdit` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 8).
Widget _host(
  Future<Object?> Function(BuildContext) open,
  void Function(Object?) onResult, {
  bool dark = false,
}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
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
  SeriesSummary.fromJson({'id': 's1', 'name': 'Bodies in Color', 'pieceCount': 6}),
  SeriesSummary.fromJson({'id': 's2', 'name': 'Paper Planes', 'pieceCount': 3}),
  SeriesSummary.fromJson({'id': 's3', 'name': 'Night Studies', 'pieceCount': 2}),
];

Finder _row(String title) =>
    find.byWidgetPredicate((w) => w is SeriesOptionRow && w.title == title);

Future<Object?> Function(BuildContext) _picker({String? selected}) =>
    (context) => showStudioSheet<SeriesPickerResult>(
      context: context,
      builder: (_) => SeriesPickerSheet(selectedSeriesId: selected, debugSeries: _series),
    );

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    testWidgets('picker: None, series with Mono counts, select then Done (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      Object? result;
      await tester.pumpWidget(_host(_picker(selected: 's1'), (r) => result = r, dark: dark));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(StudioSheetGrabber), findsOneWidget);
      final title = tester.widget<Text>(find.text('Series'));
      expect((title.style!.fontSize, title.style!.color), (22, c.textPrimary));
      expect(find.text('This piece stands alone'), findsOneWidget);
      expect(tester.widget<SeriesOptionRow>(_row('None')).selected, isFalse);
      expect(tester.widget<SeriesOptionRow>(_row('Bodies in Color')).selected, isTrue);
      final count = tester.widget<Text>(find.text('6 PIECES'));
      expect(count.style!.fontFamily, contains('Mono'));
      expect(find.text('+ New series'), findsOneWidget);
      expect(tester.widget<SeriesOptionRow>(_row('Night Studies')).divider, isFalse);

      // Tapping selects; Done returns it.
      await tester.tap(_row('Night Studies'));
      await tester.pump();
      expect(result, isNull);
      expect(tester.widget<SeriesOptionRow>(_row('Night Studies')).selected, isTrue);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      final picked = result! as SeriesPickerResult;
      expect((picked.selectedSeriesId, picked.displayLabel), ('s3', 'Night Studies'));
    });
  }

  testWidgets('None then Done clears the series', (tester) async {
    Object? result;
    await tester.pumpWidget(_host(_picker(selected: 's1'), (r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(_row('None'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect((result! as SeriesPickerResult).hasSelection, isFalse);
  });

  testWidgets('New series: name and optional description; Create series makes it', (
    tester,
  ) async {
    Object? result;
    await tester.pumpWidget(_host(_picker(), (r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ New series'));
    await tester.pumpAndSettle();

    expect(find.text('This piece will be the first in it.'), findsOneWidget);
    final fields = tester.widgetList<StudioUnderlineField>(find.byType(StudioUnderlineField));
    expect(fields.map((f) => f.label), ['Name', 'Description']);
    expect(fields.last.maxLength, 300);
    expect(find.text('Optional · up to 300 characters'), findsOneWidget);
    final create = find.widgetWithText(StudioButton, 'Create series');
    expect(tester.widget<StudioButton>(create).onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, '  Paper Planes ');
    await tester.enterText(find.byType(TextField).last, 'Folded studies.');
    await tester.pump();
    await tester.tap(create);
    await tester.pumpAndSettle();
    final picked = result! as SeriesPickerResult;
    expect(
      (picked.newSeriesName, picked.newSeriesDescription, picked.hasSelection),
      ('Paper Planes', 'Folded studies.', true),
    );
  });

  final pieces = [
    for (final t in ['I', 'II', 'III', 'IV'])
      PieceSummary(id: t, title: 'Bodies in Color $t'),
  ];
  final edited = SeriesSummary(
    id: 's1',
    name: 'Bodies in Color',
    pieceCount: 4,
    description:
        'A study of skin under colored light. Each piece started from the same pose, painted '
        'at a different hour…',
  );

  for (final dark in [false, true]) {
    testWidgets('edit: Cancel / Save, name, description, pieces with Remove (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1000);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: SeriesEditorPage(seriesId: 's1', debugSeries: edited, debugPieces: pieces),
        ),
      );
      await tester.pump();
      expect(find.text('Edit series'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Bodies in Color'), findsOneWidget);
      expect(find.textContaining('A study of skin'), findsOneWidget);
      expect(find.text('Pieces · newest first'), findsOneWidget);
      expect(find.text('Remove'), findsNWidgets(4));
      expect(find.text('+ Add pieces'), findsOneWidget);
      expect(find.text('Delete series'), findsOneWidget); // B15
    });
  }

  // BACKEND_CHANGES B15: "Delete series asks to confirm; the pieces stay on the profile, just not
  // grouped." (`NoteSeriesEdit`)
  group('Delete series', () {
    Future<(_Server, List<Object?>)> open(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final server = _Server();
      ApiClient.instance.debugUseAdapter(server);
      final wasToken = AuthSession.instance.accessToken;
      AuthSession.instance.accessToken = 'token';
      addTearDown(() => AuthSession.instance.accessToken = wasToken);
      setBoardViewport(tester, height: 1000);
      final results = <Object?>[];
      await tester.pumpWidget(
        _host(
          (context) => Navigator.push<SeriesEditResult>(
            context,
            MaterialPageRoute<SeriesEditResult>(
              builder: (_) => SeriesEditorPage(seriesId: 's1', debugSeries: edited, debugPieces: pieces),
            ),
          ),
          results.add,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (server, results);
    }

    testWidgets('asks first; Cancel keeps the series', (tester) async {
      final (server, results) = await open(tester);
      await tester.tap(find.text('Delete series'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this series?'), findsOneWidget);
      expect(find.text('The pieces stay on your profile, just not grouped.'), findsOneWidget);
      await tester.tap(find.widgetWithText(StudioButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(server.requests, isEmpty);
      expect(find.text('Edit series'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('confirmed, deletes it on the server and closes saying so', (tester) async {
      final (server, results) = await open(tester);
      await tester.tap(find.text('Delete series'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(StudioButton, 'Delete series'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(server.requests, [('DELETE', '/api/series/s1')]);
      expect(find.text('Edit series'), findsNothing);
      expect(results, [SeriesEditResult.deleted]);
    });

    testWidgets('Cancel in the header closes with nothing changed', (tester) async {
      final (server, results) = await open(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(server.requests, isEmpty);
      expect(results, [null]);
    });
  });

  group('goldens', () {
    final skip = Platform.environment['NEW_UI_GOLDENS'] != '1';
    testWidgets('SeriesPicker', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_host(_picker(selected: 's1'), (_) {}));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/SeriesPicker.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('SeriesNew', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _host((context) => SeriesNewSheet.show(context, initial: const SeriesDraft(name: 'Night Studies')), (_) {}),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/SeriesNew.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('SeriesEdit', (tester) async {
      setBoardViewport(tester, height: 1000);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: SeriesEditorPage(seriesId: 's1', debugSeries: edited, debugPieces: pieces),
        ),
      );
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/SeriesEdit.png'));
      await checkAcceptance(tester);
    }, skip: skip);
  });
}

/// Answers `DELETE /api/series/<id>` as the server does.
class _Server implements HttpClientAdapter {
  final requests = <(String, String)>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    requests.add((options.method, options.uri.path));
    final id = options.uri.pathSegments.last;
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'message': 'Series deleted.', 'data': {'id': id, 'deleted': true}}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
