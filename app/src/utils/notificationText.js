/** Builds the "actor {displayText}" line the same way the app does — see
 * `lib/models/notification_item.dart`'s `displayText` getter. The server's
 * `message` field is only a fallback for unrecognized types; every known
 * type is rendered from `type` + `payload` client-side. */
export function notificationDisplayText(item) {
  const targetType = item.target?.type || 'post';
  switch (item.type) {
    case 'follow':
      return 'started following you';
    case 'like':
      return `liked your ${targetType}`;
    case 'save':
      return `saved your ${targetType}`;
    case 'comment': {
      const preview = item.payload?.commentPreview;
      return preview ? `commented: ${preview}` : 'commented on your post';
    }
    case 'inquiry': {
      const pieceTitle = item.payload?.pieceTitle;
      return pieceTitle ? `sent an inquiry about '${pieceTitle}'` : 'sent you an inquiry';
    }
    case 'purchase': {
      const pieceTitle = item.payload?.pieceTitle;
      return pieceTitle ? `purchased '${pieceTitle}'` : 'made a purchase';
    }
    default:
      return item.message || 'sent you a notification';
  }
}

/** Chat DMs (`message`) and piece inquiries (`inquiry`) surface as the Chats
 * tab badge/push only — Instagram-style — never in the activity Notifications
 * list. Matches `NotificationsBodyState._load`'s `!isInquiry && !isChatMessage`
 * filter. */
export function isChatLikeNotification(item) {
  return item.type === 'inquiry' || item.type === 'message';
}
