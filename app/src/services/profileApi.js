import { apiFetch } from './apiClient';

/// Profile + account-settings calls. Everything passes `auth: true` so a signed-in viewer's
/// token goes along (owner sees drafts, followers see private content, blocks apply).

const enc = encodeURIComponent;

/** GET /api/user/:username. A locked private account comes back as
 * `{ username, name, profilePhotoUrl, profileVisibility: 'private', isFollowing, followRequestPending }`
 * with no counts. 404 = missing or blocked either way. */
export function getProfile(username, { auth = true } = {}) {
  return apiFetch(`/api/user/${enc(username)}`, { auth });
}

const asArray = (data) => (Array.isArray(data) ? data : data?.items ?? []);

/** Profile grids — plain arrays (no author / engagement fields). */
export async function listUserPieces(username, opts) {
  return asArray(await apiFetch(`/api/users/${enc(username)}/pieces`, { auth: true, ...opts }));
}
export async function listUserPosts(username, opts) {
  return asArray(await apiFetch(`/api/users/${enc(username)}/posts`, { auth: true, ...opts }));
}
export async function listUserSeries(username, opts) {
  return asArray(await apiFetch(`/api/users/${enc(username)}/series`, { auth: true, ...opts }));
}

/** `kind` is 'followers' | 'following'. Resolves `{ items: [{username,name,profilePhotoUrl}], nextCursor }`. */
export async function listFollows(username, kind, cursor) {
  const q = new URLSearchParams({ limit: '30' });
  if (cursor) q.set('cursor', cursor);
  const data = await apiFetch(`/api/users/${enc(username)}/${kind}?${q}`, { auth: true });
  return { items: asArray(data), nextCursor: data?.nextCursor ?? null };
}

// ---- Account settings (bearer) ------------------------------------------------------------

export function getMe() {
  return apiFetch('/api/user/me', { auth: true });
}

/** `{ profileVisibility?: 'public'|'private', messagePermission?: 'everyone'|'following'|'no_one' }` → UserMe. */
export function updatePrivacy(body) {
  return apiFetch('/api/user/me', { method: 'PATCH', auth: true, body });
}

/** Revokes every session server-side and returns `{ accessToken, user }` for this one. */
export function changePassword(currentPassword, newPassword) {
  return apiFetch('/api/user/me/password', {
    method: 'PATCH',
    auth: true,
    body: { currentPassword, newPassword },
  });
}

/** Deep-merged server-side. Resolves `{ notificationPreferences }`. */
export function updateNotificationPreferences(body) {
  return apiFetch('/api/user/me/notification-preferences', { method: 'PATCH', auth: true, body });
}

/** Emails a 6-digit code to the new address. */
export function requestEmailChange(newEmail) {
  return apiFetch('/api/user/me/email/request-change', { method: 'POST', auth: true, body: { newEmail } });
}

export function confirmEmailChange(newEmail, otp) {
  return apiFetch('/api/user/me/email/confirm-change', {
    method: 'POST',
    auth: true,
    body: { newEmail, otp },
  });
}

export function logoutAllDevices() {
  return apiFetch('/api/auth/logout-all', { method: 'POST', auth: true });
}

/** `{ location }` or `{ useProfileLocation: true }`. 400 "Seller location is required." otherwise. */
export function enableSeller(body) {
  return apiFetch('/api/user/me/seller/enable', { method: 'POST', auth: true, body });
}

/** 400 while active listings or in-progress sales exist. */
export function disableSeller() {
  return apiFetch('/api/user/me/seller/disable', { method: 'POST', auth: true });
}

/** `{ savesCount, likesCount, inquiriesCount, salesCount, period }`. */
export function getSellerAnalytics() {
  return apiFetch('/api/user/me/seller/analytics', { auth: true });
}
