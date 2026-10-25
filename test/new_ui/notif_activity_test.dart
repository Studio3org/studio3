import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/notification_item.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/inbox/notifications_body.dart';
import 'package:studio3/widgets/studio/studio_avatar.dart';
import 'package:studio3/widgets/studio/studio_tab_bar.dart';

import 'golden_harness.dart';

/// `NotifActivity` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 9).
final _now = DateTime.now();

NotificationItem _n(
  String type, {
  String? actor,
  String? targetType,
  String? targetId,
  Map<String, dynamic> payload = const {},
  String? message,
  bool read = false,
  Duration ago = const Duration(minutes: 12),
}) => NotificationItem(
  id: '$type-${ago.inMinutes}',
  type: type,
  actorName: actor,
  actorUsername: actor?.toLowerCase().replaceAll(' ', ''),
  targetType: targetType,
  targetId: targetId,
  payload: payload,
  message: message,
  read: read,
  createdAt: _now.subtract(ago),
);

final _board = [
  _n(
    'outbid',
    targetType: 'piece',
    message: 'Someone bid \$3,700 on Bodies in Color. Bid \$3,800 to take it back.',
  ),
  _n(
    'purchase',
    actor: 'Jordan Lee',
    targetType: 'order',
    payload: {'pieceTitle': 'Companion Bloom', 'totalCents': 120000},
    ago: const Duration(minutes: 48),
  ),
  _n('follow', actor: 'Amara Osei', targetType: 'user', ago: const Duration(hours: 4), read: true),
  _n(
    'save',
    actor: 'Cedric Okafor',
    targetType: 'piece',
    targetId: 'p1',
    payload: {'pieceTitle': 'Portrait Dream'},
    ago: const Duration(hours: 6),
    read: true,
  ),
  _n(
    'order',
    targetType: 'order',
    message: 'Your order Bodies in Color has shipped. Arriving in 7 to 10 days.',
    ago: const Duration(days: 2),
    read: true,
  ),
  _n(
    'comment',
    actor: 'Sarah Osmei',
    targetType: 'post',
    targetId: 's1',
    payload: {'commentPreview': 'The underpainting is so warm'},
    ago: const Duration(days: 12),
    read: true,
  ),
];

Widget _host(List<NotificationItem> items, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: Scaffold(body: NotificationsBody(debugItems: items)),
);

String _line(WidgetTester tester, NotificationItem item) =>
    activityLine(item).map((s) => s.$1).join();

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });

  test('groups and Mono times: Today, This week (weekday), Earlier (date)', () {
    final now = DateTime(2026, 10, 23, 15); // Friday
    expect(activityGroup(DateTime(2026, 10, 23, 1), now), 'Today');
    expect(activityTime(DateTime(2026, 10, 23, 14, 48), now), '12m');
    expect(activityTime(DateTime(2026, 10, 23, 11), now), '4h');
    expect(activityGroup(DateTime(2026, 10, 20, 9), now), 'This week');
    expect(activityTime(DateTime(2026, 10, 20, 9), now), 'Tue');
    expect(activityGroup(DateTime(2026, 10, 11), now), 'Earlier');
    expect(activityTime(DateTime(2026, 10, 11), now), 'Oct 11');
  });

  test('lines name people and pieces, never "your item"', () {
    String line(NotificationItem n) => activityLine(n).map((s) => s.$1).join();
    expect(line(_board[1]), 'Jordan Lee collected Companion Bloom.');
    expect(line(_board[2]), 'Amara Osei followed you.');
    expect(line(_board[3]), 'Cedric Okafor saved your piece Portrait Dream.');
    expect(line(_board[5]), 'Sarah Osmei commented: “The underpainting is so warm”');
    expect(
      line(_n('purchase', payload: {'pieceTitle': 'Night Study'})),
      'Your order Night Study is confirmed.',
    );
    expect(line(_n('follow_request', actor: 'Kai')), 'Kai asked to follow you.');
    expect(activityLine(_board[1]).where((s) => s.$2).map((s) => s.$1), [
      'Jordan Lee',
      'Companion Bloom',
    ]);
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    testWidgets('rows: groups, unread 500 Ink, read grey, status word, Mono time (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_host(_board, dark: dark));
      await tester.pump();

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('EARLIER'), findsOneWidget);
      final label = tester.widget<Text>(find.text('TODAY'));
      expect((label.style!.fontSize, label.style!.color), (11, c.textTertiary));

      final outbid = tester.widget<Text>(find.text('Outbid'));
      expect(outbid.style!.color, c.alert);

      RichText rich(String start) => tester.widget<RichText>(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().startsWith(start)),
      );
      final unread = rich('Jordan Lee').text as TextSpan;
      expect((unread.style!.fontWeight, unread.style!.color), (FontWeight.w500, c.textPrimary));
      final read = rich('Amara Osei').text as TextSpan;
      expect((read.style!.fontWeight, read.style!.color), (FontWeight.w400, c.textSecondary));
      // The name inside a read row stays 500 Ink.
      final name = (read.children!.first as TextSpan).children!.first as TextSpan;
      expect((name.style!.fontWeight, name.style!.color), (FontWeight.w500, c.textPrimary));

      expect(tester.widget<Text>(find.text('12m')).style!.fontFamily, contains('Mono'));
      // People lead with a 40 avatar; a piece-led row has no avatar.
      expect(find.byType(StudioAvatar), findsNWidgets(3));
      expect(find.byType(Icon), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('an empty Activity tab says what will show', (tester) async {
    await tester.pumpWidget(_host(const []));
    await tester.pump();
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('tabs: equal 44 tabs with a Mono count, full-width rule', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: const StudioTabBar(
              labels: ['Activity', 'Messages', 'Requests'],
              counts: [null, 2, 0],
              ruleFullWidth: true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Messages'), findsOneWidget);
    final count = tester.widget<Text>(find.text('2'));
    expect(count.style!.fontSize, 11);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('golden: NotifActivity', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: DefaultTabController(
          length: 3,
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
                  Expanded(child: NotificationsBody(debugItems: _board)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/NotifActivity.png'));
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
