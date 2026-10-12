import { apiFetch } from './api';

const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_BYTES = 20 * 1024 * 1024;

/// Uploads a profile/cover photo straight to storage and resolves its public URL:
/// presign with the backend, then PUT the raw bytes to the presigned URL. The PUT
/// carries no auth header or cookies — the signature is the credential.
export async function uploadImage(file, purpose) {
  if (!file) throw new Error('Choose an image first.');
  if (!IMAGE_TYPES.includes(file.type)) throw new Error('Use a JPEG, PNG, or WebP image.');
  if (file.size > MAX_BYTES) throw new Error('Images must be 20 MB or smaller.');

  const { presignedPutUrl, url } = await apiFetch('/api/media/presign', {
    method: 'POST',
    auth: true,
    body: { purpose, contentType: file.type },
  });

  let res;
  try {
    res = await fetch(presignedPutUrl, {
      method: 'PUT',
      headers: { 'Content-Type': file.type },
      body: file,
      credentials: 'omit',
    });
  } catch {
    throw new Error("Couldn't upload the image. Check your connection.");
  }
  if (!res.ok) throw new Error(`Upload failed (${res.status}).`);
  return url;
}
