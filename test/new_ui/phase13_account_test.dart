import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/main.dart' show AuthGate;
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/screens/edit_profile_page.dart';
import 'package:studio3/screens/forgot_password_page.dart';
import 'package:studio3/screens/login_page.dart';
import 'package:studio3/screens/login_password_page.dart';
import 'package:studio3/screens/signup_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/utils/app_routes.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Phase 13, 17.2 (docs/new-ui/NEW_UI_EXECUTION_PLAN.md): account required, Welcome back,
/// password reset and Edit profile, against a fake server.

const _user = {
  'id': 'u1',
  'username': 'jordanlee',
  'name': 'Jordan Lee',
  'email': 'jordan@email.com',
  'onboardingComplete': true,
};

class _Fake implements HttpClientAdapter {
  final requests = <({String path, Map<String, dynamic>? body})>[];
  String? password = 'Correct-pass';

  Iterable<Map<String, dynamic>?> bodies(String path) => requests.where((r) => r.path == path).map((r) => r.body);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : null;
    requests.add((path: options.uri.path, body: body));
    Object json;
    var status = 200;
    switch ('${options.method} ${options.uri.path}') {
      case 'POST /api/auth/login':
        if (body?['password'] == password) {
          json = {
            'success': true,
            'data': {'accessToken': 'token', 'user': _user},
          };
        } else {
          status = 401;
          json = {'success': false, 'message': 'Invalid email or password.'};
        }
      case 'POST /api/auth/otp/generate':
        json = {'success': true, 'data': {'message': 'OTP sent successfully.'}};
      case 'POST /api/auth/forget-password':
        json = {'success': true, 'data': {}};
      case 'POST /api/auth/reset-password':
        password = body?['newPassword'] as String?;
        json = {'success': true, 'data': {}};
      case 'GET /api/user/me':
        json = {
          'success': true,
          'data': {
            ..._user,
            'bio': 'Painter in Dallas.',
            'location': 'Dallas, TX',
            'canChangeUsername': false,
            'lastUsernameChangeAt': '2037-11-01T12:00:00Z',
          },
        };
      case 'PATCH /api/user/me':
        json = {'success': true, 'data': body};
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

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 350));
  }
}

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.light,
  initialRoute: '/under-test',
  routes: {
    '/under-test': (_) => home,
    '/': (_) => const Scaffold(body: Text('home feed')),
    '/login': (_) => const Scaffold(body: Text('sign in')),
    '/onboarding': (_) => const Scaffold(body: Text('onboarding')),
    '/terms': (_) => const Scaffold(body: Text('terms page')),
  },
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadStudioFonts();
    dotenv.loadFromString(envString: '', isOptional: true);
  });

  late AuthUser? wasUser;
  late String? wasToken;
  setUp(() {
    _server = _Fake();
    ApiClient.instance.debugUseAdapter(_server);
    wasUser = AuthSession.instance.user;
    wasToken = AuthSession.instance.accessToken;
  });
  tearDown(() {
    AuthSession.instance.user = wasUser;
    AuthSession.instance.accessToken = wasToken;
  });

  test('an account is required: signed out starts on sign-in', () {
    AuthSession.instance.user = null;
    AuthSession.instance.accessToken = null;
    expect(kAccountRequired, isTrue);
    expect(resolveInitialRoute(), '/login');
  });

  testWidgets('signed out, the home route sends people to sign-in instead of the feed', (tester) async {
    AuthSession.instance.user = null;
    AuthSession.instance.accessToken = null;
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (_) => const AuthGate(child: Scaffold(body: Text('home feed'))),
          '/login': (_) => const Scaffold(body: Text('sign in')),
        },
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('sign in'), findsOneWidget);
    expect(find.text('home feed'), findsNothing);
  });

  group('Welcome back', () {
    testWidgets('the right password logs in and opens the feed', (tester) async {
      AuthSession.instance.user = null;
      AuthSession.instance.accessToken = null;
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const LoginPasswordPage(email: 'jordan@email.com')));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Correct-pass');
      await tester.pump();
      await tester.tap(_button('Log in'));
      await _settle(tester);
      expect(_server.bodies('/api/auth/login').single, {'username': 'jordan@email.com', 'password': 'Correct-pass'});
      expect(find.text('home feed'), findsOneWidget);
    });

    testWidgets('a wrong password stays on the screen and says why', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const LoginPasswordPage(email: 'jordan@email.com')));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'nope-nope');
      await tester.pump();
      await tester.tap(_button('Log in'));
      await _settle(tester);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.textContaining('Invalid email or password'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // the error toast
    });
  });

  testWidgets('Welcome back → Create an account: the code goes to that email, and it opens on the code step', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(const LoginPasswordPage(email: 'new@email.com')));
    await tester.pump();
    await tester.tap(find.textContaining('Create an account', findRichText: true));
    await _settle(tester);
    expect(_server.bodies('/api/auth/otp/generate').single, {'email': 'new@email.com'});
    expect(find.text('Enter your code'), findsOneWidget);
    expect(find.textContaining('new@email.com', findRichText: true), findsWidgets);
    // Back from the code returns to Welcome back, not to an email step.
    await tester.tap(find.byTooltip('Back'));
    await _settle(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  group('Forgot password', () {
    testWidgets('from Welcome back: the email goes out at once, then Check your email', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const ForgotPasswordPage(email: 'jordan@email.com')));
      await _settle(tester);
      expect(_server.bodies('/api/auth/forget-password').single, {'email': 'jordan@email.com'});
      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining('jordan@email.com'), findsOneWidget);
      expect(_button('Back to log in'), findsOneWidget);
      expect(find.text('Send it again'), findsOneWidget);
    });

    testWidgets('Set a new password: the code and 8+ characters, then Save and log in opens the feed', (tester) async {
      AuthSession.instance.user = null;
      AuthSession.instance.accessToken = null;
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const ForgotPasswordPage(email: 'jordan@email.com')));
      await _settle(tester);
      await tester.tap(find.text('Have a reset code?'));
      await tester.pump();

      // `LoginReset`.
      final title = tester.widget<Text>(find.text('Set a new password'));
      expect((title.style!.fontSize, title.style!.fontWeight), (28, StudioType.medium));
      expect(find.text('For jordan@email.com'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(tester.widget<StudioButton>(_button('Save and log in')).onPressed, isNull);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'abc123');
      await tester.enterText(fields.at(1), 'short');
      await tester.pump();
      expect(tester.widget<StudioButton>(_button('Save and log in')).onPressed, isNull);
      await tester.enterText(fields.at(1), 'new-password');
      await tester.pump();
      await tester.tap(_button('Save and log in'));
      await _settle(tester);
      expect(_server.bodies('/api/auth/reset-password').single, {'token': 'abc123', 'newPassword': 'new-password'});
      expect(_server.bodies('/api/auth/login').single, {'username': 'jordan@email.com', 'password': 'new-password'});
      expect(find.text('home feed'), findsOneWidget);
    });
  });

  group('Edit profile', () {
    setUp(() {
      AuthSession.instance.user = AuthUser.fromJson(_user);
      AuthSession.instance.accessToken = 'token';
    });

    testWidgets('Cancel / Save, @, the username date, the bio count, Location and Website rows', (tester) async {
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const EditProfilePage())),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Change cover'), findsOneWidget);
      expect(find.text('@'), findsOneWidget);
      // Changed on Nov 1: locked until 30 days later.
      expect(find.text('You can change it again on Dec 1.'), findsOneWidget);
      final count = tester.widget<Text>(find.text('18 / 150'));
      expect(count.style!.fontFamily, StudioType.geistMono);
      expect(find.text('Dallas, TX'), findsOneWidget);
      expect(find.text('Website'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget); // no website yet

      // Website opens a sheet; Done fills the row.
      await tester.tap(find.text('Website'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'jordanlee.studio');
      await tester.tap(_button('Done'));
      await tester.pumpAndSettle();
      expect(find.text('jordanlee.studio'), findsOneWidget);

      // Something changed: Cancel asks first; Keep editing stays.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Edit profile'), findsOneWidget);

      // Save sends the website.
      await tester.tap(find.text('Save'));
      await _settle(tester);
      expect(_server.bodies('/api/user/me').last!['website'], 'jordanlee.studio');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('nothing changed: Cancel just closes', (tester) async {
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const EditProfilePage())),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('goldens', () {
    final skip = Platform.environment['NEW_UI_GOLDENS'] != '1';
    Widget still(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/under-test',
      routes: {
        '/under-test': (_) => MediaQuery(
          data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
          child: home,
        ),
        '/': (_) => const SizedBox(),
      },
    );
    Future<void> snap(WidgetTester tester, String name, {double height = 844}) async {
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
      await checkAcceptance(tester);
    }

    testWidgets('golden: SignInFirst', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(still(const LoginPage()));
      await snap(tester, 'SignInFirst');
    }, skip: skip);

    testWidgets('golden: LoginPassword', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(still(const LoginPasswordPage(email: 'jordan@email.com')));
      await tester.enterText(find.byType(TextField), 'password');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await snap(tester, 'LoginPassword');
    }, skip: skip);

    testWidgets('golden: LoginReset', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(still(const ForgotPasswordPage(email: 'jordan@email.com')));
      await _settle(tester);
      await tester.tap(find.text('Have a reset code?'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), 'newpassword');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await snap(tester, 'LoginReset');
    }, skip: skip);

    testWidgets('golden: SignIn3Profile', (tester) async {
      setBoardViewport(tester, height: 960);
      await tester.pumpWidget(still(const SignUpPage(initialStepIndex: 2)));
      await tester.enterText(find.byType(TextField).at(0), 'Jordan Lee');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await snap(tester, 'SignIn3Profile', height: 960);
    }, skip: skip);

    testWidgets('golden: EditProfile', (tester) async {
      AuthSession.instance.user = AuthUser.fromJson(_user);
      AuthSession.instance.accessToken = 'token';
      setBoardViewport(tester, height: 1000);
      await tester.pumpWidget(still(const EditProfilePage()));
      await _settle(tester);
      await snap(tester, 'EditProfile', height: 1000);
    }, skip: skip);
  });
}
