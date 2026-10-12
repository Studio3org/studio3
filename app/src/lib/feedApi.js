import { useEffect, useState } from 'react';
import { apiFetch, isBlockedAuthor, onAuthorBlocked } from './api';
import { normalizeList } from './content';

const PAGE_SIZE = 20;

function query(params) {
  const qs = Object.entries(params)
    .filter(([, v]) => v != null && v !== '')
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
    .join('&');
  return qs ? `?${qs}` : '';
}

/// Feed endpoints all answer `{ items, nextCursor }` with typed FeedItems.
async function fetchFeedPage(path, cursor, extra = {}) {
  const data = await apiFetch(`${path}${query({ cursor, limit: PAGE_SIZE, ...extra })}`, { auth: true });
  return { items: normalizeList(data?.items), nextCursor: data?.nextCursor ?? null };
}

export const fetchForYou = (cursor) => fetchFeedPage('/api/feed/for-you', cursor);
export const fetchFollowing = (cursor) => fetchFeedPage('/api/feed/following', cursor);
/// `medium`: 'video' → video scenes only; any other value → pieces of that medium.
export const fetchExplore = (cursor, medium) => fetchFeedPage('/api/feed/explore', cursor, { medium });

/// Notifications + chats unread, summed for the Home bell badge. A failing
/// half counts as zero so one flaky endpoint doesn't hide the other.
export async function fetchUnreadTotal() {
  const results = await Promise.allSettled([
    apiFetch('/api/notifications/unread-count', { auth: true }),
    apiFetch('/api/conversations/unread-count', { auth: true }),
  ]);
  return results.reduce(
    (sum, r) => sum + (r.status === 'fulfilled' ? Number(r.value?.count ?? 0) : 0),
    0,
  );
}

export async function searchUsers(q) {
  const data = await apiFetch(`/api/conversations/search-users${query({ q, limit: 20 })}`, { auth: true });
  return Array.isArray(data?.items) ? data.items : [];
}

/// Saved lists are plain arrays without a `type` key — the endpoint decides it.
export async function fetchSaved(kind) {
  const path = kind === 'post' ? '/api/user/me/saved/posts' : '/api/user/me/saved/pieces';
  return normalizeList(await apiFetch(path, { auth: true }), kind);
}

export async function fetchCollections() {
  const data = await apiFetch('/api/collections', { auth: true });
  return Array.isArray(data) ? data : [];
}

/// Collection items carry `targetType` instead of `type`; normalizeItem reads it.
export async function fetchCollection(id) {
  const data = await apiFetch(`/api/collections/${encodeURIComponent(id)}`, { auth: true });
  return { ...data, items: normalizeList(data?.items) };
}

export const createCollection = (name) =>
  apiFetch('/api/collections', { method: 'POST', body: { name }, auth: true });

export const renameCollection = (id, name) =>
  apiFetch(`/api/collections/${encodeURIComponent(id)}`, { method: 'PATCH', body: { name }, auth: true });

export const deleteCollection = (id) =>
  apiFetch(`/api/collections/${encodeURIComponent(id)}`, { method: 'DELETE', auth: true });

/// Drops content from authors blocked in this tab, re-rendering when a block
/// happens so lists already on screen update immediately.
export function useVisibleItems(items) {
  const [, setTick] = useState(0);
  useEffect(() => onAuthorBlocked(() => setTick((t) => t + 1)), []);
  return items.filter((item) => !isBlockedAuthor(item.author?.username));
}
