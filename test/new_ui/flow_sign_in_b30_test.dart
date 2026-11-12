import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/screens/email_code_page.dart';
import 'package:studio3/screens/forgot_password_page.dart';
import 'package:studio3/screens/login_page.dart';
import 'package:studio3/screens/login_password_page.dart';
import 'package:studio3/screens/signup_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/cache_service.dart';
import 'package:studio3/services/chat_socket_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/auth_ui.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Sign-in by email (BACKEND_CHANGES B30, `NoteSignInFirst`, `NoteLoginPassword`,
/// `NoteLoginReset`), in light and dark, through the real screens and services against a fake
/// server: Continue checks the email; a known one gets Welcome back with "Email me a login
/// code instead" and a reset by code; five wrong passwords lock password log-in; a new one
/// goes to the sign-up code; a server that can't say keeps the old Welcome back.

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body})>[];

  /// What the email check answers: true, false, or null for a server without it (404).
  bool? exists = true;

  /// The next log-in answers 429 (locked after five wrong passwords).
  var locked = false;

  /// Log-in answers the per-network 429 (FRONTEND_HANDOFF 1.1), not the account lock.
  var rateLimited = false;

  /// The next code check answers 503 (Redis down), then this resets.
  var verifyUnavailable = false;

  /// Wrong codes since the last send; at 5 the server kills the code, so even the right one
  /// then answers the same 400 (FRONTEND_HANDOFF 1.1).
  var wrongGuesses = 0;

  Iterable<Object?> bodies(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).map((r) => r.body);

  static final _user = {
    'id': 'u1',
    'username': 'jordanlee',
    'name': 'Jordan Lee',
    'email': 'jordan@email.com',
    'onboardingComplete': true,
    'termsVersion': '9999',
  };

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path, body: options.data));
    Object json = {'success': true, 'data': {}};
    var status = 200;
    final body = options.data is Map ? options.data as Map : const {};
    switch ('${options.method} $path') {
      case 'POST /api/auth/email/check':
        if (exists == null) {
          status = 404;
          json = {'success': false, 'message': 'Not found'};
        } else {
          json = {'success': true, 'data': {'exists': exists}};
        }
      case 'POST /api/auth/otp/generate' || 'POST /api/auth/otp/resend':
        wrongGuesses = 0;
      case 'POST /api/auth/otp/verify' when verifyUnavailable:
        verifyUnavailable = false;
        status = 503;
        json = {'success': false, 'message': 'Sign-in is temporarily unavailable. Please try again shortly.'};
      case 'POST /api/auth/otp/verify':
        if (body['otp'] != '123456' || wrongGuesses >= 5) {
          if (body['otp'] != '123456') wrongGuesses++;
          status = 400;
          json = {'success': false, 'message': 'Invalid or expired OTP.'};
        } else if (body['purpose'] == 'login') {
          json = {'success': true, 'data': {'accessToken': 'token', 'user': _user}};
        } else if (body['purpose'] == 'reset') {
          json = {'success': true, 'data': {'resetToken': 'grant-1'}};
        } else {
          json = {'success': true, 'data': {'verified': true}};
        }
      case 'POST /api/auth/login':
        if (rateLimited) {
          status = 429;
          json = {'success': false, 'message': 'Too many requests. Please try again later.'};
        } else if (locked) {
          status = 429;
          json = {
            'success': false,
            'message': 'Too many wrong passwords. Log in with a code sent to your email, '
                'or try your password again in 15 minutes.',
          };
        } else if (body['password'] == 'right-password' || body['password'] == 'new-password') {
          json = {'success': true, 'data': {'accessToken': 'token', 'user': _user}};
        } else {
          status = 401;
          json = {'success': false, 'message': 'Invalid username, email, or password.'};
        }
      default:
        if (options.method == 'GET') {
          json = {
            'success': true,
            'data': {'items': <Object>[], 'nextCursor': null},
          };
        }
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
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first, warnIfMissed: false);
  await _settle(tester);
}

Finder _primary(String label) => find.byWidgetPredicate((w) => w is AuthPrimaryButton && w.label == label);

Widget _app({required bool dark}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  initialRoute: '/login',
  routes: {
    '/': (_) => const Scaffold(body: Text('The feed')),
    '/login': (_) => const LoginPage(),
    '/onboarding': (_) => const Scaffold(body: Text('onboarding')),
  },
);

Future<void> _continueWith(WidgetTester tester, String email) async {
  await tester.pumpWidget(_app(dark: _dark));
  await _settle(tester);
  await tester.enterText(find.byType(TextField), email);
  await tester.pump();
  await _tap(tester, _primary('Continue'));
}

/// Types a code into the six slots (the sixth digit submits).
Future<void> _typeCode(WidgetTester tester, String code) async {
  await tester.enterText(find.descendant(of: find.byType(AuthOtpInput), matching: find.byType(TextField)), code);
  await _settle(tester);
}

var _dark = false;

/// This file's own folder for the app's files (created once): test files run side by side and
/// must not share the cache.
final _files = Directory.systemTemp.createTempSync('studio3_flow_sign_in_b30');

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => _files.path,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _server = _Fake();
    ApiClient.instance.debugUseAdapter(_server);
  });
  tearDown(() async {
    ChatSocketService.instance.disconnect();
    AuthSession.instance.accessToken = null;
    AuthSession.instance.user = null;
    await CacheService.instance.clearAll();
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('a known email ($theme): Welcome back, then "Email me a login code instead" signs in by code',
        (tester) async {
      _dark = dark;
      setBoardViewport(tester, height: 900);
      await _continueWith(tester, 'jordan@email.com');

      expect(_server.bodies('POST', '/api/auth/email/check').single, {'email': 'jordan@email.com'});
      expect(find.byType(LoginPasswordPage), findsOneWidget);
      expect(find.text('Email me a login code instead'), findsOneWidget);
      expect(find.textContaining('Create an account', findRichText: true), findsNothing);

      await _tap(tester, find.text('Email me a login code instead'));
      expect(find.byType(EmailCodePage), findsOneWidget);
      expect(_server.bodies('POST', '/api/auth/otp/generate').single, {'email': 'jordan@email.com', 'purpose': 'login'});
      expect(find.text('Enter your code'), findsOneWidget);
      expect(find.byType(StudioProgressSegments), findsNothing, reason: 'the progress bar is for new accounts');

      // A wrong code says so and stays.
      await _typeCode(tester, '000000');
      expect(find.text('Invalid or expired OTP.'), findsOneWidget);
      expect(find.byType(EmailCodePage), findsOneWidget);

      await _typeCode(tester, '123456');
      expect(_server.bodies('POST', '/api/auth/otp/verify').last, {
        'email': 'jordan@email.com',
        'otp': '123456',
        'purpose': 'login',
      });
      expect(AuthSession.instance.isLoggedIn, isTrue);
      expect(find.text('The feed'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(minutes: 3));
    });

    testWidgets('five wrong passwords ($theme): password log-in turns off and only the code is offered',
        (tester) async {
      _dark = dark;
      setBoardViewport(tester, height: 900);
      await _continueWith(tester, 'jordan@email.com');
      _server.locked = true;

      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.pump();
      await _tap(tester, _primary('Log in'));

      expect(find.textContaining('Too many wrong passwords.'), findsOneWidget);
      expect(tester.widget<AuthPrimaryButton>(_primary('Log in')).enabled, isFalse);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(find.text('Email me a login code instead'), findsOneWidget);
      expect(AuthSession.instance.isLoggedIn, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('the network limit ($theme): its message shows and password log-in stays on', (tester) async {
      _dark = dark;
      setBoardViewport(tester, height: 900);
      await _continueWith(tester, 'jordan@email.com');
      _server.rateLimited = true;

      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.pump();
      await _tap(tester, _primary('Log in'));

      expect(find.text('Too many requests. Please try again later.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue, reason: 'not the account lock');
      expect(tester.widget<AuthPrimaryButton>(_primary('Log in')).enabled, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('five wrong codes ($theme): the code dies, "Request a new code" shows at once, a new one works',
        (tester) async {
      _dark = dark;
      setBoardViewport(tester, height: 900);
      await _continueWith(tester, 'jordan@email.com');
      await _tap(tester, find.text('Email me a login code instead'));

      // An outage shows the server's line and doesn't count as a wrong guess.
      _server.verifyUnavailable = true;
      await _typeCode(tester, '000000');
      expect(find.text('Sign-in is temporarily unavailable. Please try again shortly.'), findsOneWidget);

      for (var i = 0; i < 5; i++) {
        await _typeCode(tester, '11111$i');
      }
      expect(find.text(kCodeExpiredMessage), findsOneWidget);
      expect(find.text('Request a new code'), findsOneWidget, reason: 'shown despite the resend countdown');
      expect(tester.widget<AuthPrimaryButton>(_primary('Verify')).enabled, isFalse);

      // The right code is no longer sent: it would be refused anyway.
      final checks = _server.bodies('POST', '/api/auth/otp/verify').length;
      await _typeCode(tester, '123456');
      expect(_server.bodies('POST', '/api/auth/otp/verify').length, checks);

      await _tap(tester, find.text('Request a new code'));
      expect(_server.bodies('POST', '/api/auth/otp/resend').single, {'email': 'jordan@email.com', 'purpose': 'login'});
      expect(find.text('Request a new code'), findsNothing);

      await _typeCode(tester, '12345');
      await _typeCode(tester, '123456');
      expect(AuthSession.instance.isLoggedIn, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(minutes: 3));
    });

    testWidgets('Forgot password? ($theme): a reset code, then Set a new password, Save and log in', (tester) async {
      _dark = dark;
      setBoardViewport(tester, height: 900);
      await _continueWith(tester, 'jordan@email.com');

      await _tap(tester, find.text('Forgot password?'));
      expect(find.byType(EmailCodePage), findsOneWidget);
      expect(_server.bodies('POST', '/api/auth/otp/generate').single, {'email': 'jordan@email.com', 'purpose': 'reset'});
      expect(_server.bodies('POST', '/api/auth/forget-password'), isEmpty, reason: 'no link email');

      await _typeCode(tester, '123456');
      expect(find.byType(EmailCodePage), findsNothing);
      expect(find.byType(ForgotPasswordPage), findsOneWidget);
      expect(find.text('Set a new password'), findsOneWidget);
      expect(find.text('For jordan@email.com'), findsOneWidget);
      expect(find.text('Reset code'), findsNothing, reason: 'the code was on the code screen');

      await tester.enterText(find.byType(TextField), 'new-password');
      await tester.pump();
      await _tap(tester, _primary('Save and log in'));
      expect(_server.bodies('POST', '/api/auth/reset-password').single, {
        'token': 'grant-1',
        'newPassword': 'new-password',
      });
      expect(_server.bodies('POST', '/api/auth/login').single, {
        'username': 'jordan@email.com',
        'password': 'new-password',
      });
      expect(find.text('The feed'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a new email ($theme) goes to the sign-up code, not Welcome back', (tester) async {
      _dark = dark;
      _server.exists = false;
      setBoardViewport(tester, height: 900);
      await _continueWith(tester, 'new@email.com');

      expect(find.byType(LoginPasswordPage), findsNothing);
      expect(find.byType(SignUpPage), findsOneWidget);
      expect(find.text('Enter your code'), findsOneWidget);
      expect(_server.bodies('POST', '/api/auth/otp/generate').single, {'email': 'new@email.com'});
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(minutes: 3));
    });

    testWidgets("a server that can't say ($theme): Welcome back with Create an account, reset by link",
        (tester) async {
      _dark = dark;
      _server.exists = null;
      setBoardViewport(tester, height: 900);
      await _continueWith(tester, 'jordan@email.com');

      expect(find.byType(LoginPasswordPage), findsOneWidget);
      expect(find.textContaining('Create an account', findRichText: true), findsOneWidget);
      expect(find.text('Email me a login code instead'), findsNothing);
      await _tap(tester, find.text('Forgot password?'));
      expect(find.byType(EmailCodePage), findsNothing);
      expect(_server.bodies('POST', '/api/auth/forget-password').single, {'email': 'jordan@email.com'});
      expect(find.text('Check your email'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
