import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/screens/account_settings_page.dart';
import 'package:studio3/screens/delete_account_page.dart';
import 'package:studio3/screens/order_detail_page.dart';
import 'package:studio3/screens/profile_settings_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/cache_service.dart';
import 'package:studio3/services/engagement_store.dart';
import 'package:studio3/services/theme_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/settings_tile.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Flow regression 19.2, Settings including the theme switch and delete account
/// (docs/new-ui/NEW_UI_EXECUTION_PLAN.md), starting in light and in dark: the real Settings,
/// Account and Delete account pages under an app that follows [ThemeService] (as `main.dart`),
/// against a fake server, signed in as jordanlee.

Map<String, dynamic> _order(String status) => {
  'id': 'o1',
  'buyerId': 'u-jordan',
  'sellerId': 'u-amara',
  'status': status,
  'artworkCents': 350000,
  'shippingCents': 32000,
  'taxCents': 28875,
  'totalCents': 410875,
  'items': [
    {'pieceId': 'p1', 'priceCents': 350000, 'quantity': 1},
  ],
  'createdAt': '2026-11-02T15:00:00Z',
  'updatedAt': '2026-11-02T15:00:00Z',
};

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body})>[];
  var failTheme = 0;
  var wrongPassword = 0;

  /// The purchase on its way: it keeps the account until it is delivered.
  var purchaseStatus = 'shipped';

  Iterable<({String method, String path, Object? body})> to(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path, body: options.data));
    Object json = {'success': true, 'data': {}};
    var status = 200;
    switch ('${options.method} $path') {
      case 'GET /api/user/me':
        json = {
          'success': true,
          'data': {
            'username': 'jordanlee',
            'name': 'Jordan Lee',
            'email': 'jordan@email.com',
            'profileVisibility': 'public',
            'followersCount': 1,
            'themePreference': ThemeService.instance.preference,
          },
        };
      case 'GET /api/user/me/seller':
        json = {'success': true, 'data': {'enabled': false}};
      case 'PATCH /api/user/me':
        if (failTheme > 0) {
          failTheme--;
          status = 500;
          json = {'success': false, 'message': 'down'};
        } else {
          json = {
            'success': true,
            'data': {'username': 'jordanlee', 'name': 'Jordan Lee', ...(options.data as Map)},
          };
        }
      case 'GET /api/user/me/orders':
        json = {
          'success': true,
          'data': {
            'items': [_order(purchaseStatus)],
            'nextCursor': null,
          },
        };
      case 'GET /api/orders/o1':
        json = {'success': true, 'data': _order(purchaseStatus)};
      case 'GET /api/pieces/p1':
        json = {
          'success': true,
          'data': {'id': 'p1', 'title': 'Bodies in Color', 'status': 'sold', 'mediaUrl': ''},
        };
      case 'DELETE /api/user/me':
        if (wrongPassword > 0) {
          wrongPassword--;
          status = 401;
          json = {'success': false, 'message': 'Password is incorrect.'};
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

Finder _row(String label) => find.widgetWithText(SettingsRow, label);

Finder _button(String label) => find.widgetWithText(StudioButton, label);

/// What the app draws behind the top page.
Color _background(WidgetTester tester) => tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor!;

/// The app as `main.dart` builds it: its theme follows [ThemeService].
Widget _app() => ListenableBuilder(
  listenable: ThemeService.instance,
  builder: (context, _) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeService.instance.mode,
    routes: {'/login': (_) => const Scaffold(body: Text('Sign-in page'))},
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: const ProfileSettingsPage(),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '.',
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _server = _Fake();
    ApiClient.instance.debugUseAdapter(_server);
    await CacheService.instance.clearAll();
    AuthSession.instance.accessToken = 'token';
    AuthSession.instance.user = const AuthUser(
      username: 'jordanlee',
      name: 'Jordan Lee',
      email: 'jordan@email.com',
      onboardingComplete: true,
    );
  });
  tearDown(() async {
    AuthSession.instance.accessToken = null;
    AuthSession.instance.user = null;
    EngagementStore.instance.clear();
    await ThemeService.instance.setMode(ThemeMode.light);
    await CacheService.instance.clearAll();
  });

  for (final startDark in [false, true]) {
    final from = startDark ? 'dark' : 'light';
    final to = startDark ? 'Light' : 'Dark';

    testWidgets('Settings from $from: Appearance switches the whole app and saves it to the account '
        '(a refused save goes back); Account opens', (tester) async {
      await ThemeService.instance.setMode(startDark ? ThemeMode.dark : ThemeMode.light);
      setBoardViewport(tester, height: 1500);
      await tester.pumpWidget(_app());
      await _settle(tester);

      final startColors = startDark ? StudioColors.dark : StudioColors.light;
      final endColors = startDark ? StudioColors.light : StudioColors.dark;
      expect(_server.to('GET', '/api/user/me/seller'), isNotEmpty);
      expect(_row('Start selling'), findsOneWidget);
      expect(tester.widget<SettingsRow>(_row('Appearance')).value, startDark ? 'Dark' : 'Light');
      expect(_background(tester), startColors.background);

      // A save the server refuses puts it back.
      _server.failTheme = 1;
      await _tap(tester, _row('Appearance'));
      await _tap(tester, find.text(to).last);
      expect(_server.to('PATCH', '/api/user/me').single.body, {'themePreference': to.toLowerCase()});
      expect(find.text('Could not save appearance'), findsOneWidget);
      expect(ThemeService.instance.isDark, startDark);
      expect(_background(tester), startColors.background);
      await tester.pump(const Duration(seconds: 4));

      // Then it switches: every page, at once, and the account keeps it.
      await _tap(tester, _row('Appearance'));
      await _tap(tester, find.text(to).last);
      expect(_server.to('PATCH', '/api/user/me'), hasLength(2));
      expect(ThemeService.instance.isDark, !startDark);
      expect(tester.widget<SettingsRow>(_row('Appearance')).value, to);
      expect(_background(tester), endColors.background);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_preference'), to.toLowerCase(), reason: 'shown before sign-in next time');

      // Account opens on the new theme with the account's details.
      await _tap(tester, _row('Account'));
      expect(find.byType(AccountSettingsPage), findsOneWidget);
      expect(tester.widget<SettingsRow>(_row('Email')).value, 'jordan@email.com');
      expect(_background(tester), endColors.background);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
    });
  }

  testWidgets('Delete account: waits while a purchase is on its way, then DELETE and the password '
      '(a wrong one stays), and signs out', (tester) async {
    setBoardViewport(tester, height: 1500);
    await tester.pumpWidget(_app());
    await _settle(tester);

    await _tap(tester, _row('Delete account'));
    expect(find.byType(DeleteAccountPage), findsOneWidget);
    expect(_server.to('GET', '/api/user/me/orders'), isNotEmpty);
    expect(find.text('Finish these first'), findsOneWidget);
    expect(_row('Piece shipping'), findsOneWidget);
    expect(tester.widget<SettingsRow>(_row('Piece shipping')).value, 'Bodies in Color');
    expect(tester.widget<StudioButton>(_button('Delete account')).onPressed, isNull);

    // The row opens the order; once it is delivered and confirmed, coming back clears the list.
    await _tap(tester, _row('Piece shipping'));
    expect(find.byType(OrderDetailPage), findsOneWidget);
    _server.purchaseStatus = 'completed';
    Navigator.of(tester.element(find.byType(OrderDetailPage))).pop();
    await _settle(tester);
    expect(find.text('Finish these first'), findsNothing);
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(tester.widget<StudioButton>(_button('Delete account')).onPressed, isNotNull);

    // DELETE and a wrong password: the server says so and nothing is deleted.
    _server.wrongPassword = 1;
    await _tap(tester, _button('Delete account'));
    expect(find.text('Type DELETE to confirm.'), findsOneWidget);
    final fields = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
    await tester.enterText(fields.first, 'DELETE');
    await tester.enterText(fields.last, 'wrong');
    await tester.pump();
    await _tap(tester, _button('Delete account').last);
    expect(_server.to('DELETE', '/api/user/me').single.body, {'password': 'wrong'});
    expect(find.text('Password is incorrect.'), findsOneWidget);
    expect(find.byType(DeleteAccountPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    // Then it goes, and the app is back at sign-in, signed out.
    await _tap(tester, _button('Delete account'));
    await tester.enterText(fields.first, 'DELETE');
    await tester.enterText(fields.last, 'secret');
    await tester.pump();
    await _tap(tester, _button('Delete account').last);
    expect(_server.to('DELETE', '/api/user/me').last.body, {'password': 'secret'});
    expect(find.text('Sign-in page'), findsOneWidget);
    expect(find.byType(DeleteAccountPage), findsNothing);
    expect(AuthSession.instance.isLoggedIn, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));
  });
}
