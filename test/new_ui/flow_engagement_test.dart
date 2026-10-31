import 'dart:convert';

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
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/engagement_store.dart';
import 'package:studio3/services/saved_content_store.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/piece_detail/piece_comment_sheet.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Flow regression 19.2, like / save / comment / follow (docs/new-ui/NEW_UI_EXECUTION_PLAN.md),
/// in light and dark: the real piece pages and comment sheet against a fake server, signed in as
/// jordanlee. (Scenes have Save, Comments and Follow but no like: `flow_reels_test.dart`.
/// Nearby artists' Follow: `flow_discover_test.dart`.)

Map<String, dynamic> _pieceJson(String id, {required bool forSale, required String author}) => {
  'id': id,
  'title': 'Bodies in Color',
  'status': 'live',
  'isForSale': forSale,
  'priceCents': forSale ? 350000 : null,
  'listingState': forSale ? 'available' : null,
  'mediaUrl': '',
  'likeCount': 12,
  'isLiked': false,
  'isSaved': false,
  'author': {'username': author, 'name': author == 'amara' ? 'Amara Osei' : 'Esi Owusu', 'isFollowing': false},
};

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body, String? auth})>[];
  var failLike = 0;
  var failSave = 0;
  var failComment = 0;
  var likes = 12;

  Iterable<({String method, String path, Object? body, String? auth})> to(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path, body: options.data, auth: options.headers['Authorization'] as String?));
    Object json = {'success': true, 'data': {}};
    var status = 200;
    Object fail() {
      status = 500;
      return {'success': false, 'message': 'down'};
    }

    switch ('${options.method} $path') {
      case 'GET /api/pieces/p1':
        json = {'success': true, 'data': _pieceJson('p1', forSale: true, author: 'amara')};
      case 'GET /api/pieces/p2':
        json = {'success': true, 'data': _pieceJson('p2', forSale: false, author: 'esi')};
      case 'POST /api/pieces/p1/like' || 'POST /api/pieces/p2/like':
        if (failLike > 0) {
          failLike--;
          json = fail();
        } else {
          json = {'success': true, 'data': {'liked': true, 'likeCount': ++likes}};
        }
      case 'DELETE /api/pieces/p1/like' || 'DELETE /api/pieces/p2/like':
        json = {'success': true, 'data': {'liked': false, 'likeCount': --likes}};
      case 'POST /api/pieces/p1/save' || 'POST /api/pieces/p2/save':
        if (failSave > 0) {
          failSave--;
          json = fail();
        } else {
          json = {'success': true, 'data': {'saved': true}};
        }
      case 'DELETE /api/pieces/p1/save' || 'DELETE /api/pieces/p2/save':
        json = {'success': true, 'data': {'saved': false}};
      case 'GET /api/pieces/p1/comments':
        json = {
          'success': true,
          'data': {'items': [], 'nextCursor': null},
        };
      case 'POST /api/pieces/p1/comments':
        if (failComment > 0) {
          failComment--;
          json = fail();
        } else {
          json = {
            'success': true,
            'data': {
              'id': 'c-new',
              'body': (options.data as Map)['body'],
              'user': {'username': 'jordanlee', 'name': 'Jordan Lee'},
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            },
          };
        }
      case 'POST /api/users/amara/follow':
        json = {'success': true, 'data': {'following': true, 'requested': false}};
      // Esi's account is private: following asks.
      case 'POST /api/users/esi/follow':
        json = {'success': true, 'data': {'following': false, 'requested': true}};
      case 'DELETE /api/users/amara/follow' || 'DELETE /api/users/esi/follow':
        json = {'success': true, 'data': {'following': false, 'requested': false}};
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

FeedPreviewItem _item(String id, {required bool forSale, required String author}) => FeedPreviewItem(
  id: id,
  imageSeeds: const [1],
  title: 'Bodies in Color',
  medium: 'Oil on canvas',
  year: 2025,
  dimensions: '24 × 36 in',
  story: 'Skin as light rather than surface.',
  handle: '@$author',
  authorUsername: author,
  authorName: author == 'amara' ? 'Amara Osei' : 'Esi Owusu',
  isAvailable: forSale,
  aspectRatio: FeedAspectRatio.portrait3x4,
  priceCents: forSale ? 350000 : null,
  status: 'live',
  likeCount: 12,
);

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

/// A control by its label (the action row's Like / Liked / Comment, the top Save / Saved).
Finder _control(String label) => find.byWidgetPredicate(
  (w) => (w is Semantics && w.properties.label == label) || (w is StudioIcon && w.semanticLabel == label),
);

Finder _follow(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

Widget _app(Widget page, {required bool dark}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: page,
    ),
  ),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '.',
    );
  });

  setUp(() {
    _server = _Fake();
    ApiClient.instance.debugUseAdapter(_server);
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
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('piece for sale ($theme): like, save, comment and follow round-trip; failures roll back', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(_app(AvailablePieceDetailPage(item: _item('p1', forSale: true, author: 'amara')), dark: dark));
      await _settle(tester);

      // Like, then unlike.
      await _tap(tester, _control('Like'));
      expect(_server.to('POST', '/api/pieces/p1/like').single.auth, 'Bearer token');
      expect(_control('Liked'), findsOneWidget);
      expect(EngagementStore.instance.resolveLikeCount('p1', 0), 13);
      await _tap(tester, _control('Liked'));
      expect(_server.to('DELETE', '/api/pieces/p1/like'), hasLength(1));
      expect(_control('Like'), findsOneWidget);
      expect(EngagementStore.instance.resolveLikeCount('p1', 0), 12);

      // A like the server refuses goes back.
      _server.failLike = 1;
      await _tap(tester, _control('Like'));
      expect(_server.to('POST', '/api/pieces/p1/like'), hasLength(2));
      expect(_control('Like'), findsOneWidget);
      expect(_control('Liked'), findsNothing);

      // Save (no folders yet, so straight to All saved), then unsave.
      await _tap(tester, _control('Save'));
      expect(_server.to('POST', '/api/pieces/p1/save').single.auth, 'Bearer token');
      expect(_control('Saved'), findsOneWidget);
      expect(find.text('Added to Collection'), findsOneWidget);
      expect(SavedContentStore.instance.isSaved('p1'), isTrue);
      await tester.pump(const Duration(seconds: 4));
      await _tap(tester, _control('Saved'));
      expect(_server.to('DELETE', '/api/pieces/p1/save'), hasLength(1));
      expect(_control('Save'), findsOneWidget);
      expect(find.text('Removed from Collection'), findsOneWidget);
      expect(SavedContentStore.instance.isSaved('p1'), isFalse);
      await tester.pump(const Duration(seconds: 4));

      // A save the server refuses goes back.
      _server.failSave = 1;
      await _tap(tester, _control('Save'));
      expect(_control('Save'), findsOneWidget);
      expect(SavedContentStore.instance.isSaved('p1'), isFalse);

      // Follow the artist, then unfollow.
      await _tap(tester, _follow('Follow'));
      expect(_server.to('POST', '/api/users/amara/follow').single.auth, 'Bearer token');
      expect(_follow('Following'), findsOneWidget);
      await _tap(tester, _follow('Following'));
      expect(_server.to('DELETE', '/api/users/amara/follow'), hasLength(1));
      expect(_follow('Follow'), findsOneWidget);

      // Comment: a failed post keeps the text; then it posts and shows.
      await _tap(tester, _control('Comment'));
      expect(find.byType(PieceCommentSheet), findsOneWidget);
      expect(_server.to('GET', '/api/pieces/p1/comments'), hasLength(1));
      expect(find.text('No comments yet'), findsOneWidget);
      final field = find.descendant(of: find.byType(PieceCommentSheet), matching: find.byType(TextField));
      _server.failComment = 1;
      await tester.enterText(field, 'Love the teal');
      await tester.pump();
      await _tap(tester, _control('Send'));
      expect(find.text('Could not post comment'), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, 'Love the teal');
      expect(find.text('Love the teal'), findsOneWidget, reason: 'only in the field, not the list');
      await tester.pump(const Duration(seconds: 3));
      await _tap(tester, _control('Send'));
      final posts = _server.to('POST', '/api/pieces/p1/comments').toList();
      expect(posts, hasLength(2));
      expect(posts.last.body, {'body': 'Love the teal'});
      expect(posts.last.auth, 'Bearer token');
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(find.descendant(of: find.byType(PieceCommentSheet), matching: find.text('Love the teal')), findsOneWidget);
      expect(find.text('No comments yet'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
    });
  }

  testWidgets('what you liked and saved shows when the piece is opened again', (tester) async {
    setBoardViewport(tester, height: 1400);
    await tester.pumpWidget(_app(AvailablePieceDetailPage(item: _item('p1', forSale: true, author: 'amara')), dark: false));
    await _settle(tester);
    await _tap(tester, _control('Like'));
    await _tap(tester, _control('Save'));
    await tester.pump(const Duration(seconds: 4));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(AvailablePieceDetailPage(item: _item('p1', forSale: true, author: 'amara')), dark: false));
    await _settle(tester);
    expect(_control('Liked'), findsOneWidget);
    expect(_control('Saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('piece not for sale: Like and Save in the action row; a private artist shows Requested', (
    tester,
  ) async {
    setBoardViewport(tester, height: 1400);
    await tester.pumpWidget(_app(PieceDetailPage(item: _item('p2', forSale: false, author: 'esi')), dark: true));
    await _settle(tester);

    await _tap(tester, _control('Like'));
    expect(_server.to('POST', '/api/pieces/p2/like'), hasLength(1));
    expect(_control('Liked'), findsOneWidget);
    await _tap(tester, _control('Save'));
    expect(_server.to('POST', '/api/pieces/p2/save'), hasLength(1));
    expect(_control('Saved'), findsWidgets);
    await tester.pump(const Duration(seconds: 4));

    await _tap(tester, _follow('Follow'));
    expect(_server.to('POST', '/api/users/esi/follow'), hasLength(1));
    expect(_follow('Requested'), findsOneWidget);
    // Tapping Requested withdraws the request.
    await _tap(tester, _follow('Requested'));
    expect(_server.to('DELETE', '/api/users/esi/follow'), hasLength(1));
    expect(_follow('Follow'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 11));
  });
}
