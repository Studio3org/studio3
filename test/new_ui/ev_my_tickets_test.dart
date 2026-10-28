import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/event_list_page.dart';
import 'package:studio3/screens/my_events_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/events/your_events_widgets.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// `EvMyTickets`, Your events (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 17.1).
/// Wednesday, Nov 18, 2037: the next event (Sat, Nov 21) is in 3 days.
final _now = DateTime(2037, 11, 18, 10);

StudioEvent _e(
  String id,
  String title,
  DateTime start, {
  String venue = 'Cedars Union',
  String address = '1 Main St, Dallas, TX 75201',
  int? spotsLeft,
  bool full = false,
  String status = 'published',
  int going = 0,
}) => StudioEvent(
  id: id,
  title: title,
  startsAt: start,
  endsAt: start.add(const Duration(hours: 2)),
  status: status,
  venueName: venue,
  address: address,
  spotsLeft: spotsLeft,
  isFull: full,
  rsvpCount: going,
);

final _going = [
  _e('a', 'Inside the Mind of an Artist', DateTime(2037, 11, 21, 20), venue: 'Dec on Dragon'),
  _e('b', "Amara's Open Studio", DateTime(2037, 12, 6, 14)),
  _e('c', 'Figure Drawing', DateTime(2037, 12, 9, 19)),
  _e('d', 'New Figures opening night', DateTime(2037, 12, 12, 18), venue: 'Dec on Dragon'),
  _e('e', 'Print Night', DateTime(2038, 1, 8, 18), venue: 'Deep Ellum'),
  _e('p', 'Summer Salon', DateTime(2020, 7, 4, 18)), // past
];
final _saved = [
  _e('s1', 'Color Lab', DateTime(2037, 11, 26, 19), spotsLeft: 3),
  _e('s2', 'Small Works', DateTime(2037, 12, 13, 10)),
  _e('s3', "Collector's Preview", DateTime(2037, 12, 12, 20), full: true),
  _e('b', "Amara's Open Studio", DateTime(2037, 12, 6, 14)), // also going: not in Saved
];

Widget _app({
  List<StudioEvent>? going,
  List<StudioEvent>? saved,
  List<StudioEvent> hosting = const [],
  bool dark = false,
}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: MyEventsPage(
    debugGoing: going ?? _going,
    debugSaved: saved ?? _saved,
    debugHosting: hosting,
    debugNow: _now,
  ),
);

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('ev_mine').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  test('how soon', () {
    expect(eventHowSoon(_going[0], _now), 'In 3 days');
    expect(eventHowSoon(_e('x', 'X', DateTime(2037, 11, 18, 20)), _now), 'Tonight');
    expect(eventHowSoon(_e('x', 'X', DateTime(2037, 11, 18, 15)), _now), 'Today');
    expect(eventHowSoon(_e('x', 'X', DateTime(2037, 11, 19, 9)), _now), 'Tomorrow');
    expect(eventHowSoon(_e('x', 'X', DateTime(2037, 11, 18, 9)), _now), 'Happening now');
    expect(eventHowSoon(_e('x', 'X', DateTime(2037, 12, 30, 9)), _now), 'In 6 weeks');
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    testWidgets('Upcoming card and rows, Saved, Past events (${dark ? 'dark' : 'light'})', (tester) async {
      setBoardViewport(tester, height: 1500);
      await tester.pumpWidget(_app(dark: dark));
      await tester.pump();

      expect(find.text('Your events'), findsOneWidget);
      expect(find.byTooltip('Scan a code'), findsOneWidget);
      final label = tester.widget<Text>(find.text('UPCOMING'));
      expect((label.style!.fontSize, label.style!.color), (11, c.textTertiary));

      // The next event, large.
      expect(tester.getSize(find.byType(NextEventCard)).width, 342);
      expect(find.text('In 3 days'), findsOneWidget);
      final title = tester.widget<Text>(find.text('Inside the Mind of an Artist'));
      expect((title.style!.fontSize, title.style!.fontWeight), (18, StudioType.medium));
      expect(find.text('Sat, Nov 21 · 8:00 PM'), findsOneWidget);
      expect(find.text('Dec on Dragon, Dallas'), findsOneWidget);
      expect(find.text('View event'), findsOneWidget);

      // The rest, soonest first.
      final rows = tester.widgetList<YourEventRow>(find.byType(YourEventRow)).map((r) => r.event.title).toList();
      expect(rows, ["Amara's Open Studio", 'Figure Drawing', 'New Figures opening night', 'Print Night']);
      expect(find.text('Fri, Jan 8 · 6:00 PM'), findsOneWidget);

      // Saved: not the ones already going; Only 3 left in red, Sold out grey.
      final saved = tester.widgetList<SavedEventCard>(find.byType(SavedEventCard)).map((s) => s.event.title).toList();
      expect(saved, ['Color Lab', "Collector's Preview", 'Small Works']);
      expect(tester.widget<Text>(find.text('Only 3 left')).style!.color, c.alert);
      expect(tester.widget<Text>(find.text('Sold out')).style!.color, c.textTertiary);
      expect(find.text('Thu, Nov 26'), findsOneWidget);

      expect(find.text('Past events'), findsOneWidget);
      expect(find.text('Events you host'), findsNothing);
    });
  }

  testWidgets('no tickets: starts with Saved', (tester) async {
    setBoardViewport(tester, height: 1500);
    await tester.pumpWidget(_app(going: const []));
    await tester.pump();
    expect(find.text('UPCOMING'), findsNothing);
    expect(find.text('SAVED'), findsOneWidget);
    expect(find.text("Amara's Open Studio"), findsOneWidget); // saved now, not going
  });

  testWidgets('nothing at all: the empty state', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(going: const [], saved: const []));
    await tester.pump();
    expect(find.byType(StudioEmptyState), findsOneWidget);
    expect(find.text('No events yet'), findsOneWidget);
  });

  testWidgets('Past events opens the list, latest first', (tester) async {
    setBoardViewport(tester, height: 1500);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.text('Past events'));
    await tester.pumpAndSettle();
    expect(find.byType(EventListPage), findsOneWidget);
    expect(find.text('Summer Salon'), findsOneWidget);
  });

  testWidgets('a host gets Events you host: drafts, headcounts and Delete', (tester) async {
    setBoardViewport(tester, height: 1500);
    final hosting = [
      _e('h1', 'Studio Night', DateTime(2037, 12, 1, 19), going: 12),
      _e('h2', 'Untitled draft', DateTime(2037, 12, 20, 19), status: 'draft'),
    ];
    await tester.pumpWidget(_app(hosting: hosting));
    await tester.pump();
    expect(find.text('Events you host'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('Events you host'));
    await tester.pumpAndSettle();
    expect(find.byType(HostedEventsPage), findsOneWidget);
    expect(find.text('Cedars Union · 12 going'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.byTooltip('Host an event'), findsOneWidget);
    await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'More').first);
    await tester.pumpAndSettle();
    expect(find.text('Delete event'), findsOneWidget);
  });

  testWidgets('golden: EvMyTickets', (tester) async {
    setBoardViewport(tester, height: 1500);
    await tester.pumpWidget(_app());
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/EvMyTickets.png'));
    await checkAcceptance(tester);
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
