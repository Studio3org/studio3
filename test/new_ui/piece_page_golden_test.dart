import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/screens/available_piece_detail_page.dart';
import 'package:studio3/screens/piece_detail_page.dart';
import 'package:studio3/theme/app_theme.dart';

import 'golden_harness.dart';

/// The piece pages with the boards' own sample text, for the crop comparisons in
/// docs/new-ui/NEW_UI_EXECUTION_PLAN.md (Phase 7). Each also writes where its title block
/// starts, so the crop lines up with the board even though the app keeps the like row and
/// sizes the image by `HandoffSizes` (520, not the mock's 470).
///
///   NEW_UI_GOLDENS=1 flutter test test/new_ui/piece_page_golden_test.dart --update-goldens
FeedPreviewItem _boardPiece({required bool forSale}) {
  return FeedPreviewItem(
    id: 'p1',
    imageSeeds: const [1],
    title: 'Bodies in Color',
    medium: 'Oil',
    year: 2025,
    dimensions: '24 × 36 in',
    story:
        'Started this one trying to paint skin as light rather than surface. The teal came '
        "first. I wasn't really planning it, but once it was there everything else had to "
        'answer to it.',
    handle: '@amarasart',
    isAvailable: forSale,
    aspectRatio: FeedAspectRatio.portrait3x4,
    authorName: 'Amara Osei',
    priceCents: forSale ? 350000 : null,
    materials: const ['Oil paint', 'Linen canvas', 'Palette knife'],
    location: 'Dallas, TX',
    framingNote: 'Unframed',
    handlingNotes: 'Fragile, ships in a custom crate',
    styleTags: const ['Figurative', 'Portrait'],
    seriesName: 'Bodies in Color',
    seriesThumbs: const [1, 2, 3],
    seriesPieceCount: 6,
  );
}

Future<void> _golden(
  WidgetTester tester, {
  required Widget page,
  required String board,
  required double height,
}) async {
  dotenv.loadFromString(envString: '', isOptional: true);
  // The image cache asks path_provider for a folder; tests have no plugin for it.
  final tmp = Directory.systemTemp.createTempSync('piece_page_golden').path;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => tmp,
  );
  await loadStudioFonts();
  setBoardViewport(tester, height: height);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Builder(
        builder: (context) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: page),
      ),
    ),
  );
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();

  final title = tester.getRect(find.text('Bodies in Color').first);
  final story = tester.getRect(find.textContaining('Started this one'));
  File('build/new_ui/${board}_positions.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode({'titleTop': title.top, 'storyBottom': story.bottom}));
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${board}_page.png'));
  await checkAcceptance(tester);
  // Let the image cache's retry timers finish before the test ends.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

void main() {
  final skip = Platform.environment['NEW_UI_GOLDENS'] == null;

  testWidgets('BuyPieceFull page', (tester) async {
    await _golden(
      tester,
      page: AvailablePieceDetailPage(item: _boardPiece(forSale: true)),
      board: 'BuyPieceFull',
      height: 1980,
    );
  }, skip: skip);

  testWidgets('PieceNotForSale page', (tester) async {
    await _golden(
      tester,
      page: PieceDetailPage(item: _boardPiece(forSale: false)),
      board: 'PieceNotForSale',
      height: 1980,
    );
  }, skip: skip);
}
