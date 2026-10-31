import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/screens/profile_settings_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/delete_confirmation_dialog.dart';
import 'package:studio3/widgets/feed_skeleton.dart';
import 'package:studio3/widgets/permission_denied_sheet.dart';
import 'package:studio3/widgets/seller_mode_required_dialog.dart';
import 'package:studio3/widgets/settings_tile.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Phase 10 (no board): Settings, its rows, and the confirm sheets that replace the old
/// dialogs (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 14).
Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

/// Lets Settings' first requests fail for real (no server in tests), then draws the rows.
Future<void> _loaded(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
  await tester.pump();
}

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

/// A page with one button that runs [action] and shows what it returned.
class _Runner extends StatefulWidget {
  const _Runner(this.action);

  final Future<Object?> Function(BuildContext context) action;

  @override
  State<_Runner> createState() => _RunnerState();
}

class _RunnerState extends State<_Runner> {
  Object? result = 'none';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async {
          final r = await widget.action(context);
          setState(() => result = r);
        },
        child: Text('run: $result'),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    testWidgets('Settings: Mono labels, plain rows, no icons (${dark ? 'dark' : 'light'})', (tester) async {
      setBoardViewport(tester, height: 2400);
      await tester.pumpWidget(_app(const ProfileSettingsPage(), dark: dark));
      expect(find.byType(SettingsListSkeleton), findsOneWidget);
      // The seller status request fails in tests; the page falls back to the session.
      await _loaded(tester);

      expect(find.text('Settings'), findsOneWidget);
      final label = tester.widget<Text>(find.text('ACCOUNT'));
      expect(label.style!.fontFamily, contains('Mono'));
      expect(label.style!.color, c.textTertiary);
      final row = tester.widget<Text>(find.text('Edit profile'));
      expect((row.style!.fontSize, row.style!.color), (15, c.textPrimary));
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(SettingsToggleTile), findsOneWidget);
      expect(find.byType(StudioSwitch), findsOneWidget);
      // Log out and Delete account in Ink like every other action.
      expect(tester.widget<Text>(find.text('Delete account')).style!.color, c.textPrimary);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, c.background);
    });
  }

  testWidgets('Log out asks in a sheet', (tester) async {
    setBoardViewport(tester, height: 2400);
    await tester.pumpWidget(_app(const ProfileSettingsPage()));
    await _loaded(tester);
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    expect(_button('Log out'), findsOneWidget);
    await tester.tap(_button('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsNothing);
  });

  testWidgets('Delete account: the password turns the button on', (tester) async {
    setBoardViewport(tester, height: 2400);
    await tester.pumpWidget(_app(const ProfileSettingsPage()));
    await _loaded(tester);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(tester.widget<StudioButton>(_button('Delete account')).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.pump();
    expect(tester.widget<StudioButton>(_button('Delete account')).onPressed, isNotNull);
  });

  group('confirm sheets', () {
    testWidgets('delete: true on Delete, false on Cancel', (tester) async {
      await tester.pumpWidget(_app(_Runner((context) => showDeleteConfirmationDialog(context, itemLabel: 'event'))));
      await tester.tap(find.text('run: none'));
      await tester.pumpAndSettle();
      expect(find.text('Delete event?'), findsOneWidget);
      expect(find.text("This can't be undone. Your event will be permanently removed."), findsOneWidget);
      await tester.tap(_button('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('run: true'), findsOneWidget);

      await tester.tap(find.text('run: true'));
      await tester.pumpAndSettle();
      await tester.tap(_button('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('run: false'), findsOneWidget);
    });

    testWidgets('seller required and permission denied read as sheets', (tester) async {
      await tester.pumpWidget(_app(_Runner(showSellerModeRequiredDialog)));
      await tester.tap(find.text('run: none'));
      await tester.pumpAndSettle();
      expect(find.text('Seller profile required'), findsOneWidget);
      expect(_button('Switch to Seller'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(_button('Cancel'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _app(
          _Runner((context) async {
            await showPermissionDeniedSheet(context, title: 'Camera is off', message: 'Turn it on in Settings.');
            return 'done';
          }),
        ),
      );
      await tester.tap(find.text('run: none'));
      await tester.pumpAndSettle();
      expect(find.text('Camera is off'), findsOneWidget);
      expect(_button('Open Settings'), findsOneWidget);
      await tester.tap(_button('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('run: done'), findsOneWidget);
    });
  });
}
