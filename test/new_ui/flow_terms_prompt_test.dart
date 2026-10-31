import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/main.dart' show AuthGate;
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/screens/home_feed_page.dart';
import 'package:studio3/screens/login_page.dart';
import 'package:studio3/screens/login_password_page.dart';
import 'package:studio3/screens/reels_page.dart' show routeObserver;
import 'package:studio3/screens/terms_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/chat_socket_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/utils/app_routes.dart';
import 'package:studio3/widgets/auth_ui.dart';

import 'golden_harness.dart';

/// Flow regression 19.2, third point (docs/new-ui/NEW_UI_EXECUTION_PLAN.md): the Terms pop-up for
/// an account created before the terms, in light and dark, through the real `AuthGate`, feed,
/// sign-in and Terms screens against a fake server. The account has no `termsVersion` while the
/// server's current one is [kTermsVersion].

Map<String, dynamic> _oldAccount({String? agreed}) => {
  'id': 'u3',
  'username': 'kofi',
  'name': 'Kofi Mensah',
  'email': 'kofi@studio.test',
  'onboardingComplete': true,
  'termsVersion': ?agreed,
  'currentTermsVersion': kTermsVersion,
};

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, String? auth})>[];
  var failAccept = 0;

  int count(String method, String path) => requests.where((r) => r.method == method && r.path == path).length;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path, auth: options.headers['Authorization'] as String?));
    Object json = {'success': true, 'data': {}};
    var status = 200;
    switch ('${options.method} $path') {
      case 'POST /api/auth/login':
        json = {
          'success': true,
          'data': {'accessToken': 'token', 'user': _oldAccount()},
        };
      case 'POST /api/user/me/accept-terms':
        if (failAccept > 0) {
          failAccept--;
          status = 500;
          json = {'success': false, 'message': 'down'};
        } else {
          json = {'success': true, 'data': _oldAccount(agreed: kTermsVersion)};
        }
      case 'POST /api/auth/logout':
        break;
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
                  'author': {'username': 'amara', 'name': 'Amara Osei'},
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

final _prompt = find.text('I agree');

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
    '/onboarding': (_) => const Scaffold(body: Text('onboarding')),
    '/terms': (_) => const TermsPage(),
  },
);

/// Signed in, AuthGate opened the chat socket; close it so its connect timer ends with the test.
Future<void> _closeSocket(WidgetTester tester) async {
  ChatSocketService.instance.disconnect();
  await tester.pump(const Duration(seconds: 21));
}

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
  });
  tearDown(() async {
    await AuthSession.instance.clear();
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('already signed in ($theme): the pop-up on launch holds until I agree, and stays gone', (tester) async {
      setBoardViewport(tester);
      await AuthSession.instance.saveSession(token: 'token', authUser: AuthUser.fromJson(_oldAccount()));
      expect(AuthSession.instance.user!.needsTermsAcceptance, isTrue);
      final start = resolveInitialRoute();
      expect(start, '/');
      await tester.pumpWidget(_app(dark: dark, initialRoute: start));
      await _settle(tester);

      // Over the blurred feed.
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.textContaining('please review and agree to our Terms of Use (EULA)'), findsOneWidget);
      expect(_prompt, findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);

      // No way past it: not the backdrop, not the system back.
      await tester.tapAt(const Offset(20, 120));
      await _settle(tester);
      expect(_prompt, findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(_prompt, findsOneWidget);
      expect(find.byType(HomePage), findsOneWidget);

      // Read terms opens the Terms; back returns to the pop-up.
      await _tap(tester, find.text('Read terms'));
      expect(find.byType(TermsPage), findsOneWidget);
      expect(find.text('Terms of Use (EULA)'), findsOneWidget);
      expect(_prompt, findsNothing);
      Navigator.of(tester.element(find.byType(TermsPage))).pop();
      await _settle(tester);
      expect(_prompt, findsOneWidget);

      // A save that fails says so and keeps the pop-up; trying again agrees.
      _server.failAccept = 1;
      await _tap(tester, _prompt);
      expect(find.text("Couldn't save that — please try again."), findsOneWidget);
      expect(_prompt, findsOneWidget);
      expect(AuthSession.instance.user!.needsTermsAcceptance, isTrue);
      await tester.pump(const Duration(seconds: 3)); // the toast

      await _tap(tester, _prompt);
      expect(_server.count('POST', '/api/user/me/accept-terms'), 2);
      expect(_server.requests.lastWhere((r) => r.path == '/api/user/me/accept-terms').auth, 'Bearer token');
      expect(_prompt, findsNothing);
      expect(find.text('Terms of Use'), findsNothing);
      expect(AuthSession.instance.user!.termsVersion, kTermsVersion);
      expect(AuthSession.instance.user!.needsTermsAcceptance, isFalse);
      expect(find.byType(HomePage), findsOneWidget);
      expect(AuthSession.instance.isLoggedIn, isTrue);

      // The next launch goes straight to the feed.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(dark: dark, initialRoute: resolveInitialRoute()));
      await _settle(tester);
      expect(find.byType(HomePage), findsOneWidget);
      expect(_prompt, findsNothing);
      expect(_server.count('POST', '/api/user/me/accept-terms'), 2);
      expect(tester.takeException(), isNull);
      await _closeSocket(tester);
    });

    testWidgets('logging in ($theme): the pop-up follows the login, and Log out returns to sign-in', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(dark: dark, initialRoute: resolveInitialRoute()));
      await _settle(tester);
      expect(find.byType(LoginPage), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'kofi@studio.test');
      await tester.pump();
      await _tap(tester, find.byWidgetPredicate((w) => w is AuthPrimaryButton && w.label == 'Continue'));
      expect(find.byType(LoginPasswordPage), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Correct-pass');
      await tester.pump();
      await _tap(tester, find.byWidgetPredicate((w) => w is AuthPrimaryButton && w.label == 'Log in'));

      expect(find.byType(HomePage), findsOneWidget);
      expect(_prompt, findsOneWidget);

      await _tap(tester, find.text('Log out'));
      expect(_server.count('POST', '/api/auth/logout'), 1);
      expect(AuthSession.instance.isLoggedIn, isFalse);
      expect(_server.count('POST', '/api/user/me/accept-terms'), 0);
      expect(_prompt, findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomePage, skipOffstage: false), findsNothing);
      expect(Navigator.of(tester.element(find.byType(LoginPage))).canPop(), isFalse);
      expect(tester.takeException(), isNull);
      await _closeSocket(tester);
    });
  }
}
