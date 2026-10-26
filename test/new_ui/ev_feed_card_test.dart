import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/home_feed/feed_event_card.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// The home feed's event card: `Main` (with a lineup) and `EventNoArtists` (without),
/// docs/new-ui/NEW_UI_EXECUTION_PLAN.md section 17.1.
final _now = DateTime(2037, 11, 18, 10);

StudioEvent _e(
  String id, {
  required DateTime start,
  String title = 'Studio Night',
  List<EventPerson> artists = const [],
  String status = 'published',
}) => StudioEvent(
  id: id,
  title: title,
  startsAt: start,
  endsAt: start.add(const Duration(hours: 3)),
  status: status,
  venueName: 'The Space',
  description: 'Five painters, one long table, new work for sale.\nDoors at eight.',
  artists: artists,
);

const _artists = [
  EventPerson(username: 'amara', name: 'Amara Osei'),
  EventPerson(username: 'cedric', name: 'Cedric Okafor'),
  EventPerson(username: 'daisy', name: 'Daisy Smith'),
  EventPerson(username: 'eli', name: 'Eli'),
  EventPerson(username: 'fay', name: 'Fay'),
];

Widget _app(Widget child, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: Builder(
    builder: (context) => Scaffold(
      backgroundColor: context.studio.background,
      body: Padding(padding: const EdgeInsets.only(top: 16), child: child),
    ),
  ),
);

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('ev_feed').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  test('which event: next two weeks, followed first, then the soonest', () {
    final soon = _e('soon', start: DateTime(2037, 11, 20, 19));
    final later = _e('later', start: DateTime(2037, 11, 25, 19));
    final tooFar = _e('far', start: DateTime(2037, 12, 10, 19));
    final cancelled = _e('x', start: DateTime(2037, 11, 19, 19), status: 'cancelled');
    expect(pickFeedEvent(EventBrowse(upcoming: [later, tooFar, soon, cancelled]), _now)?.id, 'soon');
    expect(pickFeedEvent(EventBrowse(upcoming: [soon], following: [later]), _now)?.id, 'later');
    expect(pickFeedEvent(EventBrowse(upcoming: [tooFar, cancelled]), _now), isNull);
    expect(pickFeedEvent(const EventBrowse(), _now), isNull);
  });

  test('where it goes: after the third row, never beside a series row', () {
    expect(feedEventSlot([false, false, false, false, false]), 3);
    expect(feedEventSlot([false, false, true, false, false]), 4);
    expect(feedEventSlot([false, false, false, true, false, false]), 5);
    expect(feedEventSlot([false, false]), 2);
    expect(feedEventSlot([false, true]), -1);
    expect(feedEventSlot(const []), -1);
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('no lineup: EVENT tag, Mono date, name, Price and Where, Get tickets ($theme)', (tester) async {
      setBoardViewport(tester, height: 240);
      var tickets = 0;
      var opened = 0;
      await tester.pumpWidget(
        _app(
          FeedEventCard(
            event: _e('a', start: DateTime(2037, 11, 21, 20)),
            onOpen: () => opened++,
            onGetTickets: () => tickets++,
            onArtist: (_) {},
          ),
          dark: dark,
        ),
      );
      final card = tester.widget<Container>(
        find.descendant(of: find.byType(FeedEventCard), matching: find.byType(Container)).first,
      );
      final box = card.decoration! as BoxDecoration;
      expect(box.color, StudioColors.ink);
      expect(box.border == null, !dark); // a line around it only in dark
      expect(tester.widget<Text>(find.text('EVENT')).style!.fontFamily, contains('Mono'));
      final date = tester.widget<Text>(find.text('Sat, Nov 21 · 8:00 PM'));
      expect((date.style!.fontSize, date.style!.color), (12, StudioColors.onDarkSecondary));
      final name = tester.widget<Text>(find.text('Studio Night'));
      expect((name.style!.fontSize, name.style!.fontWeight), (19, StudioType.medium));
      expect(find.text('Five painters, one long table, new work for sale.'), findsOneWidget);
      expect(find.text('Price'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Where'), findsOneWidget);
      expect(find.text('The Space'), findsOneWidget);
      expect(find.text('Showing work'), findsNothing);
      await tester.tap(find.text('Get tickets'));
      await tester.tap(find.text('Studio Night'));
      expect((tickets, opened), (1, 1));
    });
  }

  testWidgets('with a lineup: Showing work, three artists and +2 More', (tester) async {
    setBoardViewport(tester, height: 300);
    String? artist;
    var opened = 0;
    await tester.pumpWidget(
      _app(
        FeedEventCard(
          event: _e('b', start: DateTime(2037, 11, 21, 20), artists: _artists),
          onOpen: () => opened++,
          onGetTickets: () {},
          onArtist: (a) => artist = a.username,
        ),
      ),
    );
    expect(find.text('Showing work'), findsOneWidget);
    expect(find.byType(StudioAvatar), findsNWidgets(3));
    expect(find.text('Amara'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Price'), findsNothing);
    await tester.tap(find.text('Cedric'));
    expect(artist, 'cedric');
    await tester.tap(find.text('+2'));
    expect(opened, 1);
  });

  testWidgets('golden: EventNoArtists', (tester) async {
    setBoardViewport(tester, height: 240);
    await tester.pumpWidget(
      _app(
        FeedEventCard(
          event: _e('a', start: DateTime(2037, 11, 21, 20)),
          onOpen: () {},
          onGetTickets: () {},
          onArtist: (_) {},
        ),
      ),
    );
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/EventNoArtists.png'));
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
