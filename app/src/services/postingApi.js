import { apiFetch } from './apiClient';

/** Uploads one file for a piece/scene cover and returns the public `mediaUrl`
 * to reference in the create call — mirrors `MediaService.uploadBytes` (see
 * docs/api/flows/media.md): presign, then PUT the raw bytes to the presigned
 * URL (skipped in `devMode`, where the backend hands back a placeholder URL
 * with nothing to upload to).
 *
 * @param {File} file
 * @param {'piece' | 'post'} purpose
 */
export async function uploadMedia(file, purpose) {
  const presign = await apiFetch('/api/media/presign', {
    method: 'POST',
    auth: true,
    body: { purpose, contentType: file.type },
  });

  if (!presign.devMode) {
    const res = await fetch(presign.presignedPutUrl, {
      method: 'PUT',
      headers: { 'Content-Type': file.type },
      body: file,
    });
    if (!res.ok) throw new Error(`Upload failed (${res.status})`);
  }

  return presign.url;
}

export function mediaTypeOf(file) {
  return file.type.startsWith('video') ? 'video' : 'image';
}

/** Uploads N already-rendered image blobs for a piece's gallery, one at a
 * time, preserving order (order is meaningful — index 0 becomes the piece's
 * cover). Sequential rather than parallel: no confirmed backend concurrency
 * limit to design against, no user-facing win from parallelizing a handful
 * of small uploads, and it makes partial-failure handling trivial (stop and
 * report which one failed rather than reconciling partial results).
 * @param {Blob[]} blobs
 * @param {'piece' | 'post'} purpose
 * @returns {Promise<{mediaUrl: string, mediaType: 'image'}[]>}
 */
export async function uploadMediaSequence(blobs, purpose) {
  const results = [];
  for (const blob of blobs) {
    const mediaUrl = await uploadMedia(blob, purpose);
    results.push({ mediaUrl, mediaType: 'image' });
  }
  return results;
}

/** POST /api/pieces — see docs/api/flows/pieces-scenes.md. */
export function createPiece(body) {
  return apiFetch('/api/pieces', { method: 'POST', auth: true, body });
}

/** POST /api/posts — a "scene" in the web UI. */
export function createPost(body) {
  return apiFetch('/api/posts', { method: 'POST', auth: true, body });
}
