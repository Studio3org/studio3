import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:studio3/models/event_order.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/event_ticket_page.dart';
import 'package:studio3/screens/my_events_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// `EvTicket`, the ticket (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 17.1).
final _event = StudioEvent(
  id: 'ev1',
  title: 'Inside the Mind of an Artist',
  startsAt: DateTime(2037, 11, 21, 20),
  endsAt: DateTime(2037, 11, 21, 22),
  venueName: 'Dec on Dragon',
  address: '1414 Dragon St, Dallas, TX 75201',
  ticketCount: 2,
);

const _tickets = [
  EventTicket(id: 't1', code: 'S3-T-8KQ2-a1b2c3', typeName: 'General Admission', number: 'S3-T-8KQ2'),
  EventTicket(id: 't2', code: 'S3-T-4MZ7-d4e5f6', typeName: 'VIP', number: 'S3-T-4MZ7'),
];

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('ev_ticket').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  test('a ticket from the server', () {
    final t = EventTicket.fromJson({
      'id': 't1',
      'code': 'abc',
      'ticketTypeName': 'VIP',
      'scannedAt': '2037-11-21T20:05:00Z',
    });
    expect((t.typeName, t.label, t.scannedAt != null), ('VIP', 'abc', true));
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    testWidgets('one per screen, swipe between them, bars, Directions (${dark ? 'dark' : 'light'})', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(EventTicketPage(event: _event, tickets: _tickets), dark: dark));
      await tester.pump();

      expect(find.text('Ticket'), findsOneWidget);
      expect(tester.getSize(find.byType(QrImageView).first), const Size(189, 189));
      expect(find.text('General Admission'), findsOneWidget);
      expect(find.text('Ticket 1 of 2 · S3-T-8KQ2'), findsOneWidget);
      // White card, Ink text, in both themes.
      expect(tester.widget<Text>(find.text('Inside the Mind of an Artist').first).style!.color, StudioColors.ink);
      expect(find.text('Swipe for your other ticket. Turn your brightness up at the door.'), findsOneWidget);
      double bar(int i) => tester
          .getSize(find.descendant(of: find.byType(Row), matching: find.byType(AnimatedContainer)).at(i))
          .width;
      expect((bar(0), bar(1)), (18, 6));

      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Ticket 2 of 2 · S3-T-4MZ7'), findsOneWidget);
      expect((bar(0), bar(1)), (6, 18));

      final directions = find.byWidgetPredicate((w) => w is StudioButton && w.label == 'Directions');
      expect(tester.widget<StudioButton>(directions).variant, StudioButtonVariant.outline);
      expect(c.background, isNotNull);
    });
  }

  testWidgets('one ticket: no bars; a scanned ticket says so', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(
      _app(
        EventTicketPage(
          event: _event,
          tickets: [
            EventTicket(id: 't', code: 'x', typeName: 'General Admission', scannedAt: DateTime(2037, 11, 21, 20, 5)),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AnimatedContainer), findsNothing);
    expect(find.text('Turn your brightness up at the door.'), findsOneWidget);
    expect(find.text('General Admission · Scanned in'), findsOneWidget);
  });

  testWidgets('Your events: with tickets, the count and Show tickets open the ticket', (tester) async {
    setBoardViewport(tester, height: 1500);
    await tester.pumpWidget(
      _app(MyEventsPage(debugGoing: [_event], debugSaved: const [], debugNow: DateTime(2037, 11, 18, 10))),
    );
    await tester.pump();
    expect(find.text('Dec on Dragon, Dallas · 2 tickets'), findsOneWidget);
    await tester.tap(find.text('Show tickets'));
    // The page loads the tickets from the server (a spinner meanwhile), so no settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(EventTicketPage), findsOneWidget);
  });

  testWidgets('golden: EvTicket', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(EventTicketPage(event: _event, tickets: _tickets)));
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/EvTicket.png'));
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
