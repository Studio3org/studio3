import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/screens/login_page.dart';
import 'package:studio3/screens/login_password_page.dart';
import 'package:studio3/screens/profile_settings_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/cache_service.dart';
import 'package:studio3/services/chat_socket_service.dart';
import 'package:studio3/services/theme_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/auth_ui.dart';
import 'package:studio3/widgets/settings_tile.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Flow regression 19.2, log out, log back in: the theme comes back from the account
/// (docs/new-ui/NEW_UI_EXECUTION_PLAN.md), from light to dark and from dark to light: the real
/// Settings, sign-in pages and services under an app that follows [ThemeService] (as
/// `main.dart`), against a fake server that keeps the account's choice.

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body})>[];

  /// The account's saved choice, as the server keeps it.
  String accountTheme;

  _Fake(this.accountTheme);

  Map<String, dynamic> get _user => {
    'id': 'u1',
    'username': 'jordanlee',
    'name': 'Jordan Lee',
    'email': 'jordan@email.com',
    'onboardingComplete': true,
    'termsVersion': '9999',
    'themePreference': accountTheme,
  };

  Iterable<({String method, String path, Object? body})> to(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path, body: options.data));
    Object json = {'success': true, 'data': {}};
    switch ('${options.method} $path') {
      case 'GET /api/user/me':
        json = {'success': true, 'data': _user};
      case 'GET /api/user/me/seller':
        json = {'success': true, 'data': {'enabled': false}};
      case 'PATCH /api/user/me':
        final theme = (options.data as Map)['themePreference'];
        if (theme is String) accountTheme = theme;
        json = {'success': true, 'data': _user};
      case 'POST /api/auth/login':
        json = {
          'success': true,
          'data': {'accessToken': 'token', 'user': _user},
        };
      case 'POST /api/auth/logout':
        json = {'success': true, 'data': {}};
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
      200,
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

Finder _row(String label) => find.widgetWithText(SettingsRow, label);

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

/// The app's theme right now, as drawn: the top page's background.
Color _background(WidgetTester tester) => tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor ??
    Theme.of(tester.element(find.byType(Scaffold).last)).scaffoldBackgroundColor;

Widget _app() => ListenableBuilder(
  listenable: ThemeService.instance,
  builder: (context, _) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeService.instance.mode,
    initialRoute: '/profile-settings',
    routes: {
      '/': (_) => const Scaffold(body: Text('The feed')),
      '/profile-settings': (_) => const ProfileSettingsPage(),
      '/login': (_) => const LoginPage(),
      '/signup': (_) => const Scaffold(body: Text('sign-up')),
      '/onboarding': (_) => const Scaffold(body: Text('onboarding')),
    },
  ),
);

/// This file's own folder for the app's files (created once): test files run side by side and
/// must not share the cache.
final _files = Directory.systemTemp.createTempSync('studio3_flow_logout_theme');

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => _files.path,
    );
  });

  tearDown(() async {
    ChatSocketService.instance.disconnect();
    AuthSession.instance.accessToken = null;
    AuthSession.instance.user = null;
    await ThemeService.instance.setMode(ThemeMode.light);
    await CacheService.instance.clearAll();
  });

  for (final toDark in [true, false]) {
    final chosen = toDark ? 'Dark' : 'Light';
    final other = toDark ? ThemeMode.light : ThemeMode.dark;
    final chosenColors = toDark ? StudioColors.dark : StudioColors.light;
    final otherColors = toDark ? StudioColors.light : StudioColors.dark;

    testWidgets('choose $chosen, log out (the phone keeps it), the phone changes, log back in: $chosen '
        'comes back from the account', (tester) async {
      SharedPreferences.setMockInitialValues({});
      _server = _Fake(toDark ? 'light' : 'dark');
      ApiClient.instance.debugUseAdapter(_server);
      await ThemeService.instance.setMode(other);
      AuthSession.instance.accessToken = 'token';
      AuthSession.instance.user = const AuthUser(
        username: 'jordanlee',
        name: 'Jordan Lee',
        email: 'jordan@email.com',
        onboardingComplete: true,
      );
      setBoardViewport(tester, height: 1500);
      await tester.pumpWidget(_app());
      await _settle(tester);

      // Choose the theme in Settings: the account keeps it.
      expect(_background(tester), otherColors.background);
      await _tap(tester, _row('Appearance'));
      await _tap(tester, find.text(chosen).last);
      expect(_server.accountTheme, chosen.toLowerCase());
      expect(_background(tester), chosenColors.background);

      // Log out: asks, signs out, sign-in with nothing behind it, still in the chosen theme.
      await _tap(tester, _row('Log out'));
      expect(find.text('Log out?'), findsOneWidget);
      await _tap(tester, _button('Log out'));
      expect(_server.to('POST', '/api/auth/logout'), hasLength(1));
      expect(AuthSession.instance.isLoggedIn, isFalse);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(Navigator.of(tester.element(find.byType(LoginPage))).canPop(), isFalse);
      expect(ThemeService.instance.mode, toDark ? ThemeMode.dark : ThemeMode.light, reason: 'the phone keeps it');

      // Signed out, the phone's choice changes (another account on this phone, say).
      await ThemeService.instance.setMode(other);
      await tester.pump();
      expect(ThemeService.instance.mode, other);

      // Log back in: the account's choice comes back.
      await tester.enterText(find.byType(TextField), 'jordan@email.com');
      await tester.pump();
      await _tap(tester, find.byWidgetPredicate((w) => w is AuthPrimaryButton && w.label == 'Continue'));
      expect(find.byType(LoginPasswordPage), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Correct-pass');
      await tester.pump();
      await _tap(tester, _button('Log in'));
      expect(_server.to('POST', '/api/auth/login'), hasLength(1));
      expect(AuthSession.instance.isLoggedIn, isTrue);
      expect(ThemeService.instance.mode, toDark ? ThemeMode.dark : ThemeMode.light);
      expect(find.text('The feed'), findsOneWidget);
      expect(_background(tester), chosenColors.background);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_preference'), chosen.toLowerCase());
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 21));
    });
  }
}
