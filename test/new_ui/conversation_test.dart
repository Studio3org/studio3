import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/chat_message.dart';
import 'package:studio3/screens/conversation_thread_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/studio/studio_avatar.dart';

import 'golden_harness.dart';

/// `Conversation` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 9).
final _now = DateTime.now();
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

Widget _page({bool dark = false, List<ChatMessage>? messages}) => MaterialApp(
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
    debugMessages: messages ?? _thread,
    debugMyUsername: 'jordan',
  ),
);

Container _bubble(WidgetTester tester, String text) => tester.widget<Container>(
  find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
);

void main() {
  setUpAll(() async {
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
    await tester.pumpWidget(_page());
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/Conversation.png'));
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
