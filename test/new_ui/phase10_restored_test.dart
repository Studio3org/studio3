import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auction.dart';
import 'package:studio3/models/user_report.dart';
import 'package:studio3/screens/event_qr_codes_page.dart';
import 'package:studio3/screens/my_reports_page.dart';
import 'package:studio3/screens/payout_setup_page.dart';
import 'package:studio3/screens/series_view_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/piece_detail/manage_auction_sheet.dart';
import 'package:studio3/widgets/share/share_sheet.dart';
import 'package:studio3/widgets/studio/studio.dart';
import 'package:studio3/widgets/studio_message.dart';

import 'golden_harness.dart';

/// Phase 10: the screens restored from before commit 76f4ef9, moved onto the tokens and
/// components (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 14).
Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

/// Lets the page's first requests fail for real (no server in tests).
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
  await tester.pump();
}

AuctionSummary _auction({int bids = 3}) => AuctionSummary(
  auctionId: 'a1',
  status: 'live',
  startingBidCents: 36000,
  highestBidCents: 50000,
  bidCount: bids,
  minNextBidCents: 52000,
  endsAt: DateTime.now().add(const Duration(days: 2)),
);

/// A page with one button that opens [open].
Widget _opener(void Function(BuildContext context) open, {bool dark = false}) => _app(
  Builder(
    builder: (context) => Scaffold(
      body: Center(child: TextButton(onPressed: () => open(context), child: const Text('open'))),
    ),
  ),
  dark: dark,
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    final theme = dark ? 'dark' : 'light';

    testWidgets('My reports: rows with the status word ($theme)', (tester) async {
      await tester.pumpWidget(
        _app(
          MyReportsPage(
            debugReports: [
              UserReport(
                id: 'r1',
                targetType: 'piece',
                targetLabel: 'Blue Hour',
                reason: 'spam',
                status: 'pending',
                createdAt: DateTime(2026, 10, 1),
              ),
              UserReport(
                id: 'r2',
                targetType: 'user',
                targetLabel: '@max',
                reason: 'harassment',
                status: 'resolved',
                createdAt: DateTime(2026, 9, 1),
              ),
            ],
          ),
          dark: dark,
        ),
      );
      await tester.pump();
      expect(find.text('My reports'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Pending')).style!.color, c.textPrimary);
      expect(tester.widget<Text>(find.text('Resolved')).style!.color, c.textTertiary);
      expect(find.byType(StudioTopBar), findsOneWidget);
    });

    testWidgets('Manage auction: plain Ink rows; Cancel asks first ($theme)', (tester) async {
      await tester.pumpWidget(
        _opener((context) => ManageAuctionSheet.show(context, pieceId: 'p1', auction: _auction()), dark: dark),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Manage auction'), findsOneWidget);
      expect(find.text('Live, with 3 bids.'), findsOneWidget);
      final cancel = tester.widget<Text>(find.text('Cancel the auction'));
      expect(cancel.style!.color, c.textPrimary);
      await tester.tap(find.text('Cancel the auction'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel this auction?'), findsOneWidget);
      expect(_button('Keep it running'), findsOneWidget);
      await tester.tap(_button('Keep it running'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Extend the auction'));
      await tester.pumpAndSettle();
      expect(find.text('Extend by'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      expect(find.byType(SimpleDialog), findsNothing);
    });

    testWidgets('Share sheet: title and action rows ($theme)', (tester) async {
      await tester.pumpWidget(_opener((context) => ShareSheet.show(context, shareText: 'Look'), dark: dark));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Share'), findsOneWidget);
      for (final row in ['WhatsApp', 'Messages', 'More', 'Copy link']) {
        expect(find.text(row), findsOneWidget, reason: row);
      }
      expect(find.byType(StudioActionRow), findsNWidgets(4));
      expect(find.byType(Icon), findsNothing);
    });

    // `SeriesPage` (Phase 13, 17.7) replaced the earlier look; phase13_browse_test.dart covers it.
    testWidgets('Series: back, share, Edit series on your own, empty grid ($theme)', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          const SeriesViewPage(seriesId: 's1', initialName: 'Night Garden', initialPieceCount: 4, isOwner: true),
          dark: dark,
        ),
      );
      await _settle(tester);
      expect(find.text('Night Garden'), findsOneWidget);
      expect(find.text('SERIES · 4 PIECES'), findsOneWidget);
      for (final label in ['Back', 'Share']) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      expect(find.text('Edit series'), findsOneWidget);
      expect(find.text('No pieces in this series yet'), findsOneWidget);
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, c.background);
    });
  }

  testWidgets('Payout setup and room codes: the shared states when loading fails', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_app(const PayoutSetupPage()));
    await _settle(tester);
    expect(find.text('Payout details required'), findsOneWidget);
    expect(find.byType(StudioEmptyState), findsOneWidget);
    expect(find.byType(StudioTopBar), findsOneWidget);

    await tester.pumpWidget(_app(const EventQrCodesPage(eventId: 'e1', eventTitle: 'Night')));
    await _settle(tester);
    expect(find.text('Codes for the room'), findsOneWidget);
    expect(find.text("The codes didn't load"), findsOneWidget);
  });

  testWidgets('StudioMessage is the shared toast', (tester) async {
    await tester.pumpWidget(_opener((context) => StudioMessage.show(context, 'Saved it', isError: false)));
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.text('Saved it'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
