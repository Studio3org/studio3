import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/event_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/events/event_tab_widgets.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// `EvTab`, the Events tab (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 17.1).
/// Saturday, Nov 21, 10:00.
final _now = DateTime(2026, 11, 21, 10);

StudioEvent _e(
  String id,
  String title, {
  required DateTime start,
  Duration length = const Duration(hours: 2),
  String? category,
  String venue = 'Cedars Union',
  String address = '1 Main St, Dallas, TX 75201',
  String? host,
}) => StudioEvent(
  id: id,
  title: title,
  startsAt: start,
  endsAt: start.add(length),
  status: 'published',
  category: category,
  timezoneName: 'CST',
  venueName: venue,
  address: address,
  hostName: host,
);

DateTime _at(int dayOffset, int hour) => DateTime(2026, 11, 21 + dayOffset, hour);

final _featured = _e(
  'f',
  'Inside the Mind of an Artist',
  start: _at(0, 18),
  category: 'gallery_walk',
  venue: 'Dec on Dragon',
);
final _today = _e("t", "Collector's Preview and Auction", start: _at(0, 20));
final _browse = EventBrowse(
  today: [_featured, _today],
  following: [
    _e('a', "Amara's Open Studio", start: _at(1, 18), host: 'Amara Osei'),
    _e('p', 'Paper Planes Release', start: _at(2, 14), venue: 'Deep Ellum'),
    _e('c', 'Color Lab', start: _at(5, 19), venue: 'Bishop Arts', address: '2 Elm St, Fort Worth, TX'),
  ],
  upcoming: [
    _e('w1', 'Intro to Encaustic', start: _at(1, 11), category: 'workshop', venue: 'Studio 3'),
    _e('w2', 'Figure Drawing', start: _at(4, 19), category: 'workshop'),
    _e('w3', 'Print Night', start: _at(6, 18), category: 'workshop', venue: 'Deep Ellum'),
    _e('x1', 'New Figures', start: _at(-3, 10), length: const Duration(days: 21), category: 'exhibition', venue: 'Dec on Dragon'),
    _e('x2', 'Small Works', start: _at(-1, 10), length: const Duration(days: 44), category: 'exhibition', venue: 'Oak Cliff'),
    _e('x3', 'Bodies in Color', start: _at(7, 10), length: const Duration(days: 30), category: 'exhibition', venue: 'Design District'),
  ],
  categories: const [
    EventCategoryCount(id: 'studio_visits', upcomingCount: 6),
    EventCategoryCount(id: 'pop_ups', upcomingCount: 4),
    EventCategoryCount(id: 'workshop', upcomingCount: 9),
  ],
);

Widget _app({bool dark = false, EventBrowse? browse}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: EventPage(debugBrowse: browse ?? _browse, debugNow: _now),
);

Finder _tab(String label) => find.descendant(
  of: find.byType(EventRangeTabs),
  matching: find.text(label),
);

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('ev_tab').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  group('date lines', () {
    test('today, this week, later; a run of days says when it runs', () {
      expect(eventCardWhen(_today, _now), 'Today · 8:00 PM CST');
      expect(eventCardWhen(_e('s', 'S', start: _at(1, 18)), _now), 'Sun · 6:00 PM CST');
      expect(eventCardWhen(_e('l', 'L', start: _at(10, 18)), _now), 'Dec 1 · 6:00 PM CST');
      expect(
        eventCardWhen(_e('r', 'R', start: _at(-3, 10), length: const Duration(days: 21)), _now),
        'Through Dec 9',
      );
      expect(
        eventCardWhen(_e('o', 'O', start: _at(7, 10), length: const Duration(days: 30)), _now),
        'Opens Nov 28',
      );
      expect(eventFeaturedWhen(_featured), 'Sat, Nov 21 · 6:00 PM CST');
      expect(eventVenuePrice(_today), 'Cedars Union · Free');
    });

    test('ranges and the city in an address', () {
      expect(EventRange.today.includes(_today, _now), isTrue);
      expect(EventRange.today.includes(_browse.following.first, _now), isFalse);
      expect(EventRange.week.includes(_browse.following.last, _now), isTrue);
      expect(EventRange.week.includes(_browse.upcoming.last, _now), isFalse);
      expect(EventRange.month.includes(_browse.upcoming.last, _now), isTrue);
      expect(eventCity(_today), 'Dallas');
      expect(eventCity(_browse.following.last), 'Fort Worth');
    });
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    testWidgets('header, search, ranges, featured, today list (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      setBoardViewport(tester, height: 2560);
      await tester.pumpWidget(_app(dark: dark));
      await tester.pump();

      expect(find.bySemanticsLabel('Host an event'), findsOneWidget);
      expect(find.bySemanticsLabel('Your events'), findsOneWidget);
      expect(find.text('Near me'), findsOneWidget);
      expect(find.text('Search events'), findsOneWidget);
      final todayTab = tester.widget<Text>(_tab('Today'));
      expect((todayTab.style!.fontWeight, todayTab.style!.color), (StudioType.medium, c.textPrimary));
      expect(tester.widget<Text>(_tab('This week')).style!.color, c.textTertiary);

      // Featured: the soonest event in range, full width, 390 × 470.
      final featured = find.byType(FeaturedEventCard);
      expect(tester.getSize(featured), const Size(390, 470));
      expect(find.text('GALLERY WALK'), findsOneWidget);
      expect(find.text('Sat, Nov 21 · 6:00 PM CST'), findsOneWidget);

      // Today: the other events today, as list rows with a Mono date line.
      expect(find.text('Today'), findsNWidgets(2)); // the tab and the section
      expect(find.text("Collector's Preview and Auction"), findsOneWidget);
      final when = tester.widget<Text>(find.text('Today · 8:00 PM CST'));
      expect(when.style!.fontFamily, contains('Mono'));
      expect(when.style!.fontSize, 11);
      // Today filters everything below: nothing from later days.
      expect(find.text('From artists you follow'), findsNothing);
      expect(find.text('Browse by category'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  }

  testWidgets('This week brings in the rows; See all on each', (tester) async {
    setBoardViewport(tester, height: 2560);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(_tab('This week'));
    await tester.pump();
    for (final title in ['From artists you follow', 'Workshops and classes', 'Exhibitions']) {
      expect(find.text(title), findsOneWidget, reason: title);
      expect(
        find.byWidgetPredicate((w) => w is EventSectionTitle && w.title == title && w.onSeeAll != null),
        findsOneWidget,
      );
    }
    final poster = find.byType(EventPosterCard).first;
    expect(tester.getSize(find.descendant(of: poster, matching: find.byType(ClipRRect)).first), const Size(150, 200));
    expect(find.text('Through Dec 9'), findsWidgets);
    expect(find.text('Bodies in Color'), findsNothing); // opens after this week
    expect(find.text('6 upcoming'), findsOneWidget);
    expect(find.text('Studio visits'), findsOneWidget);
  });

  testWidgets('search and filters narrow everything; the dot shows a filter is on', (tester) async {
    setBoardViewport(tester, height: 2560);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(_tab('This month'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'encaustic');
    await tester.pump();
    expect(find.text('Intro to Encaustic'), findsWidgets);
    expect(find.text('Figure Drawing'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Free only'), findsOneWidget);
    await tester.tap(find.text('Exhibition'));
    await tester.pump();
    await tester.tap(find.text('Show events'));
    await tester.pumpAndSettle();
    expect(find.text('Intro to Encaustic'), findsNothing);
    expect(find.text('New Figures'), findsWidgets);
    expect(tester.widget<EventRangeTabs>(find.byType(EventRangeTabs)).filtersActive, isTrue);
  });

  testWidgets('Near me lists the cities and narrows to one', (tester) async {
    setBoardViewport(tester, height: 2560);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(_tab('This week'));
    await tester.pump();
    await tester.tap(find.text('Near me'));
    await tester.pumpAndSettle();
    expect(find.text('Dallas'), findsOneWidget);
    await tester.tap(find.text('Fort Worth'));
    await tester.pumpAndSettle();
    expect(find.text('Fort Worth'), findsOneWidget);
    expect(find.text('Color Lab'), findsWidgets);
    expect(find.text('Intro to Encaustic'), findsNothing);
  });

  testWidgets('no events: the empty state offers hosting', (tester) async {
    await tester.pumpWidget(_app(browse: const EventBrowse()));
    await tester.pump();
    expect(find.text('No events yet'), findsOneWidget);
    expect(find.text('Host an event'), findsOneWidget);
  });

  testWidgets('golden: EvTab', (tester) async {
    setBoardViewport(tester, height: 2560);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(_tab('This week'));
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/EvTab.png'));
    await checkAcceptance(tester);
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
