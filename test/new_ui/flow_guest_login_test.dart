import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/main.dart' show AuthGate;
import 'package:studio3/screens/home_feed_page.dart';
import 'package:studio3/screens/login_page.dart';
import 'package:studio3/screens/login_password_page.dart';
import 'package:studio3/screens/reels_page.dart' show routeObserver;
import 'package:studio3/screens/signup_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/chat_socket_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/utils/app_routes.dart';
import 'package:studio3/widgets/auth_ui.dart';
import 'package:studio3/widgets/home_feed/home_feed_widgets.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Flow regression 19.2, first point (docs/new-ui/NEW_UI_EXECUTION_PLAN.md): guest browse →
/// login prompt → login, in light and dark, through the real screens and services against a
/// fake server.
///
/// An account is required today (`kAccountRequired`, 17.1), so a signed-out launch is the
/// sign-in wall: that is the live flow. The guest path (browse the feed, an account-only action
/// asks to sign in, log in) is kept behind the switch, so it runs here too.

const _user = {
  'id': 'u1',
  'username': 'jordanlee',
  'name': 'Jordan Lee',
  'email': 'jordan@email.com',
  'onboardingComplete': true,
  'termsVersion': '9999',
};

Map<String, dynamic> _piece(String id) => {
  'type': 'piece',
  'id': id,
  'title': 'Piece $id',
  'mediaUrl': '',
  'isForSale': true,
  'status': 'live',
  'listingState': 'available',
  'author': {'username': 'amara', 'name': 'Amara Osei'},
};

class _Fake implements HttpClientAdapter {
  final requests = <({String path, String? auth, Map<String, dynamic>? body})>[];

  Iterable<String?> feedAuth() => requests.where((r) => r.path == '/api/feed/for-you').map((r) => r.auth);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : null;
    requests.add((path: options.uri.path, auth: options.headers['Authorization'] as String?, body: body));
    Object json;
    var status = 200;
    switch ('${options.method} ${options.uri.path}') {
      case 'GET /api/feed/for-you':
        json = {
          'success': true,
          'data': {
            'items': [for (var i = 1; i <= 4; i++) _piece('a$i')],
            'nextCursor': null,
          },
        };
      case 'POST /api/auth/login':
        if (body?['password'] == 'Correct-pass') {
          json = {
            'success': true,
            'data': {'accessToken': 'token', 'user': _user},
          };
        } else {
          status = 401;
          json = {'success': false, 'message': 'Invalid email or password.'};
        }
      case 'GET /api/user/me':
        json = {'success': true, 'data': _user};
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

final _inbox = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Inbox');

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 350));
  }
}

/// The app's own routes for this flow: the feed behind [AuthGate] at '/', sign-in, sign-up.
Widget _app({required bool dark, required String initialRoute, Widget? guestHome}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  navigatorObservers: [routeObserver],
  initialRoute: initialRoute,
  routes: {
    '/': (_) => AuthGate(child: HomePage(store: HomeFeedStore())),
    // With the switch off, a guest's '/' is this feed (AuthGate lets it through); named without a
    // slash so the gated '/' isn't built under it.
    'guest': (_) => guestHome!,
    '/login': (_) => const LoginPage(),
    '/signup': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      return SignUpPage(initialEmail: args is String ? args : null);
    },
    '/onboarding': (_) => const Scaffold(body: Text('onboarding')),
    '/terms': (_) => const Scaffold(body: Text('terms page')),
  },
);

/// Sign-in → Welcome back → the feed, from wherever the sign-in page is open.
Future<void> _logIn(WidgetTester tester) async {
  expect(find.byType(LoginPage), findsOneWidget);
  final continueButton = find.byWidgetPredicate((w) => w is AuthPrimaryButton && w.label == 'Continue');
  expect(tester.widget<AuthPrimaryButton>(continueButton).enabled, isFalse);
  await tester.enterText(find.byType(TextField), 'jordan@email.com');
  await tester.pump();
  expect(tester.widget<AuthPrimaryButton>(continueButton).enabled, isTrue);
  await tester.tap(continueButton);
  await _settle(tester);

  expect(find.byType(LoginPasswordPage), findsOneWidget);
  expect(find.text('Welcome back'), findsOneWidget);
  await tester.enterText(find.byType(TextField), 'nope-nope');
  await tester.pump();
  await tester.tap(_button('Log in'));
  await _settle(tester);
  expect(find.byType(LoginPasswordPage), findsOneWidget, reason: 'a wrong password stays');
  expect(AuthSession.instance.isLoggedIn, isFalse);
  await tester.pump(const Duration(seconds: 5)); // the error toast

  await tester.enterText(find.byType(TextField), 'Correct-pass');
  await tester.pump();
  await tester.tap(_button('Log in'));
  await _settle(tester);
  expect(_server.requests.where((r) => r.path == '/api/auth/login').last.body, {
    'username': 'jordan@email.com',
    'password': 'Correct-pass',
  });
  expect(AuthSession.instance.isLoggedIn, isTrue);
}

/// Signed in: on the feed, signed in, with nothing behind it to go back to.
Future<void> _expectSignedInFeed(WidgetTester tester) async {
  expect(find.byType(HomePage), findsOneWidget);
  expect(find.byType(FeedPieceCard, skipOffstage: false), findsWidgets);
  expect(find.byType(LoginPage, skipOffstage: false), findsNothing);
  expect(find.byType(LoginPasswordPage, skipOffstage: false), findsNothing);
  expect(Navigator.of(tester.element(find.byType(HomePage))).canPop(), isFalse);
  expect(_server.feedAuth().last, 'Bearer token', reason: 'the feed is asked for as the account');
  expect(tester.takeException(), isNull);
  // Signed in, AuthGate opened the chat socket; close it so its connect timer ends with the test.
  ChatSocketService.instance.disconnect();
  await tester.pump(const Duration(seconds: 21));
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '.',
    );
    // AuthGate starts the deep-link listener.
    for (final name in ['com.llfbandit.app_links/messages', 'com.llfbandit.app_links/events']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        (call) async => null,
      );
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

    testWidgets('signed out ($theme): the launch is sign-in, the feed sends back to it, logging in opens the feed', (
      tester,
    ) async {
      setBoardViewport(tester);
      expect(kAccountRequired, isTrue);
      final start = resolveInitialRoute();
      expect(start, '/login');
      await tester.pumpWidget(_app(dark: dark, initialRoute: start));
      await _settle(tester);
      // Only sign-in is left: no feed under it, no back to one, no way to look around first.
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomePage, skipOffstage: false), findsNothing);
      expect(Navigator.of(tester.element(find.byType(LoginPage))).canPop(), isFalse);
      expect(find.text('Look around first'), findsNothing);

      // A link straight to the feed while signed out lands on sign-in again.
      Navigator.of(tester.element(find.byType(LoginPage))).pushNamed('/');
      await _settle(tester);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomePage, skipOffstage: false), findsNothing);

      await _logIn(tester);
      await _expectSignedInFeed(tester);
      await tester.pump(const Duration(seconds: 11)); // the image cache's clean-up timer
    });

    testWidgets('guest path behind the switch ($theme): browse the feed, the inbox asks to sign in, Log in, the feed', (
      tester,
    ) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          dark: dark,
          initialRoute: 'guest',
          guestHome: HomePage(store: HomeFeedStore()),
        ),
      );
      await _settle(tester);

      // Browsing: the feed loads with no account.
      expect(find.byType(FeedPieceCard, skipOffstage: false), findsWidgets);
      expect(_server.feedAuth(), isNotEmpty);
      expect(_server.feedAuth().every((a) => a == null), isTrue);

      // An account-only action asks to sign in and does nothing else.
      await tester.tap(_inbox);
      await _settle(tester);
      expect(find.text('Sign in to see your inbox'), findsOneWidget);
      expect(find.text('Log in to see your notifications and messages.'), findsOneWidget);
      expect(_server.requests.where((r) => r.path.startsWith('/api/notifications')), isEmpty);

      await tester.tap(_button('Log in'));
      await _settle(tester);
      expect(find.text('Sign in to see your inbox'), findsNothing);

      await _logIn(tester);
      await _expectSignedInFeed(tester);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('guest path behind the switch ($theme): an email in the prompt opens sign-up with it', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          dark: dark,
          initialRoute: 'guest',
          guestHome: HomePage(store: HomeFeedStore()),
        ),
      );
      await _settle(tester);
      await tester.tap(_inbox);
      await _settle(tester);

      expect(
        tester.widget<StudioButton>(_button('Continue')).onPressed,
        isNull,
        reason: 'grey until the email is valid',
      );
      await tester.enterText(find.byType(TextField), 'new@email.com');
      await tester.pump();
      await tester.tap(_button('Continue'));
      await _settle(tester);
      final signUp = tester.widget<SignUpPage>(find.byType(SignUpPage));
      expect(signUp.initialEmail, 'new@email.com');
      expect(AuthSession.instance.isLoggedIn, isFalse);
      await tester.pump(const Duration(seconds: 11));
    });
  }
}
