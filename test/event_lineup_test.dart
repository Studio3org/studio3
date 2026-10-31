import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/studio_event.dart';

/// What the room's own screen shows for each work on the bill.
EventLineupItem _item({
  String mode = 'bid',
  int? priceCents = 40000,
  Map<String, dynamic>? auction,
}) {
  return EventLineupItem.fromJson({
    'id': 'l1',
    'pieceId': 'p1',
    'mode': mode,
    'priceCents': priceCents,
    'title': 'Untitled',
    if (auction != null) 'auction': auction,
  });
}

Map<String, dynamic> _auction({
  String status = 'live',
  int? highestBidCents,
  int bidCount = 0,
  bool isHighestBidder = false,
  bool isWinner = false,
  int? winningBidCents,
}) {
  return {
    'auctionId': 'a1',
    'auctionStatus': status,
    'startingBidCents': 40000,
    'highestBidCents': highestBidCents,
    'bidCount': bidCount,
    'isHighestBidder': isHighestBidder,
    'isWinner': isWinner,
    'winningBidCents': winningBidCents,
  };
}

void main() {
  group('the figure shown for a work', () {
    test('is the live high bid once there is one', () {
      // Falling back the other way would show a starting bid on a piece already bid past —
      // which makes the screen in the room the least current thing in it.
      final item = _item(auction: _auction(highestBidCents: 55000, bidCount: 3));

      expect(item.currentCents, 55000);
    });

    test('is the asking price before anyone bids', () {
      expect(_item(auction: _auction()).currentCents, 40000);
    });

    test('is the asking price for work that is not being auctioned', () {
      expect(_item(mode: 'sale', auction: null).currentCents, 40000);
    });
  });

  group('the status line', () {
    test('counts the bids', () {
      expect(_item(auction: _auction(bidCount: 1)).statusLine, '1 bid');
      expect(_item(auction: _auction(bidCount: 12)).statusLine, '12 bids');
    });

    test('says starting bid before anyone has', () {
      expect(_item(auction: _auction()).statusLine, 'Starting bid');
    });

    test('says sold once it has settled on a winner', () {
      final item = _item(
        auction: _auction(status: 'awaiting_winner', winningBidCents: 55000),
      );

      expect(item.statusLine, 'Sold');
    });

    test('distinguishes an auction that ended without a sale', () {
      expect(
        _item(auction: _auction(status: 'closed_no_bids')).statusLine,
        'Auction ended',
      );
    });

    test('describes work that is only on show', () {
      expect(_item(mode: 'featured', auction: null).statusLine, 'On show');
      expect(_item(mode: 'sale', auction: null).statusLine, 'For sale');
    });
  });

  group('whether bidding is open', () {
    test('open while the auction is live', () {
      expect(_item(auction: _auction()).isBiddingOpen, isTrue);
    });

    test('closed once it has settled — an event auction stops dead', () {
      expect(
        _item(auction: _auction(status: 'awaiting_winner')).isBiddingOpen,
        isFalse,
      );
    });

    test('never open for work that is not being auctioned', () {
      expect(_item(mode: 'featured', auction: null).isBiddingOpen, isFalse);
    });
  });

  group('viewer-relative state', () {
    test('surfaces that you are winning', () {
      final item = _item(
        auction: _auction(highestBidCents: 55000, bidCount: 2, isHighestBidder: true),
      );

      expect(item.auction!.isHighestBidder, isTrue);
    });

    test('surfaces that you won after the close', () {
      final item = _item(
        auction: _auction(
          status: 'awaiting_winner',
          isWinner: true,
          winningBidCents: 55000,
        ),
      );

      expect(item.auction!.isWinner, isTrue);
      expect(item.auction!.needsCheckout, isTrue);
    });
  });
}
