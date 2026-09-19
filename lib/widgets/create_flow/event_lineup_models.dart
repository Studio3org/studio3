import '../../models/piece_summary.dart';

class EventLineupPerson {
  const EventLineupPerson({
    required this.username,
    required this.name,
    this.avatarUrl,
  });

  final String username;
  final String name;
  final String? avatarUrl;

  String get displayName => name.isNotEmpty ? name : username;

  String get handle => '@$username';

  @override
  bool operator ==(Object other) =>
      other is EventLineupPerson && other.username == username;

  @override
  int get hashCode => username.hashCode;
}

enum EventPieceMode { featured, sale, bid }

enum EventFulfillment { ship, pickup }

class EventTaggedPiece {
  const EventTaggedPiece({
    required this.piece,
    this.mode = EventPieceMode.featured,
    this.price = '25.00',
    this.fulfillment = EventFulfillment.pickup,
  });

  final PieceSummary piece;
  final EventPieceMode mode;
  final String price;
  final EventFulfillment fulfillment;

  /// Tagging this piece to an event ends its current fixed-price listing.
  bool get needsRelistForSale =>
      piece.isForSale && !piece.isAuction && piece.isAvailableListing;

  /// Tagging this piece to an event ends the auction it is currently in — which releases
  /// every bidder's hold and notifies them, so the confirmation has to say so.
  ///
  /// Keyed on isAuctionLive, not isAvailableListing: a live auction is deliberately not
  /// "available", because the price on it is a starting bid rather than something anyone
  /// can pay.
  bool get needsRelistForBid => piece.isAuctionLive;

  EventTaggedPiece copyWith({
    PieceSummary? piece,
    EventPieceMode? mode,
    String? price,
    EventFulfillment? fulfillment,
  }) {
    return EventTaggedPiece(
      piece: piece ?? this.piece,
      mode: mode ?? this.mode,
      price: price ?? this.price,
      fulfillment: fulfillment ?? this.fulfillment,
    );
  }
}

String eventPieceCoverUrl(PieceSummary piece) {
  if (piece.images.isNotEmpty && piece.images.first.mediaUrl.isNotEmpty) {
    return piece.images.first.mediaUrl;
  }
  return piece.mediaUrl ?? '';
}

String eventPiecePriceLabel(PieceSummary piece) {
  final cents = piece.priceCents;
  if (cents != null && cents > 0) {
    return (cents / 100).toStringAsFixed(2);
  }
  return '25.00';
}
