import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/address.dart';
import 'package:studio3/models/auction.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/screens/auction_flow.dart';
import 'package:studio3/screens/available_piece_detail_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/api_exception.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/bid_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/auction/artist_auction.dart' show winnerDeadlinePhrase;
import 'package:studio3/widgets/auction/auction_widgets.dart';
import 'package:studio3/widgets/piece_detail/collect_piece_sheet.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Flow 7, bidding: `BuyPieceScrolled`, `BidVerify`, `BidSheet`, `BidLeading`, `BidOutbid`,
/// `BidWon`, `BidCheckout`, `BidPaymentFailed`, `BidLost`, `BidReserveNotMet`
/// (docs/new-ui/NEW_UI_EXECUTION_PLAN.md).
final _now = DateTime(2026, 10, 25, 12);

const _studio = Address(
  id: 'a1',
  firstName: 'Jordan',
  lastName: 'Lee',
  phone: '2145550100',
  line1: '4521 Lovers Ln',
  city: 'Dallas',
  state: 'TX',
  zip: '75225',
  country: 'US',
  isDefault: true,
);

const _home = Address(
  id: 'a2',
  firstName: 'Jordan',
  lastName: 'Lee',
  phone: '2145550100',
  line1: '88 Elm St',
  city: 'Austin',
  state: 'TX',
  zip: '78701',
  country: 'US',
);

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
  int increment = 0,
  DateTime? retryAt,
  SecondChanceOffer? offer,
  AutoCheckout? autoCheckout,
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
  bidIncrementCents: increment,
  paymentRetryAt: retryAt,
  secondChanceOffer: offer,
  autoCheckout: autoCheckout,
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

/// Stripe's PaymentSheet stand-in: the card it saved.
Future<SavedCard?> _fakeSheet() async => const SavedCard(id: 'pm_new', brand: 'visa', last4: '4242');

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

    // BACKEND_CHANGES B18: the server's own-bid status comes first, from any phone.
    test("the server's own-bid status wins over this phone's", () {
      AuctionBarState s({String? status, int? mine}) =>
          auctionBarState(auction: _auction(), isOwner: false, myTopBidCents: mine, myBidStatus: status);
      // Bid from another phone: this one remembers nothing, the server says outbid.
      expect(s(status: 'outbid', mine: 360000), AuctionBarState.outbid);
      // A bid this phone remembers from an earlier run: the server says none in this one.
      expect(s(status: 'none', mine: 360000), AuctionBarState.open);
      // No word from the server: this phone's memory, as before.
      expect(s(mine: 360000), AuctionBarState.outbid);
      expect(s(), AuctionBarState.open);

      final piece = PieceSummary.fromJson({
        'id': 'p1',
        'title': 'Bodies in Color',
        'listingType': 'auction',
        'myTopBidCents': 360000,
        'myBidStatus': 'lost',
      });
      expect((piece.myTopBidCents, piece.myBidStatus), (360000, 'lost'));
      final item = FeedPreviewItem.fromPieceSummary(piece);
      expect((item.myTopBidCents, item.myBidStatus), (360000, 'lost'));
      final back = FeedPreviewItem.fromCacheJson(item.toJson());
      expect((back.myTopBidCents, back.myBidStatus), (360000, 'lost'));
      expect(PieceSummary.fromJson({'id': 'p1', 'title': 'T'}).myBidStatus, isNull);
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

  group('before you bid', () {
    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('title, boxed Card row, Ship to the default address; Save off until the card; '
          'returns the card and the address (${dark ? 'dark' : 'light'})', (tester) async {
        Object? result;
        var sheets = 0;
        await tester.pumpWidget(
          _sheetHost(
            (_) => BidVerifySheet(
              debugAddresses: const [_studio, _home],
              saveCard: () {
                sheets++;
                return _fakeSheet();
              },
            ),
            (r) => result = r,
            dark: dark,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Before you bid'), findsOneWidget);
        expect(find.text('If you win, this card is charged when the auction ends.'), findsOneWidget);
        // The card sits in a 10 radius box, Line Strong outline (`BidVerify`).
        final box = tester.widget<Container>(find.byKey(const Key('bid-verify-card')));
        final deco = box.decoration! as BoxDecoration;
        expect(deco.borderRadius, BorderRadius.circular(10));
        expect(deco.color, c.card);
        expect((deco.border! as Border).top.color, c.lineStrong);
        // Ship to: the default address on one line, not a ZIP field.
        expect(find.text('Ship to'), findsOneWidget);
        expect(find.text('Jordan Lee, 4521 Lovers Ln, Dallas, TX 75225'), findsOneWidget);
        expect(find.text('ZIP'), findsNothing);
        expect(find.text('Saving lets us charge this card if you win. Bidding terms'), findsOneWidget);
        StudioButton save() => tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Save and continue'));
        expect(save().onPressed, isNull);
        // The Card row opens Stripe's sheet (PaymentSheet, with Apple Pay when configured).
        expect(find.text('Card'), findsOneWidget);
        expect(find.text('Add your card'), findsOneWidget);
        await tester.tap(find.byKey(const Key('bid-verify-card')));
        await tester.pumpAndSettle();
        expect(sheets, 1);
        expect(find.text('Visa ending 4242'), findsOneWidget);
        expect(save().onPressed, isNotNull);
        await tester.tap(find.text('Save and continue'));
        await tester.pumpAndSettle();
        expect(result, (paymentMethodId: 'pm_new', addressId: 'a1'));
        expect(await BidStore.instance.zip(), '75225');
      });
    }

    testWidgets('Ship to opens the picker; no address yet holds Save', (tester) async {
      Object? result;
      await tester.pumpWidget(
        _sheetHost(
          (_) => BidVerifySheet(
            debugAddresses: const [],
            pickAddress: (current) async => _home,
            saveCard: _fakeSheet,
          ),
          (r) => result = r,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Add your address'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bid-verify-card')));
      await tester.pumpAndSettle();
      expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Save and continue')).onPressed, isNull);
      await tester.tap(find.byKey(const Key('bid-verify-ship-to')));
      await tester.pumpAndSettle();
      expect(find.text('Jordan Lee, 88 Elm St, Austin, TX 78701'), findsOneWidget);
      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();
      expect(result, (paymentMethodId: 'pm_new', addressId: 'a2'));
      expect(await BidStore.instance.zip(), '78701');
    });

    testWidgets('closing Stripe\'s sheet leaves the card empty and Save off', (tester) async {
      await tester.pumpWidget(
        _sheetHost(
          (_) => BidVerifySheet(debugAddresses: const [_studio], saveCard: () async => null),
          (_) {},
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bid-verify-card')));
      await tester.pumpAndSettle();
      expect(find.text('Add your card'), findsOneWidget);
      expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Save and continue')).onPressed, isNull);
    });

    testWidgets('a declined card stays on the sheet with the reason', (tester) async {
      await tester.pumpWidget(
        _sheetHost(
          (_) => BidVerifySheet(
            debugAddresses: const [_studio],
            saveCard: () async => throw ApiException('Your card was declined.'),
          ),
          (_) {},
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bid-verify-card')));
      await tester.pumpAndSettle();
      expect(find.text('Your card was declined.'), findsOneWidget);
      expect(find.text('Before you bid'), findsOneWidget);
      expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Save and continue')).onPressed, isNull);
    });

    testWidgets('updating the card after a decline: just the card, no Ship to', (tester) async {
      Object? result;
      await tester.pumpWidget(
        _sheetHost((_) => const BidVerifySheet(shipTo: false, saveCard: _fakeSheet), (r) => result = r),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Add a card'), findsOneWidget);
      expect(find.text('Ship to'), findsNothing);
      await tester.tap(find.byKey(const Key('bid-verify-card')));
      await tester.pumpAndSettle();
      expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Save and continue')).onPressed, isNotNull);
      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();
      expect(result, (paymentMethodId: 'pm_new', addressId: null));
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
        expect(
          find.text("The artist's private minimum. Below it, the piece doesn't sell and no one is charged."),
          findsOneWidget,
        );
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
      expect(find.text("Bids didn't reach the artist's minimum. Nothing was charged."), findsOneWidget);
      expect(find.text('Save to hear if it comes back'), findsOneWidget);
      expect(find.text(r'$3,200'), findsOneWidget);
    });

    testWidgets('payment failed: time left, the card, Use another card and try again', (tester) async {
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
        find.text('Still yours. Update your card in time or it goes to the next bidder.'),
        findsOneWidget,
      );
      expect(find.text('23h 41m'), findsOneWidget);
      expect(find.text('Visa ending 4242 · declined'), findsOneWidget);
      await tester.tap(find.text('Try the same card again'));
      await tester.pump();
      await tester.tap(find.text('Use another card'));
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

  // FRONTEND_HANDOFF 7a and 7b: auctions v2.
  group('auctions v2', () {
    // Fresh per test: built once at load, a slow run could pass the 30 s margin before the
    // countdown test reads "20h 10m".
    late SecondChanceOffer offer;
    setUp(() {
      offer = SecondChanceOffer(
        amountCents: 360000,
        expiresAt: DateTime.now().add(const Duration(hours: 20, minutes: 10, seconds: 30)),
      );
    });

    test('bar state: the offered bidder accepts; everyone else sees it ended; shipping pending', () {
      AuctionBarState s(AuctionSummary a, {bool owner = false}) =>
          auctionBarState(auction: a, isOwner: owner, myTopBidCents: null, myBidStatus: 'outbid');
      expect(s(_auction(status: 'second_chance', offer: offer)), AuctionBarState.secondChance);
      expect(s(_auction(status: 'second_chance')), AuctionBarState.ended);
      expect(s(_auction(status: 'second_chance'), owner: true), AuctionBarState.ended);
      AuctionSummary won(String? state) => _auction(
        status: 'awaiting_winner',
        winner: true,
        autoCheckout: state == null ? null : AutoCheckout(state: state),
      );
      expect(s(won('pending_quote')), AuctionBarState.shippingPending);
      for (final state in ['failed', 'manual', null]) {
        expect(s(won(state)), AuctionBarState.won, reason: '$state');
      }
    });

    testWidgets('bar: Accept for the offer, with its countdown', (tester) async {
      await tester.pumpWidget(
        _barHost(AuctionBarState.secondChance, _auction(status: 'second_chance', offer: offer)),
      );
      expect(find.text(r'Accept for $3,600'), findsOneWidget);
      expect(find.text('Offer ends in'), findsOneWidget);
      expect(tester.widget<StudioButton>(find.byType(StudioButton)).onPressed, isNotNull);
    });

    testWidgets('bar: shipping price on its way never opens checkout', (tester) async {
      await tester.pumpWidget(
        _barHost(
          AuctionBarState.shippingPending,
          _auction(status: 'awaiting_winner', winner: true, autoCheckout: const AutoCheckout(state: 'pending_quote')),
        ),
      );
      expect(find.text('Shipping price on its way'), findsOneWidget);
      expect(find.text('Finish checkout'), findsNothing);
      expect(tester.widget<StudioButton>(find.byType(StudioButton)).onPressed, isNull);
    });

    test("quick picks step by the server's increment, else the table on the high bid", () {
      // Backward compatible: no step given, the table on the minimum.
      expect(bidQuickPicks(360000), [360000, 370000, 380000]);
      expect(bidQuickPicks(360000, stepCents: 25000), [360000, 385000, 410000]);
      expect(bidQuickPicks(360000, stepCents: 0), [360000, 370000, 380000]);
    });

    testWidgets("bid sheet picks use the server's increment", (tester) async {
      await tester.pumpWidget(
        _sheetHost(
          (_) => BidSheet(pieceId: 'p1', auction: _auction(increment: 25000), card: _card, now: _now),
          (_) {},
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      for (final pick in [r'$3,600', r'$3,850', r'$4,100']) {
        expect(find.widgetWithText(GestureDetector, pick), findsWidgets, reason: pick);
      }
    });

    testWidgets('bid sheet picks without one: the table on the current high bid', (tester) async {
      // High bid $950 (step $50), minimum $1,000: $1,000, $1,050, $1,100.
      await tester.pumpWidget(
        _sheetHost(
          (_) => BidSheet(
            pieceId: 'p1',
            auction: _auction(highest: 95000, minNext: 100000),
            card: _card,
            now: _now,
          ),
          (_) {},
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      for (final pick in [r'$1,050', r'$1,100']) {
        expect(find.widgetWithText(GestureDetector, pick), findsWidgets, reason: pick);
      }
    });

    testWidgets('fine print: charged only if they win; shipping follows automatically', (tester) async {
      await tester.pumpWidget(
        _sheetHost((_) => BidSheet(pieceId: 'p1', auction: _auction(), card: _card, now: _now), (_) {}),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final print = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('card ending 4242 is charged only if you win'),
      );
      expect(print, findsOneWidget);
      expect(
        tester.widget<RichText>(print).text.toPlainText(),
        contains('shipping, insurance and tax follow on it automatically'),
      );
    });

    group('the bid call', () {
      late _BidServer server;
      setUp(() {
        server = _BidServer();
        ApiClient.instance.debugUseAdapter(server);
        AuthSession.instance.accessToken = 'token';
      });
      tearDown(() => AuthSession.instance.accessToken = null);

      Future<void> bid(WidgetTester tester, BidSheet sheet) async {
        await tester.pumpWidget(_sheetHost((_) => sheet, (_) {}));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await _tapBidAndWait(tester);
        await tester.pumpAndSettle();
      }

      testWidgets('sends the Ship to picked in Before you bid', (tester) async {
        await bid(tester, BidSheet(pieceId: 'p1', auction: _auction(), card: _card, addressId: 'a1', now: _now));
        expect(server.bids.single, {'amountCents': 360000, 'paymentMethodId': 'pm_1', 'addressId': 'a1'});
      });

      testWidgets('no address: none sent', (tester) async {
        await bid(tester, BidSheet(pieceId: 'p1', auction: _auction(), card: _card, now: _now));
        expect(server.bids.single, {'amountCents': 360000, 'paymentMethodId': 'pm_1'});
      });

      testWidgets("a returning bidder's first bid here: Ship to in the sheet, and its address goes", (
        tester,
      ) async {
        await tester.pumpWidget(
          _sheetHost(
            (_) => BidSheet(
              pieceId: 'p1',
              auction: _auction(),
              card: _card,
              shipTo: true,
              debugAddresses: const [_studio, _home],
              pickAddress: (_) async => _home,
              now: _now,
            ),
            (_) {},
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Ship to'), findsOneWidget);
        expect(find.text('Jordan Lee, 4521 Lovers Ln, Dallas, TX 75225'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('bid-sheet-ship-to')));
        await tester.tap(find.byKey(const Key('bid-sheet-ship-to')));
        await tester.pumpAndSettle();
        expect(find.text('Jordan Lee, 88 Elm St, Austin, TX 78701'), findsOneWidget);
        await _tapBidAndWait(tester);
        await tester.pumpAndSettle();
        expect(server.bids.single['addressId'], 'a2');
      });
    });

    testWidgets('a bidder with a bid here already: no Ship to in the sheet', (tester) async {
      await tester.pumpWidget(
        _sheetHost((_) => BidSheet(pieceId: 'p1', auction: _auction(), card: _card, now: _now), (_) {}),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Ship to'), findsNothing);
    });

    testWidgets("payment failed: when it tries again; Use another card; then the piece as it now is", (
      tester,
    ) async {
      setBoardViewport(tester);
      final retried = <String>[];
      final retryAt = DateTime.now().add(const Duration(hours: 1));
      await tester.pumpWidget(
        _app(
          BidPaymentFailedPage(
            piece: _piece,
            auction: _auction(
              status: 'awaiting_payment',
              winner: true,
              awaitingPayment: true,
              deadline: DateTime.now().add(const Duration(hours: 11)),
              retryAt: retryAt,
            ),
            debugCard: _card,
            retry: (id) async => retried.add(id),
            newCard: () async => 'pm_2',
            // The fresh piece: paid, delivery being priced (7b).
            reload: () async => PieceSummary(
              id: 'p1',
              title: 'Bodies in Color',
              authorName: 'Amara Osei',
              listingType: 'auction',
              auction: _auction(
                status: 'awaiting_winner',
                winner: true,
                winning: 370000,
                autoCheckout: const AutoCheckout(state: 'pending_quote'),
              ),
            ),
          ),
        ),
      );
      expect(
        find.textContaining("We'll try again at ${winnerDeadlinePhrase(retryAt, DateTime.now()).split(' ').first}"),
        findsOneWidget,
      );
      expect(find.text('Update card'), findsNothing);
      await tester.tap(find.text('Use another card'));
      await tester.pumpAndSettle();
      expect(retried, ['pm_2']);
      expect(find.text('AUCTION WON'), findsOneWidget);
      expect(find.text('Shipping price on its way'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('payment failed without a retry planned: no retry line', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          BidPaymentFailedPage(
            piece: _piece,
            auction: _auction(status: 'awaiting_payment', winner: true, awaitingPayment: true),
            debugCard: _card,
          ),
        ),
      );
      expect(find.textContaining("We'll try again"), findsNothing);
    });

    testWidgets('won with the shipping price on its way: no checkout', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          AuctionResultPage.won(
            piece: _piece,
            auction: _auction(
              status: 'awaiting_winner',
              winner: true,
              winning: 370000,
              autoCheckout: const AutoCheckout(state: 'pending_quote'),
            ),
            now: _now,
          ),
        ),
      );
      expect(find.text('Finish checkout'), findsNothing);
      expect(find.text('Shipping price on its way'), findsOneWidget);
      expect(
        tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Shipping price on its way')).onPressed,
        isNull,
      );
      expect(find.textContaining('Nothing more to do.'), findsOneWidget);
    });

    testWidgets('won, failed or manual delivery: Finish checkout as before', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          AuctionResultPage.won(
            piece: _piece,
            auction: _auction(status: 'awaiting_winner', winner: true, autoCheckout: const AutoCheckout(state: 'failed')),
            now: _now,
          ),
        ),
      );
      expect(find.text('Finish checkout'), findsOneWidget);
    });

    group('second chance', () {
      final wonPiece = PieceSummary(
        id: 'p1',
        title: 'Bodies in Color',
        authorName: 'Amara Osei',
        listingType: 'auction',
        auction: _auction(status: 'awaiting_winner', winner: true, winning: 360000),
      );

      Widget page({
        SecondChanceOffer? withOffer,
        Future<void> Function(String?)? accept,
        Future<void> Function()? decline,
        Future<String?> Function()? newCard,
      }) => _app(
        SecondChancePage(
          piece: _piece,
          auction: _auction(status: 'second_chance', offer: withOffer ?? offer),
          accept: accept,
          decline: decline,
          newCard: newCard,
          reload: () async => wonPiece,
        ),
      );

      testWidgets('the amount, the countdown; Accept and pay, then the win', (tester) async {
        setBoardViewport(tester);
        final accepted = <String?>[];
        await tester.pumpWidget(page(accept: (id) async => accepted.add(id)));
        expect(find.text('Bodies in Color can still be yours'), findsOneWidget);
        expect(find.text(r'$3,600'), findsOneWidget);
        expect(find.text('20h 10m'), findsOneWidget);
        expect(find.text('No thanks'), findsOneWidget);
        await tester.tap(find.text('Accept and pay'));
        await tester.pumpAndSettle();
        expect(accepted, [null]);
        expect(find.text('AUCTION WON'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
      });

      testWidgets('declined (402): the reason, then Use another card pays with it', (tester) async {
        setBoardViewport(tester);
        final accepted = <String?>[];
        await tester.pumpWidget(
          page(
            accept: (id) async {
              accepted.add(id);
              if (id == null) {
                throw ApiException(
                  'Your card was declined. Try another card before the offer runs out.',
                  statusCode: 402,
                );
              }
            },
            newCard: () async => 'pm_2',
          ),
        );
        await tester.tap(find.text('Accept and pay'));
        await tester.pumpAndSettle();
        expect(find.text('Your card was declined. Try another card before the offer runs out.'), findsOneWidget);
        await tester.tap(find.text('Use another card'));
        await tester.pumpAndSettle();
        expect(accepted, [null, 'pm_2']);
        expect(find.text('AUCTION WON'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
      });

      testWidgets("the server's last error shows with Use another card", (tester) async {
        setBoardViewport(tester);
        await tester.pumpWidget(
          page(
            withOffer: SecondChanceOffer(
              amountCents: 360000,
              expiresAt: DateTime.now().add(const Duration(hours: 3)),
              lastError: 'Insufficient funds.',
            ),
          ),
        );
        expect(find.text('Insufficient funds.'), findsOneWidget);
        expect(find.text('Use another card'), findsOneWidget);
        expect(find.text('Accept and pay'), findsNothing);
      });

      testWidgets('an expired offer (409): the message as a toast', (tester) async {
        setBoardViewport(tester);
        await tester.pumpWidget(
          page(accept: (_) async => throw ApiException('This offer has expired.', statusCode: 409)),
        );
        await tester.tap(find.text('Accept and pay'));
        await tester.pump();
        expect(find.text('This offer has expired.'), findsOneWidget);
        await tester.pumpAndSettle();
        // Then the piece as it is now.
        expect(find.text('AUCTION WON'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
      });

      testWidgets('No thanks: confirmed, then declined', (tester) async {
        setBoardViewport(tester);
        var declined = 0;
        await tester.pumpWidget(page(decline: () async => declined++));
        await tester.tap(find.text('No thanks'));
        await tester.pumpAndSettle();
        expect(find.text('Pass on this piece?'), findsOneWidget);
        await tester.tap(find.widgetWithText(StudioButton, 'No thanks'));
        await tester.pumpAndSettle();
        expect(declined, 1);
        await tester.pump(const Duration(seconds: 3));
      });
    });

    test('openAuctionOutcome goes by the piece as it is now', () {
      PieceSummary piece({AuctionSummary? auction, String status = 'auction_won', String? myBid, Map? order}) =>
          PieceSummary.fromJson({
            'id': 'p1',
            'title': 'Bodies in Color',
            'status': status,
            'listingType': 'auction',
            ...?auction?.toJson(),
            'myBidStatus': ?myBid,
            'viewerOrder': ?order,
          });
      final won = _auction(status: 'awaiting_winner', winner: true);
      // Bought: the piece, never the "lost" page.
      expect(auctionOutcomePage(piece(status: 'sold', myBid: 'won'), type: 'auction_won'), isNull);
      expect(
        auctionOutcomePage(piece(auction: won, order: <String, dynamic>{'id': 'o1', 'side': 'buyer', 'status': 'paid'}), type: 'auction_won'),
        isNull,
      );
      expect(auctionOutcomePage(piece(myBid: 'won'), type: 'auction_won'), isNull);
      // A payment notification for a payment already fixed: the win.
      expect(auctionOutcomePage(piece(auction: won), type: 'auction_payment_failed'), isA<AuctionResultPage>());
      expect(
        auctionOutcomePage(
          piece(auction: _auction(status: 'awaiting_payment', winner: true, awaitingPayment: true)),
          type: 'auction_won',
        ),
        isA<BidPaymentFailedPage>(),
      );
      expect(
        auctionOutcomePage(piece(auction: _auction(status: 'second_chance', offer: offer)), type: 'auction_second_chance'),
        isA<SecondChancePage>(),
      );
      // The offer is gone: the piece.
      expect(auctionOutcomePage(piece(myBid: 'lost'), type: 'auction_second_chance'), isNull);
      expect(auctionOutcomePage(piece(myBid: 'lost'), type: 'auction_lost'), isA<AuctionResultPage>());
    });
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
      await sheet(
        tester,
        (_) => const BidVerifySheet(saveCard: _fakeSheet, debugAddresses: [_studio]),
        'BidVerify',
      );
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

/// Records `POST /api/pieces/p1/bids` and answers with the auction after it.
/// Taps "Bid $3,600" and waits (real time, up to 5 s) until the bid call has come back
/// and the sheet has closed, so nothing lands after the test ends on a loaded machine.
Future<void> _tapBidAndWait(WidgetTester tester) async {
  final route = ModalRoute.of(tester.element(find.byType(BidSheet)))!;
  await tester.runAsync(() async {
    await tester.tap(find.text(r'Bid $3,600'));
    for (var i = 0; i < 100 && route.isCurrent; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });
  expect(route.isCurrent, isFalse, reason: 'the bid sheet should close after the bid');
}

class _BidServer implements HttpClientAdapter {
  final bids = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    Object json = {'success': true, 'data': <String, dynamic>{}};
    if (options.method == 'POST' && options.uri.path == '/api/pieces/p1/bids') {
      bids.add(Map<String, dynamic>.from(options.data as Map));
      json = {'success': true, 'data': _auction(highest: 360000, highestBidder: true).toJson()};
    }
    return ResponseBody.fromString(
      jsonEncode(json),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
