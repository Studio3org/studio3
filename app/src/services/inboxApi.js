import { apiFetch } from './apiClient';

/** GET /api/notifications — cursor-paginated. Returns `{items, nextCursor}`
 * where each item is `{id, type, actor:{username,name,profilePhotoUrl},
 * target:{type,id}, payload, message, read, createdAt}` — see
 * docs/api/flows/notifications.md. */
export function fetchNotifications({ cursor, limit } = {}) {
  const params = new URLSearchParams();
  if (cursor) params.set('cursor', cursor);
  if (limit) params.set('limit', String(limit));
  const qs = params.toString();
  return apiFetch(`/api/notifications${qs ? `?${qs}` : ''}`, { auth: true });
}

export function markNotificationRead(id) {
  return apiFetch(`/api/notifications/${id}/read`, { method: 'PATCH', auth: true });
}

export function markAllNotificationsRead() {
  return apiFetch('/api/notifications/read-all', { method: 'POST', auth: true });
}

export function fetchUnreadNotificationCount() {
  return apiFetch('/api/notifications/unread-count', { auth: true }).then((data) => data?.count ?? 0);
}

/** GET /api/conversations — the chat inbox. Returns `{items, nextCursor}`
 * where each item is `{id, otherParty:{id,username,name,profilePhotoUrl},
 * preview, updatedAt, unread, status}` — see lib/services/chat_service.dart. */
export function fetchConversations({ cursor, limit } = {}) {
  const params = new URLSearchParams();
  if (cursor) params.set('cursor', cursor);
  if (limit) params.set('limit', String(limit));
  const qs = params.toString();
  return apiFetch(`/api/conversations${qs ? `?${qs}` : ''}`, { auth: true });
}

/** Pending message requests (recipient-side) — same shape as fetchConversations. */
export function fetchConversationRequests({ cursor, limit } = {}) {
  const params = new URLSearchParams();
  if (cursor) params.set('cursor', cursor);
  if (limit) params.set('limit', String(limit));
  const qs = params.toString();
  return apiFetch(`/api/conversations/requests${qs ? `?${qs}` : ''}`, { auth: true });
}

export function acceptConversationRequest(id) {
  return apiFetch(`/api/conversations/${id}/accept`, { method: 'POST', auth: true });
}

export function declineConversationRequest(id) {
  return apiFetch(`/api/conversations/${id}/decline`, { method: 'POST', auth: true });
}

/** GET /api/conversations/:id — full thread. Raw response is
 * `{id, otherParty:{id,username,name,profilePhotoUrl,...}, otherPartyReadAt,
 * status, messages: {items:[...]} | [...]}` — flattened here the same way
 * `lib/models/chat_message.dart`'s `ChatThread.fromJson` does, so screens can
 * read `thread.otherPartyName` etc. directly. Each message is
 * `{id, body, imageUrl, sender:{username,name,profilePhotoUrl}, createdAt}`. */
export async function fetchConversationThread(id) {
  const data = await apiFetch(`/api/conversations/${id}`, { auth: true });
  const otherParty = data?.otherParty || {};
  const messagesRaw = data?.messages;
  const messages = Array.isArray(messagesRaw) ? messagesRaw : messagesRaw?.items ?? [];
  return {
    ...data,
    otherPartyId: otherParty.id,
    otherPartyUsername: otherParty.username,
    otherPartyName: otherParty.name,
    otherPartyAvatarUrl: otherParty.profilePhotoUrl,
    otherPartyFollowersCount: otherParty.followersCount,
    otherPartyPiecesCount: otherParty.piecesCount,
    otherPartyIsFollowing: otherParty.isFollowing,
    otherPartyReadAt: data?.otherPartyReadAt ?? otherParty.otherPartyReadAt,
    messages,
  };
}

export function sendConversationMessage(id, { body, imageUrl } = {}) {
  return apiFetch(`/api/conversations/${id}/messages`, {
    method: 'POST',
    auth: true,
    body: { ...(body ? { body } : {}), ...(imageUrl ? { imageUrl } : {}) },
  });
}

export function markConversationRead(id) {
  return apiFetch(`/api/conversations/${id}/read`, { method: 'PATCH', auth: true });
}

export function fetchUnreadConversationCount() {
  return apiFetch('/api/conversations/unread-count', { auth: true }).then((data) => data?.count ?? 0);
}
