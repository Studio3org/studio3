import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/theme/studio_colors.dart';

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

/// Section 19.1 checks on the screen as it is now (called right after each board golden, so the
/// golden itself is untouched): tap targets at least 44 × 44, every tappable thing labelled, and
/// text drawn only in theme colour tokens (or white / Ink on a picture), so its contrast is the
/// token's (`acceptance_19_1_test.dart` holds the token contrast). [skipTapTargets] lists the
/// labels of controls that are knowingly smaller, each logged in plan 0.3.
Future<void> checkAcceptance(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  try {
    await tester.pump();
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    final screen = find.byType(Scaffold).evaluate().isEmpty ? find.byType(MaterialApp) : find.byType(Scaffold);
    final dark = Theme.of(tester.element(screen.first)).brightness == Brightness.dark;
    final c = dark ? StudioColors.dark : StudioColors.light;
    final off = <String>{};
    for (final paragraph in tester.allRenderObjects.whereType<RenderParagraph>()) {
      paragraph.text.visitChildren((span) {
        final colour = span.style?.color;
        if (colour != null && !studioTextColourAllowed(c, colour)) {
          off.add('${span.toPlainText().trim()} (#${colour.toARGB32().toRadixString(16)})');
        }
        return true;
      });
    }
    expect(off, isEmpty, reason: 'text outside the theme colour tokens');
  } finally {
    handle.dispose();
  }
}

/// A theme token, or white / Ink at any opacity (text and marks on a picture or a dark screen).
bool studioTextColourAllowed(StudioColors c, Color colour) {
  final tokens = [
    c.background, c.surface, c.card, c.line, c.lineStrong, c.textPrimary, c.textBody, c.textSecondary,
    c.textTertiary, c.textPlaceholder, c.buttonFill, c.buttonText, c.buttonDisabledFill,
    c.buttonDisabledText, c.navActive, c.navIconActive, c.navIconInactive, c.available, c.positive,
    c.alert, c.tooltipText, StudioColors.ink, StudioColors.galleryWhite, StudioColors.onDarkSecondary,
    StudioColors.onDarkTertiary, StudioColors.onDarkOff, StudioColors.onDarkChipText,
  ];
  if (tokens.contains(colour)) return true;
  final rgb = colour.toARGB32() & 0xFFFFFF;
  return rgb == 0xFFFFFF || rgb == 0xFAFAF8 || rgb == 0x111111 || rgb == 0x000000;
}
