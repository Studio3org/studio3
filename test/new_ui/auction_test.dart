import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auction.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/screens/auction_flow.dart';
import 'package:studio3/screens/available_piece_detail_page.dart';
import 'package:studio3/services/api_exception.dart';
import 'package:studio3/services/bid_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/auction/auction_widgets.dart';
import 'package:studio3/widgets/piece_detail/collect_piece_sheet.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Flow 7, bidding: `BuyPieceScrolled`, `BidVerify`, `BidSheet`, `BidLeading`, `BidOutbid`,
/// `BidWon`, `BidCheckout`, `BidPaymentFailed`, `BidLost`, `BidReserveNotMet`
/// (docs/new-ui/NEW_UI_EXECUTION_PLAN.md).
final _now = DateTime(2026, 10, 25, 12);

AuctionSummary _auction({
  int? highest = 350000,
  int bids = 12,
  int minNext = 360000,
  Duration left = const Duration(days: 2, hours: 4, minutes: 5),
  bool hasReserve = true,
  bool reserveMet = false,
  bool highestBidder = false,
  String status = 'live',
  bool winner = false,
  bool awaitingPayment = false,
  DateTime? deadline,
  int? winning,
}) => AuctionSummary(
  auctionId: 'a1',
  status: status,
  startingBidCents: 36000,
  highestBidCents: highest,
  bidCount: bids,
  minNextBidCents: minNext,
  endsAt: _now.add(left),
  hasReserve: hasReserve,
  reserveMet: reserveMet,
  isHighestBidder: highestBidder,
  isWinner: winner,
  awaitingPayment: awaitingPayment,
  winnerDeadlineAt: deadline,
  winningBidCents: winning,
);

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

Widget _barHost(AuctionBarState state, AuctionSummary a, {bool dark = false}) => _app(
  Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: AuctionBar(auction: a, state: state, onPrimary: () {}, now: _now),
    ),
  ),
  dark: dark,
);

/// Opens [builder] as a Studio sheet from a button.
Widget _sheetHost(WidgetBuilder builder, void Function(Object?) onResult, {bool dark = false}) =>
    _app(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async =>
                onResult(await showStudioSheet<Object?>(context: context, builder: builder)),
            child: const Text('open'),
          ),
        ),
      ),
      dark: dark,
    );

const _card = SavedCard(id: 'pm_1', brand: 'visa', last4: '4242');

final _piece = PieceSummary(
  id: 'p1',
  title: 'Bodies in Color',
  authorName: 'Amara Osei',
  authorUsername: 'amarasart',
  isForSale: true,
  listingType: 'auction',
);

/// A fake card field: a switch that reports the card complete.
Widget _fakeCard(ValueChanged<bool> onComplete) => TextButton(
  onPressed: () => onComplete(true),
  child: const Text('4242 4242 4242 4242'),
);

/// The colour of the span reading [text] inside the rich text at [finder].
Color? _spanColor(WidgetTester tester, Finder finder, String text) {
  Color? found;
  tester.widget<RichText>(finder).text.visitChildren((span) {
    if (span is TextSpan && span.text == text) found = span.style?.color;
    return found == null;
  });
  return found;
}

Finder _info(String label) =>
    find.byWidgetPredicate((w) => w is StudioInfoButton && w.semanticLabel == label);

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('auction_test').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BidStore.instance.debugSet();
  });

  group('rules', () {
    test('increments: \$25 under \$500, \$50 to \$999, \$100 to \$4,999, \$250 to \$9,999, \$500 above', () {
      expect(bidIncrementCents(49900), 2500);
      expect(bidIncrementCents(50000), 5000);
      expect(bidIncrementCents(99900), 5000);
      expect(bidIncrementCents(100000), 10000);
      expect(bidIncrementCents(499900), 10000);
      expect(bidIncrementCents(500000), 25000);
      expect(bidIncrementCents(1000000), 50000);
      expect(bidQuickPicks(360000), [360000, 370000, 380000]);
    });

    test('time left and the countdown', () {
      expect(auctionTimeLeft(_now.add(const Duration(days: 2, hours: 4)), _now), '2d 4h');
      expect(auctionTimeLeft(_now.add(const Duration(hours: 5, minutes: 12)), _now), '5h 12m');
      expect(auctionTimeLeft(_now.add(const Duration(minutes: 42)), _now), '42m');
      expect(auctionTimeLeft(_now.subtract(const Duration(minutes: 1)), _now), 'Ended');
      expect(auctionEndingSoon(_now.add(const Duration(hours: 23)), _now), isTrue);
      expect(auctionEndingSoon(_now.add(const Duration(hours: 25)), _now), isFalse);
      expect(auctionCountdown(_now.add(const Duration(hours: 47, minutes: 52)), _now), '47h 52m');
      expect(auctionDateTime(DateTime(2026, 11, 2, 18, 40)), 'Nov 2 · 6:40 PM');
    });

    test('the server bid summary reads into an auction; no auctionId means none', () {
      final a = AuctionSummary.maybeFrom({
        'auctionId': 'a1',
        'auctionStatus': 'live',
        'startingBidCents': 36000,
        'highestBidCents': 350000,
        'bidCount': 12,
        'minNextBidCents': 360000,
        'auctionEndsAt': '2026-10-27T16:00:00Z',
        'hasReserve': true,
        'reserveMet': false,
        'isHighestBidder': true,
      })!;
      expect((a.currentCents, a.bidCount, a.minNextBidCents, a.isOpen), (350000, 12, 360000, true));
      expect((a.hasReserve, a.reserveMet, a.isHighestBidder), (true, false, true));
      expect(AuctionSummary.maybeFrom({'priceCents': 1}), isNull);
      final piece = PieceSummary.fromJson({
        'id': 'p1',
        'title': 'T',
        'listingType': 'auction',
        'auctionId': 'a1',
        'bidCount': 3,
      });
      expect((piece.isAuction, piece.auction!.bidCount), (true, 3));
      expect(PieceSummary.fromJson(piece.toJson()).auction!.auctionId, 'a1');
    });

    test('bar state from the auction and the viewer', () {
      AuctionBarState s(AuctionSummary? a, {bool owner = false, int? mine}) =>
          auctionBarState(auction: a, isOwner: owner, myTopBidCents: mine);
      expect(s(_auction()), AuctionBarState.open);
      expect(s(_auction(highestBidder: true), mine: 360000), AuctionBarState.leading);
      expect(s(_auction(), mine: 360000), AuctionBarState.outbid);
      expect(s(_auction(), owner: true), AuctionBarState.owner);
      expect(s(_auction(status: 'awaiting_winner', winner: true)), AuctionBarState.won);
      expect(
        s(_auction(status: 'awaiting_payment', winner: true, awaitingPayment: true)),
        AuctionBarState.paymentFailed,
      );
      expect(s(_auction(status: 'awaiting_winner')), AuctionBarState.ended);
      expect(s(null), AuctionBarState.ended);
    });
  });

  group('bar', () {
    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      final t = dark ? 'dark' : 'light';
      testWidgets('open: current bid, bids in Mono, time remaining, Place a bid ($t)', (
        tester,
      ) async {
        await tester.pumpWidget(_barHost(AuctionBarState.open, _auction(hasReserve: false), dark: dark));
        expect(
          find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == 'Current bid · 12 bids',
          ),
          findsOneWidget,
        );
        expect(find.text(r'$3,500'), findsOneWidget);
        expect(find.text('Time remaining'), findsOneWidget);
        expect(tester.widget<Text>(find.text('2d 4h')).style!.color, c.textPrimary);
        expect(find.text('Place a bid'), findsOneWidget);
        expect(find.text('Reserve not met yet'), findsNothing);
      });

      testWidgets('leading: green "Your bid" with its line, reserve note, Raise your bid ($t)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _barHost(AuctionBarState.leading, _auction(highest: 360000, highestBidder: true), dark: dark),
        );
        final status = find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().startsWith('Your bid'),
        );
        expect(status, findsOneWidget);
        expect(_spanColor(tester, status, 'Your bid'), c.positive);
        expect(
          tester.widgetList<Container>(find.byType(Container)).any((w) => w.color == c.positive),
          isTrue,
        );
        expect(find.text(r'$3,600'), findsOneWidget);
        expect(tester.widget<Text>(find.text('Reserve not met yet')).style!.fontFamily, contains('Mono'));
        expect(find.text('Raise your bid'), findsOneWidget);
      });

      testWidgets('outbid in the final hours: red status and time, Bid the next minimum ($t)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _barHost(
            AuctionBarState.outbid,
            _auction(highest: 370000, minNext: 380000, left: const Duration(minutes: 42)),
            dark: dark,
          ),
        );
        final status = find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().startsWith('Outbid'),
        );
        expect(_spanColor(tester, status, 'Outbid'), c.alert);
        final time = tester.widget<Text>(find.text('42m'));
        expect((time.style!.color, time.style!.fontWeight), (c.alert, StudioType.medium));
        expect(find.text(r'Bid $3,800'), findsOneWidget);
      });
    }

    testWidgets("the artist's own auction offers Manage auction, not bidding", (tester) async {
      await tester.pumpWidget(_barHost(AuctionBarState.owner, _auction()));
      expect(tester.widget<StudioButton>(find.byType(StudioButton)).onPressed, isNotNull);
      expect(find.text('Manage auction'), findsOneWidget);
      expect(find.text('Place a bid'), findsNothing);
    });

    testWidgets('on the piece page an auction piece gets the auction bar', (tester) async {
      setBoardViewport(tester);
      final item = FeedPreviewItem.fromPieceSummary(_piece).copyWith();
      await tester.pumpWidget(
        _app(
          AvailablePieceDetailPage(
            item: FeedPreviewItem(
              id: 'p1',
              imageSeeds: const [1],
              title: item.title,
              medium: 'Oil',
              year: 2025,
              dimensions: '24 × 36 in',
              story: '',
              handle: '@amarasart',
              isAvailable: true,
              aspectRatio: FeedAspectRatio.portrait3x4,
              listingType: 'auction',
              auction: _auction(left: const Duration(days: 30)),
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(find.byType(AuctionBar), findsOneWidget);
      expect(find.text('Place a bid'), findsOneWidget);
      expect(find.text('Collect'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });
  });

  group('add a card', () {
    for (final dark in [false, true]) {
      testWidgets('title, card, ZIP with its note; Save off until both; returns the card (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        Object? result;
        final zips = <String>[];
        await tester.pumpWidget(
          _sheetHost(
            (_) => BidVerifySheet(
              cardField: _fakeCard,
              saveCard: (zip) async {
                zips.add(zip);
                return 'pm_new';
              },
            ),
            (r) => result = r,
            dark: dark,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Add a card to bid'), findsOneWidget);
        expect(find.text("We'll check it's valid. You're only charged if you win."), findsOneWidget);
        expect(find.text('We use your ZIP to estimate shipping before you bid.'), findsOneWidget);
        StudioButton save() =>
            tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Save card and continue'));
        expect(save().onPressed, isNull);
        await tester.tap(find.text('4242 4242 4242 4242'));
        await tester.enterText(find.byType(TextField), '75225');
        await tester.pump();
        expect(save().onPressed, isNotNull);
        await tester.tap(find.text('Save card and continue'));
        await tester.pumpAndSettle();
        expect(result, 'pm_new');
        expect(zips, ['75225']);
      });
    }

    testWidgets('a declined card stays on the sheet with the reason', (tester) async {
      await tester.pumpWidget(
        _sheetHost(
          (_) => BidVerifySheet(
            cardField: _fakeCard,
            saveCard: (_) async => throw ApiException('Your card was declined.'),
          ),
          (_) {},
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4242 4242 4242 4242'));
      await tester.enterText(find.byType(TextField), '75225');
      await tester.pump();
      await tester.tap(find.text('Save card and continue'));
      await tester.pumpAndSettle();
      expect(find.text('Your card was declined.'), findsOneWidget);
      expect(find.text('Add a card to bid'), findsOneWidget);
    });
  });

  group('bid sheet', () {
    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('amounts, the minimum, three picks, reserve, Bid \$X, fine print (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        Object? result;
        final placed = <int>[];
        await tester.pumpWidget(
          _sheetHost(
            (_) => BidSheet(
              pieceId: 'p1',
              auction: _auction(),
              card: _card,
              now: _now,
              placeBid: (cents) async {
                placed.add(cents);
                return _auction(highest: cents, highestBidder: true);
              },
            ),
            (r) => result = r,
            dark: dark,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Your bid'), findsOneWidget);
        expect(find.text(r'at least $3,600'), findsOneWidget);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect((field.controller!.text, field.style!.fontSize), (r'$3,600', 32));
        // Quick picks: the minimum (selected), then one and two steps up.
        for (final pick in [r'$3,600', r'$3,700', r'$3,800']) {
          expect(find.widgetWithText(GestureDetector, pick), findsWidgets);
        }
        expect(find.text('Reserve not met yet'), findsOneWidget);
        await tester.tap(_info('What is the reserve?'));
        await tester.pump();
        expect(find.textContaining('This changes to Reserve met'), findsOneWidget);
        await tester.tap(find.text('Your bid'));
        await tester.pump();
        expect(
          find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().contains('card ending 4242'),
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(r'$3,800'));
        await tester.pump();
        expect(find.text(r'Bid $3,800'), findsOneWidget);
        expect(tester.widget<Text>(find.text('2d 4h')).style!.color, c.textPrimary);
        await tester.tap(find.text(r'Bid $3,800'));
        await tester.pumpAndSettle();
        expect(placed, [380000]);
        expect((result! as AuctionSummary).isHighestBidder, isTrue);
      });
    }

    testWidgets('below the minimum, Bid is off', (tester) async {
      await tester.pumpWidget(
        _sheetHost(
          (_) => BidSheet(pieceId: 'p1', auction: _auction(), card: _card, now: _now),
          (_) {},
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3000');
      await tester.pump();
      expect(tester.widget<StudioButton>(find.byType(StudioButton)).onPressed, isNull);
    });

    testWidgets('a bid the server now finds too low keeps what was typed and says why', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sheetHost(
          (_) => BidSheet(
            pieceId: 'p1',
            auction: _auction(),
            card: _card,
            now: _now,
            placeBid: (_) async =>
                throw ApiException(r'Bid must be at least $3,700.00.', statusCode: 409),
            refresh: () async => _auction(highest: 360000, minNext: 370000),
          ),
          (_) {},
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(r'Bid $3,600'));
      await tester.pumpAndSettle();
      expect(find.text(r'Bid must be at least $3,700.00.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, r'$3,600');
      expect(find.text(r'at least $3,700'), findsOneWidget);
    });
  });

  group('results', () {
    for (final dark in [false, true]) {
      testWidgets('won: label, title, winning bid, time to pay, Finish checkout (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        setBoardViewport(tester);
        await tester.pumpWidget(
          _app(
            AuctionResultPage.won(
              piece: _piece,
              auction: _auction(
                status: 'awaiting_winner',
                winner: true,
                winning: 370000,
                deadline: _now.add(const Duration(hours: 47, minutes: 52)),
              ),
              now: _now,
            ),
            dark: dark,
          ),
        );
        expect(find.text('AUCTION WON'), findsOneWidget);
        expect(find.text('Bodies in Color is yours'), findsOneWidget);
        expect(find.text('By Amara Osei. Confirm shipping and pay to bring it home.'), findsOneWidget);
        expect(find.text(r'$3,700'), findsOneWidget);
        expect(find.text('47h 52m'), findsOneWidget);
        expect(find.text('Finish checkout'), findsOneWidget);
        expect(find.byType(ColorFiltered), findsOneWidget);
      });
    }

    testWidgets('lost: final bid and your top bid, See more from the artist', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          AuctionResultPage.lost(
            piece: _piece,
            auction: _auction(highest: 370000, status: 'awaiting_winner'),
            myTopBidCents: 360000,
          ),
        ),
      );
      expect(find.text('AUCTION ENDED'), findsOneWidget);
      expect(find.text('Bodies in Color went to another collector'), findsOneWidget);
      expect(find.text('Thanks for bidding. Nothing was charged.'), findsOneWidget);
      expect(find.text('Final bid'), findsOneWidget);
      expect(find.text('Your top bid'), findsOneWidget);
      expect(find.text('See more from Amara'), findsOneWidget);
      expect(find.text('Back to Explore'), findsOneWidget);
    });

    testWidgets('reserve not met: closed without selling, Save to hear if it comes back', (
      tester,
    ) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(AuctionResultPage.reserveNotMet(piece: _piece, myTopBidCents: 320000)),
      );
      expect(find.text('AUCTION CLOSED'), findsOneWidget);
      expect(find.text('Closed without selling'), findsOneWidget);
      expect(find.text('Save to hear if it comes back'), findsOneWidget);
      expect(find.text(r'$3,200'), findsOneWidget);
    });

    testWidgets('payment failed: time left, the card, Update card and try again', (tester) async {
      setBoardViewport(tester);
      final retried = <String>[];
      await tester.pumpWidget(
        _app(
          BidPaymentFailedPage(
            piece: _piece,
            auction: _auction(
              status: 'awaiting_payment',
              winner: true,
              awaitingPayment: true,
              deadline: DateTime.now().add(const Duration(hours: 23, minutes: 41, seconds: 30)),
            ),
            debugCard: _card,
            retry: (id) async {
              retried.add(id);
              throw ApiException('That card was declined too.');
            },
            newCard: () async => 'pm_2',
          ),
        ),
      );
      expect(find.text("Your card didn't go through"), findsOneWidget);
      // The ! ring and the title in red; the line under it stays Graphite (`BidPaymentFailed`).
      expect(tester.widget<Text>(find.text("Your card didn't go through")).style!.color, StudioColors.light.alert);
      expect(tester.widget<Text>(find.text('!')).style!.color, StudioColors.light.alert);
      expect(
        find.text('Bodies in Color is still yours. Update your card to finish paying.'),
        findsOneWidget,
      );
      expect(find.text('23h 41m'), findsOneWidget);
      expect(find.text('Visa ending 4242 · declined'), findsOneWidget);
      await tester.tap(find.text('Try the same card again'));
      await tester.pump();
      await tester.tap(find.text('Update card'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(retried, ['pm_1', 'pm_2']);
    });
  });

  testWidgets('winner checkout: won at auction, time left, card, Winning bid, Pay and collect', (
    tester,
  ) async {
    setBoardViewport(tester);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: CollectPieceSheet(
            item: FeedPreviewItem.fromPieceSummary(_piece),
            auction: _auction(
              status: 'awaiting_winner',
              winner: true,
              winning: 370000,
              deadline: DateTime.now().add(const Duration(hours: 47, minutes: 52, seconds: 30)),
            ),
            debugCard: _card,
          ),
        ),
      ),
    );
    expect(find.text('Amara Osei · won at auction'), findsOneWidget);
    expect(find.text('Time left to pay'), findsOneWidget);
    expect(find.text('47h 52m'), findsOneWidget);
    expect(find.text('Visa ending 4242'), findsOneWidget);
    expect(find.text('Winning bid'), findsOneWidget);
    expect(find.text(r'$3,700.00'), findsOneWidget);
    expect(find.text('Sales tax'), findsOneWidget);
    expect(find.text('Pay and collect'), findsOneWidget);
  });

  group('goldens', () {
    final skip = Platform.environment['NEW_UI_GOLDENS'] != '1';

    Future<void> sheet(WidgetTester tester, WidgetBuilder builder, String name) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_sheetHost(builder, (_) {}));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
      await checkAcceptance(tester);
    }

    testWidgets('BidVerify', (tester) async {
      await sheet(tester, (_) => const BidVerifySheet(cardField: _fakeCard), 'BidVerify');
    }, skip: skip);

    testWidgets('BidSheet', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _sheetHost(
          (_) => BidSheet(pieceId: 'p1', auction: _auction(), card: _card, now: _now),
          (_) {},
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(_info('What is the reserve?'));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/BidSheet.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    for (final (name, state, a) in [
      ('BuyPieceScrolled_bar', AuctionBarState.open, _auction(hasReserve: false)),
      ('BidLeading_bar', AuctionBarState.leading, _auction(highest: 360000, highestBidder: true)),
      (
        'BidOutbid_bar',
        AuctionBarState.outbid,
        _auction(highest: 370000, minNext: 380000, left: const Duration(minutes: 42)),
      ),
    ]) {
      testWidgets(name, (tester) async {
        setBoardViewport(tester);
        await tester.pumpWidget(_barHost(state, a));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
        await checkAcceptance(tester);
      }, skip: skip);
    }

    testWidgets('BidPaymentFailed', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          BidPaymentFailedPage(
            piece: _piece,
            auction: _auction(
              status: 'awaiting_payment',
              winner: true,
              awaitingPayment: true,
              deadline: DateTime.now().add(const Duration(hours: 23, minutes: 41, seconds: 30)),
            ),
            debugCard: _card,
          ),
        ),
      );
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/BidPaymentFailed.png'));
      await checkAcceptance(tester);
    }, skip: skip);
  });
}
