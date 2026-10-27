import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/screens/profile_settings_page.dart';
import 'package:studio3/screens/seller/seller_setup_flow.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/payout_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Phase 13, 17.3 (docs/new-ui/NEW_UI_EXECUTION_PLAN.md): Turn on selling first, then seller
/// setup (intro, Stripe, your studio, done), against a fake server.

const _user = {
  'id': 'u1',
  'username': 'jordanlee',
  'name': 'Jordan Lee',
  'email': 'jordan@email.com',
  'onboardingComplete': true,
};

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Map<String, dynamic>? body})>[];

  /// What GET /api/artists/connect/status answers.
  Map<String, dynamic> status = {'onboarded': false, 'canListForSale': false, 'requirementsDue': <String>[]};
  String? location = 'Dallas, TX';

  Iterable<Map<String, dynamic>?> bodies(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).map((r) => r.body);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : null;
    requests.add((method: options.method, path: options.uri.path, body: body));
    Object json;
    var code = 200;
    switch ('${options.method} ${options.uri.path}') {
      case 'GET /api/user/me':
        json = {
          'success': true,
          'data': {..._user, 'location': location},
        };
      case 'PATCH /api/user/me':
        json = {'success': true, 'data': body};
      case 'POST /api/user/me/seller/enable':
        json = {
          'success': true,
          'data': {'enabled': true, 'location': location},
        };
      case 'POST /api/artists/connect':
        json = {
          'success': true,
          'data': {'onboardingUrl': 'https://connect.stripe.com/setup/e/acct_1/abc'},
        };
      case 'GET /api/artists/connect/status':
        json = {'success': true, 'data': status};
      default:
        code = 404;
        json = {'success': false, 'message': 'no route'};
    }
    return ResponseBody.fromString(
      jsonEncode(json),
      code,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

late _Fake _server;
final _launched = <String>[];

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

/// Back from Stripe: the app goes to the background and comes back.
Future<void> _backFromStripe(WidgetTester tester) async {
  for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await _settle(tester);
}

/// A screen with one button that runs [run] and prints what it returned.
class _Runner extends StatefulWidget {
  const _Runner(this.run);

  final Future<Object?> Function(BuildContext context) run;

  @override
  State<_Runner> createState() => _RunnerState();
}

class _RunnerState extends State<_Runner> {
  String _result = 'not yet';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () async {
              final result = await widget.run(context);
              if (mounted) setState(() => _result = 'result: $result');
            },
            child: const Text('open'),
          ),
          Text(_result),
        ],
      ),
    ),
  );
}

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.light,
  initialRoute: '/under-test',
  routes: {
    '/under-test': (_) => home,
    '/': (_) => const Scaffold(body: Text('home feed')),
    '/terms': (_) => const Scaffold(body: Text('terms page')),
    '/post': (_) => const Scaffold(body: Text('post page')),
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
  late bool wasSeller;
  setUp(() async {
    _server = _Fake();
    _launched.clear();
    ApiClient.instance.debugUseAdapter(_server);
    wasUser = AuthSession.instance.user;
    wasToken = AuthSession.instance.accessToken;
    wasSeller = AuthSession.instance.sellerEnabled;
    AuthSession.instance.sellerEnabled = false;
    AuthSession.instance.user = AuthUser.fromJson(_user);
    AuthSession.instance.accessToken = 'token';
    await PayoutService.instance.invalidateStatus();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        final args = call.arguments as Map;
        _launched.add(args['url'] as String);
        return true;
      },
    );
  });
  tearDown(() {
    AuthSession.instance.user = wasUser;
    AuthSession.instance.accessToken = wasToken;
    AuthSession.instance.sellerEnabled = wasSeller;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      null,
    );
  });

  group('Turn on selling first', () {
    testWidgets('the sheet says why; the second line keeps it not for sale', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_Runner((context) => showSellerPrompt(context))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Turn on selling first'), findsOneWidget);
      expect(find.textContaining('It takes about 5 minutes and your draft stays saved'), findsOneWidget);
      expect(_button('Set up seller profile'), findsOneWidget);
      await tester.tap(_button('Post it as not for sale instead'));
      await tester.pumpAndSettle();
      expect(find.text('result: SellerPromptChoice.notForSale'), findsOneWidget);
    });

    testWidgets('Set up seller profile opens the setup', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_Runner((context) => SellerSetupPage.prompt(context))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(_button('Set up seller profile'));
      await _settle(tester);
      expect(find.text('Sell your work on Studio 3'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await _settle(tester);
      expect(find.text('result: false'), findsOneWidget);
    });
  });

  testWidgets('the whole setup: intro → Stripe → your studio → done, back to the draft', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(
      _app(_Runner((context) => SellerSetupPage.start(context, returnLabel: 'Back to your draft'))),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);

    // SellerIntro.
    expect(find.text('SELLER PROFILE'), findsOneWidget);
    expect(find.text('Set up payouts with Stripe'), findsOneWidget);
    expect(find.text('Your studio'), findsOneWidget);
    await tester.tap(_button('Get started'));
    await _settle(tester);
    expect(_server.bodies('POST', '/api/user/me/seller/enable').single, {
      'location': 'Dallas, TX',
      'useProfileLocation': true,
    });
    expect(AuthSession.instance.sellerEnabled, isTrue);

    // SellerStripe.
    expect(find.text('Set up payouts with Stripe'), findsOneWidget);
    expect(find.textContaining('never sees your full bank or ID details'), findsOneWidget);
    await tester.tap(_button('Continue to Stripe'));
    await _settle(tester);
    expect(_server.bodies('POST', '/api/artists/connect'), hasLength(1));
    expect(_launched, ['https://connect.stripe.com/setup/e/acct_1/abc']);

    // Stripe finished; the app comes back.
    _server.status = {'onboarded': true, 'canListForSale': true, 'payoutsEnabled': true, 'chargesEnabled': true};
    await _backFromStripe(tester);

    // SellerStudio.
    expect(find.text('Stripe verified'), findsOneWidget);
    expect(find.text('Your studio'), findsOneWidget);
    expect(find.text('Where Convelio picks up pieces you sell. Buyers only ever see your city.'), findsOneWidget);
    expect(find.text('Dallas, TX'), findsOneWidget);
    await tester.tap(_button('Finish setup'));
    await _settle(tester);

    // SellerDone.
    expect(find.text('You can sell now'), findsOneWidget);
    expect(_button('Go to your profile'), findsOneWidget);
    await tester.tap(_button('Back to your draft'));
    await _settle(tester);
    expect(find.text('result: true'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('Stripe still needs something: it says what, and Back to Stripe', (tester) async {
    AuthSession.instance.sellerEnabled = true;
    _server.status = {
      'onboarded': true,
      'canListForSale': false,
      'requirementsDue': ['external_account', 'individual.verification.document'],
    };
    setBoardViewport(tester);
    await tester.pumpWidget(_app(_Runner((context) => SellerSetupPage.resume(context))));
    await tester.tap(find.text('open'));
    await _settle(tester);
    expect(find.text('Stripe still needs: a bank account, ID.'), findsOneWidget);
    expect(find.text('Stripe verified'), findsNothing);
    expect(_button('Finish setup'), findsNothing);
    await tester.tap(_button('Back to Stripe'));
    await _settle(tester);
    expect(_launched, hasLength(1));
  });

  testWidgets('Finish later leaves it unfinished; Settings then says so with Continue', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(_Runner((context) => SellerSetupPage.start(context))));
    await tester.tap(find.text('open'));
    await _settle(tester);
    await tester.tap(_button('Get started'));
    await _settle(tester);
    await tester.tap(_button('Finish later'));
    await _settle(tester);
    expect(find.text('result: false'), findsOneWidget);
    expect(AuthSession.instance.sellerEnabled, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('settings'),
        theme: AppTheme.light,
        home: Scaffold(
          body: PayoutSettingsTile(
            status: const PayoutStatus(onboarded: false, payoutsEnabled: false, canListForSale: false),
            onStartSetup: () {},
            onOpenDashboard: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Seller profile: setup not finished'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('opened on its own, done offers List a piece; See seller terms opens the terms', (tester) async {
    _server.status = {'onboarded': true, 'canListForSale': true};
    setBoardViewport(tester);
    await tester.pumpWidget(_app(_Runner((context) => SellerSetupPage.start(context))));
    await tester.tap(find.text('open'));
    await _settle(tester);
    await tester.tap(find.textContaining('See seller terms', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('terms page'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    await tester.tap(_button('Get started'));
    await _settle(tester);
    // Stripe already done: straight to the studio.
    expect(find.text('Stripe verified'), findsOneWidget);
    await tester.tap(_button('Finish setup'));
    await _settle(tester);
    await tester.tap(_button('List a piece'));
    await _settle(tester);
    expect(find.text('post page'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
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
    Future<void> snap(WidgetTester tester, String name) async {
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
    }

    Future<void> open(WidgetTester tester, {String? returnLabel}) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        still(_Runner((context) => SellerSetupPage.start(context, returnLabel: returnLabel))),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
    }

    testWidgets('golden: SellerPrompt', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(still(_Runner((context) => showSellerPrompt(context))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await snap(tester, 'SellerPrompt');
    }, skip: skip);

    testWidgets('golden: SellerIntro', (tester) async {
      await open(tester);
      await snap(tester, 'SellerIntro');
    }, skip: skip);

    testWidgets('golden: SellerStripe', (tester) async {
      await open(tester);
      await tester.tap(_button('Get started'));
      await _settle(tester);
      await snap(tester, 'SellerStripe');
    }, skip: skip);

    testWidgets('golden: SellerStudio', (tester) async {
      _server.status = {'onboarded': true, 'canListForSale': true};
      await open(tester);
      await tester.tap(_button('Get started'));
      await _settle(tester);
      await snap(tester, 'SellerStudio');
    }, skip: skip);

    testWidgets('golden: SellerDone', (tester) async {
      _server.status = {'onboarded': true, 'canListForSale': true};
      await open(tester, returnLabel: 'Back to your draft');
      await tester.tap(_button('Get started'));
      await _settle(tester);
      await tester.tap(_button('Finish setup'));
      await _settle(tester);
      await snap(tester, 'SellerDone');
    }, skip: skip);
  });
}
