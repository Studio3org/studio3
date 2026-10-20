import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared setup for new-UI golden tests (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 0.4).
///
/// A golden written here is compared against the matching board render from
/// `tool/new_ui/render_boards.mjs` with `tool/new_ui/compare.py`. For that comparison to be
/// meaningful both sides must use the same fonts, the same frame size and the same scale, so:
///   * [loadStudioFonts] loads the bundled Geist / Geist Mono / Outfit files (Flutter tests
///     otherwise draw every glyph as a box);
///   * [setBoardViewport] sizes the test view to the board's frame in logical pixels at
///     [kBoardScale] — the same `--scale` the board renderer uses.
const double kBoardScale = 2;

Future<void> loadStudioFonts() async {
  const families = {
    'Geist': ['Geist-Regular.ttf', 'Geist-Medium.ttf'],
    'GeistMono': ['GeistMono-Regular.ttf', 'GeistMono-Medium.ttf'],
    'Outfit': ['Outfit-VariableFont_wght.ttf'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      loader.addFont(rootBundle.load('assets/fonts/$file'));
    }
    await loader.load();
  }
}

/// Sizes the test view to a board frame (default: the 390×844 phone template).
void setBoardViewport(WidgetTester tester, {double width = 390, double height = 844}) {
  tester.view.devicePixelRatio = kBoardScale;
  tester.view.physicalSize = Size(width * kBoardScale, height * kBoardScale);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
