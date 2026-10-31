import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/auth_palette.dart';
import 'package:studio3/widgets/studio/studio.dart';

/// Behaviour of the Phase 1 components (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 5).
/// Their looks are checked against the boards by studio_components_golden_test.dart.
Widget _app(Widget child, {bool dark = false, bool reduceMotion = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: Scaffold(body: child),
      ),
    ),
  );
}

Border? _underline(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(StudioUnderlineField),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border != null,
      ),
    ),
  );
  return (box.decoration as BoxDecoration).border as Border?;
}

Finder _info(String label) =>
    find.byWidgetPredicate((w) => w is StudioInfoButton && w.semanticLabel == label);

void main() {
  group('theme', () {
    test('both themes register StudioColors and keep AuthPalette', () {
      expect(AppTheme.light.extension<StudioColors>(), StudioColors.light);
      expect(AppTheme.dark.extension<StudioColors>(), StudioColors.dark);
      expect(AppTheme.light.extension<AuthPalette>(), AuthPalette.light);
      expect(AppTheme.dark.extension<AuthPalette>(), AuthPalette.dark);
      expect(AppTheme.light.scaffoldBackgroundColor, const Color(0xFFFAFAF8));
      expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xFF111111));
      expect(AppTheme.light.textTheme.bodyMedium!.fontFamily, 'Geist');
    });

    testWidgets('context.studio follows the theme', (tester) async {
      late StudioColors seen;
      Widget probe() => Builder(
        builder: (context) {
          seen = context.studio;
          return const SizedBox();
        },
      );
      await tester.pumpWidget(_app(probe()));
      expect(seen, StudioColors.light);
      await tester.pumpWidget(_app(probe(), dark: true));
      await tester.pumpAndSettle();
      expect(seen.background, StudioColors.dark.background);
    });

    test('every style lays text out in a CSS line box', () {
      for (final style in [
        StudioType.title32(),
        StudioType.body16(),
        StudioType.body14(),
        StudioType.mono11(),
      ]) {
        expect(style.height, isNotNull);
        expect(style.leadingDistribution, TextLeadingDistribution.even);
      }
      // Chrome's "normal": rounded ascent + descent (22 px -> 22 + 6 = 28).
      expect(StudioType.sans(22).height! * 22, closeTo(28, 1e-9));
      expect(StudioType.body14().height! * 14, closeTo(18, 1e-9));
    });
  });

  testWidgets('StudioButton: disabled without a callback, taps when enabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            StudioButton(label: 'Continue', onPressed: () => taps++),
            const StudioButton(label: 'Locked', onPressed: null),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Continue'));
    await tester.tap(find.text('Locked'));
    expect(taps, 1);
    final locked = tester.widget<Material>(
      find.ancestor(of: find.text('Locked'), matching: find.byType(Material)).first,
    );
    expect(locked.color, StudioColors.light.buttonDisabledFill);
    expect(tester.getSize(find.byType(StudioButton).first).height, 52);
  });

  testWidgets('StudioUnderlineField: Ink 1.5 px underline on focus, required dot until filled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Padding(
          padding: EdgeInsets.all(24),
          child: StudioUnderlineField(label: 'Title', required: true),
        ),
      ),
    );
    expect(_underline(tester)!.bottom, BorderSide(color: StudioColors.light.lineStrong));
    expect(find.byType(StudioRequiredDot), findsOneWidget);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(
      _underline(tester)!.bottom,
      BorderSide(color: StudioColors.light.textPrimary, width: 1.5),
    );

    await tester.enterText(find.byType(TextField), 'Portrait Dream');
    await tester.pump();
    expect(find.byType(StudioRequiredDot), findsNothing);
  });

  testWidgets('StudioSelectRow: selected row is indented 16 with the line; taps select', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              for (var i = 0; i < 2; i++)
                StudioSelectRow(
                  title: 'Option $i',
                  selected: selected == i,
                  onTap: () => setState(() => selected = i),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Option 0')).dx - tester.getTopLeft(find.text('Option 1')).dx,
      16,
    );
    await tester.tap(find.text('Option 1'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(
      tester.getTopLeft(find.text('Option 1')).dx - tester.getTopLeft(find.text('Option 0')).dx,
      16,
    );
  });

  testWidgets('StudioTooltip: one open at a time, tap anywhere closes', (tester) async {
    Widget field(String label, String message) => StudioTooltip(
      message: message,
      builder: (context, toggle) => StudioUnderlineField(
        label: label,
        labelTrailing: StudioInfoButton(onTap: toggle, semanticLabel: 'What is $label?'),
      ),
    );
    await tester.pumpWidget(
      _app(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              field('Weight', 'Weight help'),
              const SizedBox(height: 120),
              field('Framing', 'Framing help'),
              const SizedBox(height: 120),
              const Text('elsewhere'),
            ],
          ),
        ),
      ),
    );

    await tester.tap(_info('What is Weight?'));
    await tester.pump();
    expect(find.text('Weight help'), findsOneWidget);

    await tester.tap(_info('What is Framing?'));
    await tester.pump();
    expect(find.text('Weight help'), findsNothing);
    expect(find.text('Framing help'), findsOneWidget);

    await tester.tap(find.text('elsewhere'));
    await tester.pump();
    expect(find.text('Framing help'), findsNothing);
  });

  testWidgets('StudioSwitch toggles', (tester) async {
    var on = false;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) =>
              StudioSwitch(value: on, onChanged: (v) => setState(() => on = v)),
        ),
      ),
    );
    expect(tester.getSize(find.byType(StudioSwitch)), const Size(44, 26));
    await tester.tap(find.byType(StudioSwitch));
    await tester.pumpAndSettle();
    expect(on, isTrue);
  });

  testWidgets('showStudioToast shows one toast and removes it', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showStudioToast(context, 'Saved'),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('showStudioSheet: grabber and content, capped at 90 %', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showStudioSheet<void>(
              context: context,
              builder: (_) => const StudioSheet(children: [Text('Sign in to save this piece')]),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(StudioSheetGrabber), findsOneWidget);
    expect(tester.getSize(find.byType(StudioSheetGrabber)), const Size(40, 5));
    expect(find.text('Sign in to save this piece'), findsOneWidget);
  });

  testWidgets('reduced motion: iridescence and haze stay still', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            StudioStatusChip(StudioStatus.collected),
            SizedBox(height: 200, child: StudioHaze()),
          ],
        ),
        reduceMotion: true,
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('floating nav: 64 tall, reports taps, person icon when signed out', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(
      _app(
        Align(
          alignment: Alignment.bottomCenter,
          child: StudioFloatingNav(
            currentIndex: 0,
            onTap: (i) => tapped = i,
            items: const [
              StudioNavItem(label: 'Home', icon: StudioIcons.home),
              StudioNavItem(label: 'Profile', isProfile: true),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(GestureDetector).last);
    expect(tapped, 1);
    expect(find.byType(StudioAvatar), findsNothing);
    final pill = find
        .descendant(of: find.byType(StudioFloatingNav), matching: find.byType(Container))
        .first;
    expect(tester.getSize(pill).height, 64);
  });
}
