import { apiFetch, getAccessToken } from './apiClient';

/// Feeds, single-post lookup and the Discover side calls (nearby sellers, people search).
/// Every call passes `auth: true` so a signed-in viewer gets isLiked / isSaved / blocks
/// applied; the backend treats these routes as optional-auth, so guests work too.

const FEED_PATHS = {
  forYou: '/api/feed/for-you',
  following: '/api/feed/following', // onboarded accounts only — gate guests before calling
  explore: '/api/feed/explore',
};

/**
 * One page of a feed. `medium` only applies to explore: `video` → video scenes only, any
 * other value → pieces of that (lowercase) medium.
 * @returns {Promise<{ items: object[], nextCursor: string|null }>}
 */
export async function fetchFeed(kind, { cursor, limit, medium, signal } = {}) {
  // Guests read For You from explore: for-you is the same merged feed server-side, and a
  // backend that still gates for-you behind login would otherwise show guests an error.
  if (kind === 'forYou' && !getAccessToken()) kind = 'explore';
  const q = new URLSearchParams();
  if (cursor) q.set('cursor', cursor);
  if (limit) q.set('limit', String(limit));
  if (medium && kind === 'explore') q.set('medium', medium);
  const qs = q.toString();
  const data = await apiFetch(`${FEED_PATHS[kind]}${qs ? `?${qs}` : ''}`, { auth: true, signal });
  return { items: Array.isArray(data?.items) ? data.items : [], nextCursor: data?.nextCursor ?? null };
}

/** GET /api/posts/:id — the detail dict has no `type` key, so tag it as a scene. */
export async function fetchPost(id, { signal } = {}) {
  const post = await apiFetch(`/api/posts/${encodeURIComponent(id)}`, { auth: true, signal });
  return post ? { ...post, type: 'post' } : null;
}

/** GET /api/users/nearby — seller accounts within ~50km. Plain array of user dicts + `distanceKm`. */
export async function fetchNearbySellers(lat, lng) {
  const data = await apiFetch(`/api/users/nearby?lat=${lat}&lng=${lng}`, { auth: true });
  return Array.isArray(data?.items) ? data.items : [];
}

/** People search. Plain array of `{ username, name, profilePhotoUrl }`. */
export async function searchUsers(q, { signal } = {}) {
  const data = await apiFetch(`/api/conversations/search-users?q=${encodeURIComponent(q)}&limit=20`, {
    auth: true,
    signal,
  });
  return Array.isArray(data?.items) ? data.items : [];
}

/** True for a video scene (the backend also accepts legacy "reel"/"reels" media types). */
export function isVideoItem(item) {
  return ['video', 'reel', 'reels'].includes(item?.mediaType);
}

/** A piece someone can still buy or bid on — what the Home "Available" filter shows. */
export function isAvailablePiece(item) {
  if (item?.type !== 'piece' || !item.isForSale) return false;
  if (item.listingState) return item.listingState === 'available' || item.listingState === 'auction_live';
  return item.status === 'live';
}

/** "$1,200" from priceCents + currency; null when there's no price. */
export function formatPrice(priceCents, currency = 'USD') {
  if (priceCents == null) return null;
  try {
    return new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency: (currency || 'USD').toUpperCase(),
      maximumFractionDigits: priceCents % 100 === 0 ? 0 : 2,
    }).format(priceCents / 100);
  } catch {
    return `$${(priceCents / 100).toFixed(0)}`;
  }
}
