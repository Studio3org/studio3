import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:studio3/models/post_image_transform.dart';
import 'package:studio3/screens/post_cover_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/utils/crop_cover_math.dart';
import 'package:studio3/widgets/studio/studio_icon.dart';
import 'package:studio3/widgets/studio/studio_on_image.dart';

import 'golden_harness.dart';

/// `PostCover` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 8): the piece framing step.
/// The last test writes the golden for the board comparison
/// (`NEW_UI_GOLDENS=1 flutter test ... --update-goldens`).
late List<String> _photos;

typedef _Result = ({
  List<String> paths,
  List<PostImageTransform> transforms,
  int index,
});

Widget _host(
  List<String> paths, {
  bool dark = false,
  List<PostImageTransform>? transforms,
  void Function(_Result)? onNext,
  void Function(_Result)? onBack,
  void Function(_Result)? onAdd,
}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: PostCoverPage(
    imagePaths: paths,
    initialTransforms: transforms,
    onBack: (p, t) => onBack?.call((paths: p, transforms: t, index: 0)),
    onAddPhotos: (p, t) => onAdd?.call((paths: p, transforms: t, index: 0)),
    onNext: (p, t, i) => onNext?.call((paths: p, transforms: t, index: i)),
  ),
);

Finder get _frame => find.byWidgetPredicate(
  (w) => w is GestureDetector && w.onScaleStart != null,
);

Finder _thumb(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

Finder get _thumbs => find.byWidgetPredicate(
  (w) => w is Semantics && (w.properties.label ?? '').startsWith('Photo '),
);

Finder get _addTile => find.bySemanticsLabel('Add a photo');

Finder _label(String text) =>
    find.byWidgetPredicate((w) => w is StudioImageLabel && w.text == text);

void main() {
  setUpAll(() async {
    await loadStudioFonts();
    final dir = Directory.systemTemp.createTempSync('post_cover');
    // The board's teal art ground, landscape so the 3:4 frame can be dragged sideways.
    final photo = img.Image(width: 400, height: 300)
      ..clear(img.ColorRgb8(0x70, 0xA4, 0xB0));
    _photos = [
      for (var i = 0; i < 4; i++)
        (File(
          '${dir.path}/p$i.png',
        )..writeAsBytesSync(img.encodePng(photo))).path,
    ];
  });

  for (final dark in [false, true]) {
    testWidgets(
      'dark in both themes: Ink, back, "Set your cover", Next (${dark ? 'dark' : 'light'})',
      (tester) async {
        setBoardViewport(tester);
        await tester.pumpWidget(_host(_photos, dark: dark));
        await tester.pump();

        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          StudioColors.ink,
        );
        final title = tester.widget<Text>(find.text('Set your cover'));
        expect(title.style!.fontSize, 16);
        expect(title.style!.fontWeight, FontWeight.w500);
        expect(title.style!.color, StudioColors.galleryWhite);
        final next = tester.widget<Text>(find.text('Next'));
        expect(next.style!.fontSize, 15);
        expect(next.style!.color, StudioColors.galleryWhite);
        final back = tester.widget<StudioIcon>(
          find.byWidgetPredicate(
            (w) => w is StudioIcon && w.asset == StudioIcons.backBold,
          ),
        );
        expect(back.color, StudioColors.galleryWhite);
        expect(find.bySemanticsLabel('Close'), findsNothing);
        expect(find.byType(Icon), findsNothing);
      },
    );
  }

  testWidgets('3:4 frame in 24 margins, thirds grid, Cover and 1 / N labels', (
    tester,
  ) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_host(_photos));
    await tester.pump();

    expect(tester.getSize(_frame), const Size(342, 456));
    expect(tester.getTopLeft(_frame), const Offset(24, 76));
    expect(_label('Cover'), findsNWidgets(2)); // frame + first thumb
    expect(_label('1 / 4'), findsOneWidget);
    expect(find.text('Drag or pinch to fit the frame'), findsOneWidget);
    expect(find.text('Just the piece, up to 4 angles'), findsOneWidget);
    expect(
      find.text(
        'Drag to reorder. The first photo is the cover. Studio and process shots go in a Scene.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    '62×83 thumbs; tapping one shows it, drops the frame Cover label',
    (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_host(_photos));
      await tester.pump();

      expect(_thumbs, findsNWidgets(4));
      expect(tester.getSize(_thumb('Photo 2')), const Size(62, 83));
      expect(tester.getTopLeft(_thumb('Photo 1, cover')), const Offset(26, 582));

      await tester.tap(_thumb('Photo 3'));
      await tester.pump();
      expect(_label('3 / 4'), findsOneWidget);
      expect(_label('Cover'), findsOneWidget); // only the first thumb's
    },
  );

  testWidgets('one photo: no count; the strip shows it and the add tile', (
    tester,
  ) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_host(_photos.take(1).toList()));
    await tester.pump();
    expect(_thumbs, findsOneWidget);
    expect(_addTile, findsOneWidget);
    expect(_label('1 / 1'), findsNothing);
  });

  testWidgets('dashed add tile 62×83 after the thumbs; hidden at 4 photos', (
    tester,
  ) async {
    setBoardViewport(tester);
    _Result? added;
    await tester.pumpWidget(
      _host(_photos.take(3).toList(), onAdd: (r) => added = r),
    );
    await tester.pump();
    expect(tester.getSize(_addTile), const Size(62, 83));
    expect(tester.getTopLeft(_addTile), const Offset(26 + 3 * 72, 582));
    await tester.tap(_addTile);
    expect(added!.paths, _photos.take(3).toList());

    await tester.pumpWidget(_host(_photos));
    await tester.pump();
    expect(_addTile, findsNothing);
  });

  testWidgets('long-press drag reorders; the first photo becomes the cover', (
    tester,
  ) async {
    setBoardViewport(tester);
    _Result? result;
    await tester.pumpWidget(_host(_photos, onNext: (r) => result = r));
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(_thumb('Photo 3')));
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-16, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.tap(find.text('Next'));
    expect(result!.paths, [_photos[2], _photos[0], _photos[1], _photos[3]]);
  });

  testWidgets(
    'framing only: Next returns 3:4 fill, no rotation, flip or colour',
    (tester) async {
      setBoardViewport(tester);
      final edited = PostImageTransform()
        ..aspectRatio = CropAspectRatio.ratio16x9
        ..fitMode = CropFitMode.fit
        ..rotationDegrees = 90
        ..cropRect = const Rect.fromLTWH(0.1, 0.1, 0.5, 0.5)
        ..flipHorizontal = true
        ..brightness = 80;
      _Result? result;
      await tester.pumpWidget(
        _host(
          _photos.take(2).toList(),
          transforms: [edited, PostImageTransform()],
          onNext: (r) => result = r,
        ),
      );
      await tester.pump();
      await tester.tap(_thumb('Photo 2'));
      await tester.pump();
      await tester.tap(find.text('Next'));

      expect(result, isNotNull);
      expect(result!.paths, _photos.take(2).toList());
      expect(result!.index, 1);
      for (final t in result!.transforms) {
        expect(t.aspectRatio, CropAspectRatio.ratio3x4);
        expect(t.fitMode, CropFitMode.fill);
        expect(t.rotationDegrees, 0);
        expect(t.flipHorizontal, isFalse);
        expect(t.flipVertical, isFalse);
        expect([t.brightness, t.contrast, t.exposure], [50, 50, 50]);
      }
      expect(result!.transforms.first.cropRect, isNull);
    },
  );

  testWidgets('back and system back return to the gallery with the photos', (
    tester,
  ) async {
    setBoardViewport(tester);
    final backs = <_Result>[];
    await tester.pumpWidget(_host(_photos, onBack: backs.add));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.binding.handlePopRoute();
    expect(backs, hasLength(2));
    expect(backs.first.paths, _photos);
    expect(backs.first.transforms, hasLength(4));
  });

  testWidgets('drag pans the photo inside the frame', (tester) async {
    setBoardViewport(tester);
    _Result? result;
    await tester.pumpWidget(
      _host(_photos.take(1).toList(), onNext: (r) => result = r),
    );
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(_frame));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(15, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    await tester.tap(find.text('Next'));
    final rect = result!.transforms.single.cropRect!;
    // Dragging the photo right shows more of its left side.
    expect(rect.center.dx, lessThan(0.5));
    expect(rect.left, greaterThanOrEqualTo(0));
  });

  testWidgets('375 wide at text scale 1.4 does not overflow', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(375, 667),
          textScaler: TextScaler.linear(1.4),
        ),
        child: _host(_photos),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('golden: PostCover', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_host(_photos));
    // Decode the photos for real (file I/O and codecs need the real event loop).
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/PostCover.png'),
    );
    await checkAcceptance(tester);
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
