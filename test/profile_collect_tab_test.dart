import 'package:flutter_test/flutter_test.dart';

import 'package:studio3/models/piece_summary.dart';

/// Collect is the marketplace view of a profile. These pin the rules that
/// decide what lands in it and under which filter.
PieceSummary piece(
  String id, {
  bool isForSale = false,
  String? status,
  String? listingType,
  String? listingState,
}) {
  return PieceSummary(
    id: id,
    title: id,
    isForSale: isForSale,
    status: status,
    listingType: listingType,
    listingState: listingState,
  );
}

/// Mirrors `_ProfilePageState._collectPieces`.
List<PieceSummary> collectPieces(
  List<PieceSummary> listed,
  List<PieceSummary> pieces,
) {
  final merged = <String, PieceSummary>{};
  for (final p in listed) {
    merged[p.id] = p;
  }
  for (final p in pieces) {
    if (!p.hasListingBadge) continue;
    merged.putIfAbsent(p.id, () => p);
  }
  return merged.values.toList();
}

void main() {
  group('listing state', () {
    test('a live for-sale piece is available', () {
      expect(piece('a', isForSale: true, status: 'live').isAvailableListing,
          isTrue);
    });

    test('a live auction is biddable, not fixed-price available', () {
      final auction =
          piece('a', isForSale: true, status: 'live', listingType: 'auction');
      expect(auction.isAuctionLive, isTrue);
      expect(auction.isAvailableListing, isFalse);
      expect(auction.hasListingBadge, isTrue);
    });

    test('a draft never carries a listing badge, even marked for sale', () {
      expect(piece('a', isForSale: true, status: 'draft').hasListingBadge,
          isFalse);
    });

    test('a piece not for sale never carries a listing badge', () {
      expect(piece('a', status: 'live').hasListingBadge, isFalse);
    });
  });

  group('collect source', () {
    test('falls back to the pieces list when the listing feed is empty', () {
      // The exact failure being fixed: Collect was blank because
      // `/pieces/for-sale` returned nothing, while Pieces plainly showed
      // work marked for sale.
      final pieces = [
        piece('sold-out', isForSale: true, status: 'live'),
        piece('not-listed', status: 'live'),
      ];
      final result = collectPieces(const [], pieces);
      expect(result.map((p) => p.id), ['sold-out']);
    });

    test('keeps sold pieces the listing feed has already dropped', () {
      final result = collectPieces(
        [piece('live-one', isForSale: true, status: 'live')],
        [
          piece('live-one', isForSale: true, status: 'live'),
          piece('gone', isForSale: true, status: 'sold'),
        ],
      );
      expect(result.map((p) => p.id), ['live-one', 'gone']);
    });

    test('renders a seller whose every piece has already sold', () {
      // Taken from live data: `/pieces` returned two pieces, both
      // status=sold/listingState=collected, and `/pieces/for-sale`
      // correctly returned []. Collect used to render nothing at all for
      // this seller instead of two pieces under "Sold".
      final result = collectPieces(const [], [
        piece('rce', isForSale: true, status: 'sold', listingState: 'collected'),
        piece('ankit',
            isForSale: true, status: 'sold', listingState: 'collected'),
      ]);
      expect(result, hasLength(2));
      expect(result.every((p) => p.isCollectedListing), isTrue);
    });

    test('does not duplicate a piece present in both sources', () {
      final result = collectPieces(
        [piece('x', isForSale: true, status: 'live')],
        [piece('x', isForSale: true, status: 'live')],
      );
      expect(result, hasLength(1));
    });

    test('the listing feed wins on conflict — it has fresher bid fields', () {
      final result = collectPieces(
        [piece('x', isForSale: true, listingState: 'auction_live')],
        [piece('x', isForSale: true, listingState: 'collected')],
      );
      expect(result.single.isAuctionLive, isTrue);
    });
  });

  group('collect segments', () {
    final all = [
      piece('fixed', isForSale: true, status: 'live'),
      piece('auction',
          isForSale: true, status: 'live', listingType: 'auction'),
      piece('sold', isForSale: true, status: 'sold'),
      piece('reserved', isForSale: true, status: 'reserved'),
      piece('won', isForSale: true, status: 'auction_won'),
    ];

    List<String> available() => all
        .where((p) => p.isAvailableListing || p.isAuctionLive)
        .map((p) => p.id)
        .toList();

    List<String> sold() => all
        .where((p) => p.isCollectedListing || p.isAuctionEnded)
        .map((p) => p.id)
        .toList();

    test('Available covers fixed-price and live auctions', () {
      expect(available(), ['fixed', 'auction']);
    });

    test('Sold covers sold, reserved and won-at-auction', () {
      expect(sold(), ['sold', 'reserved', 'won']);
    });

    test('every listing falls under exactly one of the two filters', () {
      expect({...available(), ...sold()}, all.map((p) => p.id).toSet());
      expect(available().toSet().intersection(sold().toSet()), isEmpty);
    });
  });
}
