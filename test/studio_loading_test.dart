import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/studio_loading.dart';

void main() {
  group('StudioBubbleGeometry', () {
    test('preserves Figma size hierarchy largest > medium > smallest', () {
      final diameters = StudioBubbleGeometry.bubbles
          .map((b) => b.diameter)
          .toList();
      expect(diameters[0], greaterThan(diameters[1]));
      expect(diameters[1], greaterThan(diameters[2]));
      expect(diameters, [623, 398, 242]);
    });

    test('preserves Figma positions and artboard size', () {
      expect(StudioBubbleGeometry.designWidth, 1088);
      expect(StudioBubbleGeometry.designHeight, 854);
      expect(StudioBubbleGeometry.bubbles[0].left, 0);
      expect(StudioBubbleGeometry.bubbles[0].top, 231);
      expect(StudioBubbleGeometry.bubbles[1].left, 586);
      expect(StudioBubbleGeometry.bubbles[1].top, 0);
      expect(StudioBubbleGeometry.bubbles[2].left, 846);
      expect(StudioBubbleGeometry.bubbles[2].top, 442);
    });

    test('activates bubbles strictly largest → medium → smallest', () {
      expect(StudioBubbleGeometry.activeIndex(0.0), 0);
      expect(StudioBubbleGeometry.activeIndex(0.1), 0);
      expect(StudioBubbleGeometry.activeIndex(0.34), 1);
      expect(StudioBubbleGeometry.activeIndex(0.5), 1);
      expect(StudioBubbleGeometry.activeIndex(0.67), 2);
      expect(StudioBubbleGeometry.activeIndex(0.9), 2);
    });

    test('uses the faster pulse timing and subtle expansion', () {
      expect(
        StudioBubbleGeometry.cycleDuration,
        const Duration(milliseconds: 1200),
      );
      expect(
        StudioBubbleGeometry.phaseDuration,
        const Duration(milliseconds: 400),
      );
      expect(StudioBubbleGeometry.activeScalePeak, 1.075);
    });

    test('only one bubble has non-zero emphasis at a time', () {
      for (final t in [0.05, 0.2, 0.4, 0.55, 0.75, 0.95]) {
        final emphases = List.generate(
          StudioBubbleGeometry.bubbleCount,
          (i) => StudioBubbleGeometry.emphasis(t, i),
        );
        final activeCount = emphases.where((e) => e > 0).length;
        expect(activeCount, 1, reason: 't=$t emphases=$emphases');
        expect(
          emphases.indexWhere((e) => e > 0),
          StudioBubbleGeometry.activeIndex(t),
        );
      }
    });
  });

  group('StudioBubbleLoader widget', () {
    Future<void> pumpLoader(
      WidgetTester tester, {
      ThemeData? theme,
      Size size = const Size(390, 844),
      bool disableAnimations = false,
      Widget? child,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: disableAnimations,
          ),
          child: MaterialApp(
            theme: theme ?? AppTheme.light,
            home: Scaffold(
              body:
                  child ?? const Center(child: StudioBubbleLoader(width: 120)),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders three circular bubbles with stable composition size', (
      tester,
    ) async {
      await pumpLoader(tester);

      final composition = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(StudioBubbleLoader),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(composition.width, 120);
      expect(
        composition.height,
        closeTo(
          120 *
              StudioBubbleGeometry.designHeight /
              StudioBubbleGeometry.designWidth,
          0.001,
        ),
      );

      final circles = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(circles, findsNWidgets(3));

      final sizes = tester
          .widgetList<Positioned>(
            find.descendant(
              of: find.byType(StudioBubbleLoader),
              matching: find.byType(Positioned),
            ),
          )
          .map((p) => p.width!)
          .toList();
      expect(sizes[0], greaterThan(sizes[1]));
      expect(sizes[1], greaterThan(sizes[2]));
    });

    testWidgets('composition size stays stable across animation phases', (
      tester,
    ) async {
      await pumpLoader(tester);

      Size compositionSize() {
        final box = tester.renderObject<RenderBox>(
          find
              .descendant(
                of: find.byType(StudioBubbleLoader),
                matching: find.byType(SizedBox),
              )
              .first,
        );
        return box.size;
      }

      final initial = compositionSize();
      await tester.pump(const Duration(milliseconds: 600));
      expect(compositionSize(), initial);
      await tester.pump(const Duration(milliseconds: 600));
      expect(compositionSize(), initial);
      await tester.pump(const Duration(milliseconds: 600));
      expect(compositionSize(), initial);
    });

    testWidgets('full-screen overlay centers loader', (tester) async {
      await pumpLoader(tester, child: const StudioLoadingOverlay());

      final overlayBox = tester.getRect(find.byType(StudioLoadingOverlay));
      final loaderBox = tester.getRect(find.byType(StudioBubbleLoader));
      expect(overlayBox.width, 390);
      expect(overlayBox.height, 844);
      expect((loaderBox.center.dx - overlayBox.center.dx).abs(), lessThan(0.5));
      expect((loaderBox.center.dy - overlayBox.center.dy).abs(), lessThan(0.5));
    });

    testWidgets('uses the light theme colours on a light overlay', (tester) async {
      await pumpLoader(
        tester,
        theme: AppTheme.light,
        child: const StudioLoadingOverlay(),
      );

      final colored = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(StudioLoadingOverlay),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(colored.color, StudioColors.light.background);

      final circle = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(StudioLoadingOverlay),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is DecoratedBox &&
                    w.decoration is BoxDecoration &&
                    (w.decoration as BoxDecoration).shape == BoxShape.circle,
              ),
            )
            .first,
      );
      expect(
        (circle.decoration as BoxDecoration).color,
        StudioColors.light.textPrimary,
      );
    });

    testWidgets('dark overlay uses AppTheme.dark semantics', (tester) async {
      await pumpLoader(
        tester,
        theme: AppTheme.dark,
        child: const StudioLoadingOverlayDark(),
      );

      final colored = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(StudioLoadingOverlayDark),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(colored.color, AppTheme.dark.scaffoldBackgroundColor);

      final circle = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(StudioLoadingOverlayDark),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is DecoratedBox &&
                    w.decoration is BoxDecoration &&
                    (w.decoration as BoxDecoration).shape == BoxShape.circle,
              ),
            )
            .first,
      );
      expect(
        (circle.decoration as BoxDecoration).color,
        AppTheme.dark.colorScheme.onSurface,
      );
    });

    testWidgets('respects ColorScheme.onSurface when no override', (
      tester,
    ) async {
      const accent = Color(0xFF4A92BE);
      final theme = ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
          onSurface: accent,
        ),
      );
      await pumpLoader(
        tester,
        theme: theme,
        child: const Center(child: StudioBubbleLoader(width: 100)),
      );

      final circle = tester.widget<DecoratedBox>(
        find
            .byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).shape == BoxShape.circle,
            )
            .first,
      );
      expect((circle.decoration as BoxDecoration).color, accent);
    });

    testWidgets('reduced motion keeps static bubbles', (tester) async {
      await pumpLoader(tester, disableAnimations: true);

      expect(find.byType(StudioBubbleLoader), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
        findsNWidgets(3),
      );

      // No animation ticks should be required; composition remains present.
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(StudioBubbleLoader), findsOneWidget);
    });

    testWidgets('exposes loading semantics', (tester) async {
      await pumpLoader(tester);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });

    testWidgets('gate shows overlay only while loading', (tester) async {
      await pumpLoader(
        tester,
        child: const StudioLoadingGate(
          loading: true,
          child: SizedBox.expand(child: ColoredBox(color: Colors.red)),
        ),
      );
      expect(find.byType(StudioLoadingOverlay), findsOneWidget);

      await pumpLoader(
        tester,
        child: const StudioLoadingGate(
          loading: false,
          child: SizedBox.expand(child: ColoredBox(color: Colors.red)),
        ),
      );
      expect(find.byType(StudioLoadingOverlay), findsNothing);
    });

    testWidgets('login experience is isolated from regular dark loaders', (
      tester,
    ) async {
      await pumpLoader(
        tester,
        child: const StudioLoadingGate(
          loading: true,
          dark: true,
          loginExperience: true,
          child: SizedBox.expand(),
        ),
      );
      expect(find.byType(StudioLoginLoadingOverlay), findsOneWidget);
      expect(find.text('This will only take a moment'), findsNothing);
      expect(find.byType(StudioLoadingOverlayDark), findsNothing);

      await pumpLoader(
        tester,
        child: const StudioLoadingGate(
          loading: true,
          dark: true,
          child: SizedBox.expand(),
        ),
      );
      expect(find.byType(StudioLoadingOverlayDark), findsOneWidget);
      expect(find.byType(StudioLoginLoadingOverlay), findsNothing);
    });

    testWidgets('centers across small and tablet viewports', (tester) async {
      for (final size in const [
        Size(320, 568),
        Size(390, 844),
        Size(768, 1024),
      ]) {
        await pumpLoader(
          tester,
          size: size,
          child: const StudioLoadingOverlay(),
        );
        final overlayBox = tester.getRect(find.byType(StudioLoadingOverlay));
        final loaderBox = tester.getRect(find.byType(StudioBubbleLoader));
        expect(
          (loaderBox.center.dx - overlayBox.center.dx).abs(),
          lessThan(0.5),
          reason: 'width=${size.width}',
        );
        expect(
          (loaderBox.center.dy - overlayBox.center.dy).abs(),
          lessThan(0.5),
          reason: 'height=${size.height}',
        );
      }
    });

    testWidgets('StudioLoadingBody embeds compact loader', (tester) async {
      await pumpLoader(tester, child: const StudioLoadingBody());
      final loader = tester.widget<StudioBubbleLoader>(
        find.byType(StudioBubbleLoader),
      );
      expect(loader.width, 96);
    });
  });
}
