/// Piece-scoped inquiries — deferred to v2.
///
/// Launch messaging uses Conversations (`ChatService` + Socket.IO). Do not
/// wire this service into live navigation until the backend inquiries
/// blueprint is re-registered.
import '../models/inquiry_summary.dart';
import 'api_client.dart';

class InquiryInboxPage {
  const InquiryInboxPage({required this.items, this.nextCursor});

  final List<InquirySummary> items;
  final String? nextCursor;
}

class InquiryService {
  InquiryService._();
  static final InquiryService instance = InquiryService._();

  final _api = ApiClient.instance;

  Future<InquiryInboxPage> getInbox({String? cursor, int? limit}) {
    return _getInquiryPage('/api/inquiries', cursor: cursor, limit: limit);
  }

  /// Pending message requests (seller-side) — same shape/pagination as
  /// [getInbox], routed to a different endpoint.
  Future<InquiryInboxPage> listRequests({String? cursor, int? limit}) {
    return _getInquiryPage(
      '/api/inquiries/requests',
      cursor: cursor,
      limit: limit,
    );
  }

  Future<InquiryInboxPage> _getInquiryPage(
    String path, {
    String? cursor,
    int? limit,
  }) async {
    final query = <String, String>{};
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    if (limit != null) query['limit'] = limit.toString();

    final json = await _api.get(
      path,
      query: query.isEmpty ? null : query,
      auth: true,
    );
    final data = _api.extractData(json);
    final items = _api
        .extractList(json)
        .map(InquirySummary.fromJson)
        .toList(growable: false);
    final nextCursor =
        data is Map<String, dynamic> ? data['nextCursor'] as String? : null;
    return InquiryInboxPage(items: items, nextCursor: nextCursor);
  }

  Future<void> acceptRequest(String id) async {
    await _api.post('/api/inquiries/$id/accept', auth: true);
  }

  Future<void> declineRequest(String id) async {
    await _api.post('/api/inquiries/$id/decline', auth: true);
  }

  Future<InquiryCreateResult> createInquiry(String pieceId, String message) async {
    final json = await _api.post(
      '/api/inquiries',
      body: {'pieceId': pieceId, 'message': message},
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    return InquiryCreateResult.fromJson(data);
  }

  Future<InquiryThread> getThread(String id) async {
    final json = await _api.get('/api/inquiries/$id', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    return InquiryThread.fromJson(data);
  }

  Future<InquiryMessage> reply(String id, String body) async {
    final json = await _api.post(
      '/api/inquiries/$id/messages',
      body: {'body': body},
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    return InquiryMessage.fromJson(data);
  }

  Future<void> markRead(String id) => _api.patch('/api/inquiries/$id/read');
}
