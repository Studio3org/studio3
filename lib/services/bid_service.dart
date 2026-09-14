import '../models/bid.dart';
import 'api_client.dart';

class BidService {
  BidService._();
  static final BidService instance = BidService._();

  final _api = ApiClient.instance;

  Future<Bid> placeBid(String pieceId, int amountCents) async {
    final json = await _api.post(
      '/api/pieces/$pieceId/bids',
      body: {'amountCents': amountCents},
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    return Bid.fromJson(data);
  }
}
