import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/event_detail_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/events/event_detail_widgets.dart';
import 'package:studio3/widgets/events/event_tickets_sheet.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// `EvChooseTickets`, Choose tickets (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 17.1).
const _ga = EventTicketType(id: 'ga', name: 'General Admission', includes: 'Open to everyone', left: 18);
const _vip = EventTicketType(
  id: 'vip',
  name: 'VIP',
  priceCents: 2500,
  includes: 'Early entry, reserved seating',
  left: 3,
  perOrderLimit: 4,
);

StudioEvent _event({List<EventTicketType> types = const [], int? spotsLeft, bool full = false}) =>
    StudioEvent(
      id: 'ev1',
      title: 'Inside the Mind of an Artist',
      startsAt: DateTime(2037, 11, 21, 20),
      endsAt: DateTime(2037, 11, 21, 22),
      category: 'gallery_walk',
      venueName: 'Dec on Dragon',
      address: '1414 Dragon St, Dallas, TX 75201',
      hostUsername: 'amara',
      hostName: 'Amara Osei',
      spotsLeft: spotsLeft,
      isFull: full,
      ticketTypes: types,
    );

Widget _app(StudioEvent event, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: EventDetailPage(event: event, debugDetail: event),
);

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

Finder _card(String name) => find.byWidgetPredicate((w) => w is EventTicketCard && w.type.name == name);

Future<void> _open(WidgetTester tester, StudioEvent event, {bool dark = false}) async {
  setBoardViewport(tester);
  await tester.pumpWidget(_app(event, dark: dark));
  await tester.pump();
  await tester.tap(_button('Get tickets'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('ev_tickets').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  test('a free RSVP event offers one General Admission place per person', () {
    final options = _event(spotsLeft: 18).ticketOptions;
    expect(options, hasLength(1));
    expect(options.single.name, 'General Admission');
    expect(options.single.isFree, isTrue);
    expect(options.single.left, 18);
    expect(options.single.maxPerOrder, 1);
    expect(_event(full: true).ticketOptions.single.isSoldOut, isTrue);
    expect(_event(types: [_vip]).ticketOptions, [_vip]);
    expect(_vip.maxPerOrder, 3); // fewer left than the per-order limit
    expect(EventTicketChoice({_ga: 1, _vip: 2}).totalCents, 5000);
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    testWidgets('free RSVP: one place, already picked, Reserve (${dark ? 'dark' : 'light'})', (tester) async {
      await _open(tester, _event(spotsLeft: 18), dark: dark);
      expect(find.byType(EventTicketsSheet), findsOneWidget);
      final title = tester.widget<Text>(
        find.descendant(
          of: find.byType(EventTicketsSheet),
          matching: find.text('Inside the Mind of an Artist'),
        ),
      );
      expect((title.style!.fontSize, title.style!.fontWeight), (20, StudioType.medium));
      expect(find.text('General Admission'), findsOneWidget);
      expect(find.text('Open to everyone'), findsOneWidget);
      final left = tester.widget<Text>(find.text('18 left'));
      expect(left.style!.color, c.textTertiary);
      // Already at 1; + stops at the one place per person.
      expect(find.descendant(of: _card('General Admission'), matching: find.text('1')), findsOneWidget);
      final plus = tester.widget<Semantics>(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'One more General Admission'),
      );
      expect(plus.properties.enabled, isFalse);
      final border =
          (tester
                          .widget<Container>(
                            find
                                .descendant(of: _card('General Admission'), matching: find.byType(Container))
                                .first,
                          )
                          .decoration!
                      as BoxDecoration)
                  .border!
              as Border;
      expect(border.top.color, dark ? const Color(0xFF5A5A57) : const Color(0xFFB8B8B4));
      expect(find.textContaining('1 ticket', findRichText: true), findsOneWidget);
      expect(_button('Reserve'), findsOneWidget);
      expect(tester.widget<StudioButton>(_button('Reserve')).onPressed, isNotNull);
    });
  }

  testWidgets('ticket types: pick from several; Only 3 left in red; total and Continue to payment', (
    tester,
  ) async {
    await _open(tester, _event(types: [_ga, _vip]));
    // Nothing picked yet with more than one type.
    expect(tester.widget<StudioButton>(_button('Reserve')).onPressed, isNull);
    final only = tester.widget<Text>(find.text('Only 3 left'));
    expect(only.style!.color, StudioColors.light.alert);
    expect(find.text(r'$25'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('One more General Admission'));
    await tester.pump();
    expect(find.text('Free'), findsWidgets);
    expect(_button('Reserve'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('One more VIP'));
    await tester.pump();
    expect(find.textContaining('2 tickets · tax added at checkout', findRichText: true), findsOneWidget);
    expect(find.text(r'$25'), findsNWidgets(2)); // the VIP price and the total
    expect(_button('Continue to payment'), findsOneWidget);

    // VIP stops at the 3 left.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('One more VIP'));
      await tester.pump();
    }
    expect(find.descendant(of: _card('VIP'), matching: find.text('3')), findsOneWidget);
  });

  testWidgets('a sold-out type stays as a grey card with Sold out', (tester) async {
    await _open(
      tester,
      _event(
        types: [
          _ga,
          const EventTicketType(id: 'x', name: 'VIP', priceCents: 2500, left: 0),
        ],
      ),
    );
    expect(find.descendant(of: _card('VIP'), matching: find.text('Sold out')), findsOneWidget);
    expect(find.bySemanticsLabel('One more VIP'), findsNothing);
  });

  testWidgets('every place gone: the event bar says Sold out', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(_event(full: true)));
    await tester.pump();
    expect(find.byType(EventSoldOutBar), findsOneWidget);
  });

  testWidgets('Reserve asks a signed-out viewer to sign in', (tester) async {
    await _open(tester, _event(spotsLeft: 18));
    await tester.tap(_button('Reserve'));
    await tester.pumpAndSettle();
    expect(find.byType(EventTicketsSheet), findsNothing);
    expect(find.text('Sign in to get tickets'), findsOneWidget);
  });

  testWidgets('tapping outside closes it', (tester) async {
    await _open(tester, _event(spotsLeft: 18));
    await tester.tapAt(const Offset(195, 100));
    await tester.pumpAndSettle();
    expect(find.byType(EventTicketsSheet), findsNothing);
  });

  testWidgets('golden: EvChooseTickets', (tester) async {
    await _open(tester, _event(types: [_ga, _vip]));
    await tester.tap(find.bySemanticsLabel('One more General Admission'));
    await tester.tap(find.bySemanticsLabel('One more VIP'));
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/EvChooseTickets.png'));
    await checkAcceptance(tester);
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
