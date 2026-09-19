/// A placed auction bid, and the fresh auction summary returned alongside it —
/// response shape of `POST /api/pieces/:id/bids`.
class Bid {
  const Bid({
    required this.id,
    required this.pieceId,
    required this.amountCents,
    required this.bidderId,
    this.createdAt,
    this.highestBidCents,
    this.startingBidCents,
    this.bidIncrementCents,
    this.bidCount = 0,
    this.minNextBidCents,
    this.auctionEndsAt,
  });

  final String id;
  final String pieceId;
  final int amountCents;
  final String bidderId;
  final DateTime? createdAt;
  final int? highestBidCents;
  final int? startingBidCents;
  final int? bidIncrementCents;
  final int bidCount;
  final int? minNextBidCents;
  final DateTime? auctionEndsAt;

  factory Bid.fromJson(Map<String, dynamic> json) {
    return Bid(
      id: json['id'] as String? ?? '',
      pieceId: json['pieceId'] as String? ?? '',
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      bidderId: json['bidderId'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      highestBidCents: (json['highestBidCents'] as num?)?.toInt(),
      startingBidCents: (json['startingBidCents'] as num?)?.toInt(),
      bidIncrementCents: (json['bidIncrementCents'] as num?)?.toInt(),
      bidCount: (json['bidCount'] as num?)?.toInt() ?? 0,
      minNextBidCents: (json['minNextBidCents'] as num?)?.toInt(),
      auctionEndsAt: DateTime.tryParse(json['auctionEndsAt'] as String? ?? ''),
    );
  }
}
