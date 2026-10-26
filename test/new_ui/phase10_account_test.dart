import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/blocked_user.dart';
import 'package:studio3/screens/blocked_users_page.dart';
import 'package:studio3/screens/change_email_page.dart';
import 'package:studio3/screens/change_password_page.dart';
import 'package:studio3/screens/edit_profile_page.dart';
import 'package:studio3/screens/privacy_settings_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/labeled_dropdown.dart';
import 'package:studio3/widgets/profile_edit_header.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Phase 10 (no board): Edit profile, Privacy, Blocked accounts, Change password, Change email
/// (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 14).
Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

/// Lets the page's first requests fail for real (no server in tests).
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
  await tester.pump();
}

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

void _themed(WidgetTester tester, StudioColors c) {
  final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
  expect(scaffold.backgroundColor, c.background);
  expect(find.byType(Icon), findsNothing);
  expect(find.byType(AlertDialog), findsNothing);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    final theme = dark ? 'dark' : 'light';

    testWidgets('Edit profile: underline fields, banner picker, camera labels ($theme)', (tester) async {
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(_app(const EditProfilePage(), dark: dark));
      await _settle(tester);
      _themed(tester, c);
      expect(find.byType(ProfileEditHeader), findsOneWidget);
      expect(find.bySemanticsLabel('Change cover photo'), findsOneWidget);
      expect(find.bySemanticsLabel('Change profile photo'), findsOneWidget);
      // Name, Username, Bio, Location, Pronouns and the Banner rule picker.
      expect(find.byType(StudioUnderlineField), findsNWidgets(6));
      expect(find.text('Use my current location'), findsOneWidget);
      expect(find.text('PINNED BANNER'), findsOneWidget);
      expect(_button('Pin a piece or post'), findsOneWidget);

      await tester.tap(find.text('None (manual pin)'));
      await tester.pumpAndSettle();
      expect(find.text('Most saved'), findsOneWidget);
      await tester.tap(find.text('Most saved'));
      await tester.pumpAndSettle();
      expect(find.text('Most saved'), findsOneWidget); // now the field's value
    });

    testWidgets('Privacy: two pickers as underline fields ($theme)', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const PrivacySettingsPage(), dark: dark));
      await _settle(tester);
      _themed(tester, c);
      expect(find.byType(LabeledDropdown), findsNWidgets(2));
      await tester.tap(find.text('Everyone'));
      await tester.pumpAndSettle();
      expect(find.text('People I follow'), findsOneWidget);
      expect(find.text('No one'), findsOneWidget);
    });

    testWidgets('Blocked accounts: rows with Unblock; it asks first ($theme)', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          const BlockedUsersPage(
            debugBlocked: [BlockedUser(username: 'jo', name: 'Jo Park'), BlockedUser(username: 'max', name: 'Max')],
          ),
          dark: dark,
        ),
      );
      await tester.pump();
      _themed(tester, c);
      expect(find.text('Jo Park'), findsOneWidget);
      expect(tester.widget<Text>(find.text('@jo')).style!.color, c.textSecondary);
      expect(_button('Unblock'), findsNWidgets(2));
      await tester.tap(_button('Unblock').first);
      await tester.pumpAndSettle();
      expect(find.text('Unblock @jo?'), findsOneWidget);
      await tester.tap(_button('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Jo Park'), findsOneWidget);
    });

    testWidgets('Change password: three fields with Show, errors on empty submit ($theme)', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const ChangePasswordPage(), dark: dark));
      await tester.pump();
      _themed(tester, c);
      expect(find.byType(StudioUnderlineField), findsNWidgets(3));
      expect(find.text('Show'), findsNWidgets(3));
      await tester.tap(_button('Update password'));
      await tester.pump();
      expect(find.text('Current password is required'), findsOneWidget);
      await tester.tap(find.text('Show').first);
      await tester.pump();
      expect(find.text('Hide'), findsOneWidget);
    });

    testWidgets('Change email: field, then a bad address says so ($theme)', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const ChangeEmailPage(), dark: dark));
      await tester.pump();
      _themed(tester, c);
      expect(find.byType(StudioUnderlineField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.tap(_button('Send code'));
      await tester.pump();
      expect(find.textContaining('email', findRichText: true), findsWidgets);
      expect(find.text('New email address'), findsOneWidget);
    });
  }

  testWidgets('Blocked accounts: none is the empty state', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(const BlockedUsersPage(debugBlocked: [])));
    await tester.pump();
    expect(find.text('No blocked accounts'), findsOneWidget);
  });
}
