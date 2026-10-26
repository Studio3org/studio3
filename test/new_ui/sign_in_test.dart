import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/screens/forgot_password_page.dart';
import 'package:studio3/screens/login_page.dart';
import 'package:studio3/screens/onboarding/onboarding_page.dart';
import 'package:studio3/screens/signup_page.dart';
import 'package:studio3/screens/terms_page.dart';
import 'package:studio3/screens/welcome_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/utils/require_login.dart';
import 'package:studio3/widgets/auth_ui.dart';
import 'package:studio3/widgets/studio/studio.dart';
import 'package:studio3/widgets/terms_acceptance_dialog.dart';

Widget _routed({
  required Widget home,
  bool dark = false,
  bool reduceMotion = false,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: _instant(AppTheme.light),
    darkTheme: _instant(AppTheme.dark),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(disableAnimations: reduceMotion, textScaler: textScaler),
        child: child!,
      );
    },
    key: UniqueKey(),
    initialRoute: '/under-test',
    routes: {
      '/under-test': (_) => home,
      '/': (_) => const Scaffold(body: Text('home')),
      '/login': (_) => const LoginPage(),
      '/signup': (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        return SignUpPage(initialEmail: args is String ? args : null);
      },
      '/forgot-password': (_) => const ForgotPasswordPage(),
      '/terms': (_) => const TermsPage(),
    },
  );
}

ThemeData _instant(ThemeData theme) {
  return theme.copyWith(
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {for (final platform in TargetPlatform.values) platform: const _InstantPageTransitionsBuilder()},
    ),
  );
}

class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return child;
  }
}

Future<void> _surface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

double _contrast(Color a, Color b) {
  double lin(double channel) {
    final v = channel > 1 ? channel / 255 : channel;
    return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  double lum(Color c) => 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
  final hi = math.max(lum(a), lum(b));
  final lo = math.min(lum(a), lum(b));
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('sign-in text meets 4.5:1 on the page background', () {
    for (final colors in [StudioColors.light, StudioColors.dark]) {
      expect(_contrast(colors.textPrimary, colors.background), greaterThanOrEqualTo(4.5));
      expect(_contrast(colors.textSecondary, colors.background), greaterThanOrEqualTo(4.5));
      expect(_contrast(colors.buttonText, colors.buttonFill), greaterThanOrEqualTo(4.5));
    }
    // Dark tertiary sits on near-black and clears 4.5. Light tertiary is the board's
    // own #8E8E8E label, which is under 4.5 on Gallery White; the board wins.
    expect(_contrast(StudioColors.dark.textTertiary, StudioColors.dark.background), greaterThanOrEqualTo(4.5));
  });

  for (final dark in [false, true]) {
    testWidgets('first screen: haze, logo, Email and a grey Continue; no browsing, no legal line (${dark ? 'dark' : 'light'})', (tester) async {
      await _surface(tester, const Size(390, 844));
      await tester.pumpWidget(_routed(home: const LoginPage(), dark: dark));
      await tester.pump();

      expect(find.byType(StudioHaze), findsOneWidget);
      expect(tester.state<StudioHazeState>(find.byType(StudioHaze)).isDrifting, isTrue);
      expect(find.byType(StudioLogo), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('you@email.com'), findsOneWidget);
      // An account is required (`HandoffAccount`): no guest link, no password here, no legal line.
      expect(find.text('Look around first', skipOffstage: false), findsNothing);
      expect(find.byType(AuthGuestLink), findsNothing);
      expect(find.text('Password'), findsNothing);
      expect(find.textContaining('By continuing, you agree', skipOffstage: false), findsNothing);

      final haze = tester.widget<ColoredBox>(
        find.descendant(of: find.byType(StudioHaze), matching: find.byType(ColoredBox)).first,
      );
      expect(haze.color, dark ? StudioColors.dark.signInBackground : StudioColors.light.signInBackground);

      final cont = find.widgetWithText(StudioButton, 'Continue');
      expect(tester.getSize(cont).height, StudioSize.buttonPrimary);
      expect(tester.widget<StudioButton>(cont).onPressed, isNull);
      final formPadding = tester.widgetList<Padding>(find.byType(Padding)).where((padding) {
        final insets = padding.padding;
        return insets is EdgeInsets && insets.left == 24 && insets.right == 24 && insets.bottom == 28;
      });
      expect(formPadding, isNotEmpty);
    });
  }

  testWidgets('Continue with an email opens Welcome back: the email, Password with the eye, Forgot password?, Log in', (tester) async {
    await _surface(tester, const Size(390, 844));
    await tester.pumpWidget(_routed(home: const LoginPage()));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'jordan@email.com');
    await tester.pump();
    expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Continue')).onPressed, isNotNull);
    await tester.tap(find.widgetWithText(StudioButton, 'Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // `LoginPassword`: 28/500 title, the email 15 Graphite, Password 13 Tertiary over 18.
    final title = tester.widget<Text>(find.text('Welcome back'));
    expect((title.style!.fontSize, title.style!.fontWeight), (28, StudioType.medium));
    final email = tester.widget<Text>(find.text('jordan@email.com'));
    expect((email.style!.fontSize, email.style!.color), (15, StudioColors.light.textSecondary));
    expect(find.text('Password'), findsOneWidget);
    expect(find.byTooltip('Show password'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isFalse);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Log in')).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'secret-pass');
    await tester.pump();
    expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Log in')).onPressed, isNotNull);
    // Until the server can tell a new email from a known one (B30), new people start here.
    expect(find.textContaining('Create an account', findRichText: true), findsOneWidget);

    // Back returns to the first screen.
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Welcome back'), findsNothing);
    expect(find.widgetWithText(StudioButton, 'Continue'), findsOneWidget);
  });

  testWidgets('first screen: back pops, the haze is still with reduced motion, small and large phones fit', (tester) async {
    await _surface(tester, const Size(390, 844));
    await tester.pumpWidget(
      _routed(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LoginPage())),
              child: const Text('open'),
            ),
          ),
        ),
        reduceMotion: true,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.state<StudioHazeState>(find.byType(StudioHaze)).isDrifting, isFalse);
    expect(tester.getSize(find.byTooltip('Back')), const Size(44, 44));
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('open'), findsOneWidget);

    for (final size in [const Size(375, 667), const Size(440, 956)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_routed(home: const LoginPage(), textScaler: const TextScaler.linear(1.4)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Continue'), findsOneWidget);
    }
  });

  for (final dark in [false, true]) {
    testWidgets('sign-in sheet actions (${dark ? 'dark' : 'light'})', (tester) async {
      await _surface(tester, const Size(390, 844));
      await tester.pumpWidget(
        _routed(
          dark: dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => requireLogin(context, title: 'Sign in to save this piece'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Sign in to save this piece'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Continue')).onPressed, isNull);
      expect(find.text('Create account'), findsNothing);
      expect(tester.getSize(find.widgetWithText(StudioButton, 'Log in')).height, StudioSize.buttonPrimary);

      Navigator.of(tester.element(find.text('Sign in to save this piece'))).pop();
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Sign in to save this piece'), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Log in'));
      await tester.tap(find.text('Log in'));
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('you@email.com'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('open'));
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'amara@studio.test');
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(StudioButton, 'Continue'));
      await tester.tap(find.widgetWithText(StudioButton, 'Continue'));
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widgetList<TextField>(find.byType(TextField)).any((field) => field.controller?.text == 'amara@studio.test'),
        isTrue,
      );
      // The Terms agreement moved to profile setup (`SignIn3Profile`).
      expect(find.textContaining('I agree to the'), findsNothing);
    });
  }

  testWidgets('a direct sign-up starts on email (no terms there, no browsing), Continue once valid', (tester) async {
    await _surface(tester, const Size(390, 900));
    await tester.pumpWidget(_routed(home: const SignUpPage()));
    await tester.pump();
    expect(find.byType(StudioHaze), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('you@email.com'), findsOneWidget);
    expect(find.textContaining('I agree to the'), findsNothing);
    expect(find.text('Look around first'), findsNothing);
    expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Continue')).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'amara@studio.test');
    await tester.pump();
    expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Continue')).onPressed, isNotNull);
  });

  testWidgets('code step: six slots, wrong email goes back, resend copy, three segments', (tester) async {
    await _surface(tester, const Size(390, 844));
    await tester.pumpWidget(_routed(home: const SignUpPage(initialStepIndex: 1)));
    await tester.pump();

    expect(find.text('Enter your code'), findsOneWidget);
    expect(find.textContaining('Wrong email?'), findsOneWidget);
    expect(find.text('Resend code'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
    expect(tester.getSize(find.byTooltip('Back')), const Size(44, 44));

    final slots = find.descendant(of: find.byType(StudioOtpSlots), matching: find.byType(SizedBox));
    final heights = tester.widgetList<SizedBox>(slots).where((box) => box.height == 56).length;
    expect(heights, 6);

    await tester.enterText(find.byType(TextField), '4');
    await tester.pump();
    final digits = tester.widgetList<Text>(find.text('4')).where((text) => text.style?.fontSize == 32);
    expect(digits, isNotEmpty);
    expect(digits.first.style!.fontFamily, 'GeistMono');

    final active = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).where((box) {
      final decoration = box.decoration;
      return decoration is BoxDecoration && decoration.border?.bottom.width == 2;
    });
    expect(active.length, 1);

    await tester.tap(find.textContaining('Wrong email?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('profile step (`SignIn3Profile`): Name, Username, Password, Phone, then the unticked Terms box; Continue waits for both', (tester) async {
    await _surface(tester, const Size(390, 960));
    await tester.pumpWidget(_routed(home: const SignUpPage(initialStepIndex: 2)));
    await tester.pump();
    expect(find.text('Set up your profile'), findsOneWidget);
    expect(find.text('Add a photo'), findsOneWidget);
    expect(find.text('Optional'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
    // No marketing texts here (they live in notification settings), and no password step after.
    expect(find.text('Text me about events and new work'), findsNothing);
    expect(find.text('Set password'), findsNothing);
    expect(find.text('Confirm password'), findsNothing);

    final y = [for (final label in ['Name', 'Username', 'Password', 'Phone']) tester.getTopLeft(find.text(label)).dy];
    expect(y, [...y]..sort());
    expect(find.textContaining('For shipping and delivery updates', skipOffstage: false), findsWidgets);

    final terms = find.byType(AuthTermsCheckbox);
    expect(tester.widget<AuthTermsCheckbox>(terms).value, isFalse);
    expect(find.textContaining('Terms of Service', findRichText: true), findsWidgets);
    expect(find.textContaining('Privacy Policy', findRichText: true), findsWidgets);
    expect(tester.getTopLeft(terms).dy, greaterThan(tester.getTopLeft(find.text('Phone')).dy));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Jordan Lee');
    await tester.enterText(fields.at(1), 'jordanlee');
    await tester.enterText(fields.at(2), 'longenough');
    await tester.pump();
    expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Continue')).onPressed, isNull);
    await tester.tap(find.byType(AuthTermsCheckbox));
    await tester.pump();
    expect(tester.widget<AuthTermsCheckbox>(terms).value, isTrue);
    expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Continue')).onPressed, isNotNull);
    // A short password keeps it grey.
    await tester.enterText(fields.at(2), 'short');
    await tester.pump();
    expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Continue')).onPressed, isNull);
  });

  testWidgets('role step keeps the current roles and requires one before continuing', (tester) async {
    await _surface(tester, const Size(390, 844));
    await tester.pumpWidget(_routed(home: const OnboardingPage()));
    await tester.pump();
    expect(find.text('What brings you to Studio 3?'), findsOneWidget);
    expect(find.text('Collecting art'), findsOneWidget);
    expect(find.text('Sharing my work'), findsOneWidget);
    expect(find.text('Exploring and events'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 3 of 3'), findsOneWidget);
    expect(tester.getSize(find.widgetWithText(StudioButton, 'Continue')).height, StudioSize.buttonPrimaryTall);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Please select a role'), findsOneWidget);

    await tester.tap(find.text('Sharing my work'));
    await tester.pump();
    expect(tester.widget<StudioSelectRow>(find.widgetWithText(StudioSelectRow, 'Sharing my work')).selected, isTrue);
  });

  testWidgets('preferences step still requires three in each group', (tester) async {
    await _surface(tester, const Size(390, 844));
    await tester.pumpWidget(_routed(home: const OnboardingPage(initialStep: 1), textScaler: const TextScaler.linear(1.3)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Your taste'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Select at least 3 in each category'), findsOneWidget);
  });

  testWidgets('photo step is a 72 circle and stays optional', (tester) async {
    await _surface(tester, const Size(390, 844));
    await tester.pumpWidget(_routed(home: const OnboardingPage(initialStep: 2)));
    await tester.pump();
    expect(find.text('Add a photo'), findsWidgets);
    expect(find.text('Optional'), findsOneWidget);
    final circle = tester.widgetList<Container>(find.byType(Container)).where((box) {
      return box.constraints?.maxWidth == 72 && box.constraints?.maxHeight == 72;
    });
    expect(circle.length, 1);
    expect(find.text('Finish'), findsOneWidget);
  });

  testWidgets('signed-out saved hero opens the existing login and has no recently viewed', (tester) async {
    await _surface(tester, const Size(390, 844));
    await tester.pumpWidget(
      _routed(
        home: const GuestAccountPlaceholder(
          icon: Icons.bookmark_border_rounded,
          title: 'Keep track of the art you love',
          message: 'Save pieces, follow artists, share your own work, and keep your event tickets in one place.',
        ),
      ),
    );
    expect(find.text('Keep track of the art you love'), findsOneWidget);
    expect(find.text('Recently viewed'), findsNothing);
    expect(tester.getSize(find.widgetWithText(StudioButton, 'Log in')).height, 50);
    await tester.tap(find.text('Log in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('you@email.com'), findsOneWidget);
  });

  testWidgets('terms page and the required pop-up restyle and still open the terms', (tester) async {
    await _surface(tester, const Size(390, 844));
    await tester.pumpWidget(
      _routed(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showTermsAcceptanceDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('I agree'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('I agree'), findsOneWidget);

    await tester.tap(find.text('Read terms'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Terms of Use (EULA)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Your account'), 400);
    expect(find.text('Your account'), findsOneWidget);
  });

  testWidgets('forgot password and welcome use the shared type and still offer their actions', (tester) async {
    await _surface(tester, const Size(375, 667));
    await tester.pumpWidget(_routed(home: const ForgotPasswordPage(), textScaler: const TextScaler.linear(1.3)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Forgot your password?'), findsOneWidget);
    expect(find.text('Send the email'), findsOneWidget);
    expect(tester.getSize(find.byTooltip('Back')), const Size(44, 44));

    await tester.pumpWidget(
      _routed(
        home: const WelcomePage(
          user: AuthUser(username: 'amara', name: 'Amara Osei', email: 'amara@studio.test'),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Welcome, Amara'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
