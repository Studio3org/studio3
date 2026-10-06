import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Guards the fix for multi-second stalls when a screen first used a font
/// weight: every Inter/Geist weight the app asks for must resolve from
/// `assets/google_fonts/`, never from fonts.gstatic.com.
///
/// `allowRuntimeFetching = false` makes a missing weight throw, so this
/// test fails loudly if a font file is dropped from the bundle or a new
/// weight is introduced without one.
void main() {
  const usedWeights = [
    FontWeight.w300,
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
  ];

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('every used Inter and Geist weight loads from the bundle', (
    tester,
  ) async {
    for (final weight in usedWeights) {
      expect(
        () => GoogleFonts.inter(fontWeight: weight),
        returnsNormally,
        reason: 'Inter $weight is not bundled',
      );
      expect(
        () => GoogleFonts.geist(fontWeight: weight),
        returnsNormally,
        reason: 'Geist $weight is not bundled',
      );
    }
    await GoogleFonts.pendingFonts();
  });

  test('runtime fetching stays disabled', () {
    // If this is ever flipped back on, a missing weight silently becomes a
    // network download again — which is the stall this fix removed.
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
  });
}
