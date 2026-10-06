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

  String get actorDisplayName =>
      (actorName != null && actorName!.isNotEmpty) ? actorName! : 'Someone';

  bool get isInquiry => type == 'inquiry';

  /// Chat DMs — phone push + Chats badge only; not shown in Notifications tab.
  bool get isChatMessage => type == 'message';

  bool get isSale => type == 'purchase';

  /// The action text shown after the actor's name, built from the real
  /// notification type and payload — never a fabricated string.
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
