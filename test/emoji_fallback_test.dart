import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:studio3/theme/app_fonts.dart';
import 'package:studio3/theme/app_theme.dart';

/// Emoji stopped rendering on iOS wherever text used Inter — a chat message, a caption,
/// a bio — because Inter has no emoji glyphs and nothing ever told Flutter where else to
/// look. Android's own font fallback papered over the same gap, which is why it only ever
/// showed up on one platform, even though nothing about the fix is iOS-specific.
///
/// The fix relies on TextStyle.merge keeping a base style's fontFamilyFallback whenever
/// the style merged on top leaves it unset. These tests exercise that merge for real,
/// against the app's actual theme and an ad-hoc GoogleFonts.inter(...) call shaped exactly
/// like the ~500 already in the app — not just asserting the constant exists.
void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('every slot in the light and dark TextThemes carries the fallback', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final slots = <String, TextStyle?>{
        'displayLarge': theme.textTheme.displayLarge,
        'headlineMedium': theme.textTheme.headlineMedium,
        'titleLarge': theme.textTheme.titleLarge,
        // The one TextField actually merges onto (Material3), per
        // packages/flutter/lib/src/material/text_field.dart — the whole reason this is
        // not only a Text-widget problem.
        'titleMedium': theme.textTheme.titleMedium,
        'bodyLarge': theme.textTheme.bodyLarge,
        'bodyMedium': theme.textTheme.bodyMedium,
        'labelLarge': theme.textTheme.labelLarge,
      };
      slots.forEach((name, style) {
        expect(
          style?.fontFamilyFallback,
          containsAll(AppTheme.emojiFallback),
          reason: '$name is missing the emoji fallback',
        );
      });
    }
  });

  test('GoogleFonts.inter sets its own fontFamilyFallback — the reason a global '
      'DefaultTextStyle fix alone does not work', () {
    // TextStyle.merge only keeps a base style's fontFamilyFallback when the style merged
    // on top leaves that field null. GoogleFonts does not leave it null — it uses the
    // field itself for its own weight-variant bookkeeping — so any ad-hoc
    // GoogleFonts.inter(...) call always wins that merge and silently discards whatever
    // fallback an ambient DefaultTextStyle or the theme provided. This is what sent the
    // fix to AppFonts (which appends to, rather than relies on inheriting, that list)
    // instead of a single global wrapper.
    expect(GoogleFonts.inter(fontSize: 14).fontFamilyFallback, isNotEmpty);
  });

  test('AppFonts.inter and AppFonts.geist append the emoji fallback, not replace it', () {
    for (final style in [AppFonts.inter(fontSize: 14), AppFonts.geist(fontSize: 14)]) {
      expect(style.fontFamilyFallback, containsAll(AppTheme.emojiFallback));
      // GoogleFonts' own bookkeeping survives — this is additive.
      expect(style.fontFamilyFallback, isNot(equals(AppTheme.emojiFallback)));
    }
  });

  testWidgets(
    'a Text widget using AppFonts, exactly as every real screen does, renders with the fallback',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Text('😀', style: AppFonts.inter(fontSize: 14)),
          ),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final resolved = richText.text.style;
      expect(resolved?.fontFamilyFallback, containsAll(AppTheme.emojiFallback));
      // And Inter must still be the primary font — this is additive, not a replacement.
      expect(resolved?.fontFamily, contains('Inter'));
    },
  );

  testWidgets('a TextField with no explicit style resolves the fallback from the theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: TextField()),
      ),
    );

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(
      editable.style.fontFamilyFallback,
      containsAll(AppTheme.emojiFallback),
      reason: 'TextField merges onto theme.textTheme.titleMedium, not onto '
          'DefaultTextStyle — the theme fix has to carry this on its own',
    );
  });
}
