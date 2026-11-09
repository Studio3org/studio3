import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auction.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/screens/available_piece_detail_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/cache_service.dart';
import 'package:studio3/services/engagement_store.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/auction/artist_auction.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// The artist's own auction (`ArtistAuctionLive`, `ArtistAuctionEnd`, `ArtistAuctionPayment`,
/// `ArtistAuctionUnsold`; BACKEND_CHANGES B38): YOUR AUCTION with the bids as Bidder N, ending
/// early as a cancel, the winner's failed payment with their deadline, and the three ways on
/// after no sale.

final _now = DateTime(2026, 11, 9, 9);

AuctionSummary _live({int bids = 6, bool reserveMet = true, Duration left = const Duration(hours: 5, minutes: 12)}) =>
    AuctionSummary(
      auctionId: 'a1',
      status: 'live',
      startingBidCents: 40000,
      highestBidCents: bids == 0 ? null : 130000,
      bidCount: bids,
      minNextBidCents: 135000,
      endsAt: _now.add(left),
      hasReserve: true,
      reserveMet: reserveMet,
    );

const _history = AuctionBidHistory(
  bidCount: 6,
  bidderCount: 4,
  nextBidCents: 125000,
  items: [],
);

AuctionBidHistory _bids() => AuctionBidHistory(
  bidCount: 6,
  bidderCount: 4,
  nextBidCents: 125000,
  items: [
    AuctionBidRow(bidder: 3, amountCents: 130000, createdAt: _now.subtract(const Duration(minutes: 2)), isTop: true),
    AuctionBidRow(bidder: 1, amountCents: 125000, createdAt: _now.subtract(const Duration(minutes: 18))),
    AuctionBidRow(bidder: 3, amountCents: 115000, createdAt: _now.subtract(const Duration(hours: 1)), isTop: true),
    AuctionBidRow(bidder: 2, amountCents: 110000, createdAt: _now.subtract(const Duration(hours: 3))),
    AuctionBidRow(bidder: 1, amountCents: 80000, createdAt: _now.subtract(const Duration(days: 1))),
    AuctionBidRow(bidder: 4, amountCents: 40000, createdAt: _now.subtract(const Duration(days: 2))),
  ],
);

FeedPreviewItem _item({
  AuctionSummary? auction,
  EndedAuction? last,
  String status = 'live',
  int? saves,
}) => FeedPreviewItem(
  id: 'p1',
  imageSeeds: const [1],
  title: 'Quiet Hours',
  medium: 'Oil on linen',
  year: 2025,
  dimensions: '18 × 24 in',
  story: '',
  handle: '@amarasart',
  isAvailable: true,
  aspectRatio: FeedAspectRatio.portrait3x4,
  listingType: 'auction',
  status: status,
  auction: auction,
  lastAuction: last,
  savesCount: saves,
);

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  home: Scaffold(body: home),
);

void main() {
  setUpAll(() async {
    await loadStudioFonts();
  });

  group('which view', () {
    test('live, settling, payment failed, unsold; nothing for a buyer, a sale or a cancel', () {
      expect(artistAuctionView(_item(auction: _live()), isOwner: true), ArtistAuctionView.live);
      expect(artistAuctionView(_item(auction: _live()), isOwner: false), isNull);
      const paying = AuctionSummary(
        auctionId: 'a1',
        status: 'awaiting_payment',
        startingBidCents: 40000,
        bidCount: 6,
        minNextBidCents: 0,
      );
      expect(artistAuctionView(_item(auction: paying), isOwner: true), ArtistAuctionView.paymentFailed);
      const settling = AuctionSummary(
        auctionId: 'a1',
        status: 'awaiting_winner',
        startingBidCents: 40000,
        bidCount: 6,
        minNextBidCents: 0,
      );
      expect(artistAuctionView(_item(auction: settling), isOwner: true), ArtistAuctionView.settling);
      const unsold = EndedAuction(status: 'needs_seller_action', topBidCents: 130000, bidderCount: 4);
      expect(artistAuctionView(_item(last: unsold, status: 'delisted'), isOwner: true), ArtistAuctionView.unsold);
      const cancelled = EndedAuction(status: 'cancelled');
      expect(artistAuctionView(_item(last: cancelled, status: 'delisted'), isOwner: true), isNull);
      expect(artistAuctionView(_item(last: unsold, status: 'sold'), isOwner: true), isNull);
    });

    test('the deadline reads as a time and a day', () {
      final morning = DateTime(2026, 11, 10, 9, 40);
      expect(winnerDeadlinePhrase(morning, _now), startsWith('9:40 AM'));
      expect(winnerDeadlinePhrase(morning, _now), endsWith('tomorrow'));
      expect(winnerDeadlinePhrase(DateTime(2026, 11, 9, 21, 5), _now), endsWith('today'));
      expect(winnerDeadlinePhrase(DateTime(2026, 11, 12, 9, 40), _now), startsWith('Nov 12 at 9:40 AM'));
    });

    test('why it did not sell, and the interest it had', () {
      expect(
        unsoldLine(const EndedAuction(status: 'needs_seller_action', topBidCents: 130000, bidderCount: 4), saves: 31),
        r'Top bid $1,300, under your reserve. 4 bidders and 31 saves.',
      );
      expect(unsoldLine(const EndedAuction(status: 'closed_no_bids'), saves: 1), 'No one bid this time. 1 save.');
      expect(unsoldLine(const EndedAuction(status: 'closed_no_bids')), 'No one bid this time.');
    });
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    final c = dark ? StudioColors.dark : StudioColors.light;

    testWidgets('live ($theme): YOUR AUCTION, current bid, Ends in red, bids as Bidder N', (tester) async {
      setBoardViewport(tester, height: 1180);
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: ArtistAuctionSection(
              view: ArtistAuctionView.live,
              item: _item(auction: _live()),
              history: _bids(),
              now: _now,
            ),
          ),
          dark: dark,
        ),
      );
      expect(find.text('YOUR AUCTION'), findsOneWidget);
      expect(find.text('Current bid'), findsOneWidget);
      final amount = tester.widget<Text>(find.text(r'$1,300').first);
      expect((amount.style!.fontSize, amount.style!.fontWeight), (36, StudioType.medium));
      final ends = tester.widget<Text>(find.text('5h 12m'));
      expect((ends.style!.fontFamily, ends.style!.fontSize, ends.style!.color), (StudioType.geistMono, 20, c.alert));
      expect(find.text('6 bids'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Reserve met')).style!.color, c.positive);
      expect(find.text(r'Started at $400'), findsOneWidget);
      expect(find.text('Bids'), findsOneWidget);
      expect(find.text('Bidder 3'), findsNWidgets(2));
      expect(tester.widget<Text>(find.text('Bidder 3').first).style!.fontWeight, StudioType.medium);
      expect(tester.widget<Text>(find.text('Bidder 1').first).style!.fontWeight, StudioType.regular);
      for (final age in ['2m', '18m', '1h', '3h', '1d', '2d']) {
        expect(find.text(age), findsOneWidget);
      }
      expect(find.text('Bidders stay anonymous until the winner pays.'), findsOneWidget);
    });

    testWidgets('payment failed ($theme): Winning bid, the red card with the deadline and the next bid', (
      tester,
    ) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          ArtistAuctionSection(
            view: ArtistAuctionView.paymentFailed,
            item: _item(
              auction: AuctionSummary(
                auctionId: 'a1',
                status: 'awaiting_payment',
                startingBidCents: 40000,
                bidCount: 6,
                minNextBidCents: 0,
                winningBidCents: 130000,
                winnerDeadlineAt: DateTime(2026, 11, 10, 9, 40),
              ),
            ),
            history: _history,
            now: _now,
          ),
          dark: dark,
        ),
      );
      expect(find.text('AUCTION ENDED'), findsOneWidget);
      expect(find.text('Winning bid'), findsOneWidget);
      expect(find.text(r'$1,300'), findsOneWidget);
      final title = tester.widget<Text>(find.text("Payment didn't go through"));
      expect((title.style!.color, title.style!.fontWeight), (c.alert, StudioType.medium));
      final card = tester.widget<Container>(find.byKey(const Key('artist-auction-payment-card')));
      expect((card.decoration! as BoxDecoration).color, c.card);
      final line = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().startsWith('The winner has until 9:40 AM'),
      );
      expect(line, findsOneWidget);
      expect(
        tester.widget<RichText>(line).text.toPlainText(),
        endsWith(r'tomorrow to update their card. If not, it goes to the next bidder at $1,250.'),
      );
      expect(find.text("Nothing to do. We'll tell you when it's paid."), findsOneWidget);
    });

    testWidgets('unsold ($theme): why, the interest, and the three ways on', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          Stack(
            children: [
              ArtistAuctionSection(
                view: ArtistAuctionView.unsold,
                item: _item(
                  last: const EndedAuction(status: 'needs_seller_action', topBidCents: 130000, bidderCount: 4),
                  status: 'delisted',
                  saves: 31,
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ArtistAuctionBar(view: ArtistAuctionView.unsold, bidCount: 0),
              ),
            ],
          ),
          dark: dark,
        ),
      );
      final heading = tester.widget<Text>(find.text("It didn't sell this time"));
      expect((heading.style!.fontSize, heading.style!.fontWeight), (24, StudioType.medium));
      expect(find.text(r'Top bid $1,300, under your reserve. 4 bidders and 31 saves.'), findsOneWidget);
      final relist = tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Relist as an auction'));
      expect(relist.variant, StudioButtonVariant.primary);
      final fixed = tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Sell at a fixed price'));
      expect((fixed.variant, fixed.height), (StudioButtonVariant.outline, 52.0));
      final keep = tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Keep it as not for sale'));
      expect(keep.variant, StudioButtonVariant.text);
    });
  }

  testWidgets('the live bar: Share auction, and End auction early once someone bid', (tester) async {
    await tester.pumpWidget(_app(const ArtistAuctionBar(view: ArtistAuctionView.live, bidCount: 6)));
    expect(find.text('Share auction'), findsOneWidget);
    expect(find.text('End auction early'), findsOneWidget);
    await tester.pumpWidget(_app(const ArtistAuctionBar(view: ArtistAuctionView.live, bidCount: 0)));
    expect(find.text('Share auction'), findsOneWidget);
    expect(find.text('End auction early'), findsNothing);
    await tester.pumpWidget(_app(const ArtistAuctionBar(view: ArtistAuctionView.paymentFailed, bidCount: 6)));
    expect(find.text('Message Studio 3 support'), findsOneWidget);
    expect(find.text('Share auction'), findsNothing);
  });

  testWidgets('End this auction? says how many are told; Keep running keeps it', (tester) async {
    bool? ended;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => ended = await confirmEndAuction(context, bidderCount: 4),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('End this auction?'), findsOneWidget);
    expect(
      find.text("No one wins or is charged, and all 4 bidders are told. This can't be undone."),
      findsOneWidget,
    );
    await tester.tap(find.text('Keep auction running'));
    await tester.pumpAndSettle();
    expect(ended, isFalse);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End and cancel auction'));
    await tester.pumpAndSettle();
    expect(ended, isTrue);
  });

  group('on the piece page', () {
    late _Fake server;
    final files = Directory.systemTemp.createTempSync('studio3_artist_auction');

    setUpAll(() {
      dotenv.loadFromString(envString: '', isOptional: true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => files.path,
      );
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      server = _Fake();
      ApiClient.instance.debugUseAdapter(server);
      AuthSession.instance.accessToken = 'token';
      AuthSession.instance.user = const AuthUser(
        username: 'amarasart',
        name: 'Amara Osei',
        email: 'amara@email.com',
        onboardingComplete: true,
      );
    });

    tearDown(() async {
      AuthSession.instance.accessToken = null;
      AuthSession.instance.user = null;
      EngagementStore.instance.clear();
      await CacheService.instance.clearAll();
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
    }

    for (final dark in [false, true]) {
      testWidgets('your live auction (${dark ? 'dark' : 'light'}): the bids from the server, More '
          'instead of Edit, End auction early cancels it', (tester) async {
        setBoardViewport(tester, height: 1180);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: AvailablePieceDetailPage(item: _item(auction: _live(left: const Duration(days: 30)))),
          ),
        );
        await settle(tester);

        expect(find.text('YOUR AUCTION'), findsOneWidget);
        expect(server.to('GET', '/api/pieces/p1/auction/bids'), hasLength(1));
        expect(find.text('Bidder 2'), findsOneWidget);
        expect(find.text('Place a bid'), findsNothing);
        expect(find.text('Manage auction'), findsNothing);
        expect(find.bySemanticsLabel('Edit piece'), findsNothing);
        expect(find.bySemanticsLabel('More'), findsOneWidget);

        await tester.tap(find.text('End auction early'));
        await settle(tester);
        expect(
          find.text("No one wins or is charged, and all 2 bidders are told. This can't be undone."),
          findsOneWidget,
        );
        await tester.tap(find.text('End and cancel auction'));
        await settle(tester);
        expect(server.to('POST', '/api/pieces/p1/auction/cancel'), hasLength(1));
        expect(find.text('Auction ended. Bidders were told.'), findsOneWidget);
        // Back to not for sale (`NoteArtistAuctionEnd`): the cancel leaves it delisted.
        expect(server.to('PATCH', '/api/pieces/p1').single.body, {'isForSale': false, 'status': 'live'});
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(minutes: 1));
      });
    }

    testWidgets('no bids yet: More holds Edit piece and Cancel auction', (tester) async {
      setBoardViewport(tester, height: 1180);
      server.bids = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AvailablePieceDetailPage(item: _item(auction: _live(bids: 0, left: const Duration(days: 30)))),
        ),
      );
      await settle(tester);
      expect(find.text('End auction early'), findsNothing);
      await tester.tap(find.bySemanticsLabel('More'));
      await settle(tester);
      expect(find.text('Edit piece'), findsOneWidget);
      expect(find.text('Cancel auction'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });

    testWidgets('unsold: Keep it as not for sale takes the price off and puts it back up', (tester) async {
      setBoardViewport(tester, height: 1000);
      server.unsold = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AvailablePieceDetailPage(
            item: _item(
              last: const EndedAuction(status: 'closed_no_bids'),
              status: 'delisted',
              saves: 31,
            ),
          ),
        ),
      );
      await settle(tester);
      expect(find.text("It didn't sell this time"), findsOneWidget);
      expect(find.text('No one bid this time. 31 saves.'), findsOneWidget);
      expect(find.text('Auction ended'), findsNothing, reason: 'not the disabled buyer bar');
      await tester.tap(find.text('Keep it as not for sale'));
      await settle(tester);
      final patch = server.to('PATCH', '/api/pieces/p1').single;
      expect(patch.body, {'isForSale': false, 'status': 'live'});
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });
  });
}

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body})>[];
  var bids = 2;
  var unsold = false;

  Iterable<({String method, String path, Object? body})> to(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  Map<String, dynamic> _piece() => {
    'id': 'p1',
    'title': 'Quiet Hours',
    'status': unsold ? 'delisted' : 'live',
    'isForSale': true,
    'listingType': 'auction',
    'priceCents': 40000,
    'mediaUrl': '',
    'savesCount': 31,
    'author': {'username': 'amarasart', 'name': 'Amara Osei', 'isFollowing': false},
    if (unsold)
      'lastAuction': {'status': 'closed_no_bids', 'bidCount': 0, 'bidderCount': 0, 'startingBidCents': 40000}
    else ...{
      'auctionId': 'a1',
      'auctionStatus': 'live',
      'startingBidCents': 40000,
      'highestBidCents': bids == 0 ? null : 80000,
      'bidCount': bids,
      'minNextBidCents': 85000,
      'auctionEndsAt': DateTime.now().add(const Duration(days: 30)).toUtc().toIso8601String(),
      'hasReserve': false,
      'reserveMet': true,
    },
  };

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    requests.add((method: options.method, path: path, body: options.data));
    Object json;
    switch ('${options.method} $path') {
      case 'GET /api/pieces/p1':
        json = {'success': true, 'data': _piece()};
      case 'GET /api/pieces/p1/auction/bids':
        json = {
          'success': true,
          'data': {
            'auctionId': 'a1',
            'bidCount': bids,
            'bidderCount': bids,
            'nextBidCents': bids > 1 ? 40000 : null,
            'items': [
              if (bids > 1)
                {'bidder': 2, 'amountCents': 80000, 'createdAt': DateTime.now().toUtc().toIso8601String(), 'isTop': true},
              if (bids > 0)
                {'bidder': 1, 'amountCents': 40000, 'createdAt': DateTime.now().toUtc().toIso8601String(), 'isTop': false},
            ],
          },
        };
      case 'POST /api/pieces/p1/auction/cancel':
        json = {'success': true, 'data': {'cancelledBids': bids}};
      case 'PATCH /api/pieces/p1':
        json = {
          'success': true,
          'data': {..._piece(), 'isForSale': false, 'listingType': null, 'status': 'live'}..remove('lastAuction'),
        };
      default:
        json = {'success': true, 'data': {'items': <Object>[], 'nextCursor': null}};
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
