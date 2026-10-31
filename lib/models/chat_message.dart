/// One row in the "new message" user search, from `GET /api/conversations/search-users`.
class MessageableUser {
  const MessageableUser({
    required this.username,
    required this.name,
    this.profilePhotoUrl,
  });

  final String username;
  final String name;
  final String? profilePhotoUrl;

  factory MessageableUser.fromJson(Map<String, dynamic> json) {
    return MessageableUser(
      username: json['username'] as String? ?? '',
      name: json['name'] as String? ?? '',
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
    );
  }

  String get displayName => name.isNotEmpty ? name : username;
}

/// Result of `POST /api/conversations`.
class ConversationCreateResult {
  const ConversationCreateResult({
    required this.id,
    required this.reused,
    this.status = 'open',
  });

  final String id;
  final bool reused;

  /// `"open"` or `"pending"` — pending means it landed in the recipient's
  /// message-requests folder instead of their main inbox.
  final String status;

  factory ConversationCreateResult.fromJson(Map<String, dynamic> json) {
    return ConversationCreateResult(
      id: json['id'] as String? ?? '',
      reused: json['reused'] as bool? ?? false,
      status: json['status'] as String? ?? 'open',
    );
  }
}

/// One row in the chat inbox, from `GET /api/conversations`.
/// The piece a conversation started from (BACKEND_CHANGES B9): the `Conversation` "About this
/// piece" card and the piece's thumbnail in Messages. [priceCents] only while it is for sale.
class ChatPiece {
  const ChatPiece({
    required this.id,
    required this.title,
    this.imageUrl,
    this.priceCents,
    this.artistUsername,
  });

  final String id;
  final String title;
  final String? imageUrl;
  final int? priceCents;
  final String? artistUsername;

  static ChatPiece? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) return null;
    return ChatPiece(
      id: id,
      title: json['title'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      priceCents: (json['priceCents'] as num?)?.toInt(),
      artistUsername: json['artistUsername'] as String?,
    );
  }
}

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    this.otherPartyId,
    this.otherPartyUsername,
    this.otherPartyName,
    this.otherPartyAvatarUrl,
    this.preview,
    required this.updatedAt,
    required this.unread,
    required this.status,
    this.muted = false,
    this.piece,
    this.matchPreview,
  });

  final String id;
  final String? otherPartyId;
  final String? otherPartyUsername;
  final String? otherPartyName;
  final String? otherPartyAvatarUrl;
  final String? preview;
  final DateTime updatedAt;
  final bool unread;
  final String status;

  /// Muted by the viewer (`ConvMenu` Mute notifications): the row shows a crossed-out bell.
  final bool muted;

  /// The piece the chat started from; its thumbnail shows on the right of the row.
  final ChatPiece? piece;

  /// From "Search messages" only: the newest message matching the search, cut so the match
  /// shows (BACKEND_CHANGES B10). Null when only the name matched.
  final String? matchPreview;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    final otherParty = json['otherParty'] as Map<String, dynamic>?;
    return ConversationSummary(
      id: json['id'] as String? ?? '',
      otherPartyId: otherParty?['id'] as String?,
      otherPartyUsername: otherParty?['username'] as String?,
      otherPartyName: otherParty?['name'] as String?,
      otherPartyAvatarUrl: otherParty?['profilePhotoUrl'] as String?,
      preview: json['preview'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      unread: json['unread'] as bool? ?? false,
      status: json['status'] as String? ?? 'open',
      muted: json['muted'] as bool? ?? false,
      piece: ChatPiece.fromJson(json['piece']),
      matchPreview: json['matchPreview'] as String?,
    );
  }

  String get otherPartyDisplayName =>
      (otherPartyName != null && otherPartyName!.isNotEmpty)
          ? otherPartyName!
          : 'Someone';

  ConversationSummary copyWith({bool? unread, String? status, bool? muted}) {
    return ConversationSummary(
      id: id,
      otherPartyId: otherPartyId,
      otherPartyUsername: otherPartyUsername,
      otherPartyName: otherPartyName,
      otherPartyAvatarUrl: otherPartyAvatarUrl,
      preview: preview,
      updatedAt: updatedAt,
      unread: unread ?? this.unread,
      status: status ?? this.status,
      muted: muted ?? this.muted,
      piece: piece,
      matchPreview: matchPreview,
    );
  }
}

/// A single message in a chat thread. `body` and/or `imageUrl` may be set.
class ChatMessage {
  const ChatMessage({
    required this.id,
    this.body,
    this.imageUrl,
    this.videoUrl,
    this.thumbnailUrl,
    this.senderUsername,
    this.senderName,
    this.senderAvatarUrl,
    required this.createdAt,
    this.isPending = false,
  });

  final String id;
  final String? body;
  final String? imageUrl;

  /// A video message (BACKEND_CHANGES B11) and its poster frame, when it has one.
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? senderUsername;
  final String? senderName;
  final String? senderAvatarUrl;
  final DateTime createdAt;
  /// True for a locally-created optimistic message shown immediately while
  /// its send request is still in flight — never set from the server
  /// (`fromJson` never sets it, so it defaults false for every real
  /// message).
  final bool isPending;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return ChatMessage(
      id: json['id'] as String? ?? '',
      body: json['body'] as String?,
      imageUrl: json['imageUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      senderUsername: sender?['username'] as String?,
      senderName: sender?['name'] as String?,
      senderAvatarUrl: sender?['profilePhotoUrl'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Full thread detail from `GET /api/conversations/:id`.
class ChatThread {
  const ChatThread({
    required this.id,
    this.otherPartyId,
    this.otherPartyUsername,
    this.otherPartyName,
    this.otherPartyAvatarUrl,
    this.otherPartyFollowersCount,
    this.otherPartyPiecesCount,
    this.otherPartyIsFollowing,
    this.otherPartyReadAt,
    required this.status,
    required this.messages,
    this.muted = false,
    this.piece,
  });

  final String id;
  final String? otherPartyId;
  final String? otherPartyUsername;
  final String? otherPartyName;
  final String? otherPartyAvatarUrl;
  final int? otherPartyFollowersCount;
  final int? otherPartyPiecesCount;
  final bool? otherPartyIsFollowing;
  final DateTime? otherPartyReadAt;
  final String status;
  final List<ChatMessage> messages;

  /// Muted by the viewer: no alerts for this chat (BACKEND_CHANGES B8).
  final bool muted;

  /// The piece the chat started from (B9): the "About this piece" card at the top.
  final ChatPiece? piece;

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final otherParty = json['otherParty'] as Map<String, dynamic>?;
    final messagesJson = json['messages'];
    final items = messagesJson is Map<String, dynamic>
        ? messagesJson['items']
        : messagesJson;
    final readAtRaw = json['otherPartyReadAt'] as String? ??
        otherParty?['otherPartyReadAt'] as String?;
    return ChatThread(
      id: json['id'] as String? ?? '',
      otherPartyId: otherParty?['id'] as String?,
      otherPartyUsername: otherParty?['username'] as String?,
      otherPartyName: otherParty?['name'] as String?,
      otherPartyAvatarUrl: otherParty?['profilePhotoUrl'] as String?,
      otherPartyFollowersCount: (otherParty?['followersCount'] as num?)?.toInt(),
      otherPartyPiecesCount: (otherParty?['piecesCount'] as num?)?.toInt(),
      otherPartyIsFollowing: otherParty?['isFollowing'] as bool?,
      otherPartyReadAt: readAtRaw != null ? DateTime.tryParse(readAtRaw) : null,
      status: json['status'] as String? ?? 'open',
      messages: items is List
          ? items.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson).toList()
          : const [],
      muted: json['muted'] as bool? ?? false,
      piece: ChatPiece.fromJson(json['piece']),
    );
  }
}
