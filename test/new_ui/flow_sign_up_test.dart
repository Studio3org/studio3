import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/data/post_picker_options.dart';
import 'package:studio3/main.dart' show AuthGate;
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/screens/home_feed_page.dart';
import 'package:studio3/screens/login_page.dart';
import 'package:studio3/screens/login_password_page.dart';
import 'package:studio3/screens/onboarding/onboarding_page.dart';
import 'package:studio3/screens/reels_page.dart' show routeObserver;
import 'package:studio3/screens/signup_page.dart';
import 'package:studio3/screens/terms_page.dart';
import 'package:studio3/screens/welcome_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/chat_socket_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/auth_ui.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Flow regression 19.2, second point (docs/new-ui/NEW_UI_EXECUTION_PLAN.md): sign up, all
/// steps and the Terms, then onboarding, in light and dark, through the real screens and services
/// against a fake server: sign-in → Welcome back → Create an account → the code → profile setup
/// with the Terms → Welcome → role, taste, photo → the feed.

const _code = '482913';

Map<String, dynamic> _account({required bool onboarded}) => {
  'id': 'u2',
  'username': 'amara.osei',
  'name': 'Amara Osei',
  'email': 'amara@studio.test',
  'onboardingComplete': onboarded,
  'termsVersion': kTermsVersion,
  'currentTermsVersion': kTermsVersion,
};

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, String? auth, Object? body})>[];

  Iterable<Object?> bodies(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).map((r) => r.body);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : options.data;
    final path = options.uri.path;
    requests.add((method: options.method, path: path, auth: options.headers['Authorization'] as String?, body: body));
    Object json = {'success': true, 'data': {}};
    var status = 200;
    switch ('${options.method} $path') {
      case 'POST /api/auth/otp/generate' || 'POST /api/auth/otp/resend':
        json = {'success': true, 'data': {'message': 'OTP sent successfully.'}};
      case 'POST /api/auth/otp/verify':
        if ((body as Map)['otp'] != _code) {
          status = 400;
          json = {'success': false, 'message': 'Invalid or expired code'};
        }
      case 'GET /api/auth/username/check':
        final taken = options.uri.queryParameters['username'] == 'amara';
        json = {
          'success': true,
          'data': {
            'available': !taken,
            if (taken) 'message': 'That username is taken',
            if (taken) 'suggestions': ['amara.osei', 'amara_art'],
          },
        };
      case 'POST /api/auth/register':
        json = {
          'success': true,
          'data': {'accessToken': 'token', 'user': _account(onboarded: false)},
        };
      case 'PATCH /api/user/me/role' ||
          'POST /api/user/me/onboarding/preferences' ||
          'POST /api/user/me/onboarding/photos' ||
          'POST /api/user/me/onboarding/complete':
        break;
      case 'GET /api/user/me':
        json = {'success': true, 'data': _account(onboarded: true)};
      case 'GET /api/feed/for-you':
        json = {
          'success': true,
          'data': {
            'items': [
              for (var i = 1; i <= 3; i++)
                {
                  'type': 'piece',
                  'id': 'a$i',
                  'title': 'Piece a$i',
                  'mediaUrl': '',
                  'isForSale': true,
                  'status': 'live',
                  'listingState': 'available',
                  'author': {'username': 'kofi', 'name': 'Kofi Mensah'},
                },
            ],
            'nextCursor': null,
          },
        };
      default:
        status = 404;
        json = {'success': false, 'message': 'no route'};
    }
    return ResponseBody.fromString(
      jsonEncode(json),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

late _Fake _server;

Finder _primary(String label) => find.byWidgetPredicate((w) => w is AuthPrimaryButton && w.label == label);
Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);
bool _enabled(WidgetTester tester, String label) => tester.widget<AuthPrimaryButton>(_primary(label)).enabled;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 350));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

/// The app's routes for this flow (as in `main.dart`).
Widget _app({required bool dark, required String initialRoute}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  navigatorObservers: [routeObserver],
  initialRoute: initialRoute,
  routes: {
    '/': (_) => AuthGate(child: HomePage(store: HomeFeedStore())),
    '/login': (_) => const LoginPage(),
    '/signup': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      return SignUpPage(initialEmail: args is String ? args : null);
    },
    '/welcome': (context) => WelcomePage(user: ModalRoute.of(context)!.settings.arguments! as AuthUser),
    '/onboarding': (_) => const OnboardingPage(),
    '/terms': (_) => const TermsPage(),
  },
);

TextField _field(WidgetTester tester, int i) => tester.widget<TextField>(find.byType(TextField).at(i));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthSession.instance.initialize(); // as at launch: the session's device storage
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => '.');
    // Signed in, AuthGate asks for notifications (denied here) and starts the deep-link listener.
    messenger.setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/permissions/methods'), (call) async {
      return switch (call.method) {
        'checkPermissionStatus' => 0,
        'requestPermissions' => {for (final p in call.arguments as List) p: 0},
        _ => false,
      };
    });
    for (final name in ['com.llfbandit.app_links/messages', 'com.llfbandit.app_links/events']) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async => null);
    }
  });

  setUp(() {
    _server = _Fake();
    ApiClient.instance.debugUseAdapter(_server);
    AuthSession.instance.user = null;
    AuthSession.instance.accessToken = null;
  });
  tearDown(() {
    AuthSession.instance.user = null;
    AuthSession.instance.accessToken = null;
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('sign up ($theme): code, profile and Terms, Welcome, role, taste, photo, the feed', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(dark: dark, initialRoute: '/login'));
      await _settle(tester);

      // Sign-in → Welcome back → Create an account.
      await tester.enterText(find.byType(TextField), 'amara@studio.test');
      await tester.pump();
      await _tap(tester, _primary('Continue'));
      expect(find.byType(LoginPasswordPage), findsOneWidget);
      await _tap(tester, find.textContaining('Create an account', findRichText: true));

      // The code: sent to that email on arrival; a wrong code stays and says why.
      expect(find.byType(SignUpPage), findsOneWidget);
      expect(find.text('Enter your code'), findsOneWidget);
      expect(find.textContaining('We sent it to amara@studio.test.', findRichText: true), findsOneWidget);
      expect(_server.bodies('POST', '/api/auth/otp/generate').single, {'email': 'amara@studio.test'});
      expect(find.textContaining('You can resend in', findRichText: true), findsOneWidget);
      await tester.enterText(find.byType(TextField), '000000');
      await _settle(tester);
      expect(find.text('Invalid or expired code'), findsOneWidget);
      expect(find.text('Enter your code'), findsOneWidget);
      await tester.enterText(find.byType(TextField), _code);
      await _settle(tester);
      expect(_server.bodies('POST', '/api/auth/otp/verify').last, {'email': 'amara@studio.test', 'otp': _code});

      // Profile setup.
      expect(find.text('Set up your profile'), findsOneWidget);
      expect(_enabled(tester, 'Continue'), isFalse);
      await tester.enterText(find.byType(TextField).at(0), 'Amara Osei');
      await tester.enterText(find.byType(TextField).at(1), 'amara');
      await tester.pump(const Duration(milliseconds: 500));
      await _settle(tester);
      expect(find.text('That username is taken'), findsOneWidget);
      await _tap(tester, find.widgetWithText(StudioChip, 'amara.osei'));
      await tester.pump(const Duration(milliseconds: 500));
      await _settle(tester);
      expect(find.text('available'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(2), 'Painting-2026');
      await tester.pump();
      // Everything filled in, but Continue waits for the Terms box.
      expect(_enabled(tester, 'Continue'), isFalse);

      // The Terms link opens the Terms; back keeps what was typed.
      await _tap(tester, find.text('Terms of Service'));
      expect(find.byType(TermsPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(TermsPage))).pop();
      await _settle(tester);
      expect(find.text('Set up your profile'), findsOneWidget);
      expect(_field(tester, 0).controller!.text, 'Amara Osei');
      expect(_field(tester, 1).controller!.text, 'amara.osei');

      await _tap(tester, find.textContaining('I agree to the', findRichText: true));
      expect(_enabled(tester, 'Continue'), isTrue);
      await _tap(tester, _primary('Continue'));
      expect(_server.bodies('POST', '/api/auth/register').single, {
        'username': 'amara.osei',
        'name': 'Amara Osei',
        'email': 'amara@studio.test',
        'password': 'Painting-2026',
        'otp': _code,
        'acceptedTerms': true,
      });
      expect(AuthSession.instance.isLoggedIn, isTrue);
      expect(AuthSession.instance.termsAgreedOnDevice, kTermsVersion);

      // Welcome → onboarding.
      expect(find.text('Welcome, Amara!'), findsOneWidget);
      expect(find.text('Your Studio 3 account @amara.osei is ready.'), findsOneWidget);
      expect(Navigator.of(tester.element(find.byType(WelcomePage))).canPop(), isFalse);
      await _tap(tester, _primary('Get Started'));

      // Role: needs one, then saves it.
      expect(find.text('What brings you to Studio 3?'), findsOneWidget);
      await _tap(tester, _button('Continue'));
      expect(find.text('Please select a role'), findsOneWidget);
      expect(_server.bodies('PATCH', '/api/user/me/role'), isEmpty);
      await _tap(tester, find.text('Collecting art'));
      await _tap(tester, _button('Continue'));
      expect(_server.bodies('PATCH', '/api/user/me/role').single, {'role': 'collector'});

      // Taste: three in each group.
      expect(find.text('Your taste'), findsOneWidget);
      await _tap(tester, _button('Continue'));
      expect(find.text('Select at least 3 in each category'), findsOneWidget);
      final mediums = PostMediumOptions.all.take(3).toList();
      final styles = PostStyleOptions.all.take(3).toList();
      for (final name in [...mediums.map((o) => o.name), ...styles.map((o) => o.name), 'Nature', 'Urban', 'Memory']) {
        await _tap(tester, find.widgetWithText(StudioChip, name).first);
      }
      await _tap(tester, _button('Continue'));
      expect(_server.bodies('POST', '/api/user/me/onboarding/preferences').single, {
        'mediums': mediums.map((o) => o.id).toList(),
        'styles': styles.map((o) => o.id).toList(),
        'themes': ['Nature', 'Urban', 'Memory'],
      });

      // Photo: optional; Finish skips it and completes onboarding.
      expect(find.text('Add a photo'), findsWidgets);
      expect(find.text('Add a profile photo and cover image, or tap Finish to skip for now.'), findsOneWidget);
      await tester.tap(_button('Finish'));
      // The welcome toast shows for 2.5 s once the feed opens: look for it as it arrives.
      final toast = find.text('Welcome to Studio 3, Amara');
      for (var i = 0; i < 40 && toast.evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(toast, findsOneWidget);
      await _settle(tester);
      expect(_server.bodies('POST', '/api/user/me/onboarding/photos').single, {'skip': true});
      expect(_server.bodies('POST', '/api/user/me/onboarding/complete'), hasLength(1));
      expect(AuthSession.instance.isOnboarded, isTrue);

      // The feed, as the new account, with nothing to go back to and no Terms pop-up (agreed at sign-up).
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Terms of Use'), findsNothing);
      expect(Navigator.of(tester.element(find.byType(HomePage))).canPop(), isFalse);
      expect(
        _server.requests.where((r) => r.path == '/api/feed/for-you').last.auth,
        'Bearer token',
      );
      for (final path in [
        '/api/user/me/role',
        '/api/user/me/onboarding/preferences',
        '/api/user/me/onboarding/photos',
        '/api/user/me/onboarding/complete',
      ]) {
        expect(_server.requests.lastWhere((r) => r.path == path).auth, 'Bearer token', reason: path);
      }
      expect(tester.takeException(), isNull);

      // Signed in, AuthGate opened the chat socket; close it so its timer ends with the test.
      ChatSocketService.instance.disconnect();
      await tester.pump(const Duration(seconds: 21));
    });
  }

  testWidgets('a direct sign-up: email, Continue sends the code, Wrong email? goes back, Log in opens sign-in', (
    tester,
  ) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(dark: false, initialRoute: '/login'));
    await _settle(tester);
    Navigator.of(tester.element(find.byType(LoginPage))).pushNamed('/signup');
    await _settle(tester);

    expect(find.text('Email'), findsOneWidget);
    expect(find.textContaining('I agree to the', findRichText: true), findsNothing, reason: 'Terms come on the profile step');
    expect(_enabled(tester, 'Continue'), isFalse);
    await tester.enterText(find.byType(TextField), 'amara@studio.test');
    await tester.pump();
    await _tap(tester, _primary('Continue'));
    expect(find.text('Enter your code'), findsOneWidget);
    expect(_server.bodies('POST', '/api/auth/otp/generate').single, {'email': 'amara@studio.test'});

    await _tap(tester, find.textContaining('Wrong email?', findRichText: true));
    expect(find.text('Enter your code'), findsNothing);
    expect(_field(tester, 0).controller!.text, 'amara@studio.test');

    await _tap(tester, find.textContaining('Log in', findRichText: true).last);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(AuthSession.instance.isLoggedIn, isFalse);

    // Leaves the sign-up page (and its resend countdown) behind.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
