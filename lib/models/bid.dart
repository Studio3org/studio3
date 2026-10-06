import 'auction_summary.dart';

/// A placed auction bid — the response shape of `POST /api/pieces/:id/bids`.
///
/// The server returns the bid *and* the refreshed auction state in one payload, so a client
/// never has to re-fetch to find out whether the bid it just placed is still leading. The
/// auction half lives in [auction]; nothing about it is duplicated here.
class Bid {
  const Bid({
    required this.id,
    required this.pieceId,
    required this.amountCents,
    required this.bidderId,
    this.createdAt,
    this.auction,
  });

  final String id;
  final String pieceId;
  final int amountCents;
  final String bidderId;
  final DateTime? createdAt;

  /// The auction as it stands immediately after this bid landed.
  final AuctionSummary? auction;

  /// Whether this bid is currently in front. False if someone outbid it between the request
  /// being sent and the server answering, which is exactly the case worth telling the bidder
  /// about rather than congratulating them.
  bool get isLeading => auction?.isHighestBidder ?? false;

  int? get highestBidCents => auction?.highestBidCents;
  int? get minNextBidCents => auction?.minNextBidCents;
  int get bidCount => auction?.bidCount ?? 0;
  DateTime? get auctionEndsAt => auction?.endsAt;

  factory Bid.fromJson(Map<String, dynamic> json) {
    return Bid(
      id: json['id'] as String? ?? '',
      pieceId: json['pieceId'] as String? ?? '',
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      bidderId: json['bidderId'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      // The auction fields are flattened into the same object by the server.
      auction: AuctionSummary.maybeFrom(json),
    );
  }
}
