import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/screens/available_piece_detail_page.dart';
import 'package:studio3/screens/piece_detail_page.dart';
import 'package:studio3/screens/saved_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/cache_service.dart';
import 'package:studio3/services/engagement_store.dart';
import 'package:studio3/services/saved_content_store.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/saved/saved_collection_widgets.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Flow regression 19.2, Saved and collections (docs/new-ui/NEW_UI_EXECUTION_PLAN.md), in light
/// and dark: the real Saved tab, folder sheets and piece page against a fake server, signed in
/// as jordanlee with two saved pieces and no folders yet.

Map<String, dynamic> _piece(String id, String title, {required bool forSale}) => {
  'id': id,
  'title': title,
  'status': 'live',
  'isForSale': forSale,
  'priceCents': forSale ? 350000 : null,
  'listingState': forSale ? 'available' : null,
  'mediaUrl': '',
  'isSaved': true,
  'author': {'username': 'amara', 'name': 'Amara Osei', 'isFollowing': false},
};

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body})>[];
  final saved = <Map<String, dynamic>>[
    _piece('p1', 'Bodies in Color', forSale: true),
    _piece('p2', 'Quiet Hours', forSale: false),
  ];

  /// Folder id → its pieces' ids.
  final folders = <String, ({String name, List<String> items})>{};

  Iterable<({String method, String path, Object? body})> to(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    final method = options.method;
    requests.add((method: method, path: path, body: options.data));
    Object json = {'success': true, 'data': {}};
    var status = 200;
    final folderItem = RegExp(r'^/api/collections/([^/]+)/items(?:/piece/([^/]+))?$').firstMatch(path);
    final folder = RegExp(r'^/api/collections/([^/]+)$').firstMatch(path);

    if (method == 'GET' && path == '/api/user/me/saved/pieces') {
      json = {'success': true, 'data': saved};
    } else if (method == 'GET' && path == '/api/user/me/saved/posts') {
      json = {'success': true, 'data': <Object>[]};
    } else if (method == 'GET' && path == '/api/collections') {
      json = {
        'success': true,
        'data': [
          for (final e in folders.entries) {'id': e.key, 'name': e.value.name, 'createdAt': '2026-11-06T10:00:00Z'},
        ],
      };
    } else if (method == 'POST' && path == '/api/collections') {
      final id = 'col${folders.length + 1}';
      final name = (options.data as Map)['name'] as String;
      folders[id] = (name: name, items: <String>[]);
      json = {
        'success': true,
        'data': {'id': id, 'name': name, 'createdAt': '2026-11-06T10:00:00Z'},
      };
    } else if (folderItem != null && method == 'POST') {
      folders[folderItem.group(1)!]!.items.add((options.data as Map)['targetId'] as String);
    } else if (folderItem != null && method == 'DELETE') {
      folders[folderItem.group(1)!]!.items.remove(folderItem.group(2));
    } else if (folder != null && method == 'GET') {
      final f = folders[folder.group(1)!]!;
      json = {
        'success': true,
        'data': {
          'id': folder.group(1),
          'name': f.name,
          'items': [
            for (final id in f.items) {...saved.firstWhere((p) => p['id'] == id), 'targetType': 'piece'},
          ],
        },
      };
    } else if (folder != null && method == 'PATCH') {
      final id = folder.group(1)!;
      folders[id] = (name: (options.data as Map)['name'] as String, items: folders[id]!.items);
    } else if (folder != null && method == 'DELETE') {
      folders.remove(folder.group(1));
    } else if (method == 'DELETE' && path == '/api/pieces/p1/save') {
      saved.removeWhere((p) => p['id'] == 'p1');
      json = {'success': true, 'data': {'saved': false}};
    } else if (method == 'POST' && path == '/api/pieces/p3/save') {
      json = {'success': true, 'data': {'saved': true}};
    } else if (method == 'GET' && path.startsWith('/api/pieces/')) {
      final id = path.split('/')[3];
      // p3 isn't saved yet; the others are.
      json = {
        'success': true,
        'data': id == 'p3'
            ? {..._piece(id, 'Paper Planes', forSale: false), 'isSaved': false}
            : _piece(id, 'Bodies in Color', forSale: true),
      };
    } else if (method == 'GET') {
      json = {
        'success': true,
        'data': {'items': <Object>[], 'nextCursor': null},
      };
    } else {
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

Future<void> _hold(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.longPress(finder.first, warnIfMissed: false);
  await _settle(tester);
}

Finder _button(String label) => find.widgetWithText(StudioButton, label);

/// A folder tile on the Saved index by its name (its title, where a tap lands).
Finder _folder(String name) =>
    find.descendant(of: find.byType(SavedFolderTile), matching: find.text(name));

Future<void> _back(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
  await _settle(tester);
}

Widget _app(Widget home, {required bool dark}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: home,
    ),
  ),
);

/// This file's own folder for the app's files (created once): test files run side by side and
/// must not share the cache.
final _files = Directory.systemTemp.createTempSync('studio3_flow_saved');

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => _files.path,
    );
  });

  setUp(() async {
    _server = _Fake();
    ApiClient.instance.debugUseAdapter(_server);
    await CacheService.instance.clearAll();
    await SavedContentStore.instance.clearLocal();
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
    await SavedContentStore.instance.clearLocal();
    await CacheService.instance.clearAll();
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('Saved ($theme): All saved and Available, a new folder, move in, rename, move out, '
        'delete, open a piece, remove from Saved', (tester) async {
      setBoardViewport(tester, height: 1200);
      await tester.pumpWidget(_app(const SavedPage(), dark: dark));
      await _settle(tester);

      // The index: everything saved, the pieces for sale, no folders yet.
      expect(_server.to('GET', '/api/user/me/saved/pieces'), isNotEmpty);
      expect(_folder('All saved'), findsOneWidget);
      expect(_folder('Available'), findsOneWidget);
      expect(find.text('Only you can see what you save.'), findsOneWidget);
      expect(SavedContentStore.instance.entries().map((e) => e.id).toSet(), {'p1', 'p2'});

      // Available: only the piece for sale.
      await _tap(tester, _folder('Available'));
      expect(find.text('Bodies in Color'), findsOneWidget);
      expect(find.text('Quiet Hours'), findsNothing);
      await _back(tester);

      // A new folder.
      await _tap(tester, find.byTooltip('New folder'));
      expect(find.text('Folder name'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Living room');
      await tester.pump();
      await _tap(tester, _button('Create folder'));
      expect(_server.to('POST', '/api/collections').single.body, {'name': 'Living room'});
      expect(_folder('Living room'), findsOneWidget);

      // From All saved: hold Quiet Hours → Move to folder → Living room → Done.
      await _tap(tester, _folder('All saved'));
      expect(find.text('Bodies in Color'), findsOneWidget);
      expect(find.text('Quiet Hours'), findsOneWidget);
      await _hold(tester, find.text('Quiet Hours'));
      expect(find.text('Move to folder'), findsOneWidget);
      expect(find.text('Remove from Saved'), findsOneWidget);
      await _tap(tester, find.text('Move to folder'));
      await _tap(tester, find.text('Living room').last);
      await _tap(tester, _button('Done'));
      expect(_server.to('POST', '/api/collections/col1/items').single.body, {'targetType': 'piece', 'targetId': 'p2'});
      await _back(tester);

      // The folder holds it.
      await _tap(tester, _folder('Living room'));
      expect(_server.to('GET', '/api/collections/col1'), isNotEmpty);
      expect(find.text('Quiet Hours'), findsOneWidget);
      expect(find.text('Bodies in Color'), findsNothing);

      // Rename from the folder's options.
      await _tap(tester, find.byTooltip('Folder options'));
      await _tap(tester, find.text('Rename folder'));
      await tester.enterText(find.byType(TextField).last, 'Bedroom');
      await tester.pump();
      await _tap(tester, _button('Rename'));
      expect(_server.to('PATCH', '/api/collections/col1').single.body, {'name': 'Bedroom'});

      // Move it out again: uncheck the folder.
      await _hold(tester, find.text('Quiet Hours'));
      await _tap(tester, find.text('Move to folder'));
      await _tap(tester, find.text('Bedroom').last);
      await _tap(tester, _button('Done'));
      expect(_server.to('DELETE', '/api/collections/col1/items/piece/p2'), hasLength(1));
      expect(find.text('Quiet Hours'), findsNothing);
      await _back(tester);

      // Delete the folder from the index (hold it): the pieces stay in All saved.
      expect(_folder('Bedroom'), findsOneWidget);
      await _hold(tester, _folder('Bedroom'));
      await _tap(tester, find.text('Delete folder'));
      expect(find.text('Delete "Bedroom"?'), findsOneWidget);
      expect(find.text('The pieces stay in All saved.'), findsOneWidget);
      await _tap(tester, find.text('Delete').last);
      expect(_server.to('DELETE', '/api/collections/col1'), hasLength(1));
      expect(_folder('Bedroom'), findsNothing);
      expect(SavedContentStore.instance.entries(), hasLength(2));

      // A saved piece opens its page.
      await _tap(tester, _folder('All saved'));
      await _tap(tester, find.text('Bodies in Color'));
      expect(find.byType(AvailablePieceDetailPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(AvailablePieceDetailPage))).pop();
      await _settle(tester);

      // Remove from Saved.
      await _hold(tester, find.text('Bodies in Color'));
      await _tap(tester, find.text('Remove from Saved'));
      expect(_server.to('DELETE', '/api/pieces/p1/save'), hasLength(1));
      expect(find.text('Bodies in Color'), findsNothing);
      expect(SavedContentStore.instance.isSaved('p1'), isFalse);
      expect(find.text('Quiet Hours'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
    });
  }

  testWidgets('saving from a piece page once a folder exists asks which folders, then saves to both', (
    tester,
  ) async {
    _server.folders['col1'] = (name: 'Living room', items: <String>[]);
    await tester.runAsync(SavedContentStore.instance.loadCollectionsFromApi);
    expect(SavedContentStore.instance.hasCollections, isTrue);
    setBoardViewport(tester, height: 1400);
    await tester.pumpWidget(
      _app(
        const PieceDetailPage(
          item: FeedPreviewItem(
            id: 'p3',
            imageSeeds: [1],
            title: 'Paper Planes',
            medium: 'Ink',
            year: 2025,
            dimensions: '12 × 16 in',
            story: '',
            handle: '@amara',
            authorUsername: 'amara',
            authorName: 'Amara Osei',
            isAvailable: false,
            aspectRatio: FeedAspectRatio.portrait3x4,
            status: 'live',
          ),
        ),
        dark: false,
      ),
    );
    await _settle(tester);
    await _tap(
      tester,
      find.byWidgetPredicate((w) => (w is Semantics && w.properties.label == 'Save') || (w is StudioIcon && w.semanticLabel == 'Save')),
    );
    expect(find.text('Living room'), findsOneWidget);
    await _tap(tester, find.text('Living room'));
    await _tap(tester, _button('Done'));
    expect(_server.to('POST', '/api/pieces/p3/save'), hasLength(1));
    expect(_server.to('POST', '/api/collections/col1/items').single.body, {'targetType': 'piece', 'targetId': 'p3'});
    expect(SavedContentStore.instance.isSaved('p3'), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 11));
  });
}
