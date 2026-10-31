import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/event_confirmed_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/events/event_tickets_sheet.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// `EvConfirmed`, You're going (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 17.1).
const _ga = EventTicketType(id: 'ga', name: 'General Admission');
const _vip = EventTicketType(id: 'vip', name: 'VIP', priceCents: 2500);

final _event = StudioEvent(
  id: 'ev1',
  title: 'Inside the Mind of an Artist',
  startsAt: DateTime(2037, 11, 21, 20),
  endsAt: DateTime(2037, 11, 21, 22),
  venueName: 'Dec on Dragon',
  address: '1414 Dragon St, Dallas, TX 75201',
  description: 'An evening inside the studio.',
);

Widget _app({bool paid = true, bool dark = false, bool reduceMotion = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  builder: (context, child) =>
      MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
  home: EventConfirmedPage(
    event: _event,
    choice: paid ? const EventTicketChoice({_ga: 1, _vip: 1}) : const EventTicketChoice({_ga: 1}),
    email: paid ? 'jordan@email.com' : null,
  ),
);

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

void main() {
  final calendarCalls = <MethodCall>[];

  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('ev_confirmed').path;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => tmp);
    messenger.setMockMethodCallHandler(const MethodChannel('add_2_calendar'), (call) async {
      calendarCalls.add(call);
      return true;
    });
  });

  test('the stub lines', () {
    expect(eventTicketTypesLine(const EventTicketChoice({_ga: 1, _vip: 1})), 'GA · VIP');
    expect(eventTicketTypesLine(const EventTicketChoice({_ga: 2})), 'GA');
    expect(eventTicketWhen(_event), 'SAT NOV 21 · 8:00 PM');
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    testWidgets('paid: headline, ticket, emailed line, Add to calendar, View tickets (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(dark: dark));
      await tester.pumpAndSettle();

      final headline = tester.widget<Text>(find.text("You're going."));
      expect((headline.style!.fontSize, headline.style!.fontWeight), (36, StudioType.medium));
      expect(headline.style!.color, c.textPrimary);
      expect(tester.getSize(find.byType(EventTicketArt)), const Size(300, 452));
      expect(find.text('ADMIT 2'), findsOneWidget);
      expect(find.text('GA · VIP'), findsOneWidget);
      expect(find.text('SAT NOV 21 · 8:00 PM'), findsOneWidget);
      expect(find.text('Dec on Dragon, Dallas'), findsOneWidget);
      // The ticket is white in both themes, its text Ink.
      expect(tester.widget<Text>(find.text('Inside the Mind of an Artist')).style!.color, StudioColors.ink);
      expect(find.text('Your 2 tickets are saved here and emailed to jordan@email.com.'), findsOneWidget);
      expect(_button('Add to calendar'), findsOneWidget);
      expect(_button('View tickets'), findsOneWidget);
    });
  }

  testWidgets('a free reservation: ADMIT 1, saved in Your events', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(paid: false));
    await tester.pumpAndSettle();
    expect(find.text('ADMIT 1'), findsOneWidget);
    expect(find.text('GA'), findsOneWidget);
    expect(find.text('Your place is saved in Your events.'), findsOneWidget);
    expect(_button('Your events'), findsOneWidget);
  });

  testWidgets('the ticket shape: corners and notches cut inward', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final clip = tester.widget<ClipPath>(
      find.descendant(of: find.byType(EventTicketArt), matching: find.byType(ClipPath)),
    );
    final path = clip.clipper!.getClip(EventTicketArt.size);
    expect(path.contains(const Offset(150, 100)), isTrue);
    expect(path.contains(const Offset(2, 2)), isFalse); // corner
    expect(path.contains(const Offset(298, 450)), isFalse); // corner
    expect(path.contains(const Offset(3, 300)), isFalse); // left notch
    expect(path.contains(const Offset(297, 300)), isFalse); // right notch
    expect(path.contains(const Offset(20, 300)), isTrue);
  });

  testWidgets('the ticket rises in; reduced motion shows it at once', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app());
    double ticketOpacity() => tester
        .widget<Opacity>(find.ancestor(of: find.byType(EventTicketArt), matching: find.byType(Opacity)).first)
        .opacity;
    expect(ticketOpacity(), 0);
    await tester.pump(const Duration(milliseconds: 350));
    expect(ticketOpacity(), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(ticketOpacity(), 1);

    await tester.pumpWidget(_app(reduceMotion: true));
    await tester.pump();
    expect(ticketOpacity(), 1);
  });

  testWidgets('Add to calendar sends the event to the calendar', (tester) async {
    setBoardViewport(tester);
    calendarCalls.clear();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(_button('Add to calendar'));
    await tester.pump();
    expect(calendarCalls.single.method, 'add2Cal');
    final args = calendarCalls.single.arguments as Map;
    expect(args['title'], 'Inside the Mind of an Artist');
    expect(args['location'], 'Dec on Dragon, 1414 Dragon St, Dallas, TX 75201');
    expect(args['startDate'], DateTime(2037, 11, 21, 20).millisecondsSinceEpoch);
  });

  testWidgets('golden: EvConfirmed', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/EvConfirmed.png'));
    await checkAcceptance(tester);
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
