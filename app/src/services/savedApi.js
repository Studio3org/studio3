import { apiFetch } from './apiClient';

/// Saved items and collections ("saved folders"). All bearer-only.

const asArray = (data) => (Array.isArray(data) ? data : []);

/** Saved pieces — plain array of piece dicts (no `type` key; the endpoint says which). */
export async function listSavedPieces() {
  return asArray(await apiFetch('/api/user/me/saved/pieces', { auth: true }));
}

/** Saved scenes — plain array of post dicts. */
export async function listSavedPosts() {
  return asArray(await apiFetch('/api/user/me/saved/posts', { auth: true }));
}

/** Saved events — `{ events: EventCard[] }` from the events list's `saved` scope. */
export async function listSavedEvents() {
  const data = await apiFetch('/api/events?scope=saved&limit=100', { auth: true });
  return asArray(data?.events);
}

/** POST /api/events/:id/save `{ saved }` → `{ saved, saveCount }`. */
export function setEventSaved(eventId, saved) {
  return apiFetch(`/api/events/${eventId}/save`, { method: 'POST', auth: true, body: { saved } });
}

/** Plain array of `{id, name, createdAt, itemCount, cover{targetType,targetId,mediaUrl}|null}`. */
export async function listCollections() {
  return asArray(await apiFetch('/api/collections', { auth: true }));
}

export function createCollection(name) {
  return apiFetch('/api/collections', { method: 'POST', auth: true, body: { name } });
}

/** `{id, name, itemCount, items[]}` — items are piece/post dicts carrying `targetType`. */
export function getCollection(id) {
  return apiFetch(`/api/collections/${id}`, { auth: true });
}

export function renameCollection(id, name) {
  return apiFetch(`/api/collections/${id}`, { method: 'PATCH', auth: true, body: { name } });
}

export function deleteCollection(id) {
  return apiFetch(`/api/collections/${id}`, { method: 'DELETE', auth: true });
}

/** → `{ added, itemCount }`. targetType is 'piece' | 'post'. */
export function addToCollection(id, targetType, targetId) {
  return apiFetch(`/api/collections/${id}/items`, { method: 'POST', auth: true, body: { targetType, targetId } });
}

/** → `{ removed, itemCount }`. */
export function removeFromCollection(id, targetType, targetId) {
  return apiFetch(`/api/collections/${id}/items/${targetType}/${targetId}`, { method: 'DELETE', auth: true });
}
