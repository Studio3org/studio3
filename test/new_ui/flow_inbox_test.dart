import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/screens/available_piece_detail_page.dart';
import 'package:studio3/screens/conversation_thread_page.dart';
import 'package:studio3/screens/inbox_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/cache_service.dart';
import 'package:studio3/services/chat_socket_service.dart';
import 'package:studio3/services/engagement_store.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Flow regression 19.2, Inbox: notifications, follow requests, chats, conversation
/// (docs/new-ui/NEW_UI_EXECUTION_PLAN.md), in light and dark: the real Inbox, its three tabs and
/// a conversation against a fake server, signed in as jordanlee.

final _now = DateTime.now().toUtc();
String _ago(Duration d) => _now.subtract(d).toIso8601String();

Map<String, dynamic> _pieceJson() => {
  'id': 'p1',
  'title': 'Bodies in Color',
  'status': 'live',
  'isForSale': true,
  'priceCents': 350000,
  'listingState': 'available',
  'mediaUrl': '',
  'author': {'username': 'jordanlee', 'name': 'Jordan Lee'},
};

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body})>[];
  var failSend = 0;
  var requestPending = true;

  Iterable<({String method, String path, Object? body})> to(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path, body: options.data));
    Object json = {'success': true, 'data': {}};
    var status = 200;
    switch ('${options.method} $path') {
      case 'GET /api/notifications':
        json = {
          'success': true,
          'data': {
            'items': [
              {
                'id': 'n1',
                'type': 'follow',
                'actor': {'username': 'esi', 'name': 'Esi Owusu'},
                'target': {'type': 'user', 'id': 'u-esi'},
                'read': true,
                'createdAt': _ago(const Duration(hours: 3)),
              },
              {
                'id': 'n2',
                'type': 'like',
                'actor': {'username': 'amara', 'name': 'Amara Osei'},
                'target': {'type': 'piece', 'id': 'p1'},
                'payload': {'pieceTitle': 'Bodies in Color'},
                'read': false,
                'createdAt': _ago(const Duration(minutes: 20)),
              },
            ],
            'nextCursor': null,
          },
        };
      case 'GET /api/notifications/unread-count':
        json = {'success': true, 'data': {'count': 1}};
      case 'GET /api/pieces/p1':
        json = {'success': true, 'data': _pieceJson()};
      case 'GET /api/users/follow-requests':
        json = {
          'success': true,
          'data': [
            if (requestPending)
              {'username': 'daisy', 'name': 'Daisy Smith', 'requestedAt': _ago(const Duration(hours: 2))},
          ],
        };
      case 'POST /api/users/follow-requests/daisy/accept':
        requestPending = false;
      case 'GET /api/conversations':
        json = {
          'success': true,
          'data': {
            'items': [
              {
                'id': 'c1',
                'otherParty': {'id': 'u-esi', 'username': 'esi', 'name': 'Esi Owusu'},
                'preview': 'See you at the show',
                'updatedAt': _ago(const Duration(hours: 1)),
                'unread': true,
                'status': 'open',
              },
            ],
            'nextCursor': null,
          },
        };
      case 'GET /api/conversations/unread-count':
        json = {'success': true, 'data': {'count': 1}};
      case 'GET /api/conversations/c1':
        json = {
          'success': true,
          'data': {
            'id': 'c1',
            'status': 'open',
            'otherParty': {'id': 'u-esi', 'username': 'esi', 'name': 'Esi Owusu'},
            'messages': [
              {
                'id': 'm1',
                'body': 'See you at the show',
                'sender': {'username': 'esi', 'name': 'Esi Owusu'},
                'createdAt': _ago(const Duration(hours: 1)),
              },
            ],
          },
        };
      case 'POST /api/conversations/c1/messages':
        if (failSend > 0) {
          failSend--;
          status = 500;
          json = {'success': false, 'message': 'down'};
        } else {
          json = {
            'success': true,
            'data': {
              'id': 'm2',
              'body': (options.data as Map)['body'],
              'sender': {'username': 'jordanlee', 'name': 'Jordan Lee'},
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            },
          };
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

Finder _rich(String text) => find.textContaining(text, findRichText: true);

Widget _app({required bool dark}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: const InboxPage(),
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
    ChatSocketService.instance.disconnect();
    AuthSession.instance.accessToken = null;
    AuthSession.instance.user = null;
    EngagementStore.instance.clear();
    await CacheService.instance.clearAll();
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('Inbox ($theme): Activity opens what it is about, Requests approves, Messages opens the '
        'chat, a reply is sent (a failure keeps the text)', (tester) async {
      setBoardViewport(tester, height: 1000);
      await tester.pumpWidget(_app(dark: dark));
      await _settle(tester);

      // Activity: newest first, read as the account.
      expect(find.text('Inbox'), findsOneWidget);
      expect(_server.to('GET', '/api/notifications'), isNotEmpty);
      expect(_rich('Esi Owusu followed you.'), findsOneWidget);
      expect(_rich('Amara Osei liked your piece Bodies in Color.'), findsOneWidget);

      // The unread like: marked read and it opens the piece.
      await _tap(tester, _rich('Amara Osei liked your piece'));
      expect(_server.to('PATCH', '/api/notifications/n2/read'), hasLength(1));
      expect(_server.to('PATCH', '/api/notifications/n1/read'), isEmpty, reason: 'already read');
      expect(find.byType(AvailablePieceDetailPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(AvailablePieceDetailPage))).pop();
      await _settle(tester);

      // Requests: Daisy asked; Accept lets her follow.
      await _tap(tester, find.text('Requests'));
      expect(find.text('Daisy Smith'), findsOneWidget);
      expect(find.text('@daisy · 2h'), findsOneWidget);
      await _tap(tester, find.widgetWithText(StudioButton, 'Accept'));
      expect(_server.to('POST', '/api/users/follow-requests/daisy/accept'), hasLength(1));
      expect(find.text('Daisy Smith can follow you now'), findsOneWidget);
      expect(find.text('Daisy Smith'), findsNothing);
      await tester.pump(const Duration(seconds: 4));

      // Messages: the chat with Esi, unread.
      await _tap(tester, find.text('Messages'));
      expect(_server.to('GET', '/api/conversations'), isNotEmpty);
      expect(find.text('Esi Owusu'), findsOneWidget);
      expect(find.text('See you at the show'), findsOneWidget);
      await _tap(tester, find.text('Esi Owusu'));

      // The conversation: the thread loads; a send the server refuses keeps the text.
      expect(find.byType(ConversationThreadPage), findsOneWidget);
      expect(_server.to('GET', '/api/conversations/c1'), isNotEmpty);
      expect(find.text('See you at the show'), findsWidgets);
      final field = find.descendant(of: find.byType(ConversationThreadPage), matching: find.byType(TextField));
      _server.failSend = 1;
      await tester.enterText(field, 'On my way');
      await tester.pump();
      await _tap(tester, find.bySemanticsLabel('Send'));
      expect(find.text("Couldn't send. Try again."), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, 'On my way');
      await tester.pump(const Duration(seconds: 4));

      // Then it sends and shows in the thread.
      await _tap(tester, find.bySemanticsLabel('Send'));
      final sent = _server.to('POST', '/api/conversations/c1/messages').toList();
      expect(sent, hasLength(2));
      expect(sent.last.body, {'body': 'On my way'});
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(find.text('On my way'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
    });
  }
}
