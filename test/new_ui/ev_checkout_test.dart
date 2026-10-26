import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/event_order.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/event_checkout_page.dart';
import 'package:studio3/screens/event_detail_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/events/event_tickets_sheet.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// `EvCheckout`, checkout for paid tickets (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, 17.1).
const _ga = EventTicketType(id: 'ga', name: 'General Admission', includes: 'Open to everyone', left: 18);
const _vip = EventTicketType(id: 'vip', name: 'VIP', priceCents: 2500, includes: 'Early entry', left: 3);
const _quote = EventOrderQuote(
  serviceFeeCents: 200,
  taxCents: 223,
  totalCents: 2923,
  refundPolicy: 'Refunds up to 24 hours before the event.',
);
const _choice = EventTicketChoice({_ga: 1, _vip: 1});

final _event = StudioEvent(
  id: 'ev1',
  title: 'Inside the Mind of an Artist',
  startsAt: DateTime(2037, 11, 21, 20),
  endsAt: DateTime(2037, 11, 21, 22),
  venueName: 'Dec on Dragon',
  address: '1414 Dragon St, Dallas, TX 75201',
  ticketTypes: const [_ga, _vip],
);

EventCheckoutPage _page() =>
    EventCheckoutPage(event: _event, choice: _choice, debugQuote: _quote, debugEmail: 'jordan@email.com');

/// Opens checkout and shows how it ended.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  EventCheckoutOutcome? outcome;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async {
          final result = await Navigator.of(
            context,
          ).push<EventCheckoutOutcome>(MaterialPageRoute(builder: (_) => _page()));
          setState(() => outcome = result);
        },
        child: Text('outcome: ${outcome?.name ?? 'none'}'),
      ),
    ),
  );
}

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

Finder _summaryLine(String label, String value) => find.byWidgetPredicate(
  (w) =>
      w is Row &&
      w.children.length == 2 &&
      w.children.first is Expanded &&
      ((w.children.first as Expanded).child is Text) &&
      ((w.children.first as Expanded).child as Text).data == label &&
      w.children.last is Text &&
      (w.children.last as Text).data == value,
);

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('ev_checkout').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  test('amounts always show cents; the choice reads as a list', () {
    expect(eventCheckoutMoney(2500), r'$25.00');
    expect(eventCheckoutMoney(2923), r'$29.23');
    expect(eventCheckoutMoney(123456), r'$1,234.56');
    expect(_choice.summary, '1 General Admission, 1 VIP');
    expect(_choice.totalCents, 2500);
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    testWidgets('event, rows, order summary, refund line, Confirm and pay (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_page(), dark: dark));
      await tester.pump();

      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Sat, Nov 21 · 8:00 PM'), findsOneWidget);
      expect(find.text('Dec on Dragon, Dallas'), findsOneWidget);
      expect(find.text('1 General Admission, 1 VIP'), findsOneWidget);
      expect(find.text('jordan@email.com'), findsOneWidget);
      expect(find.text('Add a payment method'), findsOneWidget);

      expect(_summaryLine('General Admission × 1', 'Free'), findsOneWidget);
      expect(_summaryLine('VIP × 1', r'$25.00'), findsOneWidget);
      expect(_summaryLine('Service fee', r'$2.00'), findsOneWidget);
      expect(_summaryLine('Sales tax', r'$2.23'), findsOneWidget);
      final total = tester.widget<Text>(find.text(r'$29.23'));
      expect(total.style!.fontWeight, StudioType.medium);
      expect(tester.widget<Text>(find.text('Service fee')).style!.color, c.textSecondary);

      expect(find.textContaining('Refunds up to 24 hours', findRichText: true), findsOneWidget);
      expect(tester.widget<StudioButton>(_button(r'Confirm and pay $29.23')).onPressed, isNotNull);
    });
  }

  testWidgets('changing to free tickets only leaves checkout to reserve them', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(const _Host()));
    await tester.tap(find.text('outcome: none'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 General Admission, 1 VIP'));
    await tester.pumpAndSettle();
    // The sheet opens with what was picked.
    expect(find.byType(EventTicketsSheet), findsOneWidget);
    expect(_button('Continue to payment'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('One less VIP'));
    await tester.pump();
    await tester.tap(_button('Reserve'));
    await tester.pumpAndSettle();
    expect(find.text('outcome: reserveInstead'), findsOneWidget);
  });

  testWidgets('paid tickets from the event page ask a signed-out viewer to sign in', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(EventDetailPage(event: _event, debugDetail: _event)));
    await tester.pump();
    expect(find.text(r'$25'), findsNothing); // From: the lowest price is Free
    await tester.tap(_button('Get tickets'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('One more VIP'));
    await tester.pump();
    await tester.tap(_button('Continue to payment'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to get tickets'), findsOneWidget);
    expect(find.byType(EventCheckoutPage), findsNothing);
  });

  testWidgets('golden: EvCheckout', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(_page()));
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/EvCheckout.png'));
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
