import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/screens/host/host_event_page.dart';
import 'package:studio3/screens/post_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/utils/shell_back.dart';

import 'golden_harness.dart';

/// The phone's back button (the user's call, 2026-11-08, as on Instagram): on the tabs it goes
/// Home first; on Home the first back goes to the top and refreshes, the next closes the app;
/// posting a piece, Scene or event asks before back leaves it.

final _now = DateTime(2026, 11, 8, 10);

/// A first screen with a button that opens [page] over it, so back has somewhere to go.
Widget _over(Widget page, {bool dark = false}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  group('the tabs (ShellBack)', () {
    test('another tab goes Home first', () {
      final back = ShellBack();
      expect(back.onBack(onHome: false, homeAtTop: true), ShellBackAction.goHome);
      expect(back.armed, isFalse);
    });

    test('on Home: first back refreshes at the top, the next closes the app', () {
      final back = ShellBack();
      expect(back.onBack(onHome: true, homeAtTop: true), ShellBackAction.refreshHome);
      expect(back.onBack(onHome: true, homeAtTop: true), ShellBackAction.exit);
    });

    test('scrolled down again: back goes to the top again before closing', () {
      final back = ShellBack();
      expect(back.onBack(onHome: true, homeAtTop: false), ShellBackAction.refreshHome);
      expect(back.onBack(onHome: true, homeAtTop: false), ShellBackAction.refreshHome);
      expect(back.onBack(onHome: true, homeAtTop: true), ShellBackAction.exit);
    });

    test('from another tab: Home, then the top, then closed; leaving Home starts over', () {
      final back = ShellBack();
      expect(back.onBack(onHome: false, homeAtTop: false), ShellBackAction.goHome);
      expect(back.onBack(onHome: true, homeAtTop: false), ShellBackAction.refreshHome);
      back.reset();
      expect(back.onBack(onHome: true, homeAtTop: true), ShellBackAction.refreshHome);
      expect(back.onBack(onHome: true, homeAtTop: true), ShellBackAction.exit);
    });
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('a new event ($theme): back asks before leaving, even untouched', (tester) async {
      setBoardViewport(tester, height: 960);
      await tester.pumpWidget(_over(HostEventPage(debugNow: _now), dark: dark));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Leave this event?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(HostEventPage), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.byType(HostEventPage), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  }

  testWidgets('posting a piece or Scene: back on the empty picker asks too', (tester) async {
    setBoardViewport(tester);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.fluttercandies/photo_manager'),
      (call) async => null,
    );
    await tester.pumpWidget(_over(const PostPage()));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Leave posting?'), findsOneWidget);
    await tester.tap(find.text('Keep going'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PostPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Leave posting?'), findsOneWidget);
    await tester.tap(find.text('Leave'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PostPage), findsNothing);
  });
}
