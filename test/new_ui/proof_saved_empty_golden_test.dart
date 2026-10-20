import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/saved_empty_replica.dart';
import 'golden_harness.dart';

/// Phase 0 proof that the board-vs-app comparison works end to end
/// (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 0.4): a replica of the `SavedEmpty` board
/// rendered at its frame (390×844 @2x) with the bundled fonts, then compared with the board
/// render by `tool/new_ui/compare.py`.
///
/// Golden tests only run when asked (`NEW_UI_GOLDENS=1`): glyph rendering differs slightly by
/// OS, so they're a review tool, not part of every `flutter test` run.
///
///   NEW_UI_GOLDENS=1 flutter test test/new_ui --update-goldens
void main() {
  testWidgets(
    'SavedEmpty replica at the board frame',
    (tester) async {
      await loadStudioFonts();
      setBoardViewport(tester);
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Align(alignment: Alignment.topLeft, child: SavedEmptyReplica()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(find.byType(SavedEmptyReplica), matchesGoldenFile('goldens/SavedEmpty.png'));
    },
    skip: Platform.environment['NEW_UI_GOLDENS'] == null,
  );
}
