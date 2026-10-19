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

/** GET /api/conversations/:id — one page of a thread (also marks it read).
 * Raw response is `{id, otherParty:{id,username,name,profilePhotoUrl,...},
 * otherPartyReadAt, status, messages: {items:[...], nextCursor}}` — flattened
 * here the same way `lib/models/chat_message.dart`'s `ChatThread.fromJson`
 * does, so screens can read `thread.otherPartyName` etc. directly. The server
 * pages NEWEST FIRST; `messages` is reversed to oldest-first for display and
 * `nextCursor` (pass back as `cursor`) fetches the next-older page. Each
 * message is `{id, body, imageUrl, sender:{username,name,profilePhotoUrl}, createdAt}`. */
export async function fetchConversationThread(id, { cursor, limit } = {}) {
  const params = new URLSearchParams();
  if (cursor) params.set('cursor', cursor);
  if (limit) params.set('limit', String(limit));
  const qs = params.toString();
  const data = await apiFetch(`/api/conversations/${id}${qs ? `?${qs}` : ''}`, { auth: true });
  const otherParty = data?.otherParty || {};
  const messagesRaw = data?.messages;
  const newestFirst = Array.isArray(messagesRaw) ? messagesRaw : messagesRaw?.items ?? [];
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
    messages: [...newestFirst].reverse(),
    nextCursor: Array.isArray(messagesRaw) ? null : messagesRaw?.nextCursor ?? null,
  };
}

/** GET /api/conversations/with/:username — the open/pending thread with this
 * user, or `null` (none yet, closed, or blocked) — the compose-reuse check. */
export function findConversationWith(username) {
  return apiFetch(`/api/conversations/with/${encodeURIComponent(username)}`, { auth: true }).then(
    (data) => data?.conversation ?? null,
  );
}

/** POST /api/conversations — first message to someone. Returns `{id, reused, status}`.
 * 403 with a readable message when their messagePermission forbids it. */
export function startConversation({ username, message, imageUrl }) {
  return apiFetch('/api/conversations', {
    method: 'POST',
    auth: true,
    body: { username, ...(message ? { message } : {}), ...(imageUrl ? { imageUrl } : {}) },
  });
}

/** GET /api/conversations/search-users?q= → `[{username, name, profilePhotoUrl}]`. */
export function searchUsers(q, { limit = 20, signal } = {}) {
  const params = new URLSearchParams({ q, limit: String(limit) });
  return apiFetch(`/api/conversations/search-users?${params}`, { auth: true, signal }).then((data) => data?.items ?? []);
}

/** GET /api/user/:username — header info for a not-yet-started conversation. */
export function fetchUserProfile(username) {
  return apiFetch(`/api/user/${encodeURIComponent(username)}`, { auth: true });
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
