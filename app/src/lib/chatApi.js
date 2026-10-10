import { API_BASE_URL, apiFetch } from './api';

/// Direct messages (/api/conversations) — the web counterpart of the app's
/// chat service. Live updates are polled by the thread screen; there is no
/// socket client on the web.

const qs = (params) => {
  const parts = Object.entries(params)
    .filter(([, v]) => v !== undefined && v !== null && v !== '')
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`);
  return parts.length ? `?${parts.join('&')}` : '';
};

export async function listInbox(cursor) {
  const data = await apiFetch(`/api/conversations${qs({ cursor, limit: 20 })}`, { auth: true });
  return { items: data?.items ?? [], nextCursor: data?.nextCursor ?? null };
}

export async function listRequests(cursor) {
  const data = await apiFetch(`/api/conversations/requests${qs({ cursor, limit: 20 })}`, { auth: true });
  return { items: data?.items ?? [], nextCursor: data?.nextCursor ?? null };
}

export async function searchUsers(q) {
  const data = await apiFetch(`/api/conversations/search-users${qs({ q, limit: 20 })}`, { auth: true });
  return data?.items ?? [];
}

/// Existing open/pending conversation with `username`, or null.
export async function findConversationWith(username) {
  const data = await apiFetch(`/api/conversations/with/${encodeURIComponent(username)}`, { auth: true });
  return data?.conversation ?? null;
}

/// Thread with messages in display order (oldest first). Fetching marks it read.
/// `cursor` (from `olderCursor`) pages back through history.
export async function getThread(id, cursor) {
  const data = await apiFetch(`/api/conversations/${id}${qs({ cursor, limit: 50 })}`, { auth: true });
  const items = [...(data?.messages?.items ?? [])].reverse();
  return { ...data, messages: items, olderCursor: data?.messages?.nextCursor ?? null };
}

/// Public profile header for someone we haven't messaged yet. 404 when the
/// account doesn't exist or either side has blocked the other.
export function getUserProfile(username) {
  return apiFetch(`/api/user/${encodeURIComponent(username)}`, { auth: true });
}

/// Starts (or reuses) a conversation with its first message → `{id, reused, status?}`.
export function startConversation(username, { message, imageUrl } = {}) {
  return apiFetch('/api/conversations', {
    method: 'POST',
    auth: true,
    body: { username, message: message ?? '', ...(imageUrl ? { imageUrl } : {}) },
  });
}

export function sendMessage(id, { body, imageUrl } = {}) {
  return apiFetch(`/api/conversations/${id}/messages`, {
    method: 'POST',
    auth: true,
    body: { ...(body ? { body } : {}), ...(imageUrl ? { imageUrl } : {}) },
  });
}

export function acceptConversation(id) {
  return apiFetch(`/api/conversations/${id}/accept`, { method: 'POST', auth: true });
}

export function declineConversation(id) {
  return apiFetch(`/api/conversations/${id}/decline`, { method: 'POST', auth: true });
}

const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_IMAGE_BYTES = 20 * 1024 * 1024;

/// Uploads a chat photo and resolves its public URL: presign (purpose 'chat'),
/// then PUT the raw bytes straight to storage. The PUT carries no auth header
/// or cookies — the presigned URL is the credential.
export async function uploadChatImage(file) {
  if (!IMAGE_TYPES.includes(file.type)) {
    throw new Error('Photos must be JPEG, PNG, or WebP.');
  }
  if (file.size > MAX_IMAGE_BYTES) {
    throw new Error('Photos must be 20 MB or smaller.');
  }
  const presign = await apiFetch('/api/media/presign', {
    method: 'POST',
    auth: true,
    body: { purpose: 'chat', contentType: file.type },
  });
  let putUrl = presign?.presignedPutUrl;
  if (!putUrl || !presign?.url) throw new Error("Couldn't prepare the upload. Please try again.");
  // Dev-mode presigns can be server-relative.
  if (putUrl.startsWith('/')) putUrl = `${API_BASE_URL}${putUrl}`;
  let res;
  try {
    res = await fetch(putUrl, {
      method: 'PUT',
      headers: { 'Content-Type': file.type },
      body: file,
      credentials: 'omit',
    });
  } catch {
    throw new Error("Couldn't upload the photo. Check your connection.");
  }
  if (!res.ok) throw new Error(`Upload failed (${res.status}).`);
  return presign.url;
}
