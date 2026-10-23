import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:studio3/models/post_image_transform.dart';
import 'package:studio3/screens/post_edit_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/utils/crop_cover_math.dart';
import 'package:studio3/utils/image_adjust_math.dart';

import 'golden_harness.dart';

/// `ScenePhotoEditSize`, `ScenePhotoEdit` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 8).
late String _photo;

typedef _Next = ({List<PostImageTransform> transforms, int index});

Widget _host({bool dark = false, void Function(_Next)? onNext, VoidCallback? onBack}) =>
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: PostEditPage(
        postType: 'scene',
        customImagePaths: [_photo],
        onClose: onBack,
        onNext: (_, t, i) => onNext?.call((transforms: t, index: i)),
      ),
    );

Finder _pill(String label) => find.text(label);

void main() {
  setUpAll(() async {
    await loadStudioFonts();
    final dir = Directory.systemTemp.createTempSync('scene_edit');
    final photo = img.Image(width: 366, height: 488)..clear(img.ColorRgb8(0x3A, 0x36, 0x32));
    _photo = (File('${dir.path}/scene.png')..writeAsBytesSync(img.encodePng(photo))).path;
  });

  for (final dark in [false, true]) {
    testWidgets('dark in both themes: Ink, back, Next, Size / Crop / Adjust tabs (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_host(dark: dark));
      await tester.pump();
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, StudioColors.ink);
      for (final label in ['Size', 'Crop', 'Adjust', 'Next', 'Original', '4:5', '1:1', '9:16']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tester.widget<Text>(find.text('Size')).style!.color, StudioColors.galleryWhite);
      // A fresh photo starts on Original, as the board.
      expect(tester.widget<Text>(find.text('Original')).style!.color, StudioColors.ink);
      expect(tester.widget<Text>(find.text('Crop')).style!.color, const Color(0xFF8A8A8A));
      expect(find.byType(Icon), findsNothing);
    });
  }

  testWidgets('Size: 1:1 then Original; Next returns the shape', (tester) async {
    setBoardViewport(tester);
    final results = <_Next>[];
    await tester.pumpWidget(_host(onNext: results.add));
    await tester.pump();
    await tester.tap(_pill('1:1'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    expect(results.last.transforms.single.aspectRatio, CropAspectRatio.ratio1x1);
    expect(results.last.transforms.single.originalAspect, isNull);

    await tester.tap(_pill('Original'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    expect(results.last.transforms.single.originalAspect, isNotNull);
  });

  testWidgets('Adjust: four tools, zero-centred slider with a signed Mono value', (
    tester,
  ) async {
    setBoardViewport(tester);
    final results = <_Next>[];
    await tester.pumpWidget(_host(onNext: results.add));
    await tester.pump();
    await tester.tap(find.text('Adjust'));
    await tester.pump();
    for (final label in ['Brightness', 'Contrast', 'Warmth']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('0'), findsOneWidget);
    final slider = find.bySemanticsLabel('brightness');
    final box = tester.getRect(slider);
    await tester.tapAt(Offset(box.left + box.width * 0.56, box.center.dy));
    await tester.pump();
    expect(find.text('+6'), findsOneWidget);

    await tester.tap(find.text('Warmth'));
    await tester.pump();
    await tester.tapAt(Offset(box.left + box.width * 0.25, box.center.dy));
    await tester.pump();
    expect(find.text('-25'), findsOneWidget);

    await tester.tap(find.text('Next'));
    final t = results.single.transforms.single;
    expect(t.brightness, closeTo(56, 0.5));
    expect(t.warmth, closeTo(25, 0.5));
    expect(
      ImageAdjustMath.isNeutral(
        brightness: 50,
        contrast: 50,
        exposure: 50,
        warmth: t.warmth,
      ),
      isFalse,
    );
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('Crop: Rotate turns a quarter, Flip mirrors, Reset clears', (tester) async {
    setBoardViewport(tester);
    final results = <_Next>[];
    await tester.pumpWidget(_host(onNext: results.add));
    await tester.pump();
    await tester.tap(find.text('Crop'));
    await tester.pump();
    expect(find.text('0°'), findsOneWidget);
    await tester.tap(_pill('Rotate'));
    await tester.tap(_pill('Flip'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    expect(results.last.transforms.single.rotationDegrees, -90);
    expect(results.last.transforms.single.flipHorizontal, isTrue);
    await tester.tap(_pill('Reset'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    expect(results.last.transforms.single.rotationDegrees, 0);
    expect(results.last.transforms.single.flipHorizontal, isFalse);
  });

  testWidgets('back goes to the gallery', (tester) async {
    setBoardViewport(tester);
    var back = false;
    await tester.pumpWidget(_host(onBack: () => back = true));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Back'));
    expect(back, isTrue);
  });

  for (final tab in ['Size', 'Adjust']) {
    testWidgets('golden: ScenePhotoEdit $tab', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_host());
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump();
      }
      if (tab == 'Adjust') {
        await tester.tap(find.text('Adjust'));
        await tester.pump();
        final box = tester.getRect(find.bySemanticsLabel('brightness'));
        await tester.tapAt(Offset(box.left + box.width * 0.56, box.center.dy));
        await tester.pump();
      } else {
        await tester.tap(_pill('Original'));
        await tester.pump();
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          tab == 'Size' ? 'goldens/ScenePhotoEditSize.png' : 'goldens/ScenePhotoEdit.png',
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
  }
}
