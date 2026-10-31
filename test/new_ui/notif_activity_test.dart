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
import 'package:studio3/utils/app_clock.dart';

import 'golden_harness.dart';

/// `NotifActivity` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 9).
final _now = DateTime(2026, 10, 27, 16, 40);

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
  // Bundled, as on the board (BACKEND_CHANGES B7).
  _n(
    'save',
    actor: 'Cedric Okafor',
    targetType: 'piece',
    targetId: 'p1',
    payload: {
      'pieceTitle': 'Portrait Dream',
      'count': 12,
      'actors': [
        {'name': 'Cedric Okafor'},
        {'name': 'Amara Osei'},
        {'name': 'Kai Mensah'},
      ],
    },
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
  // A fixed date, so "Today · 2:14 PM", "Mon" and the goldens don't move with the real clock.
  setUp(() => appNow = () => _now);
  tearDown(() => appNow = DateTime.now);
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
    expect(line(_board[3]), '12 people saved your piece Portrait Dream.');
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

  // BACKEND_CHANGES B7: saves and follows come bundled, one row per piece (or for follows) per day.
  test('bundled saves and follows: how many, and the newest name', () {
    String line(NotificationItem n) => activityLine(n).map((s) => s.$1).join();
    List<String> bold(NotificationItem n) => activityLine(n).where((s) => s.$2).map((s) => s.$1).toList();
    final follows = _n('follow', actor: 'Cedric Okafor', targetType: 'user', payload: {'count': 5});
    expect(line(follows), 'Cedric Okafor and 4 others followed you.');
    expect(bold(follows), ['Cedric Okafor']);
    expect(line(_n('follow', actor: 'Kai', targetType: 'user', payload: {'count': 2})), 'Kai and 1 other followed you.');
    expect(line(_n('follow', actor: 'Kai', targetType: 'user', payload: {'count': 1})), 'Kai followed you.');
    final saves = _n('save', actor: 'Kai', targetType: 'piece', targetId: 'p1', payload: {'count': 3});
    expect(line(saves), '3 people saved your piece.');
    expect(bold(saves), ['3 people']);
    expect(line(_n('save', actor: 'Kai', targetType: 'post', targetId: 's1', payload: {'count': 2})),
        '2 people saved your Scene.');
    // Accepting your request is never bundled.
    expect(line(_n('follow', actor: 'Kai', payload: {'accepted': true, 'count': 3})), 'Kai accepted your follow request.');
  });

  testWidgets('a bundle leads with up to three faces in a 48 by 40 stack', (tester) async {
    final bundle = _n(
      'follow',
      actor: 'Cedric Okafor',
      targetType: 'user',
      payload: {
        'count': 5,
        'actors': [
          {'name': 'Cedric Okafor', 'profilePhotoUrl': null},
          {'name': 'Amara Osei', 'profilePhotoUrl': null},
          {'name': 'Kai', 'profilePhotoUrl': null},
        ],
      },
    );
    await tester.pumpWidget(_host([bundle, _n('follow', actor: 'Solo', targetType: 'user', ago: const Duration(hours: 1))]));
    await tester.pump();
    final small = find.byWidgetPredicate((w) => w is StudioAvatar && w.size == 28);
    expect(small, findsNWidgets(3));
    final avatars = tester.widgetList<StudioAvatar>(small).toList();
    expect(avatars.every((a) => a.ringWidth == 2 && a.ringInside), isTrue);
    final tops = [for (final e in small.evaluate()) tester.getTopLeft(find.byWidget(e.widget)).dy];
    expect(tops[1] - tops[0], 12);
    expect(tops[2], tops[0]);
    final lefts = [for (final e in small.evaluate()) tester.getTopLeft(find.byWidget(e.widget)).dx];
    expect([lefts[1] - lefts[0], lefts[2] - lefts[0]], [12, 24]);
    // A single follow keeps its one 40 photo.
    expect(find.byType(StudioAvatar), findsNWidgets(4));
    expect(find.byWidgetPredicate((w) => w is StudioAvatar && w.size == 40), findsOneWidget);
  });

  // BACKEND_CHANGES B6: the server sends the piece's title and picture with the notification.
  test('the title and picture sent with a notification are used; a Scene keeps its own', () async {
    String line(NotificationItem n) => activityLine(n).map((s) => s.$1).join();
    const planes = {
      'pieceId': 'p9',
      'pieceTitle': 'Paper Planes III',
      'pieceImageUrl': 'https://cdn.test/planes.png',
    };
    final like = _n('like', actor: 'Amara Osei', targetType: 'piece', targetId: 'p9', payload: planes);
    expect(line(like), 'Amara Osei liked your piece Paper Planes III.');
    // Given, so nothing is fetched (the test has no server: a fetch would come back null).
    expect(await ActivityThumbs.forItem(like), 'https://cdn.test/planes.png');

    final order = _n('purchase', targetType: 'order', targetId: 'o9', payload: planes);
    expect(line(order), 'Your order Paper Planes III is confirmed.');
    expect(await ActivityThumbs.forItem(order), 'https://cdn.test/planes.png');

    // A Scene: its linked piece comes along, but the row names and shows the Scene.
    final scene = _n(
      'save',
      actor: 'Kai',
      targetType: 'post',
      targetId: 's9',
      payload: {...planes, 'postImageUrl': 'https://cdn.test/scene.jpg'},
    );
    expect(line(scene), 'Kai saved your Scene.');
    expect(await ActivityThumbs.forItem(scene), 'https://cdn.test/scene.jpg');
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
      // People lead with a 40 avatar (a bundle with a stack of 28s); a piece-led row has none.
      expect(find.byWidgetPredicate((w) => w is StudioAvatar && w.size == 40), findsNWidgets(2));
      expect(find.byWidgetPredicate((w) => w is StudioAvatar && w.size == 28), findsNWidgets(3));
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
    await checkAcceptance(tester);
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
