import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/chat_message.dart';
import 'package:studio3/screens/new_message_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/inbox/chats_body.dart';
import 'package:studio3/widgets/studio/studio_avatar.dart';
import 'package:studio3/widgets/studio/studio_tab_bar.dart';
import 'package:studio3/utils/app_clock.dart';

import 'golden_harness.dart';

/// `NotifMessages`, `NewMessage` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 9).
final _now = DateTime(2026, 10, 27, 16, 40);
final _today = DateTime(_now.year, _now.month, _now.day);

ConversationSummary _c(String name, String preview, DateTime at, {bool unread = false}) =>
    ConversationSummary(
      id: name,
      otherPartyUsername: name.toLowerCase().replaceAll(' ', ''),
      otherPartyName: name,
      preview: preview,
      updatedAt: at,
      unread: unread,
      status: 'open',
    );

final _chats = [
  _c('Amara Osei', 'It comes unframed, but I can recommend a framer.',
      _today.add(const Duration(hours: 18, minutes: 30)).isAfter(_now)
          ? _now.subtract(const Duration(minutes: 5))
          : _today.add(const Duration(hours: 18, minutes: 30)),
      unread: true),
  _c('Cedric Okafor', 'Thanks for collecting! Shipping it Monday.',
      _now.subtract(const Duration(minutes: 30)), unread: true),
  _c('Daisy Smith', 'Would you be open to a commission?', _now.subtract(const Duration(days: 2))),
  _c('Jordan Lee', 'See you at the show.', _now.subtract(const Duration(days: 20))),
];

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: Scaffold(body: home),
);

void main() {
  // A fixed date, so "Today · 2:14 PM", "Mon" and the goldens don't move with the real clock.
  setUp(() => appNow = () => _now);
  tearDown(() => appNow = DateTime.now);
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });

  test('times: clock today, weekday this week, date before', () {
    final now = DateTime(2026, 10, 25, 20); // Sunday
    expect(conversationTime(DateTime(2026, 10, 25, 18, 30), now), '6:30 PM');
    expect(conversationTime(DateTime(2026, 10, 25, 0, 5), now), '12:05 AM');
    expect(conversationTime(DateTime(2026, 10, 21, 9), now), 'Wed');
    expect(conversationTime(DateTime(2026, 10, 2), now), 'Oct 2');
  });

  test('matches are highlighted wherever they appear', () {
    const match = TextStyle(fontWeight: FontWeight.w500);
    final span = highlightMatches('Shipping it Monday', 'ship', match);
    expect(span.children!.map((s) => (s as TextSpan).text), ['Ship', 'ping it Monday']);
    expect((span.children!.first as TextSpan).style, match);
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    testWidgets('rows: 56 avatars, unread Ink with a dot, read Tertiary (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await tester.pumpWidget(_app(ChatsBody(debugConversations: _chats), dark: dark));
      await tester.pump();
      expect(find.text('Search messages'), findsOneWidget);
      expect(tester.widgetList<StudioAvatar>(find.byType(StudioAvatar)).map((a) => a.size).toSet(), {56.0});
      RichText preview(String start) => tester.widget<RichText>(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().startsWith(start)),
      );
      expect(preview('Thanks for collecting').text.style!.color, c.textPrimary);
      expect(preview('See you at the show').text.style!.color, c.textTertiary);
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Unread'),
        findsNWidgets(2),
      );
      expect(find.text('Oct ${_now.subtract(const Duration(days: 20)).day}'), findsWidgets);
      expect(find.byType(Icon), findsNothing);
    });
  }

  testWidgets('search filters by name and message, highlighting the match', (tester) async {
    await tester.pumpWidget(_app(ChatsBody(debugConversations: _chats)));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'commission');
    await tester.pump();
    expect(find.byType(ConversationRow), findsOneWidget);
    expect(find.text('Daisy Smith', findRichText: true), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pump();
    expect(find.text('No conversations match “nobody”'), findsOneWidget);
  });

  testWidgets('pending message requests sit behind a row', (tester) async {
    await tester.pumpWidget(
      _app(
        ChatsBody(
          debugConversations: _chats,
          debugRequests: [_c('Kai Mori', 'Hi! Is this still available?', _now)],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Message requests'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Kai Mori'), findsNothing);
  });

  testWidgets('empty Messages says how to start one', (tester) async {
    await tester.pumpWidget(_app(const ChatsBody(debugConversations: [])));
    await tester.pump();
    expect(find.text('No messages yet'), findsOneWidget);
  });

  group('New message', () {
    const following = [
      MessageContact(username: 'amarasart', name: 'Amara Osei'),
      MessageContact(username: 'cedricokafor', name: 'Cedric Okafor'),
    ];
    const recent = [
      MessageContact(username: 'amarasart', name: 'Amara Osei'),
      MessageContact(username: 'jordanlee', name: 'Jordan Lee'),
    ];

    testWidgets('Cancel, title, search; Artists you follow then Recent (no repeats)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const NewMessagePage(recent: recent, debugFollowing: following),
        ),
      );
      await tester.pump();
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('New message'), findsOneWidget);
      expect(find.text('Search artists and collectors'), findsOneWidget);
      expect(find.text('ARTISTS YOU FOLLOW'), findsOneWidget);
      expect(find.text('RECENT'), findsOneWidget);
      expect(find.text('Amara Osei'), findsOneWidget);
      expect(find.text('@jordanlee'), findsOneWidget);
      expect(
        tester.widgetList<StudioAvatar>(find.byType(StudioAvatar)).map((a) => a.size).toSet(),
        {44.0},
      );
    });

    testWidgets('typing searches everyone', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: NewMessagePage(
            debugFollowing: following,
            debugSearch: (q) async => [MessageContact(username: 'sarahsunnyart', name: 'Sarah $q')],
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Osmei');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('Sarah Osmei'), findsOneWidget);
      expect(find.text('ARTISTS YOU FOLLOW'), findsNothing);
    });
  });

  group('goldens', () {
    final skip = Platform.environment['NEW_UI_GOLDENS'] != '1';
    testWidgets('NotifMessages', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: DefaultTabController(
            length: 3,
            initialIndex: 1,
            child: Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 56),
                    const StudioTabBar(
                      labels: ['Activity', 'Messages', 'Requests'],
                      counts: [null, 2, null],
                      ruleFullWidth: true,
                    ),
                    Expanded(child: ChatsBody(debugConversations: _chats)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/NotifMessages.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('NewMessage', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const NewMessagePage(
            recent: [
              MessageContact(username: 'jordanlee', name: 'Jordan Lee'),
              MessageContact(username: 'sarahsunnyart', name: 'Sarah Osmei'),
            ],
            debugFollowing: [
              MessageContact(username: 'amarasart', name: 'Amara Osei'),
              MessageContact(username: 'cedricokafor', name: 'Cedric Okafor'),
              MessageContact(username: 'daisysmith', name: 'Daisy Smith'),
            ],
          ),
        ),
      );
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/NewMessage.png'));
      await checkAcceptance(tester);
    }, skip: skip);
  });
}
