import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/chat_message.dart';
import 'package:studio3/models/follow_request.dart';
import 'package:studio3/models/user_profile.dart';
import 'package:studio3/screens/conversation_thread_page.dart';
import 'package:studio3/screens/notification_preferences_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/main_nav_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/accept_decline_buttons.dart';
import 'package:studio3/widgets/inbox/chats_body.dart';
import 'package:studio3/widgets/inbox/follow_requests_body.dart';
import 'package:studio3/widgets/inbox/notifications_body.dart';
import 'package:studio3/widgets/studio/studio.dart';
import 'package:studio3/utils/app_clock.dart';

import 'golden_harness.dart';

/// `ConvMenu`, `NotifEmptyActivity`, `NotifEmptyMessages`, `NotifSettings` and the
/// follow requests tab (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 9).
class _FakeServer implements HttpClientAdapter {
  final requests = <({String method, String path, Map<String, dynamic>? body})>[];

  /// The next mute or preferences change fails (500).
  var fail = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : null;
    requests.add((method: options.method, path: options.uri.path, body: body));
    if (fail > 0) {
      fail--;
      return ResponseBody.fromString(
        jsonEncode({'success': false, 'message': 'down'}),
        500,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    final Object? muteAsked = options.uri.path.endsWith('/mute') ? (body?['muted']) : null;
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {'notificationPreferences': <String, dynamic>{}, 'muted': ?muteAsked},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

final _now = DateTime(2026, 10, 27, 16, 40);
final _start = _now.subtract(const Duration(minutes: 20));

final _thread = [
  ChatMessage(
    id: '1',
    body: 'Hi! Does Bodies in Color come framed?',
    senderUsername: 'jordan',
    createdAt: _start,
  ),
  ChatMessage(
    id: '2',
    body: 'It comes unframed, but I can recommend a framer.',
    senderUsername: 'amarasart',
    createdAt: _start.add(const Duration(minutes: 1)),
  ),
];

Widget _conversation({bool dark = false}) => _app(
  const ConversationThreadPage(
    conversationId: 'c1',
    otherPartyUsername: 'amarasart',
    otherPartyName: 'Amara Osei',
    otherPartyAvatarUrl: null,
    debugMessages: [],
    debugMyUsername: 'jordan',
  ),
  dark: dark,
);

Future<void> _openMenu(WidgetTester tester, {bool dark = false, bool withThread = false}) async {
  await tester.pumpWidget(
    withThread
        ? _app(
            ConversationThreadPage(
              conversationId: 'c1',
              otherPartyUsername: 'amarasart',
              otherPartyName: 'Amara Osei',
              otherPartyAvatarUrl: null,
              debugMessages: _thread,
              debugMyUsername: 'jordan',
            ),
            dark: dark,
          )
        : _conversation(dark: dark),
  );
  await tester.pump();
  await tester.tap(find.bySemanticsLabel('Conversation options'));
  await tester.pumpAndSettle();
}

const _prefs = NotificationPreferences(
  push: {'save': false, 'follow': true, 'like': true, 'comment': true, 'purchase': true},
);

void main() {
  // A fixed date, so "Today · 2:14 PM", "Mon" and the goldens don't move with the real clock.
  setUp(() => appNow = () => _now);
  tearDown(() => appNow = DateTime.now);
  late _FakeServer server;
  String? wasToken;

  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });
  setUp(() {
    server = _FakeServer();
    ApiClient.instance.debugUseAdapter(server);
    wasToken = AuthSession.instance.accessToken;
    AuthSession.instance.accessToken = 'token';
  });
  tearDown(() => AuthSession.instance.accessToken = wasToken);

  group('ConvMenu', () {
    for (final dark in [false, true]) {
      testWidgets('person, then Mute, View profile, Block and Report in Ink (${dark ? 'dark' : 'light'})',
          (tester) async {
        setBoardViewport(tester);
        await _openMenu(tester, dark: dark);
        final c = dark ? StudioColors.dark : StudioColors.light;
        final person = tester.widget<StudioActionSheetPerson>(
          find.byType(StudioActionSheetPerson),
        );
        expect(person.name, 'Amara Osei');
        expect(person.handle, '@amarasart');
        expect(
          tester.widgetList<StudioAvatar>(find.byType(StudioAvatar)).map((a) => a.size),
          contains(40),
        );
        final rows = tester.widgetList<StudioActionRow>(find.byType(StudioActionRow)).toList();
        expect(rows.map((r) => r.title), ['Mute notifications', 'View profile', 'Block Amara Osei', 'Report']);
        expect(rows.map((r) => r.subtitle), [
          'You will still get messages, just no alerts',
          null,
          'They will not be able to message you',
          'Tell Studio 3 about a message or this person',
        ]);
        expect(rows.first.icon, StudioIcons.bellOff);
        expect(
          tester.widget<StudioSwitch>(
            find.byWidgetPredicate((w) => w is StudioSwitch && w.semanticLabel == 'Mute notifications'),
          ).value,
          isFalse,
        );
        for (final icon in tester.widgetList<StudioIcon>(
          find.descendant(of: find.byType(StudioActionRow), matching: find.byType(StudioIcon)),
        )) {
          expect(icon.color, c.textPrimary);
        }
      });
    }

    // BACKEND_CHANGES B8.
    testWidgets('Mute notifications: the switch mutes this chat on the server, and unmutes', (tester) async {
      setBoardViewport(tester);
      await _openMenu(tester);
      StudioSwitch mute() => tester.widget<StudioSwitch>(
        find.byWidgetPredicate((w) => w is StudioSwitch && w.semanticLabel == 'Mute notifications'),
      );
      Future<void> tapMute() async {
        await tester.runAsync(() async {
          await tester.tap(find.text('Mute notifications'));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();
      }

      await tapMute();
      expect(server.requests.last.method, 'PATCH');
      expect(server.requests.last.path, '/api/conversations/c1/mute');
      expect(server.requests.last.body, {'muted': true});
      expect(mute().value, isTrue);
      await tapMute();
      expect(server.requests.last.body, {'muted': false});
      expect(mute().value, isFalse);

      // Opened again, the menu shows what was kept.
      await tapMute();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Conversation options'));
      await tester.pumpAndSettle();
      expect(mute().value, isTrue);
    });

    testWidgets('Mute notifications: a refused change goes back and says so', (tester) async {
      setBoardViewport(tester);
      await _openMenu(tester);
      server.fail = 1;
      await tester.runAsync(() async {
        await tester.tap(find.text('Mute notifications'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(
        tester.widget<StudioSwitch>(
          find.byWidgetPredicate((w) => w is StudioSwitch && w.semanticLabel == 'Mute notifications'),
        ).value,
        isFalse,
      );
      expect(find.text('Could not save. Try again.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Block asks first; Cancel blocks no one', (tester) async {
      setBoardViewport(tester);
      await _openMenu(tester);
      await tester.tap(find.text('Block Amara Osei'));
      await tester.pumpAndSettle();
      expect(find.text('Block Amara Osei?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Block Amara Osei?'), findsNothing);
      expect(server.requests, isEmpty);
    });

    testWidgets('Report: the conversation reasons, then Send report files it', (tester) async {
      setBoardViewport(tester);
      await _openMenu(tester);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.text('Report Amara Osei'), findsOneWidget);
      expect(
        tester.widgetList<StudioListRow>(find.byType(StudioListRow)).map((r) => r.title),
        [
          'Spam or scam',
          'Harassment, hate, or bullying',
          'Nudity, violence, or other objectionable content',
          'Something else',
        ],
      );
      StudioButton send() => tester.widget<StudioButton>(
        find.widgetWithText(StudioButton, 'Send report'),
      );
      expect(send().onPressed, isNull);
      await tester.tap(find.text('Spam or scam'));
      await tester.pump();
      expect(send().onPressed, isNotNull);
      await tester.runAsync(() async {
        await tester.tap(find.text('Send report'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      final report = server.requests.single;
      expect(report.path, '/api/users/amarasart/report');
      expect(report.body!['reason'], 'spam');
      expect(find.text('Thanks. We will review it within 24 hours.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });

  group('empty states', () {
    testWidgets('Activity: Nothing here yet, Explore art opens Explore', (tester) async {
      var explored = 0;
      MainNavService.instance.register(goHome: () {}, goSaved: () {}, goExplore: () => explored++);
      addTearDown(MainNavService.instance.unregister);
      await tester.pumpWidget(_app(const Scaffold(body: NotificationsBody(debugItems: []))));
      await tester.pump();
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(
        find.text('Follow artists and save pieces. News about them shows up here.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Explore art'));
      expect(explored, 1);
    });

    testWidgets('Messages: no search until a chat; Start a message opens New message', (
      tester,
    ) async {
      var started = 0;
      await tester.pumpWidget(
        _app(Scaffold(body: ChatsBody(debugConversations: const [], onNewMessage: () => started++))),
      );
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('No messages yet'), findsOneWidget);
      expect(
        find.text('Message an artist from their profile or from a piece you like.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Start a message'));
      expect(started, 1);

      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ChatsBody(
              debugConversations: [
                ConversationSummary(
                  id: 'c1',
                  otherPartyUsername: 'amarasart',
                  otherPartyName: 'Amara Osei',
                  preview: 'Hi',
                  updatedAt: _now,
                  unread: false,
                  status: 'open',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('NotifSettings', () {
    for (final dark in [false, true]) {
      testWidgets('card, Mono sections, switch rows (${dark ? 'dark' : 'light'})', (tester) async {
        setBoardViewport(tester, height: 1200);
        await tester.pumpWidget(
          _app(
            const NotificationPreferencesPage(
              debugPrefs: _prefs,
              debugHasPosted: true,
              debugPushAllowed: true,
            ),
            dark: dark,
          ),
        );
        await tester.pump();
        final c = dark ? StudioColors.dark : StudioColors.light;
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Push notifications are on'), findsOneWidget);
        expect(find.text('Open'), findsOneWidget);
        for (final label in ['COLLECTING', 'FOLLOWING', 'YOUR WORK', 'MESSAGES']) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.style!.fontSize, 11);
          expect(text.style!.color, c.textTertiary);
        }
        final title = tester.widget<Text>(find.text('Auctions'));
        expect(title.style!.fontSize, 15);
        expect(title.style!.fontWeight, StudioType.medium);
        final switches = {
          for (final s in tester.widgetList<StudioSwitch>(find.byType(StudioSwitch)))
            s.semanticLabel: s.value,
        };
        expect(switches, {
          'Auctions': true,
          'Saved pieces': true,
          'Orders and shipping': true,
          'Artists you follow': true,
          'Events': true,
          'Bids and sales': true,
          'Saves and follows': false,
          'New messages': true,
        });
      });
    }

    // BACKEND_CHANGES B12: in the board's places, each turning its types off together.
    testWidgets('Saved pieces under Collecting, Artists you follow first under Following', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1300);
      await tester.pumpWidget(
        _app(
          const NotificationPreferencesPage(
            debugPrefs: _prefs,
            debugHasPosted: true,
            debugPushAllowed: true,
          ),
        ),
      );
      await tester.pump();
      double y(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(y('Auctions') < y('Saved pieces') && y('Saved pieces') < y('Orders and shipping'), isTrue);
      expect(y('FOLLOWING') < y('Artists you follow') && y('Artists you follow') < y('Events'), isTrue);
      expect(find.text('Now listed, price changes, auctions starting.'), findsOneWidget);
      expect(find.text('New pieces and Scenes.'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byWidgetPredicate(
          (w) => w is StudioSwitch && w.semanticLabel == 'Saved pieces',
        ));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(server.requests.single.body!['push'], {
        'saved_piece_listed': false,
        'saved_piece_price': false,
        'saved_piece_auction': false,
      });
    });

    testWidgets('Your work hides for people who have not posted; push off says so', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1200);
      await tester.pumpWidget(
        _app(
          const NotificationPreferencesPage(
            debugPrefs: _prefs,
            debugHasPosted: false,
            debugPushAllowed: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('YOUR WORK'), findsNothing);
      expect(find.text('Saves and follows'), findsNothing);
      expect(find.text('Push notifications are off'), findsOneWidget);
    });

    // BACKEND_CHANGES B7.
    testWidgets('Saves and follows: Daily summary by default, As they happen saves, off hides the choice', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1300);
      await tester.pumpWidget(
        _app(
          const NotificationPreferencesPage(
            debugPrefs: NotificationPreferences(),
            debugHasPosted: true,
            debugPushAllowed: true,
          ),
        ),
      );
      await tester.pump();
      final c = StudioColors.light;
      Semantics option(String label) => tester.widget<Semantics>(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label),
      );
      expect(option('Daily summary').properties.checked, isTrue);
      expect(option('As they happen').properties.checked, isFalse);
      expect(find.text('One notification a day with everything grouped'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Daily summary')).style!.color, c.textPrimary);
      expect(tester.widget<Text>(find.text('Daily summary')).style!.fontWeight, StudioType.medium);
      expect(tester.widget<Text>(find.text('As they happen')).style!.color, c.textTertiary);
      expect(tester.getSize(find.ancestor(of: find.text('As they happen'), matching: find.byType(GestureDetector)).first).height,
          greaterThanOrEqualTo(44));

      await tester.runAsync(() async {
        await tester.tap(find.text('As they happen'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(server.requests.single.body, {'savesAndFollowsMode': 'instant'});
      expect(option('As they happen').properties.checked, isTrue);
      expect(option('Daily summary').properties.checked, isFalse);

      // Refused: back to what it was.
      server.fail = 1;
      await tester.runAsync(() async {
        await tester.tap(find.text('Daily summary'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(option('As they happen').properties.checked, isTrue);
      await tester.pump(const Duration(seconds: 3));

      // Saves and follows off: no choice to make.
      await tester.runAsync(() async {
        await tester.tap(find.byWidgetPredicate(
          (w) => w is StudioSwitch && w.semanticLabel == 'Saves and follows',
        ));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(find.text('Daily summary'), findsNothing);
    });

    testWidgets('a switch writes every server type in its group', (tester) async {
      setBoardViewport(tester, height: 1200);
      await tester.pumpWidget(
        _app(
          const NotificationPreferencesPage(
            debugPrefs: _prefs,
            debugHasPosted: true,
            debugPushAllowed: true,
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.byWidgetPredicate(
          (w) => w is StudioSwitch && w.semanticLabel == 'Saves and follows',
        ));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      final patch = server.requests.single;
      expect(patch.method, 'PATCH');
      expect(patch.path, '/api/user/me/notification-preferences');
      expect(patch.body!['push'], {
        'save': true,
        'follow': true,
        'follow_request': true,
        'like': true,
        'comment': true,
      });
      final on = tester.widget<StudioSwitch>(find.byWidgetPredicate(
        (w) => w is StudioSwitch && w.semanticLabel == 'Saves and follows',
      ));
      expect(on.value, isTrue);
    });
  });

  group('follow requests (no board)', () {
    final requests = [
      FollowRequest(
        username: 'amarasart',
        name: 'Amara Osei',
        requestedAt: _now.subtract(const Duration(hours: 4)),
      ),
    ];
    for (final dark in [false, true]) {
      testWidgets('row and Decline / Accept (${dark ? 'dark' : 'light'})', (tester) async {
        await tester.pumpWidget(
          _app(Scaffold(body: FollowRequestsBody(debugRequests: requests)), dark: dark),
        );
        await tester.pump();
        expect(find.text('Amara Osei'), findsOneWidget);
        expect(find.text('@amarasart · 4h'), findsOneWidget);
        expect(tester.widget<StudioAvatar>(find.byType(StudioAvatar)).size, 40);
        final buttons = tester
            .widgetList<StudioButton>(
              find.descendant(
                of: find.byType(AcceptDeclineButtons),
                matching: find.byType(StudioButton),
              ),
            )
            .toList();
        expect(buttons.map((b) => b.label), ['Decline', 'Accept']);
        expect(buttons.map((b) => b.variant), everyElement(StudioButtonVariant.small));
        expect(buttons.map((b) => b.filled), [false, true]);
        expect(find.byType(Icon), findsNothing);
      });
    }

    testWidgets('empty', (tester) async {
      await tester.pumpWidget(
        _app(const Scaffold(body: FollowRequestsBody(debugRequests: []))),
      );
      await tester.pump();
      expect(find.text('No follow requests'), findsOneWidget);
    });
  });

  group('goldens', () {
    final skip = Platform.environment['NEW_UI_GOLDENS'] != '1';
    Widget inbox(int tab, Widget body, {Widget? action}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: DefaultTabController(
        length: 2,
        initialIndex: tab,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Builder(
                  builder: (context) => StudioTopBar(
                    context: context,
                    title: 'Inbox',
                    onBack: () {},
                    actions: [?action],
                  ),
                ),
                const StudioTabBar(labels: ['Activity', 'Messages'], ruleFullWidth: true),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );

    testWidgets('ConvMenu', (tester) async {
      setBoardViewport(tester);
      await _openMenu(tester, withThread: true);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/ConvMenu.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('NotifEmptyActivity', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(inbox(0, const NotificationsBody(debugItems: [])));
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/NotifEmptyActivity.png'),
      );
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('NotifEmptyMessages', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        inbox(
          1,
          ChatsBody(debugConversations: const [], onNewMessage: () {}),
          action: const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(child: StudioIcon(StudioIcons.newFolder, size: 24)),
            ),
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/NotifEmptyMessages.png'),
      );
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('NotifSettings', (tester) async {
      setBoardViewport(tester, height: 1340);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        _app(
          const NotificationPreferencesPage(
            debugPrefs: NotificationPreferences(),
            debugHasPosted: true,
            debugPushAllowed: true,
          ),
        ),
      );
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/NotifSettings.png'));
      await checkAcceptance(tester);
      debugDefaultTargetPlatformOverride = null;
    }, skip: skip);
  });
}
