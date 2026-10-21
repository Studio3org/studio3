import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/theme/studio_metrics.dart';
import 'package:studio3/widgets/bottom_nav.dart';
import 'package:studio3/widgets/studio/studio.dart';

/// Phase 3 shell checks: light and dark, sizes, motion, text size, and the
/// existing nav / back behaviour (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 7).
Widget _app(
  Widget child, {
  bool dark = false,
  bool reduceMotion = false,
  double bottomInset = 0,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, navChild) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          viewPadding: EdgeInsets.only(bottom: bottomInset),
          disableAnimations: reduceMotion,
          textScaler: textScaler,
        ),
        child: navChild!,
      );
    },
    home: child,
  );
}

void main() {
  test('floating nav tokens are the ink bar in both themes', () {
    expect(StudioColors.light.navFill, const Color(0xFF111111));
    expect(StudioColors.dark.navFill, StudioColors.light.navFill);
    expect(StudioColors.dark.navActive, StudioColors.light.navActive);
    expect(StudioColors.dark.navBorder, StudioColors.light.navBorder);
    expect(StudioColors.dark.navIconActive, StudioColors.light.navIconActive);
    expect(StudioColors.dark.navIconInactive, StudioColors.light.navIconInactive);
  });

  for (final dark in [false, true]) {
    testWidgets('floating nav sizes and color (${dark ? 'dark' : 'light'})', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var tapped = -1;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Stack(
              children: [
                BottomNav(
                  selectedNavIndex: BottomNavIndex.home,
                  onNavTap: (i) => tapped = i,
                ),
              ],
            ),
          ),
          dark: dark,
          bottomInset: 34,
        ),
      );

      final pill = tester.widget<Container>(
        find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final decoration = w.decoration;
          return decoration is BoxDecoration &&
              decoration.color == const Color(0xFF111111) &&
              decoration.borderRadius == BorderRadius.circular(StudioRadius.round);
        }),
      );
      final decoration = pill.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFF111111));
      expect(decoration.border, isNull);
      expect(tester.getSize(find.byWidget(pill)).height, 64);

      final pad = tester.widget<Padding>(
        find.descendant(of: find.byType(StudioFloatingNav), matching: find.byType(Padding)).first,
      );
      expect(pad.padding, const EdgeInsets.fromLTRB(16, 0, 16, 34 + 28));

      expect(tester.getSize(find.byType(AnimatedContainer).first), const Size(52, 48));
      expect(tester.getSize(find.byType(SvgPicture).first).width, 24);

      await tester.tap(find.bySemanticsLabel('Saved'));
      expect(tapped, BottomNavIndex.bookmark);
      await tester.tap(find.bySemanticsLabel('Profile'));
      expect(tapped, BottomNavIndex.profile);
    });
  }

  testWidgets('floating nav motion stops when reduced motion is on', (tester) async {
    await tester.pumpWidget(
        _app(
        Scaffold(
          body: Stack(
            children: [
              BottomNav(selectedNavIndex: 0, onNavTap: _noop),
            ],
          ),
        ),
        reduceMotion: true,
      ),
    );
    final motion = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
    expect(motion.duration, Duration.zero);
  });

  testWidgets('floating nav fits the smallest and largest phone widths', (tester) async {
    for (final width in [375.0, 440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 844));
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Stack(
              children: [
                BottomNav(selectedNavIndex: 0, onNavTap: _noop),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(StudioFloatingNav), findsOneWidget);
    }
    await tester.binding.setSurfaceSize(null);
  });

  for (final dark in [false, true]) {
    testWidgets('top bar color, type, and back target (${dark ? 'dark' : 'light'})', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        appBar: StudioTopBar(context: context, title: 'Settings'),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
          dark: dark,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(find.text('Settings'));
      expect(title.style!.fontSize, 17);
      expect(title.style!.fontWeight, FontWeight.w500);
      expect(
        title.style!.color,
        dark ? const Color(0xFFFAFAF8) : const Color(0xFF111111),
      );
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        dark ? const Color(0xFF111111) : const Color(0xFFFAFAF8),
      );
      expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 56);
      expect(tester.getSize(find.byType(IconButton)), const Size(44, 44));
      expect(
        tester.getSize(find.descendant(of: find.byType(IconButton), matching: find.byType(SvgPicture))).width,
        22,
      );

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });
  }

  testWidgets('top bar grows and wraps at a large text size', (tester) async {
    const title = 'Notification preferences';
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            appBar: StudioTopBar(context: context, title: title),
          ),
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text(title), findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight!, greaterThan(56));
  });
}

void _noop(int _) {}
