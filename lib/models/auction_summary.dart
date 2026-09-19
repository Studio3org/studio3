/// The auction as the server describes it — the shape returned by piece detail, by
/// `POST /api/pieces/:id/bids`, and by every seller and winner action.
///
/// Two things about this model are deliberate and easy to get wrong:
///
/// **The minimum bid is never computed here.** The increment is banded by price ($5 under
/// $100 rising to $500 over $10,000) and the *first* bid on a piece may land exactly on the
/// artist's stated minimum. There is no formula the client can reproduce safely, so
/// [minNextBidCents] is read, never derived.
///
/// **The reserve amount is never sent.** Only [hasReserve] and [reserveMet]. That is the
/// whole point of a hidden reserve and it would be trivial to leak by asking for the number.
class AuctionSummary {
  const AuctionSummary({
    required this.auctionId,
    required this.status,
    this.startingBidCents,
    this.highestBidCents,
    this.minNextBidCents,
    this.bidIncrementCents,
    this.bidCount = 0,
    this.opensAt,
    this.endsAt,
    this.hasReserve = false,
    this.reserveMet = true,
    this.deliveryMode,
    this.isHighestBidder = false,
    this.isWinner = false,
    this.awaitingPayment = false,
    this.winnerDeadlineAt,
    this.winningBidCents,
  });

  final String auctionId;

  /// `draft` · `live` · `closing` · `awaiting_payment` · `awaiting_winner` · `closed_sold` ·
  /// `closed_reserve_not_met` · `closed_no_bids` · `needs_seller_action` · `cancelled`.
  final String status;

  /// The artist's stated minimum. The first bid may land exactly on it, so this is a real
  /// bid target and not merely a display figure.
  final int? startingBidCents;

  /// Null until somebody bids. Deliberately not conflated with [startingBidCents] — showing
  /// a starting bid as a "current bid" tells collectors an auction has activity it does not.
  final int? highestBidCents;

  /// What to prefill and validate against. Server-computed; see the class doc.
  final int? minNextBidCents;

  /// The band for the current high bid. Zero when there are no bids yet, because the first
  /// bid steps over nothing.
  final int? bidIncrementCents;

  final int bidCount;
  final DateTime? opensAt;
  final DateTime? endsAt;

  final bool hasReserve;

  /// Met / not met only — never the amount.
  final bool reserveMet;

  /// `ship` or `pickup`. Pickup is how an event auction hands a piece over in the room.
  final String? deliveryMode;

  /// Viewer-relative: this viewer currently leads.
  final bool isHighestBidder;

  /// Viewer-relative: this viewer won. Read from the server's stored winner rather than by
  /// comparing bid amounts, which cannot express a cascade — after the top bidder's card
  /// fails the winner is somebody further down the list.
  final bool isWinner;

  /// True only for the winner whose card was declined. Never true for anyone else, so it can
  /// be rendered without leaking to other bidders that the piece may become available again.
  final bool awaitingPayment;

  /// When a declined winner loses the piece to the next bidder. 48 hours for a standalone
  /// auction, 10 minutes for an event one. Null once the sale is settled.
  final DateTime? winnerDeadlineAt;

  /// The hammer price, once there is a winner.
  final int? winningBidCents;

  /// Bidding is open right now.
  bool get isOpenForBidding => status == 'live' || status == 'closing';

  /// Inside the soft-close window: any bid now pushes the end out. Standalone auctions only.
  bool get isClosingSoon => status == 'closing';

  /// The auction is over, one way or another.
  bool get isClosed => !isOpenForBidding && status != 'draft';

  /// This viewer won and still owes the shipping-and-tax balance.
  bool get needsCheckout => isWinner && status == 'awaiting_winner';

  /// This viewer won but their card was declined — they must fix it before the deadline.
  bool get needsPaymentFix => isWinner && awaitingPayment;

  /// The seller has to decide what happens next: the reserve was not met, or nobody could pay.
  bool get needsSellerDecision => status == 'needs_seller_action';

  /// What to show as the headline figure. Falls back to the starting bid, because an auction
  /// nobody has bid on still has a number the artist is asking for.
  int? get displayBidCents => highestBidCents ?? startingBidCents;

  factory AuctionSummary.fromJson(Map<String, dynamic> json) {
    int? intOf(String key) => (json[key] as num?)?.toInt();
    DateTime? dateOf(String key) {
      final raw = json[key] as String?;
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return AuctionSummary(
      auctionId: json['auctionId'] as String? ?? '',
      status: json['auctionStatus'] as String? ?? '',
      startingBidCents: intOf('startingBidCents'),
      highestBidCents: intOf('highestBidCents'),
      minNextBidCents: intOf('minNextBidCents'),
      bidIncrementCents: intOf('bidIncrementCents'),
      bidCount: intOf('bidCount') ?? 0,
      opensAt: dateOf('opensAt'),
      endsAt: dateOf('auctionEndsAt'),
      hasReserve: json['hasReserve'] as bool? ?? false,
      reserveMet: json['reserveMet'] as bool? ?? true,
      deliveryMode: json['deliveryMode'] as String?,
      isHighestBidder: json['isHighestBidder'] as bool? ?? false,
      isWinner: json['isWinner'] as bool? ?? false,
      awaitingPayment: json['awaitingPayment'] as bool? ?? false,
      winnerDeadlineAt: dateOf('winnerDeadlineAt'),
      winningBidCents: intOf('winningBidCents'),
    );
  }

  /// Null when the payload carries no auction at all — a fixed-price piece, or an auction
  /// the viewer cannot see. Callers branch on null rather than on an empty-ish summary.
  static AuctionSummary? maybeFrom(Map<String, dynamic> json) {
    if (json['auctionId'] == null) return null;
    return AuctionSummary.fromJson(json);
  }
}
