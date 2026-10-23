import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:studio3/screens/post_video_edit_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';

import 'golden_harness.dart';

/// `SceneTrim`, `SceneCover` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 8).
late Uint8List _frame;

Widget _host({
  double durationMs = 90000,
  bool dark = false,
  void Function(SceneVideoResult)? onNext,
  VoidCallback? onClose,
}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: PostVideoEditPage(
    videoPath: 'clip.mp4',
    initialCover: _frame,
    debugDurationMs: durationMs,
    onClose: onClose ?? () {},
    onNext: onNext ?? (_) {},
  ),
);

void main() {
  setUpAll(() async {
    await loadStudioFonts();
    final image = img.Image(width: 90, height: 160)..clear(img.ColorRgb8(0x3A, 0x36, 0x32));
    _frame = img.encodePng(image);
  });

  for (final dark in [false, true]) {
    testWidgets('trim: Ink, "Edit", hint, kept / cap in Mono, strip, Mute audio (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_host(dark: dark));
      await tester.pump();
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, StudioColors.ink);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Drag the ends to trim'), findsOneWidget);
      // A 1:30 clip starts trimmed to the 1:00 cap.
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == '1:00 / 1:00'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Trim start'), findsOneWidget);
      expect(find.bySemanticsLabel('Trim end'), findsOneWidget);
      expect(find.text('Mute audio'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  }

  testWidgets('dragging the end shortens the clip; never past the cap or under 1 s', (
    tester,
  ) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_host(durationMs: 40000));
    await tester.pump();
    expect(
      find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == '0:40 / 1:00'),
      findsOneWidget,
    );
    await tester.drag(find.bySemanticsLabel('Trim end'), const Offset(-171, 0));
    await tester.pump();
    final text = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .firstWhere((t) => t.endsWith(' / 1:00'));
    expect(text, isNot('0:40 / 1:00'));
    await tester.drag(find.bySemanticsLabel('Trim end'), const Offset(-400, 0));
    await tester.pump();
    expect(
      find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == '0:01 / 1:00'),
      findsOneWidget,
    );
  });

  testWidgets('Next opens the cover step: frame window, four previews, upload; back returns', (
    tester,
  ) async {
    setBoardViewport(tester);
    SceneVideoResult? result;
    var closed = false;
    await tester.pumpWidget(_host(onNext: (r) => result = r, onClose: () => closed = true));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Mute audio').last);
    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Set a cover'), findsOneWidget);
    expect(find.bySemanticsLabel('Cover frame'), findsOneWidget);
    for (final label in ['Full screen', 'Shelf', 'Square', 'Landscape']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Upload a cover instead'), findsOneWidget);
    expect(find.text("How it'll look around the app"), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pump();
    expect(find.text('Edit'), findsOneWidget);
    expect(closed, isFalse);
    await tester.tap(find.bySemanticsLabel('Back'));
    expect(closed, isTrue);

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    // Trimmed and muted: the export runs (no plugin in tests, so the original is kept).
    expect(result!.length, const Duration(minutes: 1));
    expect(result!.cover, _frame);
  });

  for (final step in ['Trim', 'Cover']) {
    testWidgets('golden: Scene$step', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_host(durationMs: 42000));
      await tester.pump();
      if (step == 'Cover') {
        await tester.tap(find.text('Next'));
        await tester.pump();
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/Scene$step.png'),
      );
    }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
  }
}
