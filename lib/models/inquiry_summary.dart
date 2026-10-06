/// Result of `POST /api/inquiries`.
class InquiryCreateResult {
  const InquiryCreateResult({
    required this.id,
    required this.reused,
    this.status = 'open',
  });

  final String id;
  final bool reused;

  /// `"open"` or `"pending"` — pending means it landed in the seller's
  /// message-requests folder instead of their main inbox.
  final String status;

  factory InquiryCreateResult.fromJson(Map<String, dynamic> json) {
    return InquiryCreateResult(
      id: json['id'] as String? ?? '',
      reused: json['reused'] as bool? ?? false,
      status: json['status'] as String? ?? 'open',
    );
  }
}

/// One row in the inquiries inbox, from `GET /api/inquiries`.
class InquirySummary {
  const InquirySummary({
    required this.id,
    this.pieceId,
    this.pieceTitle,
    this.pieceThumbnailUrl,
    this.otherPartyUsername,
    this.otherPartyName,
    this.otherPartyAvatarUrl,
    this.preview,
    required this.updatedAt,
    required this.unread,
    required this.status,
  });

  final String id;
  final String? pieceId;
  final String? pieceTitle;
  final String? pieceThumbnailUrl;
  final String? otherPartyUsername;
  final String? otherPartyName;
  final String? otherPartyAvatarUrl;
  final String? preview;
  final DateTime updatedAt;
  final bool unread;
  final String status;

  factory InquirySummary.fromJson(Map<String, dynamic> json) {
    final piece = json['piece'] as Map<String, dynamic>?;
    final otherParty = json['otherParty'] as Map<String, dynamic>?;
    return InquirySummary(
      id: json['id'] as String? ?? '',
      pieceId: piece?['id'] as String?,
      pieceTitle: piece?['title'] as String?,
      pieceThumbnailUrl: piece?['thumbnailUrl'] as String?,
      otherPartyUsername: otherParty?['username'] as String?,
      otherPartyName: otherParty?['name'] as String?,
      otherPartyAvatarUrl: otherParty?['profilePhotoUrl'] as String?,
      preview: json['preview'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      unread: json['unread'] as bool? ?? false,
      status: json['status'] as String? ?? 'open',
    );
  }

  String get displayTitle =>
      (pieceTitle != null && pieceTitle!.isNotEmpty) ? pieceTitle! : 'Inquiry';

  String get otherPartyDisplayName =>
      (otherPartyName != null && otherPartyName!.isNotEmpty)
          ? otherPartyName!
          : 'Someone';

  InquirySummary copyWith({bool? unread, String? status}) {
    return InquirySummary(
      id: id,
      pieceId: pieceId,
      pieceTitle: pieceTitle,
      pieceThumbnailUrl: pieceThumbnailUrl,
      otherPartyUsername: otherPartyUsername,
      otherPartyName: otherPartyName,
      otherPartyAvatarUrl: otherPartyAvatarUrl,
      preview: preview,
      updatedAt: updatedAt,
      unread: unread ?? this.unread,
      status: status ?? this.status,
    );
  }
}

/// A single message in an inquiry thread.
class InquiryMessage {
  const InquiryMessage({
    required this.id,
    required this.body,
    this.senderUsername,
    this.senderName,
    this.senderAvatarUrl,
    required this.createdAt,
    this.isPending = false,
  });

  final String id;
  final String body;
  final String? senderUsername;
  final String? senderName;
  final String? senderAvatarUrl;
  final DateTime createdAt;
  /// True for a locally-created optimistic message shown immediately while
  /// its send request is still in flight — never set from the server.
  final bool isPending;

  factory InquiryMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return InquiryMessage(
      id: json['id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      senderUsername: sender?['username'] as String?,
      senderName: sender?['name'] as String?,
      senderAvatarUrl: sender?['profilePhotoUrl'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Full thread detail from `GET /api/inquiries/:id`.
class InquiryThread {
  const InquiryThread({
    required this.id,
    this.pieceId,
    this.pieceTitle,
    this.pieceThumbnailUrl,
    this.otherPartyUsername,
    this.otherPartyName,
    this.otherPartyAvatarUrl,
    required this.status,
    required this.messages,
  });

  final String id;
  final String? pieceId;
  final String? pieceTitle;
  final String? pieceThumbnailUrl;
  final String? otherPartyUsername;
  final String? otherPartyName;
  final String? otherPartyAvatarUrl;
  final String status;
  final List<InquiryMessage> messages;

  factory InquiryThread.fromJson(Map<String, dynamic> json) {
    final piece = json['piece'] as Map<String, dynamic>?;
    final otherParty = json['otherParty'] as Map<String, dynamic>?;
    final messagesJson = json['messages'];
    final items = messagesJson is Map<String, dynamic>
        ? messagesJson['items']
        : messagesJson;
    return InquiryThread(
      id: json['id'] as String? ?? '',
      pieceId: piece?['id'] as String?,
      pieceTitle: piece?['title'] as String?,
      pieceThumbnailUrl: piece?['thumbnailUrl'] as String?,
      otherPartyUsername: otherParty?['username'] as String?,
      otherPartyName: otherParty?['name'] as String?,
      otherPartyAvatarUrl: otherParty?['profilePhotoUrl'] as String?,
      status: json['status'] as String? ?? 'open',
      messages: items is List
          ? items
              .whereType<Map<String, dynamic>>()
              .map(InquiryMessage.fromJson)
              .toList()
          : const [],
    );
  }

  String get displayTitle =>
      (pieceTitle != null && pieceTitle!.isNotEmpty) ? pieceTitle! : 'Inquiry';
}
