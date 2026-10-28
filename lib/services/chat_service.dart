import '../models/chat_message.dart';
import 'api_client.dart';

class ConversationInboxPage {
  const ConversationInboxPage({required this.items, this.nextCursor});

  final List<ConversationSummary> items;
  final String? nextCursor;
}

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final _api = ApiClient.instance;

  Future<ConversationInboxPage> getInbox({String? cursor, int? limit}) {
    return _getConversationPage('/api/conversations', cursor: cursor, limit: limit);
  }

  /// Pending message requests (recipient-side) — same shape/pagination as
  /// [getInbox], routed to a different endpoint.
  Future<ConversationInboxPage> listRequests({String? cursor, int? limit}) {
    return _getConversationPage(
      '/api/conversations/requests',
      cursor: cursor,
      limit: limit,
    );
  }

  Future<ConversationInboxPage> _getConversationPage(
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
        .map(ConversationSummary.fromJson)
        .toList(growable: false);
    final nextCursor =
        data is Map<String, dynamic> ? data['nextCursor'] as String? : null;
    return ConversationInboxPage(items: items, nextCursor: nextCursor);
  }

  Future<void> acceptRequest(String id) async {
    await _api.post('/api/conversations/$id/accept', auth: true);
  }

  Future<void> declineRequest(String id) async {
    await _api.post('/api/conversations/$id/decline', auth: true);
  }

  Future<ConversationCreateResult> startConversation(
    String username,
    String message, {
    String? imageUrl,
  }) async {
    final json = await _api.post(
      '/api/conversations',
      body: {
        'username': username,
        'message': message,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    return ConversationCreateResult.fromJson(data);
  }

  /// Mutes or unmutes [id] for the viewer only (`ConvMenu`): messages still arrive, no alerts,
  /// and it leaves the unread badge. Returns the state the server kept.
  Future<bool> setMuted(String id, bool muted) async {
    final json = await _api.patch('/api/conversations/$id/mute', body: {'muted': muted});
    final data = _api.extractData(json);
    return data is Map<String, dynamic> ? data['muted'] as bool? ?? muted : muted;
  }

  Future<ChatThread> getThread(String id) async {
    final json = await _api.get('/api/conversations/$id', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    return ChatThread.fromJson(data);
  }

  /// Existing open/pending thread with [username], or null if compose is needed.
  Future<ConversationSummary?> findConversationWith(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return null;
    final encoded = Uri.encodeComponent(trimmed);
    final json = await _api.get(
      '/api/conversations/with/$encoded',
      auth: true,
    );
    final data = _api.extractData(json);
    if (data is! Map<String, dynamic>) return null;
    final conversation = data['conversation'];
    if (conversation is! Map<String, dynamic>) return null;
    return ConversationSummary.fromJson(conversation);
  }

  Future<ChatMessage> sendMessage(String id, {String? body, String? imageUrl}) async {
    final json = await _api.post(
      '/api/conversations/$id/messages',
      body: {
        if (body != null) 'body': body,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    return ChatMessage.fromJson(data);
  }

  Future<void> markRead(String id) => _api.patch('/api/conversations/$id/read');

  /// Users matching `query` (username or name) for the "new message" composer.
  Future<List<MessageableUser>> searchUsers(String query) async {
    if (query.trim().isEmpty) return const [];
    final json = await _api.get(
      '/api/conversations/search-users',
      query: {'q': query.trim()},
      auth: true,
    );
    return _api
        .extractList(json)
        .map(MessageableUser.fromJson)
        .toList(growable: false);
  }

  /// Total unread open conversations — used for the nav / inbox badge.
  Future<int> unreadCount() async {
    final json = await _api.get('/api/conversations/unread-count', auth: true);
    final data = _api.extractData(json);
    if (data is Map<String, dynamic>) {
      return (data['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }
}
