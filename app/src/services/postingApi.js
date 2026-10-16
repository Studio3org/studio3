import { apiFetch } from './apiClient';

/// Content types the presign endpoint accepts. Anything else is mapped to the nearest
/// accepted type — e.g. a .mov is declared as video/mp4, as the Flutter app does (gallery
/// files often lack a usable mime type). Images are always re-rendered to JPEG anyway.
const ACCEPTED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'video/mp4'];
const MAX_IMAGE_BYTES = 20 * 1024 * 1024;
const MAX_VIDEO_BYTES = 100 * 1024 * 1024;

function contentTypeFor(file) {
  const type = file?.type || '';
  if (ACCEPTED_TYPES.includes(type)) return type;
  return type.startsWith('video') ? 'video/mp4' : 'image/jpeg';
}

/** Uploads one file for a piece/scene and returns the public `mediaUrl` to reference in
 * the create call: presign, then PUT the raw bytes to the presigned URL. The PUT happens
 * in `devMode` too — the backend's local media endpoint stores the bytes there.
 *
 * @param {File | Blob} file
 * @param {'piece' | 'post'} purpose
 */
export async function uploadMedia(file, purpose) {
  const contentType = contentTypeFor(file);
  const isVideo = contentType.startsWith('video');
  if (file.size > (isVideo ? MAX_VIDEO_BYTES : MAX_IMAGE_BYTES)) {
    throw new Error(isVideo ? 'Videos must be 100 MB or smaller.' : 'Images must be 20 MB or smaller.');
  }

  const presign = await apiFetch('/api/media/presign', {
    method: 'POST',
    auth: true,
    body: { purpose, contentType },
  });

  // No auth header and no credentials: the presigned URL carries its own signature.
  const res = await fetch(presign.presignedPutUrl, {
    method: 'PUT',
    headers: { 'Content-Type': contentType },
    body: file,
  });
  if (!res.ok) throw new Error(`Upload failed (${res.status}). Please try again.`);

  return presign.url;
}

export function mediaTypeOf(file) {
  return file.type.startsWith('video') ? 'video' : 'image';
}

/** Uploads N already-rendered image blobs for a piece's gallery, one at a time, preserving
 * order (index 0 becomes the piece's cover). Sequential keeps partial-failure handling
 * trivial — stop and report rather than reconcile partial results.
 * @param {{blob: Blob, mediaAspectRatio?: string}[]} entries
 * @param {'piece' | 'post'} purpose
 * @returns {Promise<{mediaUrl: string, mediaType: 'image', mediaAspectRatio?: string}[]>}
 */
export async function uploadMediaSequence(entries, purpose) {
  const results = [];
  for (const { blob, mediaAspectRatio } of entries) {
    const mediaUrl = await uploadMedia(blob, purpose);
    results.push({ mediaUrl, mediaType: 'image', ...(mediaAspectRatio ? { mediaAspectRatio } : {}) });
  }
  return results;
}

/** POST /api/pieces → the created piece dict (`id`, `status`, …). */
export function createPiece(body) {
  return apiFetch('/api/pieces', { method: 'POST', auth: true, body });
}

/** POST /api/posts — a "scene" in the web UI. → the created post dict. */
export function createPost(body) {
  return apiFetch('/api/posts', { method: 'POST', auth: true, body });
}

/** The signed-in user's series. Plain array of
 * `{id, name, description, pieceCount, coverUrl, previewPieces}`. */
export async function listMySeries() {
  const data = await apiFetch('/api/user/me/series', { auth: true });
  return Array.isArray(data) ? data : [];
}

/** Creates a series already containing `pieceIds`. */
export function createSeries(name, pieceIds = []) {
  return apiFetch('/api/series', { method: 'POST', auth: true, body: { name, pieceIds } });
}

/** 400 "Piece already belongs to another series." if it's in a different one. */
export function addPieceToSeries(seriesId, pieceId) {
  return apiFetch(`/api/series/${seriesId}/pieces`, { method: 'POST', auth: true, body: { pieceId } });
}

/** The user's own pieces (the token makes the owner see drafts too), for the scene
 * composer's "Link to a Piece" picker. Plain array of piece dicts with `images[]`. */
export async function listMyPieces(username) {
  const data = await apiFetch(`/api/users/${encodeURIComponent(username)}/pieces`, { auth: true });
  return Array.isArray(data) ? data : [];
}
