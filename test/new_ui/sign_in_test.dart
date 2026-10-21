import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/screens/login_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/utils/require_login.dart';
import 'package:studio3/widgets/studio/studio.dart';

Widget _app(Widget home, {bool dark = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: home,
  );
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('login uses the first sign-in screen with its own fields (${dark ? 'dark' : 'light'})', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(const LoginPage(), dark: dark));
      await tester.pump();

      expect(find.byType(StudioHaze), findsOneWidget);
      expect(find.byType(StudioLogo), findsOneWidget);
      expect(find.text('Username or email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Remember me'), findsOneWidget);
      expect(find.text('Forgot login?'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.textContaining('Sign Up', skipOffstage: false), findsOneWidget);
      expect(find.text('Browse without an account'), findsOneWidget);
      expect(find.textContaining('By continuing, you agree'), findsOneWidget);

      final button = tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Login'));
      expect(button.onPressed, isNull);

      final haze = tester.widget<ColoredBox>(
        find.descendant(of: find.byType(StudioHaze), matching: find.byType(ColoredBox)).first,
      );
      final expected = dark ? StudioColors.dark.signInBackground : StudioColors.light.signInBackground;
      expect(haze.color, expected);
    });
  }

  testWidgets('sign-in sheet keeps Log in, Create account and Not now', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => requireLogin(context, title: 'Sign in to save this piece'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to save this piece'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.textContaining('By continuing, you agree'), findsOneWidget);
  });
}
