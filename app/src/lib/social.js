import { apiFetch, getSessionUser } from './api';

/// Engagement calls shared by feeds, detail pages, and profiles. All writes
/// need a signed-in (onboarded) account — gate them with useRequireLogin().

const base = (item) => (item.type === 'post' ? `/api/posts/${item.id}` : `/api/pieces/${item.id}`);

export function setLiked(item, liked) {
  return apiFetch(`${base(item)}/like`, { method: liked ? 'POST' : 'DELETE', auth: true });
}

export function setSaved(item, saved) {
  return apiFetch(`${base(item)}/save`, { method: saved ? 'POST' : 'DELETE', auth: true });
}

/// Resolves `{ following, requested }` (requested = pending on a private account).
export function setFollowing(username, follow) {
  return apiFetch(`/api/users/${encodeURIComponent(username)}/follow`, {
    method: follow ? 'POST' : 'DELETE',
    auth: true,
  });
}

export async function listComments(item, cursor) {
  const q = new URLSearchParams({ limit: '30' });
  if (cursor) q.set('cursor', cursor);
  const data = await apiFetch(`${base(item)}/comments?${q}`, { auth: true });
  return { items: data?.items ?? [], nextCursor: data?.nextCursor ?? null };
}

/// The create response has no author object — fill it from the session user,
/// the same way the app does, so it renders like the listed ones.
export async function addComment(item, body) {
  const data = await apiFetch(`${base(item)}/comments`, {
    method: 'POST',
    auth: true,
    body: { body },
  });
  const me = getSessionUser();
  return {
    id: data.id,
    body: data.body,
    createdAt: data.createdAt,
    author: {
      username: data.username ?? me?.username,
      name: me?.name ?? data.username,
      profilePhotoUrl: me?.profilePhotoUrl ?? null,
    },
  };
}

/// Turns the backend's onboarding/permission errors into actionable copy.
export function friendlyError(e) {
  if (e?.status === 403 && /onboarding/i.test(e.message)) {
    return 'Finish setting up your account to do that.';
  }
  return e?.message || 'Something went wrong. Please try again.';
}
