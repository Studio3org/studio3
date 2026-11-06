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
import 'package:studio3/screens/blocked_users_page.dart';
import 'package:studio3/screens/conversation_thread_page.dart';
import 'package:studio3/screens/piece_detail_page.dart';
import 'package:studio3/screens/profile_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/blocked_authors_store.dart';
import 'package:studio3/services/engagement_store.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/content_actions_sheet.dart';
import 'package:studio3/widgets/piece_detail/piece_comment_sheet.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Flow regression 19.2, report and block (docs/new-ui/NEW_UI_EXECUTION_PLAN.md), in light and
/// dark: the real piece pages, comment sheet, profile and conversation against a fake server,
/// signed in as jordanlee. Every report goes through the same sheet (a reason, optional
/// details, Send report; a failure keeps it open) and every block asks first, blocks, and
/// leaves the page. Scenes: Block in `flow_reels_test.dart`, Report there too.

Map<String, dynamic> _pieceJson(String id, {required bool forSale, required String author}) => {
  'id': id,
  'title': 'Bodies in Color',
  'status': 'live',
  'isForSale': forSale,
  'priceCents': forSale ? 350000 : null,
  'listingState': forSale ? 'available' : null,
  'mediaUrl': '',
  'likeCount': 0,
  'author': {'username': author, 'name': author == 'amara' ? 'Amara Osei' : 'Esi Owusu', 'isFollowing': false},
};

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body, String? auth})>[];
  var failReport = 0;
  var failBlock = 0;
  var blockedEsi = true;

  Iterable<({String method, String path, Object? body, String? auth})> to(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  Iterable<({String method, String path, Object? body, String? auth})> get reports =>
      requests.where((r) => r.method == 'POST' && r.path.endsWith('/report'));

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path, body: options.data, auth: options.headers['Authorization'] as String?));
    Object json = {'success': true, 'data': {}};
    var status = 200;
    final route = '${options.method} $path';
    if (route.startsWith('POST ') && path.endsWith('/report')) {
      if (failReport > 0) {
        failReport--;
        status = 500;
        json = {'success': false, 'message': 'down'};
      } else {
        json = {'success': true, 'data': {'reported': true}};
      }
    } else if (route.startsWith('POST /api/users/') && path.endsWith('/block')) {
      if (failBlock > 0) {
        failBlock--;
        status = 500;
        json = {'success': false, 'message': 'down'};
      } else {
        json = {'success': true, 'data': {'blocked': true}};
      }
    } else {
      switch (route) {
        case 'GET /api/pieces/p1':
          json = {'success': true, 'data': _pieceJson('p1', forSale: true, author: 'amara')};
        case 'GET /api/pieces/p2':
          json = {'success': true, 'data': _pieceJson('p2', forSale: false, author: 'esi')};
        case 'GET /api/pieces/p1/comments':
          json = {
            'success': true,
            'data': {
              'items': [
                {
                  'id': 'c1',
                  'body': 'Buy followers at spam.example',
                  'user': {'username': 'spammer', 'name': 'Spam Bot'},
                  'createdAt': DateTime.now().toUtc().toIso8601String(),
                },
                {
                  'id': 'c2',
                  'body': 'My own comment',
                  'user': {'username': 'jordanlee', 'name': 'Jordan Lee'},
                  'createdAt': DateTime.now().toUtc().toIso8601String(),
                },
              ],
              'nextCursor': null,
            },
          };
        case 'GET /api/user/esi':
          json = {
            'success': true,
            'data': {'username': 'esi', 'name': 'Esi Owusu', 'profileVisibility': 'public'},
          };
        case 'GET /api/users/blocked':
          json = {
            'success': true,
            'data': [
              if (blockedEsi) {'username': 'esi', 'name': 'Esi Owusu'},
            ],
          };
        case 'DELETE /api/users/esi/block':
          blockedEsi = false;
          json = {'success': true, 'data': {'blocked': false}};
        default:
          // Lists the pages read along the way (pieces, Scenes, series, messages): empty.
          if (options.method == 'GET') {
            json = {
              'success': true,
              'data': {'items': <Object>[], 'nextCursor': null},
            };
          } else {
            status = 404;
            json = {'success': false, 'message': 'no route'};
          }
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

Finder _control(String label) => find.byWidgetPredicate(
  (w) => (w is Semantics && w.properties.label == label) || (w is StudioIcon && w.semanticLabel == label),
);

Finder _button(String label) => find.widgetWithText(StudioButton, label);

/// The route under the page: the test starts on it, so a page that leaves after a block
/// lands back here.
Widget _app(Widget page, {required bool dark}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester, Widget page, {required bool dark}) async {
  await tester.pumpWidget(_app(page, dark: dark));
  await tester.tap(find.text('open'));
  await _settle(tester);
}

/// Picks [reason] in the open report sheet, adds [details], and sends it.
Future<void> _sendReport(WidgetTester tester, String reason, {String? details}) async {
  await _tap(tester, find.text(reason));
  if (details != null) {
    await tester.enterText(find.descendant(of: find.byType(ReportSheet), matching: find.byType(TextField)), details);
    await tester.pump();
  }
  await _tap(tester, _button('Send report'));
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
    BlockedAuthorsStore.instance.clear();
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('piece for sale ($theme): Report piece (a failure stays), then Block the artist and leave', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1400);
      await _open(tester, AvailablePieceDetailPage(item: _item('p1', forSale: true, author: 'amara')), dark: dark);

      await _tap(tester, _control('More'));
      expect(find.text('Block @amara'), findsOneWidget);
      expect(find.text('Report piece'), findsOneWidget);
      await _tap(tester, find.text('Report piece'));
      expect(find.byType(ReportSheet), findsOneWidget);
      expect(tester.widget<StudioButton>(_button('Send report')).onPressed, isNull, reason: 'no reason yet');

      // The server refuses: the sheet stays with what was picked and typed.
      _server.failReport = 1;
      await _sendReport(tester, 'Stolen or copied artwork', details: 'This is my painting');
      expect(find.text('Could not send the report. Try again.'), findsOneWidget);
      expect(find.byType(ReportSheet), findsOneWidget);
      // Then it goes.
      await _tap(tester, _button('Send report'));
      final sent = _server.to('POST', '/api/pieces/p1/report').toList();
      expect(sent, hasLength(2));
      expect(sent.last.body, {'reason': 'stolen_work', 'details': 'This is my painting'});
      expect(sent.last.auth, 'Bearer token');
      expect(find.byType(ReportSheet), findsNothing);
      expect(find.text('Thanks. We will review it within 24 hours.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));

      // Block asks first; Cancel does nothing.
      await _tap(tester, _control('More'));
      await _tap(tester, find.text('Block @amara'));
      expect(find.text('Block @amara?'), findsOneWidget);
      await _tap(tester, _button('Cancel'));
      expect(_server.to('POST', '/api/users/amara/block'), isEmpty);
      expect(find.byType(AvailablePieceDetailPage), findsOneWidget);

      // A block the server refuses says so and keeps the page.
      _server.failBlock = 1;
      await _tap(tester, _control('More'));
      await _tap(tester, find.text('Block @amara'));
      await _tap(tester, _button('Block'));
      expect(find.text('Could not block. Try again.'), findsOneWidget);
      expect(BlockedAuthorsStore.instance.isBlocked('amara'), isFalse);
      expect(find.byType(AvailablePieceDetailPage), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));

      // Then it blocks, and the page leaves (everything from them is hidden).
      await _tap(tester, _control('More'));
      await _tap(tester, find.text('Block @amara'));
      await _tap(tester, _button('Block'));
      expect(_server.to('POST', '/api/users/amara/block'), hasLength(2));
      expect(_server.to('POST', '/api/users/amara/block').last.auth, 'Bearer token');
      expect(BlockedAuthorsStore.instance.isBlocked('amara'), isTrue);
      expect(find.byType(AvailablePieceDetailPage), findsNothing);
      expect(find.text('Blocked @amara'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('comment ($theme): long press someone else\'s for Report comment and Block; not your own', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1400);
      await _open(tester, AvailablePieceDetailPage(item: _item('p1', forSale: true, author: 'amara')), dark: dark);
      await _tap(tester, _control('Comment'));
      expect(find.byType(PieceCommentSheet), findsOneWidget);

      // Your own comment has nothing to report.
      await tester.longPress(find.text('My own comment'));
      await _settle(tester);
      expect(find.text('Report comment'), findsNothing);

      await tester.longPress(find.text('Buy followers at spam.example'));
      await _settle(tester);
      expect(find.text('Block @spammer'), findsOneWidget);
      await _tap(tester, find.text('Report comment'));
      await _sendReport(tester, 'Spam or scam');
      final sent = _server.to('POST', '/api/comments/c1/report').single;
      expect(sent.body, {'reason': 'spam'});
      expect(find.text('Thanks. We will review it within 24 hours.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));

      await tester.longPress(find.text('Buy followers at spam.example'));
      await _settle(tester);
      await _tap(tester, find.text('Block @spammer'));
      expect(find.text('Block @spammer?'), findsOneWidget);
      await _tap(tester, _button('Block'));
      expect(_server.to('POST', '/api/users/spammer/block'), hasLength(1));
      expect(BlockedAuthorsStore.instance.isBlocked('spammer'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('profile ($theme): More options → Report account, then Block and leave the profile', (tester) async {
      setBoardViewport(tester, height: 1400);
      await _open(tester, const ProfilePage(username: 'esi'), dark: dark);
      expect(_server.to('GET', '/api/user/esi'), isNotEmpty);

      await _tap(tester, _control('More options'));
      expect(find.text('Block Esi Owusu'), findsOneWidget);
      await _tap(tester, find.text('Report'));
      expect(find.text('Report account'), findsOneWidget);
      await _sendReport(tester, 'Harassment, hate, or bullying', details: 'Messages me every day');
      final sent = _server.to('POST', '/api/users/esi/report').single;
      expect(sent.body, {'reason': 'harassment', 'details': 'Messages me every day'});
      expect(find.text('Thanks. We will review it within 24 hours.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));

      await _tap(tester, _control('More options'));
      await _tap(tester, find.text('Block Esi Owusu'));
      expect(find.text('Block @esi?'), findsOneWidget);
      await _tap(tester, _button('Block'));
      expect(_server.to('POST', '/api/users/esi/block'), hasLength(1));
      expect(BlockedAuthorsStore.instance.isBlocked('esi'), isTrue);
      expect(find.byType(ProfilePage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('chat ($theme): Conversation options → Report (the chat\'s four reasons), then Block and leave', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1400);
      await _open(
        tester,
        const ConversationThreadPage(
          conversationId: 'conv1',
          otherPartyUsername: 'esi',
          otherPartyName: 'Esi Owusu',
          otherPartyAvatarUrl: null,
          debugMessages: [],
          debugMyUsername: 'jordanlee',
        ),
        dark: dark,
      );

      await _tap(tester, _control('Conversation options'));
      expect(find.text('Block Esi Owusu'), findsOneWidget);
      await _tap(tester, find.text('Report'));
      expect(find.text('Report Esi Owusu'), findsOneWidget);
      // A conversation offers spam, harassment, inappropriate and something else; not stolen work.
      expect(find.text('Stolen or copied artwork'), findsNothing);
      await _sendReport(tester, 'Spam or scam');
      expect(_server.to('POST', '/api/users/esi/report').single.body, {'reason': 'spam'});
      expect(find.text('Thanks. We will review it within 24 hours.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));

      await _tap(tester, _control('Conversation options'));
      await _tap(tester, find.text('Block Esi Owusu'));
      expect(find.text('Block Esi Owusu?'), findsOneWidget);
      await _tap(tester, _button('Block'));
      expect(_server.to('POST', '/api/users/esi/block'), hasLength(1));
      expect(find.byType(ConversationThreadPage), findsNothing);
      expect(find.text('Blocked Esi Owusu'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
    });
  }

  testWidgets('piece not for sale: Report piece and Block from its More', (tester) async {
    setBoardViewport(tester, height: 1400);
    await _open(tester, PieceDetailPage(item: _item('p2', forSale: false, author: 'esi')), dark: false);
    await _tap(tester, _control('More'));
    await _tap(tester, find.text('Report piece'));
    await _sendReport(tester, 'Nudity, violence, or other objectionable content');
    expect(_server.to('POST', '/api/pieces/p2/report').single.body, {'reason': 'inappropriate'});
    await tester.pump(const Duration(seconds: 4));
    await _tap(tester, _control('More'));
    await _tap(tester, find.text('Block @esi'));
    await _tap(tester, _button('Block'));
    expect(_server.to('POST', '/api/users/esi/block'), hasLength(1));
    expect(find.byType(PieceDetailPage), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a guest is asked to sign in before reporting or blocking', (tester) async {
    AuthSession.instance.accessToken = null;
    AuthSession.instance.user = null;
    setBoardViewport(tester, height: 1400);
    await _open(tester, AvailablePieceDetailPage(item: _item('p1', forSale: true, author: 'amara')), dark: false);
    await _tap(tester, _control('More'));
    await _tap(tester, find.text('Report piece'));
    expect(find.byType(ReportSheet), findsNothing);
    expect(find.text('Sign in to report'), findsOneWidget);
    expect(_server.reports, isEmpty);
  });

  testWidgets('Blocked accounts (Settings › Privacy): Unblock asks, then they are gone', (tester) async {
    BlockedAuthorsStore.instance.add('esi');
    setBoardViewport(tester);
    await _open(tester, const BlockedUsersPage(), dark: false);
    expect(_server.to('GET', '/api/users/blocked'), hasLength(1));
    expect(find.text('Esi Owusu'), findsOneWidget);
    await _tap(tester, _button('Unblock'));
    expect(find.text('Unblock @esi?'), findsOneWidget);
    await _tap(tester, _button('Unblock').last);
    expect(_server.to('DELETE', '/api/users/esi/block'), hasLength(1));
    expect(BlockedAuthorsStore.instance.isBlocked('esi'), isFalse);
    expect(find.text('Esi Owusu'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
