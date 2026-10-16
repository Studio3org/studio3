import { apiFetch } from './apiClient';

/// Engagement, moderation and social-graph calls shared across screens. Writes need a
/// signed-in, onboarded account — gate them with useRequireLogin() first.

const enc = encodeURIComponent;
const targetBase = (type, id) => (type === 'post' ? `/api/posts/${id}` : `/api/pieces/${id}`);

/** Like or unlike a piece / scene. Resolves `{ liked, likeCount }`. */
export function setLiked(type, id, liked) {
  return apiFetch(`${targetBase(type, id)}/like`, { method: liked ? 'POST' : 'DELETE', auth: true });
}

/** Save or unsave a piece / scene. Resolves `{ saved, saveCount }`. */
export function setSaved(type, id, saved) {
  return apiFetch(`${targetBase(type, id)}/save`, { method: saved ? 'POST' : 'DELETE', auth: true });
}

/** Follow / unfollow. Resolves `{ following, requested }` (requested = pending on a private account). */
export function setFollowing(username, follow) {
  return apiFetch(`/api/users/${enc(username)}/follow`, { method: follow ? 'POST' : 'DELETE', auth: true });
}

/** Comments, newest first. Resolves `{ items: [{id, body, author, createdAt}], nextCursor }`. */
export async function listComments(type, id, cursor) {
  const q = new URLSearchParams({ limit: '30' });
  if (cursor) q.set('cursor', cursor);
  const data = await apiFetch(`${targetBase(type, id)}/comments?${q}`, { auth: true });
  return { items: data?.items ?? [], nextCursor: data?.nextCursor ?? null };
}

/** The create response carries no author object — the caller fills it from the signed-in user. */
export function addComment(type, id, body) {
  return apiFetch(`${targetBase(type, id)}/comments`, { method: 'POST', auth: true, body: { body } });
}

// ---- Moderation (App Store guideline 1.2) ---------------------------------------------

/** Must match the backend's REPORT_REASONS. */
export const REPORT_REASONS = [
  ['inappropriate', 'Nudity, violence, or other objectionable content'],
  ['harassment', 'Harassment, hate, or bullying'],
  ['spam', 'Spam or scam'],
  ['stolen_work', 'Stolen or copied artwork'],
  ['other', 'Something else'],
];

/** target: `{ type: 'piece'|'post'|'comment'|'user', id }` — `id` is the username for users. */
export function reportContent(target, reason, details) {
  const paths = {
    piece: `/api/pieces/${target.id}/report`,
    post: `/api/posts/${target.id}/report`,
    comment: `/api/comments/${target.id}/report`,
    user: `/api/users/${enc(target.id)}/report`,
  };
  const trimmed = details?.trim();
  return apiFetch(paths[target.type], {
    method: 'POST',
    auth: true,
    body: { reason, ...(trimmed ? { details: trimmed } : {}) },
  });
}

/** Reports this account has filed. Plain array of `{id, targetType, targetLabel, reason, status, createdAt}`. */
export function listMyReports() {
  return apiFetch('/api/reports/mine', { auth: true });
}

export function blockUser(username) {
  return apiFetch(`/api/users/${enc(username)}/block`, { method: 'POST', auth: true });
}

export function unblockUser(username) {
  return apiFetch(`/api/users/${enc(username)}/block`, { method: 'DELETE', auth: true });
}

/** Plain array of `{ username, name, profilePhotoUrl }`. */
export function listBlockedUsers() {
  return apiFetch('/api/users/blocked', { auth: true });
}

// ---- Follow requests --------------------------------------------------------------------

/** Plain array of `{ username, name, profilePhotoUrl, requestedAt }`. */
export function listFollowRequests() {
  return apiFetch('/api/users/follow-requests', { auth: true });
}

export function respondToFollowRequest(username, accept) {
  return apiFetch(`/api/users/follow-requests/${enc(username)}/${accept ? 'accept' : 'decline'}`, {
    method: 'POST',
    auth: true,
  });
}

/** Turns the backend's onboarding gate into actionable copy. */
export function friendlyError(e) {
  if (e?.status === 403 && /onboarding/i.test(e.message || '')) {
    return 'Finish setting up your account to do that.';
  }
  return e?.message || 'Something went wrong. Please try again.';
}
