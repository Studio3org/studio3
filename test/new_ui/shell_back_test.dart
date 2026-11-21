import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/main.dart' show MainShell;
import 'package:studio3/screens/event_page.dart';
import 'package:studio3/screens/explore_page.dart';
import 'package:studio3/screens/home_feed_page.dart';
import 'package:studio3/screens/reels_page.dart';
import 'package:studio3/screens/saved_page.dart';
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

  testWidgets('Home to Events opens at once: no page in between is shown on the way', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const MainShell()));
    await settle(tester);
    final width = tester.getSize(find.byType(MainShell)).width;

    await tester.tap(find.bySemanticsLabel('Events').first);
    final shownOnTheWay = <String>{};
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      for (final (name, type) in [('Explore', ExplorePage), ('Reels', ReelsPage), ('Saved', SavedPage)]) {
        final page = find.byType(type, skipOffstage: false);
        if (page.evaluate().isEmpty) continue;
        final rect = tester.getRect(page);
        if (rect.right > 0 && rect.left < width) shownOnTheWay.add(name);
      }
      if (i == 0) expect(tester.getRect(find.byType(EventPage)).left, 0, reason: 'Events is there on the first frame');
    }
    await settle(tester);

    expect(shownOnTheWay, isEmpty, reason: 'no page between Home and Events flashes up');
    expect(tester.getRect(find.byType(EventPage)).left, 0, reason: 'Events is on screen');

    // And back: Events to Home is a one-page slide too.
    await tester.tap(find.bySemanticsLabel('Home').first);
    await settle(tester);
    expect(tester.getRect(find.byType(HomePage)).left, 0, reason: 'Home is on screen');
    await tester.pump(const Duration(seconds: 11));
  });
}
