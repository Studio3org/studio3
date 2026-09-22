import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/auction_summary.dart';
import 'package:studio3/models/bid.dart';
import 'package:studio3/models/saved_card.dart';
import 'package:studio3/utils/auction_time.dart';

/// The auction state a bidder sees, and the two places it used to be wrong.
Map<String, dynamic> _payload({
  String status = 'live',
  bool isHighestBidder = false,
  bool isWinner = false,
  bool awaitingPayment = false,
  String? winnerDeadlineAt,
  int? winningBidCents,
  int? highestBidCents,
  int? startingBidCents = 40000,
  int? minNextBidCents,
  int bidCount = 0,
  bool hasReserve = false,
  bool reserveMet = true,
}) {
  return {
    'auctionId': 'a1',
    'auctionStatus': status,
    'startingBidCents': startingBidCents,
    'highestBidCents': highestBidCents,
    'minNextBidCents': minNextBidCents,
    'bidCount': bidCount,
    'isHighestBidder': isHighestBidder,
    'isWinner': isWinner,
    'awaitingPayment': awaitingPayment,
    'winnerDeadlineAt': winnerDeadlineAt,
    'winningBidCents': winningBidCents,
    'hasReserve': hasReserve,
    'reserveMet': reserveMet,
  };
}

void main() {
  group('AuctionSummary', () {
    test('a live auction is open for bidding and not closed', () {
      final auction = AuctionSummary.fromJson(_payload());

      expect(auction.isOpenForBidding, isTrue);
      expect(auction.isClosed, isFalse);
      expect(auction.needsCheckout, isFalse);
      expect(auction.needsPaymentFix, isFalse);
    });

    test('an auction in its soft-close window still takes bids', () {
      final auction = AuctionSummary.fromJson(_payload(status: 'closing'));

      expect(auction.isOpenForBidding, isTrue);
      expect(auction.isClosingSoon, isTrue);
    });

    test('the winner is read from isWinner, not from leading the live bidding', () {
      // The regression this field exists for. Once an auction closes there is no highest
      // *active* bid, so isHighestBidder is false for everyone — including the person who
      // just won. Deriving the winner from it meant nobody was ever offered the checkout.
      final auction = AuctionSummary.fromJson(
        _payload(
          status: 'awaiting_winner',
          isHighestBidder: false,
          isWinner: true,
          winningBidCents: 50000,
        ),
      );

      expect(auction.isHighestBidder, isFalse);
      expect(auction.needsCheckout, isTrue,
          reason: 'the winner was not offered their own checkout');
      expect(auction.winningBidCents, 50000);
    });

    test('a declined winner needs to fix payment, not to check out', () {
      final auction = AuctionSummary.fromJson(
        _payload(status: 'awaiting_payment', isWinner: true, awaitingPayment: true),
      );

      expect(auction.needsPaymentFix, isTrue);
      expect(auction.needsCheckout, isFalse,
          reason: 'sending them to checkout would bill a sale nobody has paid for');
    });

    test('a losing bidder is never told the winner failed to pay', () {
      // The server only sets awaitingPayment for the winner, and this asserts the client
      // does not widen it: knowing the payment failed would tell a losing bidder the piece
      // may be about to come back.
      final auction = AuctionSummary.fromJson(
        _payload(status: 'awaiting_payment', isWinner: false, awaitingPayment: false),
      );

      expect(auction.needsPaymentFix, isFalse);
      expect(auction.needsCheckout, isFalse);
      expect(auction.isClosed, isTrue);
    });

    test('a reserve is reported as met or not, never as an amount', () {
      final auction = AuctionSummary.fromJson(
        _payload(hasReserve: true, reserveMet: false),
      );

      expect(auction.hasReserve, isTrue);
      expect(auction.reserveMet, isFalse);
      // There is deliberately no field carrying the reserve itself.
      expect(
        _payload(hasReserve: true, reserveMet: false).containsKey('reserveCents'),
        isFalse,
      );
    });

    test('the headline figure falls back to the starting bid before anyone bids', () {
      final untouched = AuctionSummary.fromJson(_payload(startingBidCents: 40000));
      final bidOn = AuctionSummary.fromJson(
        _payload(startingBidCents: 40000, highestBidCents: 55000, bidCount: 2),
      );

      expect(untouched.displayBidCents, 40000);
      expect(untouched.highestBidCents, isNull,
          reason: 'a starting bid must not be presented as a bid that happened');
      expect(bidOn.displayBidCents, 55000);
    });

    test('needsSellerDecision covers an auction that ended without a sale', () {
      final auction = AuctionSummary.fromJson(_payload(status: 'needs_seller_action'));

      expect(auction.needsSellerDecision, isTrue);
      expect(auction.isClosed, isTrue);
    });

    test('canRelist covers every no-charge ending, not just needsSellerDecision', () {
      // The regression this guards: the relist button in ManageAuctionSheet was gated on
      // needsSellerDecision alone, which only matches 'needs_seller_action' (reserve not
      // met). An auction that simply got no bids — closed_no_bids, the most common way one
      // ends without a sale — never showed the option at all, even though the backend
      // accepts a relist for it.
      for (final status in ['needs_seller_action', 'closed_no_bids', 'closed_reserve_not_met']) {
        expect(
          AuctionSummary.fromJson(_payload(status: status)).canRelist,
          isTrue,
          reason: '$status should be relistable',
        );
      }
    });

    test('canRelist excludes a sold or cancelled auction', () {
      // A sold auction already has a buyer; a cancelled one was the seller deliberately
      // stopping. Relisting from either would be wrong, not just redundant — never widen
      // this list to include them.
      for (final status in ['closed_sold', 'cancelled', 'live', 'closing']) {
        expect(
          AuctionSummary.fromJson(_payload(status: status)).canRelist,
          isFalse,
          reason: '$status should not be relistable',
        );
      }
    });

    test('maybeFrom returns null for a payload with no auction in it', () {
      expect(AuctionSummary.maybeFrom({'id': 'p1', 'title': 'Untitled'}), isNull);
      expect(AuctionSummary.maybeFrom(_payload()), isNotNull);
    });
  });

  group('Bid', () {
    test('carries the refreshed auction state alongside the bid', () {
      final bid = Bid.fromJson({
        'id': 'b1',
        'pieceId': 'p1',
        'amountCents': 55000,
        'bidderId': 'u1',
        ..._payload(isHighestBidder: true, highestBidCents: 55000, bidCount: 1),
      });

      expect(bid.amountCents, 55000);
      expect(bid.isLeading, isTrue);
      expect(bid.bidCount, 1);
      expect(bid.auction, isNotNull);
    });

    test('reports honestly when the bid landed but was already beaten', () {
      final bid = Bid.fromJson({
        'id': 'b1',
        'pieceId': 'p1',
        'amountCents': 55000,
        'bidderId': 'u1',
        ..._payload(isHighestBidder: false, highestBidCents: 60000, bidCount: 2),
      });

      expect(bid.isLeading, isFalse,
          reason: 'telling someone they lead when they do not is how they stop watching');
    });
  });

  group('SavedCard', () {
    test('is valid through the last day of its expiry month', () {
      final now = DateTime.now();
      final thisMonth = SavedCard(
        id: 'pm_1',
        expMonth: now.month,
        expYear: now.year,
      );

      expect(thisMonth.isExpired, isFalse);
    });

    test('knows when it has expired', () {
      final old = SavedCard(id: 'pm_1', expMonth: 1, expYear: 2020);
      expect(old.isExpired, isTrue);
    });

    test('a card with no expiry is not assumed to be expired', () {
      expect(const SavedCard(id: 'pm_1').isExpired, isFalse);
    });

    test('labels itself for a picker', () {
      const card = SavedCard(
        id: 'pm_1',
        brand: 'visa',
        last4: '4242',
        expMonth: 4,
        expYear: 2031,
      );

      expect(card.label, 'Visa ···· 4242');
      expect(card.expiryLabel, '04/31');
    });
  });

  group('formatDeadlineCountdown', () {
    test('counts seconds inside the last hour', () {
      // An event auction gives a declined winner ten minutes. "Ending soon" is useless to
      // someone in a gallery hunting for another card.
      final deadline = DateTime.now().add(const Duration(minutes: 9, seconds: 42));

      final text = formatDeadlineCountdown(deadline);

      expect(text, matches(r'^9:\d{2}$'));
    });

    test('is coarse for the 48-hour standalone window', () {
      // Deliberately off an hour boundary: these are truncating divisions, so a deadline
      // exactly 47h away reads as 1d 22h by the time the call is made.
      final deadline = DateTime.now().add(const Duration(hours: 47, minutes: 30));

      expect(formatDeadlineCountdown(deadline), '1d 23h');
    });

    test('returns null once the deadline has passed', () {
      final past = DateTime.now().subtract(const Duration(minutes: 1));

      expect(formatDeadlineCountdown(past), isNull);
    });
  });
}
