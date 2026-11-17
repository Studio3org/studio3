import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/studio/studio.dart';
import 'package:studio3/widgets/wide_screen_column.dart';

/// Launch checklist 1.5: on an iPad the app keeps to a centred, phone-width column, and on a
/// phone (or a narrow iPad window) nothing changes.
void main() {
  late Size seen;
  late EdgeInsets seenPadding;

  Widget app({bool dark = false}) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => WideScreenColumn(child: child!),
    home: Builder(
      builder: (context) {
        seen = MediaQuery.sizeOf(context);
        seenPadding = MediaQuery.paddingOf(context);
        return Scaffold(
          body: SizedBox.expand(
            key: const Key('page'),
            child: Center(
              child: TextButton(
                onPressed: () => showStudioSheet<void>(
                  context: context,
                  builder: (_) => const StudioSheet(children: [SizedBox(key: Key('sheet'), height: 120)]),
                ),
                child: const Text('open sheet'),
              ),
            ),
          ),
        );
      },
    ),
  );

  Future<void> pumpAt(WidgetTester tester, Size size, {EdgeInsets padding = EdgeInsets.zero, bool dark = false}) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = size * 2;
    tester.view.padding = FakeViewPadding(left: padding.left * 2, top: padding.top * 2, right: padding.right * 2, bottom: padding.bottom * 2);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(dark: dark));
  }

  for (final phone in [const Size(375, 667), const Size(390, 844), const Size(440, 956)]) {
    testWidgets('phone ${phone.width.toInt()} wide: untouched', (tester) async {
      await pumpAt(tester, phone);
      expect(tester.getRect(find.byKey(const Key('page'))), Offset.zero & phone);
      expect(seen, phone);
    });
  }

  for (final narrow in [const Size(320, 1024), const Size(507, 1024)]) {
    testWidgets('narrow iPad window ${narrow.width.toInt()} wide (Slide Over, Split View): untouched', (tester) async {
      await pumpAt(tester, narrow);
      expect(tester.getRect(find.byKey(const Key('page'))).width, narrow.width);
    });
  }

  testWidgets('iPad portrait: a 600 column in the middle, and the page sees 600', (tester) async {
    await pumpAt(tester, const Size(1024, 1366), padding: const EdgeInsets.only(top: 24, bottom: 20));
    expect(tester.getRect(find.byKey(const Key('page'))), const Rect.fromLTWH(212, 0, 600, 1366));
    expect(seen, const Size(600, 1366));
    expect(seenPadding, const EdgeInsets.only(top: 24, bottom: 20), reason: 'top and bottom safe areas stay');
  });

  testWidgets('iPad landscape: the column, with side insets inside the margins dropped', (tester) async {
    await pumpAt(tester, const Size(1366, 1024), padding: const EdgeInsets.only(left: 20, top: 24, right: 20, bottom: 20));
    expect(tester.getRect(find.byKey(const Key('page'))), const Rect.fromLTWH(383, 0, 600, 1024));
    expect(seenPadding, const EdgeInsets.only(top: 24, bottom: 20));
  });

  testWidgets('iPad: sheets open inside the column too', (tester) async {
    await pumpAt(tester, const Size(1024, 1366));
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    final sheet = tester.getRect(find.byKey(const Key('sheet')));
    expect(sheet.left, greaterThanOrEqualTo(212));
    expect(sheet.right, lessThanOrEqualTo(812));
  });

  for (final dark in [false, true]) {
    testWidgets('iPad margins take the page colour (${dark ? 'dark' : 'light'})', (tester) async {
      await pumpAt(tester, const Size(1024, 1366), dark: dark);
      final box = tester.widget<ColoredBox>(
        find.descendant(of: find.byType(WideScreenColumn), matching: find.byType(ColoredBox)).first,
      );
      final theme = dark ? AppTheme.dark : AppTheme.light;
      expect(box.color, theme.scaffoldBackgroundColor);
    });
  }
}
