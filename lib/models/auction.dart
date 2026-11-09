/// Auctions (Flow 7, `PostAvailAuction`, `HandoffBidding`).
library;

/// What an artist sets when posting a piece for auction (`PostAvailAuction`): a starting
/// bid, 3 to 14 days, and an optional private reserve.
class AuctionTerms {
  const AuctionTerms({
    required this.startingBidCents,
    required this.durationDays,
    this.reserveCents,
  });

  static const minDays = 3;
  static const maxDays = 14;
  static const defaultDays = 7;

  final int startingBidCents;
  final int durationDays;

  /// Private: bidders never see it.
  final int? reserveCents;

  /// When it would end if it opened at [from].
  DateTime endsAt(DateTime from) => from.add(Duration(days: durationDays));

  Map<String, dynamic> toJson() => {
    'listingType': 'auction',
    'priceCents': startingBidCents,
    'auctionDurationDays': durationDays,
    'reserveCents': ?reserveCents,
  };
}

/// The auction state on a piece (`GET /api/pieces/:id`, and the bid endpoints): the
/// server's bid summary. Viewer-relative fields depend on who asked.
class AuctionSummary {
  const AuctionSummary({
    required this.auctionId,
    required this.status,
    required this.startingBidCents,
    required this.bidCount,
    required this.minNextBidCents,
    this.highestBidCents,
    this.bidIncrementCents = 0,
    this.endsAt,
    this.opensAt,
    this.deliveryMode,
    this.hasReserve = false,
    this.reserveMet = true,
    this.isHighestBidder = false,
    this.isWinner = false,
    this.awaitingPayment = false,
    this.winnerDeadlineAt,
    this.winningBidCents,
  });

  final String auctionId;

  /// `draft`, `live`, `closing`, `awaiting_winner`, `awaiting_payment`, …
  final String status;
  final int startingBidCents;
  final int? highestBidCents;
  final int bidCount;
  final int minNextBidCents;
  final int bidIncrementCents;
  final DateTime? endsAt;
  final DateTime? opensAt;
  final String? deliveryMode;
  final bool hasReserve;

  /// True when there is no reserve; the amount itself is never sent.
  final bool reserveMet;
  final bool isHighestBidder;
  final bool isWinner;

  /// The winner's card was declined; they have until [winnerDeadlineAt] to fix it.
  final bool awaitingPayment;
  final DateTime? winnerDeadlineAt;
  final int? winningBidCents;

  bool get isOpen => status == 'live' || status == 'closing';

  // Restored from models/auction_summary.dart (before commit 76f4ef9).
  bool get isOpenForBidding => isOpen;
  bool get isClosingSoon => status == 'closing';
  bool get isClosed => !isOpen && status != 'draft';
  bool get needsCheckout => isWinner && status == 'awaiting_winner';
  bool get needsPaymentFix => isWinner && awaitingPayment;
  bool get needsSellerDecision => status == 'needs_seller_action';
  bool get canRelist => const {
    'needs_seller_action',
    'closed_no_bids',
    'closed_reserve_not_met',
  }.contains(status);
  int? get displayBidCents => highestBidCents ?? startingBidCents;
  bool get isSettling => status == 'awaiting_winner' || status == 'awaiting_payment';

  /// What the bar shows as the amount: the highest bid, or the starting bid before any.
  int get currentCents => highestBidCents ?? startingBidCents;

  /// Reads the summary from a piece or bid response; null when it has no auction.
  static AuctionSummary? maybeFrom(Map<String, dynamic> json) {
    final id = json['auctionId'];
    if (id is! String || id.isEmpty) return null;
    return AuctionSummary.fromJson(json);
  }

  factory AuctionSummary.fromJson(Map<String, dynamic> json) {
    return AuctionSummary(
      auctionId: json['auctionId'] as String? ?? '',
      status: json['auctionStatus'] as String? ?? 'live',
      startingBidCents: _int(json['startingBidCents']) ?? 0,
      highestBidCents: _int(json['highestBidCents']),
      bidCount: _int(json['bidCount']) ?? 0,
      minNextBidCents: _int(json['minNextBidCents']) ?? _int(json['startingBidCents']) ?? 0,
      bidIncrementCents: _int(json['bidIncrementCents']) ?? 0,
      endsAt: _date(json['auctionEndsAt']),
      opensAt: _date(json['opensAt']),
      deliveryMode: json['deliveryMode'] as String?,
      hasReserve: json['hasReserve'] == true,
      reserveMet: json['reserveMet'] != false,
      isHighestBidder: json['isHighestBidder'] == true,
      isWinner: json['isWinner'] == true,
      awaitingPayment: json['awaitingPayment'] == true,
      winnerDeadlineAt: _date(json['winnerDeadlineAt']),
      winningBidCents: _int(json['winningBidCents']),
    );
  }

  /// The server's field names, so a cached piece keeps its auction.
  Map<String, dynamic> toJson() => {
    'auctionId': auctionId,
    'auctionStatus': status,
    'startingBidCents': startingBidCents,
    'highestBidCents': ?highestBidCents,
    'bidCount': bidCount,
    'minNextBidCents': minNextBidCents,
    'bidIncrementCents': bidIncrementCents,
    if (endsAt != null) 'auctionEndsAt': endsAt!.toUtc().toIso8601String(),
    if (opensAt != null) 'opensAt': opensAt!.toUtc().toIso8601String(),
    'deliveryMode': ?deliveryMode,
    'hasReserve': hasReserve,
    'reserveMet': reserveMet,
    'isHighestBidder': isHighestBidder,
    'isWinner': isWinner,
    'awaitingPayment': awaitingPayment,
    if (winnerDeadlineAt != null) 'winnerDeadlineAt': winnerDeadlineAt!.toUtc().toIso8601String(),
    'winningBidCents': ?winningBidCents,
  };

  static int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
}

/// The artist's auction that ended without anything still to settle (BACKEND_CHANGES B38
/// `lastAuction`): sold, unsold or cancelled. Sent on their own piece only, for
/// `ArtistAuctionUnsold`: why it ended, the top bid and how many people bid.
class EndedAuction {
  const EndedAuction({
    required this.status,
    this.startingBidCents,
    this.reserveCents,
    this.topBidCents,
    this.bidCount = 0,
    this.bidderCount = 0,
  });

  /// `closed_no_bids`, `needs_seller_action` / `closed_reserve_not_met`, `cancelled`,
  /// `closed_sold`.
  final String status;
  final int? startingBidCents;
  final int? reserveCents;
  final int? topBidCents;
  final int bidCount;
  final int bidderCount;

  /// Ended without a sale: no bids, or the top bid under the reserve.
  bool get unsold => const {
    'closed_no_bids',
    'closed_reserve_not_met',
    'needs_seller_action',
  }.contains(status);

  bool get underReserve => status == 'closed_reserve_not_met' || status == 'needs_seller_action';

  static EndedAuction? maybeFrom(Object? json) {
    if (json is! Map) return null;
    final status = json['status'];
    if (status is! String || status.isEmpty) return null;
    return EndedAuction(
      status: status,
      startingBidCents: AuctionSummary._int(json['startingBidCents']),
      reserveCents: AuctionSummary._int(json['reserveCents']),
      topBidCents: AuctionSummary._int(json['topBidCents']),
      bidCount: AuctionSummary._int(json['bidCount']) ?? 0,
      bidderCount: AuctionSummary._int(json['bidderCount']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'startingBidCents': ?startingBidCents,
    'reserveCents': ?reserveCents,
    'topBidCents': ?topBidCents,
    'bidCount': bidCount,
    'bidderCount': bidderCount,
  };
}

/// One bid on the artist's own auction (`ArtistAuctionLive`): "Bidder 3", the amount and
/// when. Nobody is named until the winner pays (BACKEND_CHANGES B38).
class AuctionBidRow {
  const AuctionBidRow({
    required this.bidder,
    required this.amountCents,
    this.createdAt,
    this.isTop = false,
  });

  final int bidder;
  final int amountCents;
  final DateTime? createdAt;

  /// From the top bidder (the winner once there is one): their rows are 500.
  final bool isTop;

  factory AuctionBidRow.fromJson(Map<String, dynamic> json) => AuctionBidRow(
    bidder: AuctionSummary._int(json['bidder']) ?? 0,
    amountCents: AuctionSummary._int(json['amountCents']) ?? 0,
    createdAt: AuctionSummary._date(json['createdAt']),
    isTop: json['isTop'] == true,
  );
}

/// `GET /api/pieces/:id/auction/bids` (BACKEND_CHANGES B38): every bid, newest first, how
/// many people bid, and the best offer from anyone but the top bidder.
class AuctionBidHistory {
  const AuctionBidHistory({
    this.items = const [],
    this.bidCount = 0,
    this.bidderCount = 0,
    this.nextBidCents,
  });

  final List<AuctionBidRow> items;
  final int bidCount;
  final int bidderCount;
  final int? nextBidCents;

  factory AuctionBidHistory.fromJson(Map<String, dynamic> json) => AuctionBidHistory(
    items: [
      for (final row in (json['items'] as List? ?? const []))
        if (row is Map<String, dynamic>) AuctionBidRow.fromJson(row),
    ],
    bidCount: AuctionSummary._int(json['bidCount']) ?? 0,
    bidderCount: AuctionSummary._int(json['bidderCount']) ?? 0,
    nextBidCents: AuctionSummary._int(json['nextBidCents']),
  );
}

/// "2m", "18m", "1h", "1d" (`ArtistAuctionLive` bid times).
String auctionBidAge(DateTime? at, DateTime now) {
  if (at == null) return '';
  final age = now.difference(at);
  if (age.inDays >= 1) return '${age.inDays}d';
  if (age.inHours >= 1) return '${age.inHours}h';
  return '${age.inMinutes < 1 ? 1 : age.inMinutes}m';
}

/// The step above [cents] (`HandoffBidding`): $25 under $500, $50 to $999, $100 to $4,999,
/// $250 to $9,999, $500 above. Used for the quick picks; the server's minimum always wins.
int bidIncrementCents(int cents) {
  if (cents < 50000) return 2500;
  if (cents < 100000) return 5000;
  if (cents < 500000) return 10000;
  if (cents < 1000000) return 25000;
  return 50000;
}

/// The three quick picks (`BidSheet`): the minimum, then one and two steps above it.
List<int> bidQuickPicks(int minCents) {
  final step = bidIncrementCents(minCents);
  return [minCents, minCents + step, minCents + 2 * step];
}

/// "2d 4h", "5h 12m", "42m", "Ended".
String auctionTimeLeft(DateTime? endsAt, DateTime now) {
  if (endsAt == null) return '';
  final left = endsAt.difference(now);
  if (left <= Duration.zero) return 'Ended';
  if (left.inDays >= 1) return '${left.inDays}d ${left.inHours % 24}h';
  if (left.inHours >= 1) return '${left.inHours}h ${left.inMinutes % 60}m';
  return '${left.inMinutes < 1 ? 1 : left.inMinutes}m';
}

/// Under 24 hours, time remaining turns red (`NoteBidSheet`).
bool auctionEndingSoon(DateTime? endsAt, DateTime now) {
  if (endsAt == null) return false;
  final left = endsAt.difference(now);
  return left > Duration.zero && left < const Duration(hours: 24);
}

/// "47h 52m" (`BidWon`, `BidPaymentFailed`): hours and minutes until [deadline].
String auctionCountdown(DateTime deadline, DateTime now) {
  var left = deadline.difference(now);
  if (left.isNegative) left = Duration.zero;
  return '${left.inHours}h ${(left.inMinutes % 60).toString().padLeft(2, '0')}m';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Nov 2 · 6:40 PM" (`PostAvailAuction` "Ends", `BidWon` "Pay by").
String auctionDateTime(DateTime at) {
  final t = at.toLocal();
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '${_months[t.month - 1]} ${t.day} · $hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
}
