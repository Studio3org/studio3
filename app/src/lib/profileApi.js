import { apiFetch } from './api';
import { normalizeList, withAuthor } from './content';

/// Profile endpoints used by the profile, follow-list and settings screens.
/// List calls send the token (auth: true) so the owner sees their drafts and
/// an approved follower sees a private account's work.

const enc = encodeURIComponent;

export function getMe() {
  return apiFetch('/api/user/me', { auth: true });
}

export function getProfile(username) {
  return apiFetch(`/api/user/${enc(username)}`, { auth: true });
}

/// Locked = private account the viewer doesn't follow; the backend then sends
/// only the header fields (no counts) and the content lists would 403.
export function isLockedProfile(profile) {
  return profile?.profileVisibility === 'private' && profile.followersCount == null;
}

export function updateMe(fields) {
  return apiFetch('/api/user/me', { method: 'PATCH', auth: true, body: fields });
}

const LIST_PATHS = {
  pieces: ['pieces', 'piece'],
  scenes: ['posts', 'post'],
  collect: ['pieces/for-sale', 'piece'],
};

/// Pieces / scenes / for-sale pieces as normalized items carrying `profile` as author.
export async function listProfileItems(username, tab, profile) {
  const [path, kind] = LIST_PATHS[tab];
  const data = await apiFetch(`/api/users/${enc(username)}/${path}`, { auth: true });
  return withAuthor(normalizeList(data, kind), profile);
}

export async function listSeries(username) {
  const data = await apiFetch(`/api/users/${enc(username)}/series`, { auth: true });
  return Array.isArray(data) ? data : [];
}

/// `which` is 'followers' | 'following'; resolves `{ items, nextCursor }`.
export async function listFollows(username, which, cursor) {
  const q = new URLSearchParams({ limit: '30' });
  if (cursor) q.set('cursor', cursor);
  const data = await apiFetch(`/api/users/${enc(username)}/${which}?${q}`, { auth: true });
  return { items: data?.items ?? [], nextCursor: data?.nextCursor ?? null };
}

export async function listBlocked() {
  const data = await apiFetch('/api/users/blocked', { auth: true });
  return Array.isArray(data) ? data : [];
}

export function changePassword(currentPassword, newPassword) {
  return apiFetch('/api/user/me/password', {
    method: 'PATCH',
    auth: true,
    body: { currentPassword, newPassword },
  });
}

export function deleteAccount(password) {
  return apiFetch('/api/user/me', { method: 'DELETE', auth: true, body: { password } });
}
