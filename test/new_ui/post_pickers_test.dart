import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/data/post_location_options.dart';
import 'package:studio3/data/post_picker_options.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/choose_location_sheet.dart';
import 'package:studio3/widgets/post_create_option_sheet.dart';
import 'package:studio3/widgets/post_picker_search_field.dart';
import 'package:studio3/widgets/studio/studio_button.dart';
import 'package:studio3/widgets/studio/studio_select_row.dart';
import 'package:studio3/widgets/studio/studio_sheet.dart';

import 'golden_harness.dart';

/// `PostMedium`, `PostLocation` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 8).
Widget _host(void Function(BuildContext) open, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(onPressed: () => open(context), child: const Text('open')),
      ),
    ),
  ),
);

Finder _row(String title) =>
    find.byWidgetPredicate((w) => w is StudioListRow && w.title == title);

const _dallas = PostLocationOption(
  id: 'dallas',
  name: 'Dallas, TX',
  subtitle: 'United States',
  displayName: 'Dallas, TX, United States',
);

void main() {
  setUpAll(loadStudioFonts);

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    final theme = dark ? 'dark' : 'light';

    testWidgets('medium: grabber, title, search, count, left-line rows, Done ($theme)', (
      tester,
    ) async {
      setBoardViewport(tester);
      final picks = <Set<String>>[];
      await tester.pumpWidget(
        _host(
          (context) => PostCreateOptionSheet.show(
            context,
            title: 'Medium',
            searchHint: 'Search mediums',
            options: PostMediumOptions.all,
            selectedIds: {'oil'},
            mode: PostPickerSelectionMode.multiCheckbox,
            onSelectionChanged: picks.add,
          ),
          dark: dark,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(StudioSheetGrabber), findsOneWidget);
      expect(tester.widget<Text>(find.text('Medium')).style!.fontSize, 22);
      expect(find.text('Pick all that apply. The first one shows on the piece.'), findsOneWidget);
      expect(find.byType(PostPickerSearchField), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);
      expect(tester.widget<StudioListRow>(_row('Oil')).selected, isTrue);
      final acrylic = tester.widget<Text>(
        find.descendant(of: _row('Acrylic'), matching: find.text('Acrylic')),
      );
      expect(acrylic.style!.color, c.textBody);

      await tester.tap(_row('Mixed media'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('2 selected'), findsOneWidget);
      expect(picks.last.toList(), ['oil', 'mixed_media']);

      await tester.enterText(find.byType(TextField), 'photo');
      await tester.pump();
      expect(_row('Photography'), findsOneWidget);
      expect(_row('Oil'), findsNothing);

      await tester.tap(find.widgetWithText(StudioButton, 'Done'));
      await tester.pumpAndSettle();
      expect(find.byType(PostCreateOptionSheet), findsNothing);
    });
  }

  testWidgets('style: up to three, the fourth shows a toast', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(
      _host(
        (context) => PostCreateOptionSheet.show(
          context,
          title: 'Style',
          searchHint: 'Search styles',
          options: PostStyleOptions.all,
          selectedIds: PostStyleOptions.all.take(3).map((o) => o.id).toSet(),
          mode: PostPickerSelectionMode.multiCheckbox,
          maxSelections: 3,
          onSelectionChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Pick up to 3.'), findsOneWidget);
    expect(find.text('3 of 3 selected'), findsOneWidget);
    await tester.tap(_row(PostStyleOptions.all[4].name));
    await tester.pump();
    expect(find.text('You can pick up to 3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('location: current city row, selected city, privacy footer, Done returns it', (
    tester,
  ) async {
    setBoardViewport(tester);
    PostLocationOption? picked;
    await tester.pumpWidget(
      _host(
        (context) => ChooseLocationSheet.show(
          context,
          selected: _dallas,
          onLocationSelected: (l) => picked = l,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Where the piece is now.'), findsOneWidget);
    expect(find.text('Use my current city'), findsOneWidget);
    expect(tester.widget<StudioListRow>(_row('Dallas, TX')).selected, isTrue);
    expect(
      find.text(
        'Only the city shows on your piece. Your exact pickup address stays private in '
        'payout settings.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(StudioButton, 'Done'));
    await tester.pumpAndSettle();
    expect(picked, _dallas);
    expect(find.byType(ChooseLocationSheet), findsNothing);
  });

  testWidgets('location: Done is off until a city is chosen', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(
      _host((context) => ChooseLocationSheet.show(context, onLocationSelected: (_) {})),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Done')).onPressed,
      isNull,
    );
  });

  testWidgets('golden: PostMedium', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(
      _host(
        (context) => PostCreateOptionSheet.show(
          context,
          title: 'Medium',
          searchHint: 'Search mediums',
          options: PostMediumOptions.all,
          selectedIds: {'oil', 'mixed_media'},
          mode: PostPickerSelectionMode.multiCheckbox,
          onSelectionChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/PostMedium.png'));
    await checkAcceptance(tester);
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
