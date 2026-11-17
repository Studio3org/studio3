import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/utils/privacy_policy.dart';
import 'package:studio3/utils/require_login.dart';
import 'package:studio3/widgets/auth_ui.dart';

/// Launch checklist 1.4 (`docs/new-ui/APPLE_LAUNCH_CHECKLIST.md`, App Store guideline
/// 5.1.1(i)): every "Privacy Policy" on the sign-in screens opens the real policy at
/// studiosthree.com/privacy. It used to open the in-app Terms or do nothing.
void main() {
  final opened = <Uri>[];
  var browserOpens = true;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    opened.clear();
    browserOpens = true;
    debugPrivacyPolicyLauncher = (url) async {
      opened.add(url);
      return browserOpens;
    };
  });
  tearDown(() => debugPrivacyPolicyLauncher = null);

  Widget app(Widget child) => MaterialApp(
    theme: AppTheme.light,
    routes: {'/terms': (_) => const Scaffold(body: Text('terms page'))},
    home: Scaffold(body: Center(child: child)),
  );

  test('the link is the company site (studioSthree, not studiothree)', () {
    expect(kPrivacyPolicyUrl, 'https://studiosthree.com/privacy');
  });

  testWidgets('sign-up agreement: Privacy Policy opens the policy and leaves the box alone', (tester) async {
    final changes = <bool>[];
    await tester.pumpWidget(app(AuthTermsCheckbox(value: false, onChanged: changes.add)));
    await tester.tap(find.text('Privacy Policy'));
    await tester.pump();
    expect(opened, [Uri.parse('https://studiosthree.com/privacy')]);
    expect(changes, isEmpty, reason: 'tapping the link should not tick the box');
    expect(find.text('terms page'), findsNothing);
  });

  testWidgets('sign-up agreement: Terms of Service still opens the in-app Terms', (tester) async {
    await tester.pumpWidget(app(AuthTermsCheckbox(value: false, onChanged: (_) {})));
    await tester.tap(find.text('Terms of Service'));
    await tester.pumpAndSettle();
    expect(find.text('terms page'), findsOneWidget);
    expect(opened, isEmpty);
  });

  testWidgets('legal line: Privacy Policy is a link to the policy', (tester) async {
    await tester.pumpWidget(app(const AuthLegalLine()));
    expect(tester.getSemantics(find.text('Privacy Policy')), matchesSemantics(isLink: true, hasTapAction: true, label: 'Privacy Policy'));
    await tester.tap(find.text('Privacy Policy'));
    await tester.pump();
    expect(opened, [Uri.parse(kPrivacyPolicyUrl)]);
  });

  testWidgets('guest sign-in prompt: Privacy Policy opens the policy, the sheet stays', (tester) async {
    expect(AuthSession.instance.isLoggedIn, isFalse);
    await tester.pumpWidget(
      app(Builder(builder: (context) => TextButton(onPressed: () => requireLogin(context), child: const Text('like')))),
    );
    await tester.tap(find.text('like'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue'), findsOneWidget);
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse(kPrivacyPolicyUrl)]);
    expect(find.text('Sign in to continue'), findsOneWidget);
  });

  testWidgets('no browser: says so instead of failing silently', (tester) async {
    browserOpens = false;
    await tester.pumpWidget(app(const AuthLegalLine()));
    await tester.tap(find.text('Privacy Policy'));
    await tester.pump();
    expect(find.text('Could not open the browser.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
