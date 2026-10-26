import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/event_detail_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/events/event_detail_widgets.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// `EvDetail`, the event page (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 17.1).
/// Nov 21, 2037 is a Saturday, like the board's date, and stays in the future.
StudioEvent _event({
  bool isHost = false,
  bool going = false,
  bool full = false,
  bool ended = false,
  bool cancelled = false,
  bool bare = false,
}) => StudioEvent(
  id: 'ev1',
  title: 'Inside the Mind of an Artist',
  startsAt: ended ? DateTime(2020, 11, 21, 20) : DateTime(2037, 11, 21, 20),
  endsAt: ended ? DateTime(2020, 11, 21, 22) : DateTime(2037, 11, 21, 22),
  status: cancelled ? 'cancelled' : 'published',
  category: 'gallery_walk',
  venueName: 'Dec on Dragon',
  address: '1414 Dragon St, Dallas, TX 75201',
  hostUsername: 'amara',
  hostName: 'Amara Osei',
  isHost: isHost,
  viewerIsGoing: going,
  isFull: full,
  rsvpCount: 12,
  description: bare
      ? null
      : 'An evening inside the studio with five Dallas painters. Walk the space, hear how the '
            'new work came together in a short artist talk, and see pieces that will not be '
            'online until next week. Doors open at eight; the talk starts at half past.',
  artists: bare
      ? const []
      : const [
          EventPerson(username: 'amara', name: 'Amara'),
          EventPerson(username: 'cedric', name: 'Cedric'),
          EventPerson(username: 'daisy', name: 'Daisy'),
        ],
  lineup: bare
      ? const []
      : const [
          EventLineupItem(id: 'l1', pieceId: 'p1', mode: 'sale', priceCents: 350000, title: 'Bodies in Color I'),
          EventLineupItem(id: 'l2', pieceId: 'p2', mode: 'sale', priceCents: 95000, title: 'Paper Planes III'),
          EventLineupItem(id: 'l3', pieceId: 'p3', mode: 'bid', priceCents: 130000, title: 'Night Garden'),
        ],
  faqs: bare
      ? const []
      : const [
          EventFaq(
            question: 'Where do I park?',
            answer: 'Street parking on Dragon St is free after 6 PM. There is also a paid lot on Hi Line Dr.',
          ),
          EventFaq(question: 'What do I wear?', answer: 'Whatever you like.'),
          EventFaq(question: 'Is there a waitlist?', answer: 'Not for this one.'),
        ],
);

Widget _app(StudioEvent event, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: EventDetailPage(event: event, debugDetail: event),
);

Finder _button(String label) =>
    find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('ev_detail').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  test('price lines and the When day', () {
    final e = _event();
    expect(e.lineup.map(eventPiecePriceLine).toList(), [r'$3,500', r'$950', r'Bid $1,300']);
    expect(eventPiecePriceLine(const EventLineupItem(id: 'x', pieceId: 'x', mode: 'featured')), isNull);
    expect(
      eventPiecePriceLine(
        const EventLineupItem(id: 'x', pieceId: 'x', mode: 'sale', priceCents: 100, pieceStatus: 'sold'),
      ),
      'Sold',
    );
    expect(eventDayLabel(e), 'Sat, Nov 21');
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    testWidgets('flyer, host, details, artists, pieces, location, FAQs, bar (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      setBoardViewport(tester, height: 2340);
      await tester.pumpWidget(_app(_event(), dark: dark));
      await tester.pump();

      // The flyer: 390 × 470 with the four icons and the name 28/500.
      expect(tester.getSize(find.byType(EventHero)), const Size(390, 470));
      for (final label in ['Back', 'Save', 'Share', 'More']) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      final title = tester.widget<Text>(find.text('Inside the Mind of an Artist'));
      expect((title.style!.fontSize, title.style!.fontWeight), (28, StudioType.medium));
      expect(find.text('GALLERY WALK'), findsOneWidget);
      expect(find.text('Sat, Nov 21 · 8:00 – 10:00 PM'), findsOneWidget);

      // Hosted by with Follow.
      expect(find.textContaining('Hosted by', findRichText: true), findsOneWidget);
      expect(_button('Follow'), findsOneWidget);

      // Details cut at 4 lines with Show more.
      expect(find.text('Details'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Details')).style!.color, c.textSecondary);
      expect(find.text('Show more'), findsOneWidget);
      await tester.tap(find.text('Show more'));
      await tester.pump();
      expect(find.text('Show less'), findsOneWidget);

      // Artists and pieces.
      expect(find.text('Cedric'), findsOneWidget);
      expect(find.text(r'$3,500'), findsOneWidget);
      expect(find.text(r'Bid $1,300'), findsOneWidget);

      // Location: address and a 180 map.
      expect(find.text('1414 Dragon St, Dallas, TX 75201'), findsOneWidget);
      expect(tester.getSize(find.byType(EventMapCard)).height, 180);

      // FAQs open and close.
      expect(find.textContaining('Street parking'), findsNothing);
      await tester.tap(find.text('Where do I park?'));
      await tester.pump();
      expect(find.textContaining('Street parking'), findsOneWidget);

      // The bar: Tickets with the price range (Free), When in Mono 14, Get tickets.
      expect(find.text('Tickets'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      final when = tester.widget<Text>(find.text('Sat, Nov 21'));
      expect(when.style!.fontFamily, contains('Mono'));
      expect(when.style!.fontSize, 14);
      expect(tester.widget<StudioButton>(_button('Get tickets')).onPressed, isNotNull);
    });
  }

  testWidgets('the host sees Your event, the headcount and Manage event', (tester) async {
    setBoardViewport(tester, height: 2340);
    await tester.pumpWidget(_app(_event(isHost: true)));
    await tester.pump();
    expect(find.text('Your event'), findsOneWidget);
    expect(_button('Follow'), findsNothing);
    expect(find.text('Going'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(_button('Manage event'), findsOneWidget);
  });

  testWidgets("going: You're going opens Can't make it and Copy link", (tester) async {
    setBoardViewport(tester, height: 2340);
    await tester.pumpWidget(_app(_event(going: true)));
    await tester.pump();
    await tester.tap(_button("You're going"));
    await tester.pumpAndSettle();
    expect(find.text("Can't make it"), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('Manage event'), findsNothing);
  });

  testWidgets('full: the grey Sold out bar (EvSoldOut)', (tester) async {
    setBoardViewport(tester, height: 2340);
    await tester.pumpWidget(_app(_event(full: true)));
    await tester.pump();
    expect(find.byType(EventSoldOutBar), findsOneWidget);
    expect(_button('Get tickets'), findsNothing);
  });

  testWidgets('ended: no bar, a line says so', (tester) async {
    setBoardViewport(tester, height: 2340);
    await tester.pumpWidget(_app(_event(ended: true)));
    await tester.pump();
    expect(find.byType(StudioBottomBar), findsNothing);
    expect(find.text('This event has ended. The pieces shown here are still on Studio 3.'), findsOneWidget);
    expect(find.text('Work from the show'), findsOneWidget);
  });

  testWidgets('cancelled: the reason line and a disabled bar', (tester) async {
    setBoardViewport(tester, height: 2340);
    await tester.pumpWidget(_app(_event(cancelled: true)));
    await tester.pump();
    expect(find.text('This event was cancelled.'), findsOneWidget);
    expect(tester.widget<StudioButton>(_button('Event cancelled')).onPressed, isNull);
  });

  testWidgets('sections with nothing in them are left out', (tester) async {
    setBoardViewport(tester, height: 2340);
    await tester.pumpWidget(_app(_event(bare: true)));
    await tester.pump();
    for (final heading in ['Details', 'Featured artists', 'Pieces at this event', 'FAQs']) {
      expect(find.text(heading), findsNothing, reason: heading);
    }
    expect(find.text('Location'), findsOneWidget);
  });

  testWidgets('golden: EvDetail', (tester) async {
    setBoardViewport(tester, height: 2340);
    await tester.pumpWidget(_app(_event()));
    await tester.pump();
    await tester.tap(find.text('Where do I park?'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/EvDetail.png'));
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
