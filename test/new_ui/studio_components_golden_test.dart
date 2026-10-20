import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/screens/debug/studio_gallery_page.dart';
import 'package:studio3/theme/app_theme.dart';

import 'fixtures/component_boards.dart';
import 'golden_harness.dart';

/// Phase 1 goldens (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 5):
///   * two boards composed only from the new components, to compare with the board renders:
///       python -I tool/new_ui/compare.py build/new_ui/boards/SavedEmpty.png \
///           test/new_ui/goldens/SavedEmpty_components.png
///   * the component gallery in light and in dark, for review.
///
///   NEW_UI_GOLDENS=1 flutter test test/new_ui --update-goldens
void main() {
  final skip = Platform.environment['NEW_UI_GOLDENS'] == null;

  Future<void> pumpThemed(WidgetTester tester, Widget child, {bool dark = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AppTheme.dark : AppTheme.light,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            // Screens get a Material from their Scaffold; without one, Text shows Flutter's
            // debug underline.
            child: Material(
              type: MaterialType.transparency,
              child: Align(alignment: Alignment.topLeft, child: child),
            ),
          ),
        ),
      ),
    );
    // Goldens capture from the MaterialApp so they come out at the view's 2x scale, like
    // the board renders (an inner repaint boundary would capture at 1x).
    // Let the SVG assets decode.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
  }

  testWidgets('SavedEmpty from components', (tester) async {
    await loadStudioFonts();
    setBoardViewport(tester);
    await pumpThemed(tester, const SavedEmptyFromComponents());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/SavedEmpty_components.png'),
    );
  }, skip: skip);

  testWidgets('SignIn4Intention from components', (tester) async {
    await loadStudioFonts();
    setBoardViewport(tester);
    await pumpThemed(tester, const SignIn4IntentionFromComponents());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/SignIn4Intention_components.png'),
    );
  }, skip: skip);

  for (final dark in [false, true]) {
    testWidgets('SignInFirst haze and logo (${dark ? 'dark' : 'light'})', (tester) async {
      await loadStudioFonts();
      setBoardViewport(tester);
      await pumpThemed(tester, const SignInHazeFromComponents(), dark: dark);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/SignInFirst${dark ? 'Dark' : ''}_haze_components.png'),
      );
    }, skip: skip);
  }

  for (final dark in [false, true]) {
    testWidgets('component gallery (${dark ? 'dark' : 'light'})', (tester) async {
      await loadStudioFonts();
      setBoardViewport(tester, height: 3900);
      await pumpThemed(
        tester,
        SizedBox(
          width: 390,
          height: 3900,
          child: Material(
            color: dark ? const Color(0xFF111111) : const Color(0xFFFAFAF8),
            child: const StudioGalleryBody(),
          ),
        ),
        dark: dark,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/gallery_${dark ? 'dark' : 'light'}.png'),
      );
    }, skip: skip);
  }
}
