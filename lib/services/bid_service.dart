import '../models/auction_summary.dart';
import '../models/bid.dart';
import 'api_client.dart';

/// Bidding, and the auction actions either party can take afterwards.
///
/// The one thing worth knowing before reading: a bid is not a promise to pay, it is an
/// *authorisation*. Placing one puts a hold on the bidder's card for the bid amount, which
/// is why [placeBid] needs a saved card and why being outbid does not give the money back —
/// a bidder stays funded until the auction closes, because they are still in line if the
/// bid above them falls through.
class BidService {
  BidService._();
  static final BidService instance = BidService._();

  final _api = ApiClient.instance;

  /// Place a bid and authorise the money behind it.
  ///
  /// [paymentMethodId] is required for a bidder's first bid on a piece and optional
  /// afterwards — raising your own bid reuses the card already committed to that auction
  /// rather than asking again.
  ///
  /// Throws [ApiException] with the server's own wording: 402 when the card refuses the
  /// authorisation (the bid was **not** placed), 409 when the bid is below the minimum or
  /// bidding has closed.
  Future<Bid> placeBid(
    String pieceId,
    int amountCents, {
    String? paymentMethodId,
  }) async {
    final json = await _api.post(
      '/api/pieces/$pieceId/bids',
      body: {
        'amountCents': amountCents,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
      },
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    return Bid.fromJson(data);
  }

  /// The winner supplying a different card after theirs was declined at close.
  ///
  /// Only valid while the auction is `awaiting_payment` and only before
  /// `winnerDeadlineAt` — after that the piece passes to the next bidder. Throws 402 if the
  /// replacement card is declined too, in which case the window carries on.
  Future<AuctionSummary> retryWinnerPayment(
    String pieceId, {
    required String paymentMethodId,
  }) async {
    final json = await _api.post(
      '/api/pieces/$pieceId/auction/retry-payment',
      body: {'paymentMethodId': paymentMethodId},
      auth: true,
    );
    return AuctionSummary.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  // --- seller actions ---------------------------------------------------------------------

  /// The one manual extension a seller gets, and only while more than three days remain.
  ///
  /// Bids and holds survive an extension: it lengthens the auction, it does not restart it.
  Future<AuctionSummary> extend(String pieceId, {required int extraDays}) async {
    final json = await _api.post(
      '/api/pieces/$pieceId/auction/extend',
      body: {'extraDays': extraDays},
      auth: true,
    );
    return AuctionSummary.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// Withdraw a live auction. Every bid is voided, every hold released, every bidder told.
  ///
  /// Returns how many bids were cancelled, so the confirmation can say what actually
  /// happened to the people who were bidding.
  Future<int> cancel(String pieceId) async {
    final json = await _api.post('/api/pieces/$pieceId/auction/cancel', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    return (data['cancelledBids'] as num?)?.toInt() ?? 0;
  }

  /// Run a fresh auction on a piece whose last one ended without a sale.
  ///
  /// Omitted terms inherit the previous auction's. The old auction is kept as the record of
  /// what happened rather than being reopened.
  Future<AuctionSummary> relist(
    String pieceId, {
    required int durationDays,
    int? startingBidCents,
    int? reserveCents,
  }) async {
    final json = await _api.post(
      '/api/pieces/$pieceId/auction/relist',
      body: {
        'durationDays': durationDays,
        if (startingBidCents != null) 'startingBidCents': startingBidCents,
        if (reserveCents != null) 'reserveCents': reserveCents,
      },
      auth: true,
    );
    return AuctionSummary.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }
}
