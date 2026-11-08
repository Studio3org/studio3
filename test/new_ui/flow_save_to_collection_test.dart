import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/feed_item.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/engagement_store.dart';
import 'package:studio3/services/saved_content_store.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/reels/reel_overlay.dart';
import 'package:studio3/widgets/save_flow.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Saving as on Instagram (the user's call, 2026-11-08), in light and dark, through the real
/// widgets and store against a fake server: Save saves at once and a bar says "Added to
/// Collection" with "Save to collection", which opens every folder and New collection; ticks
/// add and unticks remove; events go in folders too (BACKEND_CHANGES B35). The Scene viewer's
/// rail is Like, Comments, Save, Share, and Like round-trips.

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body})>[];
  final folders = <String, String>{};
  var failLike = false;

  Iterable<Object?> bodies(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).map((r) => r.body);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : null;
    requests.add((method: options.method, path: path, body: body));
    Object json = {'success': true, 'data': {}};
    var code = 200;
    final key = '${options.method} $path';
    if (key == 'GET /api/collections') {
      json = {
        'success': true,
        'data': [
          for (final e in folders.entries) {'id': e.key, 'name': e.value, 'createdAt': '2026-11-01T10:00:00Z'},
        ],
      };
    } else if (key == 'POST /api/collections') {
      folders['col-new'] = body!['name'] as String;
      json = {'success': true, 'data': {'id': 'col-new', 'name': body['name'], 'createdAt': '2026-11-08T10:00:00Z'}};
    } else if (key == 'GET /api/collections/col1') {
      json = {
        'success': true,
        'data': {
          'id': 'col1',
          'name': 'Weekends',
          'items': [
            {'targetType': 'event', 'id': 'ev9', 'title': 'Open Studio Night', 'startsAt': '2026-11-20T18:00:00Z',
              'endsAt': '2026-11-20T21:00:00Z', 'status': 'published'},
          ],
        },
      };
    } else if (path == '/api/posts/s1/like') {
      if (failLike) {
        code = 500;
        json = {'success': false, 'message': 'offline'};
      } else {
        json = {'success': true, 'data': {'liked': options.method == 'POST', 'likeCount': options.method == 'POST' ? 41 : 40}};
      }
    } else if (path == '/api/posts/s1/save') {
      json = {'success': true, 'data': {'saved': options.method == 'POST', 'saveCount': 215}};
    }
    return ResponseBody.fromString(jsonEncode(json), code, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
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

Finder _button(String label) => find.widgetWithText(StudioButton, label);

var _dark = false;

Widget _app(Widget home) => MaterialApp(
  theme: _dark ? AppTheme.dark : AppTheme.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: Scaffold(backgroundColor: Colors.black, body: home),
    ),
  ),
);

FeedItem _scene() => FeedItem.fromJson({
  'type': 'post',
  'id': 's1',
  'caption': 'Late night layering',
  'mediaUrl': '',
  'mediaType': 'image',
  'likeCount': 40,
  'commentCount': 18,
  'saveCount': 214,
  'author': {'username': 'amara', 'name': 'Amara Osei'},
});

final _event = StudioEvent.fromJson({
  'id': 'ev9',
  'title': 'Open Studio Night',
  'startsAt': '2026-11-20T18:00:00Z',
  'endsAt': '2026-11-20T21:00:00Z',
  'status': 'published',
});

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
    AuthSession.instance.accessToken = 'token';
    AuthSession.instance.user = AuthUser.fromJson(const {'id': 'u1', 'username': 'jordanlee', 'name': 'Jordan Lee'});
  });
  tearDown(() async {
    AuthSession.instance.accessToken = null;
    AuthSession.instance.user = null;
    EngagementStore.instance.clear();
    await SavedContentStore.instance.clearLocal();
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('the Scene viewer ($theme): Like, Comments, Save, Share; Like round-trips and rolls back', (tester) async {
      _dark = dark;
      setBoardViewport(tester);
      await tester.pumpWidget(_app(ReelOverlay(item: _scene())));
      await _settle(tester);

      final ys = ['Like, 40', 'Comments, 18', 'Save, 214', 'Share']
          .map((l) => tester.getTopLeft(find.bySemanticsLabel(l)).dy)
          .toList();
      expect(ys, [...ys]..sort());

      await _tap(tester, find.bySemanticsLabel('Like, 40'));
      expect(_server.bodies('POST', '/api/posts/s1/like'), hasLength(1));
      expect(find.bySemanticsLabel('Liked, 41'), findsOneWidget);
      await _tap(tester, find.bySemanticsLabel('Liked, 41'));
      expect(_server.bodies('DELETE', '/api/posts/s1/like'), hasLength(1));
      expect(find.bySemanticsLabel('Like, 40'), findsOneWidget);

      _server.failLike = true;
      await _tap(tester, find.bySemanticsLabel('Like, 40'));
      expect(find.bySemanticsLabel('Like, 40'), findsOneWidget, reason: 'a refused like goes back');
    });

    testWidgets('Save in the viewer ($theme) saves at once; the bar opens the folders and New collection',
        (tester) async {
      _dark = dark;
      _server.folders['col1'] = 'Living room';
      await tester.runAsync(SavedContentStore.instance.loadCollectionsFromApi);
      setBoardViewport(tester);
      await tester.pumpWidget(_app(ReelOverlay(item: _scene())));
      await _settle(tester);

      await _tap(tester, find.bySemanticsLabel('Save, 214'));
      expect(_server.bodies('POST', '/api/posts/s1/save'), hasLength(1));
      expect(SavedContentStore.instance.isSaved('s1'), isTrue);
      expect(find.text('Added to Collection'), findsOneWidget);
      expect(find.text('Living room'), findsNothing, reason: 'nothing asked before saving');

      await _tap(tester, find.text('Save to collection'));
      expect(find.text('All saved'), findsOneWidget);
      expect(find.text('Living room'), findsOneWidget);
      expect(find.text('New collection'), findsOneWidget);

      // New collection: named, made on the server, ticked; Done puts the Scene in it.
      await _tap(tester, find.text('New collection'));
      expect(find.text('Create collection'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Studio visits');
      await tester.pump();
      await _tap(tester, _button('Create collection'));
      expect(_server.bodies('POST', '/api/collections').single, {'name': 'Studio visits'});
      expect(_server.bodies('POST', '/api/collections/col-new/items').single, {'targetType': 'post', 'targetId': 's1'});
      expect(SavedContentStore.instance.collections.firstWhere((c) => c.id == 'col-new').entryIds, ['s1']);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Save to collection ($theme): already-in folders come ticked; unticking takes it out', (tester) async {
      _dark = dark;
      _server.folders.addAll({'col1': 'Living room', 'col2': 'Gifts'});
      await tester.runAsync(SavedContentStore.instance.loadCollectionsFromApi);
      SavedContentStore.instance.addEntryToCollection('col1', 'p3', targetType: 'piece');
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => chooseCollections(context, entryId: 'p3', targetType: 'piece', title: 'Paper Planes'),
                child: const Text('folders'),
              ),
            ),
          ),
        ),
      );
      await _tap(tester, find.text('folders'));
      expect(
        tester.widget<Semantics>(
          find.ancestor(of: find.text('Living room'), matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.checked != null)).first,
        ).properties.checked,
        isTrue,
      );
      await _tap(tester, find.text('Living room'));
      await _tap(tester, find.text('Gifts'));
      await _tap(tester, _button('Done'));
      expect(_server.bodies('DELETE', '/api/collections/col1/items/piece/p3'), hasLength(1));
      expect(_server.bodies('POST', '/api/collections/col2/items').last, {'targetType': 'piece', 'targetId': 'p3'});
      expect(find.text('Saved to Gifts'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('an event ($theme): the same bar, and it goes in a folder as an event', (tester) async {
      _dark = dark;
      _server.folders['col1'] = 'Weekends';
      await tester.runAsync(SavedContentStore.instance.loadCollectionsFromApi);
      SavedContentStore.instance.saveEvent(_event);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => announceEventSave(context, _event, saved: true),
                child: const Text('saved'),
              ),
            ),
          ),
        ),
      );
      await _tap(tester, find.text('saved'));
      expect(find.text('Added to Collection'), findsOneWidget);
      await _tap(tester, find.text('Save to collection'));
      await _tap(tester, find.text('Weekends'));
      await _tap(tester, _button('Done'));
      expect(_server.bodies('POST', '/api/collections/col1/items').single, {'targetType': 'event', 'targetId': 'ev9'});
      await tester.pump(const Duration(seconds: 4));
    });
  }

  test('a folder from the server keeps its events', () async {
    _server.folders['col1'] = 'Weekends';
    await SavedContentStore.instance.loadCollectionsFromApi();
    await SavedContentStore.instance.loadCollectionDetailFromApi('col1');
    final entries = SavedContentStore.instance.entriesForCollection('col1');
    expect(entries.map((e) => (e.id, e.kind)), [('ev9', SavedContentKind.event)]);
    expect(entries.single.event?.title, 'Open Studio Night');
  });
}
