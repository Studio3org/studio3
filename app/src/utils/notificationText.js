import { contentHref, profileHref } from './contentLinks';

/// The API calls scenes `post`; the UI never says "post".
function targetNoun(item) {
  const type = item.target?.type;
  if (type === 'piece') return 'piece';
  return 'scene';
}

/** Builds the "actor {displayText}" line the same way the app does — see
 * `lib/models/notification_item.dart`'s `displayText` getter. The server's
 * `message` field is only a fallback for unrecognized types; every known
 * type is rendered from `type` + `payload` client-side. */
export function notificationDisplayText(item) {
  switch (item.type) {
    case 'follow':
      return 'started following you';
    case 'follow_request':
      return 'requested to follow you';
    case 'like':
      return `liked your ${targetNoun(item)}`;
    case 'save':
      return `saved your ${targetNoun(item)}`;
    case 'comment': {
      const preview = item.payload?.commentPreview;
      return preview ? `commented: ${preview}` : `commented on your ${targetNoun(item)}`;
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

/** Where tapping a notification goes, or null when there's nothing to open.
 * Content notifications open the piece/scene (scenes on /scene/:id); follows
 * open the actor's profile; sales and inquiries open the piece. */
export function notificationHref(item) {
  const target = item.target;
  switch (item.type) {
    case 'like':
    case 'save':
    case 'comment':
      return target?.id ? contentHref({ type: target.type, id: target.id }) : null;
    case 'follow':
    case 'follow_request':
      return item.actor?.username ? profileHref(item.actor.username) : null;
    case 'inquiry':
    case 'purchase': {
      const pieceId = target?.type === 'piece' ? target.id : item.payload?.pieceId ?? target?.id;
      return pieceId ? `/piece/${pieceId}` : null;
    }
    default:
      if (target?.id && (target.type === 'piece' || target.type === 'post')) return contentHref(target);
      return item.actor?.username ? profileHref(item.actor.username) : null;
  }
}

/** Chat DMs (`message`) and piece inquiries (`inquiry`) surface as the Chats
 * tab badge/push only — Instagram-style — never in the activity Notifications
 * list. Matches `NotificationsBodyState._load`'s `!isInquiry && !isChatMessage`
 * filter. */
export function isChatLikeNotification(item) {
  return item.type === 'inquiry' || item.type === 'message';
}
