import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/piece_detail/collect_piece_sheet.dart';

import 'golden_harness.dart';

/// `BuyCheckoutEmpty` content with the board's sample data, for the crop comparison in
/// docs/new-ui/NEW_UI_EXECUTION_PLAN.md (Phase 7). Writes where the Shipping row starts so
/// the crop skips the sheet's grabber (the board draws a full screen) and the thumbnail.
///
///   NEW_UI_GOLDENS=1 flutter test test/new_ui/checkout_golden_test.dart --update-goldens
void main() {
  testWidgets('BuyCheckoutEmpty sheet content', (tester) async {
    dotenv.loadFromString(envString: '', isOptional: true);
    final tmp = Directory.systemTemp.createTempSync('checkout_golden').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
    await loadStudioFonts();
    setBoardViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: CollectPieceSheet(
              item: FeedPreviewItem(
                id: 'p1',
                imageSeeds: [1],
                title: 'Bodies in Color',
                medium: 'Oil',
                year: 2025,
                dimensions: '24 × 36 in',
                story: '',
                handle: '@amarasart',
                isAvailable: true,
                aspectRatio: FeedAspectRatio.portrait3x4,
                authorName: 'Amara Osei',
                priceCents: 350000,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();

    final shippingLabel = tester.getRect(find.text('Shipping').first);
    final note = tester.getRect(find.text('Shipping and tax are added once you enter an address.'));
    File('build/new_ui/BuyCheckoutEmpty_positions.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({'shippingLabelTop': shippingLabel.top, 'noteBottom': note.bottom}),
      );
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/BuyCheckoutEmpty.png'));
    await checkAcceptance(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  }, skip: Platform.environment['NEW_UI_GOLDENS'] == null);
}
