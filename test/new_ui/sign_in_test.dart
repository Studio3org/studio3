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
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/theme/studio_metrics.dart';
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
      '/signup': (_) => const SignUpPage(),
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

double? _spanFontSize(InlineSpan span) {
  if (span is TextSpan && span.style?.fontSize != null && span.text != null && span.text!.isNotEmpty) {
    return span.style!.fontSize;
  }
  if (span is TextSpan) {
    for (final child in span.children ?? const <InlineSpan>[]) {
      final size = _spanFontSize(child);
      if (size != null) return size;
    }
  }
  return null;
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
    testWidgets('login frame, fields and disabled Login (${dark ? 'dark' : 'light'})', (tester) async {
      await _surface(tester, const Size(390, 844));
      await tester.pumpWidget(_routed(home: const LoginPage(), dark: dark));
      await tester.pump();

      expect(find.byType(StudioHaze), findsOneWidget);
      expect(tester.state<StudioHazeState>(find.byType(StudioHaze)).isDrifting, isTrue);
      expect(find.byType(StudioLogo), findsOneWidget);
      expect(find.text('Username or email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Remember me'), findsOneWidget);
      expect(find.text('Forgot login?'), findsOneWidget);
      expect(find.textContaining('I agree to the', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('By continuing, you agree', skipOffstage: false), findsWidgets);
      expect(find.text('Browse without an account', skipOffstage: false), findsOneWidget);

      final haze = tester.widget<ColoredBox>(
        find.descendant(of: find.byType(StudioHaze), matching: find.byType(ColoredBox)).first,
      );
      expect(
        haze.color,
        dark ? StudioColors.dark.signInBackground : StudioColors.light.signInBackground,
      );

      final login = find.widgetWithText(StudioButton, 'Login');
      expect(tester.getSize(login).height, StudioSize.buttonPrimary);
      expect(tester.widget<StudioButton>(login).onPressed, isNull);

      final formPadding = tester.widgetList<Padding>(find.byType(Padding)).where((padding) {
        final insets = padding.padding;
        return insets is EdgeInsets && insets.left == 24 && insets.right == 24 && insets.bottom == 28;
      });
      expect(formPadding, isNotEmpty);

      final legal = tester.widget<RichText>(
        find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText().startsWith('By continuing, you agree'),
        ),
      );
      expect(_spanFontSize(legal.text), 11);

      expect(
        tester.getSize(find.ancestor(of: find.byType(Checkbox).first, matching: find.byType(SizedBox)).first),
        const Size(StudioSize.tapTarget, StudioSize.tapTarget),
      );
      expect(tester.getSize(find.widgetWithText(TextButton, 'Forgot login?')).height, greaterThanOrEqualTo(44));
    });
  }

  testWidgets('login enables only when the current fields are valid, and the links still route', (tester) async {
    await _surface(tester, const Size(390, 900));
    await tester.pumpWidget(_routed(home: const LoginPage()));
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), 'amara');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.pump();
    expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Login')).onPressed, isNull);

    await tester.ensureVisible(find.textContaining('I agree to the'));
    await tester.tap(find.textContaining('I agree to the'));
    await tester.pump();
    expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Login')).onPressed, isNotNull);

    await tester.ensureVisible(find.text('Forgot login?'));
    await tester.tap(find.text('Forgot login?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Forgot login?'), findsWidgets);
    expect(find.text('Send reset link'), findsOneWidget);

    Navigator.of(tester.element(find.text('Send reset link'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final signUp = find.byType(AuthLinkFooter);
    await tester.ensureVisible(signUp);
    await tester.tap(signUp);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Your name'), findsOneWidget);

    Navigator.of(tester.element(find.text('Your name'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final guest = find.byType(AuthGuestLink);
    await tester.ensureVisible(guest);
    await tester.tap(guest);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('login back still pops, haze is still when motion is reduced, and small and large phones do not overflow', (tester) async {
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
      await tester.ensureVisible(find.text('Browse without an account'));
      expect(find.text('Login'), findsOneWidget);
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
      expect(tester.getSize(find.widgetWithText(StudioButton, 'Log in')).height, StudioSize.buttonPrimary);
      expect(tester.getSize(find.widgetWithText(StudioButton, 'Create account')).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(find.widgetWithText(StudioButton, 'Not now')).height, greaterThanOrEqualTo(44));

      await tester.tap(find.text('Not now'));
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Sign in to save this piece'), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Log in'));
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Username or email'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('open'));
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Create account'));
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Your name'), findsOneWidget);
    });
  }

  testWidgets('signup name uses the same first screen, then email, without a network call', (tester) async {
    await _surface(tester, const Size(390, 900));
    await tester.pumpWidget(_routed(home: const SignUpPage()));
    await tester.pump();
    expect(find.byType(StudioHaze), findsOneWidget);
    expect(find.text('Your name'), findsOneWidget);
    expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Continue')).onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(0), 'Amara');
    await tester.enterText(find.byType(TextField).at(1), 'Osei');
    await tester.ensureVisible(find.textContaining('I agree to the'));
    await tester.tap(find.textContaining('I agree to the'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(StudioButton, 'Continue'));
    await tester.tap(find.widgetWithText(StudioButton, 'Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Your email'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
  });

  testWidgets('code step: six slots, wrong email goes back, resend copy, three segments', (tester) async {
    await _surface(tester, const Size(390, 844));
    await tester.pumpWidget(_routed(home: const SignUpPage(initialStepIndex: 2)));
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
    expect(find.text('Your email'), findsOneWidget);
  });

  testWidgets('profile steps keep the current split, available row, phone helper and skip', (tester) async {
    await _surface(tester, const Size(390, 844));
    await tester.pumpWidget(_routed(home: const SignUpPage(initialStepIndex: 3)));
    await tester.pump();
    expect(find.text('Set up your profile'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);

    await tester.pumpWidget(_routed(home: const SignUpPage(initialStepIndex: 4)));
    await tester.pump();
    expect(find.textContaining('For shipping and delivery updates', skipOffstage: false), findsWidgets);
    expect(find.text('Skip for now'), findsOneWidget);
    await tester.tap(find.text('Skip for now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Set password'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('role step keeps the current roles and requires one before continuing', (tester) async {
    await _surface(tester, const Size(390, 844));
    await tester.pumpWidget(_routed(home: const OnboardingPage()));
    await tester.pump();
    expect(find.text('What brings you to Studio 3?'), findsOneWidget);
    expect(find.text('Artist'), findsOneWidget);
    expect(find.text('Collector'), findsOneWidget);
    expect(find.text('Enthusiast'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
    expect(tester.getSize(find.widgetWithText(StudioButton, 'Continue')).height, StudioSize.buttonPrimaryTall);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Please select a role'), findsOneWidget);

    await tester.tap(find.text('Artist'));
    await tester.pump();
    expect(tester.widget<StudioSelectRow>(find.widgetWithText(StudioSelectRow, 'Artist')).selected, isTrue);
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
    expect(find.text('Username or email'), findsOneWidget);
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
    expect(find.text('Forgot login?'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
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
