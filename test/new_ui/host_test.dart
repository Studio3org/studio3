import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/host/host_cancel_page.dart';
import 'package:studio3/screens/host/host_event_page.dart';
import 'package:studio3/screens/host/host_guest_list_page.dart';
import 'package:studio3/screens/host/host_live_page.dart';
import 'package:studio3/screens/host/host_manage_page.dart';
import 'package:studio3/screens/host/host_tag_pieces_page.dart';
import 'package:studio3/screens/host/host_ticket_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/create_flow/event_lineup_models.dart';
import 'package:studio3/widgets/host/host_date_sheet.dart';
import 'package:studio3/widgets/host/host_widgets.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Hosting, Flow 10 (`HostDetails` … `HostCancel`; docs/new-ui/NEW_UI_EXECUTION_PLAN.md 17.2).
final _now = DateTime(2037, 11, 10, 10);

StudioEvent _event({
  String status = 'draft',
  int? capacity = 120,
  int going = 62,
  bool full = false,
  List<EventLineupItem>? lineup,
}) => StudioEvent(
  id: 'ev1',
  title: 'Inside the Mind of an Artist',
  startsAt: DateTime(2037, 11, 21, 20),
  endsAt: DateTime(2037, 11, 21, 22),
  status: status,
  category: 'gallery_walk',
  coverMediaUrl: 'https://example.com/flyer.jpg',
  timezoneName: 'CST',
  venueName: 'Dec on Dragon',
  address: '1414 Dragon St, Dallas, TX 75201',
  description: 'An evening inside the studio with five Dallas painters.',
  capacity: capacity,
  rsvpCount: going,
  isFull: full,
  saveCount: 48,
  isHost: true,
  cohosts: const [EventPerson(username: 'sarah', name: 'Sarah Osmei')],
  artists: const [EventPerson(username: 'maria', name: 'Maria Bruno')],
  lineup: lineup ??
      const [
        EventLineupItem(
          id: 'l1',
          pieceId: 'p1',
          mode: 'sale',
          priceCents: 350000,
          deliveryMode: 'pickup',
          title: 'Bodies in Color',
          artistName: 'Amara Osei',
        ),
        EventLineupItem(
          id: 'l2',
          pieceId: 'p2',
          mode: 'featured',
          deliveryMode: 'pickup',
          title: 'Quiet Hours',
          artistUsername: 'maria',
          artistName: 'Maria Bruno',
        ),
      ],
);

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

/// A page with one button that runs [open].
Widget _opener(Future<Object?> Function(BuildContext context) open, {void Function(Object?)? onResult}) => _app(
  Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async => onResult?.call(await open(context)),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('host').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  test('date lines', () {
    final sel = HostDateSelection(
      multiDay: false,
      startDate: DateTime(2037, 11, 21),
      start: const TimeOfDay(hour: 20, minute: 0),
      end: const TimeOfDay(hour: 22, minute: 0),
      zone: 'CST',
    );
    expect(sel.rowLabel, 'Sat, Nov 21 · 8:00 PM CST');
    expect(sel.rangeLabel, 'Sat, Nov 21 · 8:00 – 10:00 PM CST');
    expect(sel.endsAt, DateTime(2037, 11, 21, 22));
    // An end before the start runs past midnight.
    final late = HostDateSelection(
      multiDay: false,
      startDate: DateTime(2037, 11, 21),
      start: const TimeOfDay(hour: 22, minute: 0),
      end: const TimeOfDay(hour: 1, minute: 0),
    );
    expect(late.endsAt, DateTime(2037, 11, 22, 1));
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    final theme = dark ? 'dark' : 'light';

    testWidgets('Details: tabs, flyer, fields, rows; Save and continue when filled ($theme)', (tester) async {
      setBoardViewport(tester, height: 960);
      await tester.pumpWidget(_app(HostEventPage(editing: _event(), debugNow: _now), dark: dark));
      await tester.pump();
      for (final tab in kHostSteps) {
        expect(find.descendant(of: find.byType(HostStepTabs), matching: find.text(tab)), findsOneWidget);
      }
      final details = tester.widget<Text>(find.descendant(of: find.byType(HostStepTabs), matching: find.text('Details')));
      expect((details.style!.fontWeight, details.style!.color), (StudioType.medium, c.textPrimary));
      expect(tester.getSize(find.byType(HostFlyerBox)).height, 176 + 18 + 6);
      expect(find.text('Inside the Mind of an Artist'), findsOneWidget);
      for (final row in ['Location', 'Date and time', 'Category', 'Event art', 'Delivery']) {
        expect(find.text(row), findsOneWidget, reason: row);
      }
      expect(find.text('Dec on Dragon'), findsOneWidget);
      final date = tester.widget<Text>(find.text('Sat, Nov 21 · 8:00 PM CST'));
      expect(date.style!.fontFamily, contains('Mono'));
      expect(find.text('Gallery walk'), findsOneWidget);
      expect(find.text('Selling'), findsOneWidget);
      expect(find.text('Pickup at the event'), findsOneWidget);
      // Not saved by the server yet, so not shown (section 0.3).
      expect(find.text('Age limit'), findsNothing);
      expect(find.text('Public'), findsNothing);
      expect(tester.widget<StudioButton>(_button('Save and continue')).onPressed, isNotNull);
    });
  }

  testWidgets('a new event waits for title, cover, place, date and category', (tester) async {
    setBoardViewport(tester, height: 960);
    await tester.pumpWidget(_app(HostEventPage(debugNow: _now)));
    await tester.pump();
    expect(find.text('Add a cover'), findsOneWidget);
    expect(find.text('Delivery'), findsNothing); // No art by default
    expect(tester.widget<StudioButton>(_button('Save and continue')).onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, 'Studio Night');
    await tester.pump();
    expect(tester.widget<StudioButton>(_button('Save and continue')).onPressed, isNull);
  });

  testWidgets('Event art sheet: four modes, delivery only when selling or auctioning', (tester) async {
    setBoardViewport(tester, height: 960);
    await tester.pumpWidget(_app(HostEventPage(debugNow: _now)));
    await tester.pump();
    await tester.tap(find.text('Event art'));
    await tester.pumpAndSettle();
    for (final m in ['No art', 'Showing only', 'Selling', 'Auction']) {
      expect(find.text(m), findsWidgets, reason: m);
    }
    expect(find.text('DELIVERY FOR SOLD PIECES'), findsNothing);
    await tester.tap(find.text('Auction'));
    await tester.pump();
    expect(find.text('DELIVERY FOR SOLD PIECES'), findsOneWidget);
    expect(find.text('Bidding ends 30 minutes before the event ends.'), findsOneWidget);
    await tester.tap(_button('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Auction'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
  });

  testWidgets('Tickets: Free (RSVP) only; the type card and its limit', (tester) async {
    setBoardViewport(tester, height: 900);
    await tester.pumpWidget(_app(HostEventPage(editing: _event(capacity: null), debugNow: _now, debugStep: 1)));
    await tester.pump();
    expect(find.text('IS THIS A PAID EVENT?'), findsOneWidget);
    expect(find.text('Coming soon. Every event is free for now.'), findsOneWidget);
    expect(find.text('General Admission'), findsOneWidget);
    expect(find.text('Free · no limit'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(HostTicketPage), findsOneWidget);
    await tester.tap(find.byType(StudioSwitch));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '50');
    await tester.pump();
    await tester.tap(_button('Save ticket type'));
    await tester.pumpAndSettle();
    expect(find.text('Free · 50 available'), findsOneWidget);
  });

  testWidgets('Lineup: people, piece cards with chips, price line, link and QR code', (tester) async {
    setBoardViewport(tester, height: 1060);
    await tester.pumpWidget(_app(HostEventPage(editing: _event(), debugNow: _now, debugStep: 2)));
    await tester.pump();
    expect(find.text('CO-HOSTS'), findsOneWidget);
    expect(find.text('Sarah'), findsOneWidget);
    expect(find.text('Maria'), findsOneWidget);
    expect(find.byType(HostAddTile), findsNWidgets(2));
    expect(find.text('Selling · Pickup at the event (set in Details)'), findsOneWidget);
    expect(find.text('Bodies in Color'), findsOneWidget);
    final forSale = find.byWidgetPredicate((w) => w is StudioChip && w.label == 'For sale');
    // Only the host's own piece can be sold; Maria's is shown (the server answers 403 otherwise).
    expect(forSale, findsOneWidget);
    expect(tester.widget<StudioChip>(forSale.first).selected, isTrue);
    expect(find.text(r'$3,500'), findsOneWidget);
    expect(find.text('Not for sale'), findsWidgets);
    expect(find.text('Only Maria Bruno can sell this piece.'), findsOneWidget);
    await tester.tap(find.text('Link and QR code').first);
    await tester.pumpAndSettle();
    expect(find.text('Copy link'), findsOneWidget);
    expect(_button('Download QR code'), findsOneWidget);
    expect(_button('Download all 2 QR codes'), findsOneWidget);
  });

  testWidgets('Review: three cards, Edit jumps back, Publish event', (tester) async {
    setBoardViewport(tester, height: 900);
    await tester.pumpWidget(_app(HostEventPage(editing: _event(), debugNow: _now, debugStep: 3)));
    await tester.pump();
    expect(find.text('Event art: Selling · Pickup at the event'), findsOneWidget);
    expect(find.text('Sat, Nov 21 · 8:00 – 10:00 PM CST'), findsOneWidget);
    expect(find.text('General Admission · Free · 120 available'), findsOneWidget);
    expect(find.text('Co-host: Sarah Osmei'), findsOneWidget);
    expect(find.text('2 pieces: Bodies in Color (for sale), Quiet Hours (not for sale)'), findsOneWidget);
    expect(_button('Publish event'), findsOneWidget);
    await tester.tap(find.text('Edit').at(1));
    await tester.pumpAndSettle();
    expect(find.text('IS THIS A PAID EVENT?'), findsOneWidget);
  });

  testWidgets('a published event saves changes; its date is locked', (tester) async {
    setBoardViewport(tester, height: 960);
    await tester.pumpWidget(_app(HostEventPage(editing: _event(status: 'published'), debugNow: _now)));
    await tester.pump();
    expect(find.text("A published event's date can't be changed yet."), findsOneWidget);
    expect(tester.widget<HostNavRow>(find.widgetWithText(HostNavRow, 'Date and time')).enabled, isFalse);
  });

  testWidgets('date sheet: pick a day; multi-day needs an end', (tester) async {
    setBoardViewport(tester, height: 900);
    Object? result;
    await tester.pumpWidget(
      _opener((context) => HostDateSheet.show(context, now: _now), onResult: (r) => result = r),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('November 2037'), findsOneWidget);
    expect(tester.widget<StudioButton>(_button('Done')).onPressed, isNull);
    await tester.tap(find.text('21'));
    await tester.pump();
    await tester.tap(find.byType(StudioSwitch));
    await tester.pump();
    expect(tester.widget<StudioButton>(_button('Done')).onPressed, isNull); // multi-day: no end yet
    await tester.tap(find.text('23'));
    await tester.pump();
    await tester.tap(_button('Done'));
    await tester.pumpAndSettle();
    final sel = result! as HostDateSelection;
    expect((sel.multiDay, sel.startDate, sel.endDate), (true, DateTime(2037, 11, 21), DateTime(2037, 11, 23)));
  });

  testWidgets('tag pieces: grouped, selected count, Done returns them', (tester) async {
    setBoardViewport(tester, height: 1000);
    Object? result;
    const amara = EventLineupPerson(username: 'amara', name: 'Amara Osei');
    const me = EventLineupPerson(username: 'sarah', name: 'Sarah');
    final groups = [
      (
        person: amara,
        host: false,
        pieces: const [
          PieceSummary(id: 'a1', title: 'Bodies in Color', listingState: 'available'),
          PieceSummary(id: 'a2', title: 'Blue Hour', listingState: 'collected'),
        ],
      ),
      (person: me, host: true, pieces: const [PieceSummary(id: 's1', title: 'Night Garden')]),
    ];
    await tester.pumpWidget(
      _opener(
        (context) => Navigator.of(context).push<List<PieceSummary>>(
          MaterialPageRoute(
            builder: (_) => HostTagPiecesPage(artists: const [amara], selectedIds: const {}, debugGroups: groups),
          ),
        ),
        onResult: (r) => result = r,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Amara Osei'), findsOneWidget);
    expect(find.text('@amara · featured'), findsOneWidget);
    expect(find.text('Your pieces'), findsOneWidget);
    expect(find.text('For sale'), findsOneWidget);
    expect(find.text('Collected'), findsOneWidget);
    expect(find.text('0 selected'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Night Garden'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect((result! as List<PieceSummary>).single.id, 's1');
  });

  testWidgets('conflict dialog: Continue or Cancel', (tester) async {
    Object? result;
    await tester.pumpWidget(
      _opener(
        (context) => showHostConflictDialog(context, title: 'This will end its current listing', message: 'It closes.'),
        onResult: (r) => result = r,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('This will end its current listing'), findsOneWidget);
    await tester.tap(_button('Continue'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    final theme = dark ? 'dark' : 'light';

    testWidgets('Manage event: cover, numbers, ticket type, rows, bar ($theme)', (tester) async {
      setBoardViewport(tester, height: 1400);
      final e = _event(status: 'published', full: true, going: 120);
      await tester.pumpWidget(_app(HostManagePage(event: e, debugEvent: e, debugNow: _now), dark: dark));
      await tester.pump();
      expect(find.text('Manage event'), findsOneWidget);
      expect(find.text('In 11 days'), findsOneWidget);
      expect(find.text('Sat, Nov 21 · 8:00 PM CST · Dec on Dragon'), findsOneWidget);
      expect(find.text('going of 120'), findsOneWidget);
      expect(find.text('48'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Sold out')).style!.color, c.alert);
      expect(find.text('Piece links and QR codes'), findsOneWidget);
      expect(find.text('Edit event'), findsOneWidget);
      expect(find.text('Cancel event'), findsOneWidget);
      expect(find.text('Doors open'), findsOneWidget);
      expect(_button('Guest list'), findsOneWidget);
      expect(find.text('Reschedule'), findsNothing); // B28
    });
  }

  testWidgets('Cancel event: what happens, message, the two buttons', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(HostCancelPage(event: _event(status: 'published'))));
    await tester.pump();
    expect(find.text('Cancel Inside the Mind of an Artist?'), findsOneWidget);
    expect(find.text('62 people'), findsOneWidget);
    expect(find.text('Message to guests (optional)'), findsOneWidget);
    expect(_button('Cancel event and tell guests'), findsOneWidget);
    expect(_button('Keep event'), findsOneWidget);
  });

  testWidgets('Guest list: count and search', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(
      _app(
        HostGuestListPage(
          event: _event(),
          debugGuests: const [EventPerson(username: 'jo', name: 'Jo Park'), EventPerson(username: 'max', name: 'Max')],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('2 going'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'jo');
    await tester.pump();
    expect(find.text('Jo Park'), findsOneWidget);
    expect(find.text('Max'), findsNothing);
  });

  testWidgets('Your event is live: frame, headline, details, Share and Manage', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
          child: HostLivePage(
            event: _event(status: 'published'),
            whenLabel: 'Sat, Nov 21 · 8:00 PM CST',
            ticketsLabel: 'Free · 120 total',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Your event is live'), findsOneWidget);
    expect(find.text('Inside the Mind of an Artist is showing in Events now.'), findsOneWidget);
    expect(find.byType(StudioIridescent), findsWidgets);
    expect(find.text('Event details'), findsOneWidget);
    expect(find.text('Free · 120 total'), findsOneWidget);
    expect(_button('Share event'), findsOneWidget);
    expect(_button('Manage event'), findsOneWidget);
  });

  // Goldens for the boards.
  for (final (name, height, build) in <(String, double, Widget Function())>[
    ('HostDetails', 960, () => HostEventPage(editing: _event(), debugNow: _now)),
    ('HostTickets', 844, () => HostEventPage(editing: _event(), debugNow: _now, debugStep: 1)),
    ('HostLineup', 1060, () => HostEventPage(editing: _event(), debugNow: _now, debugStep: 2)),
    ('HostReview', 844, () => HostEventPage(editing: _event(), debugNow: _now, debugStep: 3)),
    ('HostCancel', 844, () => HostCancelPage(event: _event(status: 'published'))),
    ('HostManage', 1560, () {
      final e = _event(status: 'published');
      return HostManagePage(event: e, debugEvent: e, debugNow: _now);
    }),
  ]) {
    testWidgets('golden: $name', (tester) async {
      setBoardViewport(tester, height: height);
      await tester.pumpWidget(_app(build()));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
    }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
  }

  // Goldens for the sheets, dialogs and pages opened from the steps, over the screen the
  // board draws behind them.
  final goldenPieces = [
    PieceSummary.fromJson(const {'id': 'a1', 'title': 'Bodies in Color', 'listingState': 'available', 'isForSale': true}),
    PieceSummary.fromJson(const {'id': 'a2', 'title': 'Blue Hour'}),
    PieceSummary.fromJson(const {'id': 'a3', 'title': 'Red Moon', 'listingState': 'collected'}),
  ];
  for (final (name, height, build, open) in <(String, double, Widget Function(), Future<void> Function(WidgetTester))>[
    ('HostEditTicket', 1000, () => const HostTicketPage(capacity: 20), (_) async {}),
    (
      'HostTagPieces',
      1000,
      () => HostTagPiecesPage(
        artists: const [],
        selectedIds: const {'a1', 'm1'},
        debugGroups: [
          (person: const EventLineupPerson(username: 'amarasart', name: 'Amara Osei'), host: false, pieces: goldenPieces),
          (
            person: const EventLineupPerson(username: 'mariabruno', name: 'Maria Bruno'),
            host: false,
            pieces: [PieceSummary.fromJson(const {'id': 'm1', 'title': 'Quiet Hours'})],
          ),
          (
            person: const EventLineupPerson(username: 'sarahsunnyart', name: 'Sarah'),
            host: true,
            pieces: [PieceSummary.fromJson(const {'id': 's1', 'title': 'Morning'})],
          ),
        ],
      ),
      (_) async {},
    ),
    (
      'HostLive',
      844,
      () => MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
        child: HostLivePage(
          event: _event(status: 'published'),
          whenLabel: 'Sat, Nov 21 · 8:00 PM CST',
          ticketsLabel: 'Free · 120 total',
        ),
      ),
      (_) async {},
    ),
    (
      'HostArtMode',
      960,
      () => HostEventPage(editing: _event(), debugNow: _now),
      (tester) async {
        await tester.tap(find.text('Event art'));
        await tester.pumpAndSettle();
      },
    ),
    (
      'HostDate',
      844,
      () => HostEventPage(editing: _event(), debugNow: _now),
      (tester) async {
        await tester.tap(find.text('Date and time'));
        await tester.pumpAndSettle();
      },
    ),
    (
      'HostConflict',
      844,
      () => HostEventPage(editing: _event(), debugNow: _now, debugStep: 2),
      (tester) async {
        showHostConflictDialog(
          tester.element(find.byType(HostStepTabs)),
          title: 'This will end its current listing',
          message: 'Bodies in Color is already for sale on its own. Selling it at this event closes that '
              'listing and starts a new one tied to the event.',
        );
        await tester.pumpAndSettle();
      },
    ),
    (
      'HostPieceQR',
      1060,
      () => HostEventPage(editing: _event(), debugNow: _now, debugStep: 2),
      (tester) async {
        await tester.tap(find.text('Link and QR code').first);
        await tester.pumpAndSettle();
      },
    ),
  ]) {
    testWidgets('golden: $name', (tester) async {
      setBoardViewport(tester, height: height);
      await tester.pumpWidget(_app(build()));
      await tester.pump();
      await open(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
    }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
  }
}
