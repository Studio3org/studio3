/// A real activity notification (follow/like/save/comment/inquiry/purchase)
/// from `GET /api/notifications`.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    this.actorName,
    this.actorUsername,
    this.actorAvatarUrl,
    this.targetType,
    this.targetId,
    this.payload = const {},
    this.message,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String? actorName;
  final String? actorUsername;
  final String? actorAvatarUrl;
  final String? targetType;
  final String? targetId;
  final Map<String, dynamic> payload;
  final String? message;
  final bool read;
  final DateTime createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    final target = json['target'] as Map<String, dynamic>?;
    return NotificationItem(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      actorName: actor?['name'] as String?,
      actorUsername: actor?['username'] as String?,
      actorAvatarUrl: actor?['profilePhotoUrl'] as String?,
      targetType: target?['type'] as String?,
      targetId: target?['id'] as String?,
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      message: json['message'] as String?,
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Whether this notification is actually about something a person did — as opposed to a
  /// system/self event (a bid result, an auction closing, an event being cancelled) that has
  /// no one to name. [displayText] already reads as a complete sentence for the latter, so a
  /// caller should only prefix [actorDisplayName] onto it when this is true — otherwise a
  /// system message like "You won the auction" gets a fabricated "Someone" stitched onto it.
  bool get hasActor => actorName != null && actorName!.isNotEmpty;

  String get actorDisplayName => hasActor ? actorName! : 'Someone';

  bool get isInquiry => type == 'inquiry';

  /// Chat DMs — phone push + Chats badge only; not shown in Notifications tab.
  bool get isChatMessage => type == 'message';

  bool get isSale => type == 'purchase';

  /// The action text — shown after the actor's name when [hasActor], on its own otherwise.
  /// Built from the real notification type and payload where a type is worth its own
  /// sentence (follow/like/save/comment/inquiry/purchase); every other type — including
  /// every actor-less system notification — falls back to [message], which the backend now
  /// always sends (the same text it push-notified with), never a fabricated string.
  String get displayText {
    switch (type) {
      case 'follow':
        return 'started following you';
      case 'like':
        return 'liked your ${targetType ?? 'post'}';
      case 'save':
        return 'saved your ${targetType ?? 'post'}';
      case 'comment':
        final preview = payload['commentPreview'] as String?;
        return preview != null && preview.isNotEmpty
            ? 'commented: $preview'
            : 'commented on your post';
      case 'inquiry':
        final pieceTitle = payload['pieceTitle'] as String?;
        return pieceTitle != null
            ? "sent an inquiry about '$pieceTitle'"
            : 'sent you an inquiry';
      case 'purchase':
        final pieceTitle = payload['pieceTitle'] as String?;
        return pieceTitle != null
            ? "purchased '$pieceTitle'"
            : 'made a purchase';
      default:
        return message ?? 'sent you a notification';
    }
  }
}
