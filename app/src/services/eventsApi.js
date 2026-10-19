import { apiFetch } from './apiClient';

/** POST /api/events. No Flutter backend or docs/api/flows entry exists for
 * events yet (the Flutter creation flow only fakes a publish delay) — this
 * follows the same shape as createPiece/createPost in postingApi.js so it's
 * ready the moment a real endpoint lands. */
export function createEvent(body) {
  return apiFetch('/api/events', { method: 'POST', auth: true, body });
}
