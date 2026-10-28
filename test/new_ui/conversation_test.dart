import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/chat_message.dart';
import 'package:studio3/screens/conversation_thread_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/studio/studio_avatar.dart';
import 'package:studio3/utils/app_clock.dart';

import 'golden_harness.dart';

/// `Conversation` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 9).
final _now = DateTime(2026, 10, 27, 16, 40);
final _start = DateTime(_now.year, _now.month, _now.day, 14, 14).isAfter(_now)
    ? _now.subtract(const Duration(minutes: 30))
    : DateTime(_now.year, _now.month, _now.day, 14, 14);

ChatMessage _m(String id, String who, String body, int minute) => ChatMessage(
  id: id,
  body: body,
  senderUsername: who,
  createdAt: _start.add(Duration(minutes: minute)),
);

final _thread = [
  _m('1', 'jordan', 'Hi! Does Bodies in Color come framed?', 0),
  _m('2', 'amarasart',
      'Hi Jordan, thanks for asking. It comes unframed, but I can recommend a framer in Dallas.', 1),
  _m('3', 'amarasart', 'Happy to share a studio shot too.', 2),
  _m('4', 'jordan', 'That would be great. Could I see it in person before I collect?', 3),
];

/// The piece the board's chat is about (B9): Amara's, so Jordan asked.
const _bodies = ChatPiece(
  id: 'p1',
  title: 'Bodies in Color',
  priceCents: 350000,
  artistUsername: 'amarasart',
);

Widget _page({bool dark = false, List<ChatMessage>? messages, ChatPiece? piece}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: ConversationThreadPage(
    conversationId: 'c1',
    otherPartyUsername: 'amarasart',
    otherPartyName: 'Amara Osei',
    otherPartyAvatarUrl: null,
    aboutPiece: piece,
    debugMessages: messages ?? _thread,
    debugMyUsername: 'jordan',
  ),
);

/// Starting a chat from a piece page, against a fake server (BACKEND_CHANGES B9).
class _Server implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body})>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path, body: options.data));
    Object json;
    switch ('${options.method} $path') {
      case 'GET /api/conversations/with/amarasart':
        json = {'success': true, 'data': {'conversation': null}};
      case 'POST /api/conversations':
        json = {'success': true, 'data': {'id': 'c9', 'reused': false, 'status': 'open'}};
      case 'GET /api/conversations/c9':
        json = {
          'success': true,
          'data': {
            'id': 'c9',
            'status': 'open',
            'otherParty': {'username': 'amarasart', 'name': 'Amara Osei'},
            'piece': {
              'id': 'p1',
              'title': 'Bodies in Color',
              'priceCents': 350000,
              'artistUsername': 'amarasart',
            },
            'messages': {
              'items': [
                {
                  'id': 'm1',
                  'body': 'Is it still available?',
                  'sender': {'username': 'jordan', 'name': 'Jordan Lee'},
                  'createdAt': _start.toUtc().toIso8601String(),
                },
              ],
              'nextCursor': null,
            },
          },
        };
      default:
        json = {'success': true, 'data': {}};
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

Container _bubble(WidgetTester tester, String text) => tester.widget<Container>(
  find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
);

void main() {
  // A fixed date, so "Today · 2:14 PM", "Mon" and the goldens don't move with the real clock.
  setUp(() => appNow = () => _now);
  tearDown(() => appNow = DateTime.now);
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '.',
    );
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });

  test('day lines: Today / Yesterday / date, with the time', () {
    final now = DateTime(2026, 10, 25, 18);
    expect(dayLine(DateTime(2026, 10, 25, 14, 14), now), 'Today · 2:14 PM');
    expect(dayLine(DateTime(2026, 10, 24, 9, 2), now), 'Yesterday · 9:02 AM');
    expect(dayLine(DateTime(2026, 10, 12, 16, 35), now), 'Oct 12 · 4:35 PM');
    expect(dayLine(DateTime(2025, 3, 1, 8), now), 'Mar 1, 2025 · 8:00 AM');
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    testWidgets('header, day line, bubbles in runs, composer (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_page(dark: dark));
      await tester.pump();

      // Header: 34 avatar, name, handle, more.
      expect(tester.widget<StudioAvatar>(find.byType(StudioAvatar)).size, 34);
      expect(find.text('Amara Osei'), findsOneWidget);
      expect(find.text('@amarasart'), findsOneWidget);
      expect(find.bySemanticsLabel('Conversation options'), findsOneWidget);
      expect(find.textContaining('Today · '), findsOneWidget);

      // Sent: Ink with the tail bottom-right. Received run: Surface; only the last has a tail.
      final sent = _bubble(tester, 'Hi! Does Bodies in Color come framed?');
      final sentDeco = sent.decoration! as BoxDecoration;
      expect(sentDeco.color, c.buttonFill);
      expect((sentDeco.borderRadius! as BorderRadius).bottomRight, const Radius.circular(6));
      final first = _bubble(tester, _thread[1].body!).decoration! as BoxDecoration;
      final last = _bubble(tester, _thread[2].body!).decoration! as BoxDecoration;
      expect(first.color, c.surface);
      expect((first.borderRadius! as BorderRadius).bottomLeft, const Radius.circular(18));
      expect((last.borderRadius! as BorderRadius).bottomLeft, const Radius.circular(6));

      // Composer: Send grey until there is text.
      Container send() => tester.widget<Container>(
        find.descendant(of: find.bySemanticsLabel('Send'), matching: find.byType(Container)).first,
      );
      expect((send().decoration! as BoxDecoration).color, c.line);
      await tester.enterText(find.byType(TextField), 'See you Saturday');
      await tester.pump();
      expect((send().decoration! as BoxDecoration).color, c.buttonFill);
      expect(find.byType(Icon), findsNothing);
    });
  }

  // BACKEND_CHANGES B9.
  group('About this piece', () {
    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('the card under the first day line, on the side of who asked (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        setBoardViewport(tester);
        await tester.pumpWidget(_page(dark: dark, piece: _bodies));
        await tester.pump();
        final card = find.byType(ChatPieceCard);
        expect(card, findsOneWidget);
        expect(find.text('About this piece'), findsOneWidget);
        expect(find.text('\$3,500'), findsOneWidget);
        expect(tester.getSize(card).width, 236);
        // Under the day line, above the first message, on Jordan's (right) side.
        final day = tester.getBottomLeft(find.text('Today · 2:14 PM')).dy;
        final first = tester.getTopLeft(find.text('Hi! Does Bodies in Color come framed?')).dy;
        expect(tester.getTopLeft(card).dy, greaterThan(day));
        expect(tester.getBottomLeft(card).dy, lessThan(first));
        expect(tester.getTopRight(card).dx, closeTo(390 - 16, 0.5));
        final box = tester.widget<Container>(
          find.descendant(of: card, matching: find.byType(Container)).first,
        );
        final decoration = box.decoration! as BoxDecoration;
        expect(decoration.color, c.card);
        expect(decoration.borderRadius, BorderRadius.circular(16));
        expect((decoration.border! as Border).top.color, c.line);
        expect(tester.widget<Text>(find.text('About this piece')).style!.fontSize, 12);
      });
    }

    testWidgets('your own piece: the card sits on their side; no price once it is sold', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _page(piece: const ChatPiece(id: 'p2', title: 'Tide', artistUsername: 'jordan')),
      );
      await tester.pump();
      expect(tester.getTopLeft(find.byType(ChatPieceCard)).dx, closeTo(16, 0.5));
      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets('no piece: no card', (tester) async {
      await tester.pumpWidget(_page());
      await tester.pump();
      expect(find.byType(ChatPieceCard), findsNothing);
    });

    testWidgets('started from a piece page: the card shows, and the first message sends the piece', (
      tester,
    ) async {
      Future<void> settle() async {
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      setBoardViewport(tester);
      final server = _Server();
      ApiClient.instance.debugUseAdapter(server);
      final wasToken = AuthSession.instance.accessToken;
      AuthSession.instance.accessToken = 'token';
      addTearDown(() => AuthSession.instance.accessToken = wasToken);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ConversationThreadPage(
            otherPartyUsername: 'amarasart',
            otherPartyName: 'Amara Osei',
            otherPartyAvatarUrl: null,
            aboutPiece: _bodies,
            debugMyUsername: 'jordan',
          ),
        ),
      );
      await settle();
      // A new chat: the person, then the piece it is about.
      expect(find.text('Message Amara Osei'), findsOneWidget);
      expect(find.byType(ChatPieceCard), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Is it still available?');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send'));
      await settle();
      final start = server.requests.firstWhere((r) => r.method == 'POST' && r.path == '/api/conversations');
      expect(start.body, {'username': 'amarasart', 'message': 'Is it still available?', 'pieceId': 'p1'});
      // The thread, with the card the server keeps for it.
      expect(find.text('Is it still available?'), findsOneWidget);
      expect(find.byType(ChatPieceCard), findsOneWidget);
      expect(find.text('Message Amara Osei'), findsNothing);
    });

    test('the piece comes with the list and the thread, and not at all for other chats', () {
      final row = ConversationSummary.fromJson({
        'id': 'c1',
        'updatedAt': _now.toIso8601String(),
        'piece': {'id': 'p1', 'title': 'Bodies in Color', 'imageUrl': 'https://cdn.test/b.png'},
      });
      expect(row.piece!.title, 'Bodies in Color');
      expect(row.piece!.imageUrl, 'https://cdn.test/b.png');
      expect(ConversationSummary.fromJson({'id': 'c2', 'piece': null}).piece, isNull);
      expect(ChatThread.fromJson({'id': 'c1', 'piece': {'id': 'p1', 'title': 'X'}}).piece!.id, 'p1');
    });
  });

  testWidgets('a new chat shows the person until the first message', (tester) async {
    await tester.pumpWidget(_page(messages: const []));
    await tester.pump();
    expect(find.text('Message Amara Osei'), findsOneWidget);
    expect(tester.widgetList<StudioAvatar>(find.byType(StudioAvatar)).map((a) => a.size), [
      34,
      96,
    ]);
  });

  testWidgets('golden: Conversation', (tester) async {
    setBoardViewport(tester);
    // The board's chat started from Bodies in Color (B9).
    await tester.pumpWidget(_page(piece: _bodies));
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/Conversation.png'));
    await checkAcceptance(tester);
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
