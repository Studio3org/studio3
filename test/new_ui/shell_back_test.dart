import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/main.dart' show MainShell;
import 'package:studio3/screens/explore_page.dart';
import 'package:studio3/screens/home_feed_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/theme/app_theme.dart';

import 'golden_harness.dart';

/// The real `MainShell` and the phone's back (the user's call, 2026-11-08, as on Instagram):
/// from another tab it goes Home; on Home the first back refreshes at the top, the next one
/// closes the app (`SystemNavigator.pop`).
class _Fake implements HttpClientAdapter {
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    paths.add(options.uri.path);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': {'items': <Object>[], 'nextCursor': null}}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Fake server;
  final exits = <String>[];

  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '.',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _Fake();
    ApiClient.instance.debugUseAdapter(server);
    exits.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') exits.add(call.method);
        return null;
      },
    );
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets("back: Explore goes Home, then the top and a refresh, then the app closes", (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const MainShell()));
    await settle(tester);
    expect(find.byType(HomePage), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Explore').first);
    await settle(tester);
    final explore = tester.getRect(find.byType(ExplorePage));
    expect(explore.left, 0, reason: 'Explore is on screen');

    // Back on Explore: Home, not closed.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(exits, isEmpty);
    expect(tester.getRect(find.byType(HomePage)).left, 0, reason: 'Home is on screen');

    // Back on Home: the top and a fresh feed, not closed.
    final feedAsks = server.paths.where((p) => p == '/api/feed/for-you').length;
    await tester.binding.handlePopRoute();
    // The refresh circle comes in first, then the feed reloads.
    await settle(tester);
    await settle(tester);
    expect(exits, isEmpty);
    expect(server.paths.where((p) => p == '/api/feed/for-you').length, greaterThan(feedAsks));

    // Back again at the top: the app closes.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(exits, ['SystemNavigator.pop']);
    await tester.pump(const Duration(seconds: 11));
  });
}
