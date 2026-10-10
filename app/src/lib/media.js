import { apiFetch } from './api';

/// Upload helpers for the posting flow — the web counterpart of
/// lib/services/media_service.dart: presign on the backend, then PUT the raw
/// bytes straight to storage.

export const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
export const VIDEO_TYPES = ['video/mp4'];
export const MAX_IMAGE_BYTES = 20 * 1024 * 1024;
export const MAX_VIDEO_BYTES = 100 * 1024 * 1024;

export function isVideoFile(file) {
  return VIDEO_TYPES.includes(file?.type);
}

/// Returns an error message for a file the backend would reject, or null.
/// Checked at pick time so the user hears about it before filling the form.
export function validateMediaFile(file, { allowVideo = false } = {}) {
  if (!file) return 'No file selected.';
  if (IMAGE_TYPES.includes(file.type)) {
    if (file.size > MAX_IMAGE_BYTES) return `"${file.name}" is larger than 20 MB.`;
    return null;
  }
  if (VIDEO_TYPES.includes(file.type)) {
    if (!allowVideo) return 'Videos can only be posted as a Scene.';
    if (file.size > MAX_VIDEO_BYTES) return `"${file.name}" is larger than 100 MB.`;
    return null;
  }
  return allowVideo
    ? `"${file.name}" isn't supported. Use a JPEG, PNG or WebP image, or an MP4 video.`
    : `"${file.name}" isn't supported. Use a JPEG, PNG or WebP image.`;
}

/// Uploads a File/Blob and resolves to its public URL. `purpose` is one of
/// profile | cover | piece | post | chat.
export async function uploadMedia(file, purpose) {
  const contentType = file?.type;
  if (![...IMAGE_TYPES, ...VIDEO_TYPES].includes(contentType)) {
    throw new Error('Unsupported file type. Use a JPEG, PNG or WebP image, or an MP4 video.');
  }
  const limit = VIDEO_TYPES.includes(contentType) ? MAX_VIDEO_BYTES : MAX_IMAGE_BYTES;
  if (file.size > limit) {
    throw new Error(`File is too large (max ${limit / (1024 * 1024)} MB).`);
  }

  const { presignedPutUrl, url } = await apiFetch('/api/media/presign', {
    method: 'POST',
    body: { purpose, contentType },
    auth: true,
  });
  if (!presignedPutUrl || !url) throw new Error('Upload could not be prepared. Please try again.');

  /// No credentials / auth header: the signed URL is the authorization, and
  /// extra headers would break the S3 signature. In devMode the URL points at
  /// the backend's local store, which still expects the PUT.
  let res;
  try {
    res = await fetch(presignedPutUrl, {
      method: 'PUT',
      body: file,
      headers: { 'Content-Type': contentType },
    });
  } catch {
    throw new Error("Upload failed — couldn't reach storage. Check your connection.");
  }
  if (!res.ok) throw new Error(`Upload failed (${res.status}). Please try again.`);
  return url;
}

/// Natural pixel size of an image file, or null if it can't be decoded.
export function readImageSize(file) {
  return new Promise((resolve) => {
    const src = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      resolve({ width: img.naturalWidth, height: img.naturalHeight });
      URL.revokeObjectURL(src);
    };
    img.onerror = () => {
      resolve(null);
      URL.revokeObjectURL(src);
    };
    img.src = src;
  });
}

/// The app's two crop ratios: wide images default to landscape.
export function defaultAspectFor(size) {
  if (!size || !size.height) return '3:4';
  return size.width / size.height > 1.2 ? '16:9' : '3:4';
}

/// Best-effort poster frame for a video scene: first frame → JPEG Blob, or
/// null on any failure (unsupported codec, tainted canvas, timeout). Explore
/// shows this as the thumbnail instead of decoding the video itself.
export function captureVideoPoster(file, { timeoutMs = 8000 } = {}) {
  return new Promise((resolve) => {
    const src = URL.createObjectURL(file);
    const video = document.createElement('video');
    let done = false;
    const finish = (blob) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      video.removeAttribute('src');
      video.load();
      URL.revokeObjectURL(src);
      resolve(blob ?? null);
    };
    const timer = setTimeout(() => finish(null), timeoutMs);

    video.muted = true;
    video.playsInline = true;
    video.preload = 'auto';
    video.onerror = () => finish(null);
    video.onloadeddata = () => {
      // Seek slightly in: frame 0 is often black on encoder fade-ins.
      try {
        video.currentTime = Math.min(0.1, (video.duration || 1) / 2);
      } catch {
        finish(null);
      }
    };
    video.onseeked = () => {
      try {
        const w = video.videoWidth;
        const h = video.videoHeight;
        if (!w || !h) return finish(null);
        const canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        canvas.getContext('2d').drawImage(video, 0, 0, w, h);
        canvas.toBlob((blob) => finish(blob), 'image/jpeg', 0.85);
      } catch {
        finish(null);
      }
    };
    video.src = src;
  });
}
