/** Pure canvas render pipeline for a single edited image — no React.
 *
 * Rotation/flip are baked into an intermediate "working image" (a fresh
 * canvas the crop UI reads from), separate from the crop-rectangle bake —
 * this way `ImageCropEditor`'s live preview and the final publish-time
 * render both crop from the exact same pixels, guaranteeing WYSIWYG, and
 * the crop math itself never has to reason about rotation at all (it always
 * operates on an axis-aligned, already-rotated image). Brightness/contrast/
 * exposure stay a cheap `ctx.filter` string applied at crop time. */

function loadImage(url) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.crossOrigin = 'anonymous';
    img.src = url;
  });
}

/** Draws `sourceUrl` onto a canvas rotated/flipped per the given transform
 * fields and returns a new object URL for the result — or `sourceUrl`
 * unchanged if there's nothing to bake (the common case). Callers own
 * revoking the returned URL when they no longer need it (skip if it's the
 * same as `sourceUrl`). */
export async function buildWorkingImageUrl(sourceUrl, rotationDegrees, flipHorizontal, flipVertical) {
  if (!rotationDegrees && !flipHorizontal && !flipVertical) return sourceUrl;

  const img = await loadImage(sourceUrl);
  const swapDims = rotationDegrees === 90 || rotationDegrees === 270;
  const w = swapDims ? img.naturalHeight : img.naturalWidth;
  const h = swapDims ? img.naturalWidth : img.naturalHeight;

  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d');
  ctx.translate(w / 2, h / 2);
  ctx.rotate((rotationDegrees * Math.PI) / 180);
  ctx.scale(flipHorizontal ? -1 : 1, flipVertical ? -1 : 1);
  ctx.drawImage(img, -img.naturalWidth / 2, -img.naturalHeight / 2);

  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => (blob ? resolve(URL.createObjectURL(blob)) : reject(new Error('Could not rotate image'))), 'image/png');
  });
}

/** Live-preview and final-bake share this exact filter string, so what the
 * editor shows is what gets published. Exposure has no native CSS/canvas
 * filter, so it's approximated as additional brightness. */
export function filterStringFor(transform) {
  const brightness = (transform.brightness / 50) * ((transform.exposure - 50) / 100 + 1);
  const contrast = transform.contrast / 50;
  return `brightness(${brightness}) contrast(${contrast})`;
}

/** Renders one edited MediaItem (image only) to a JPEG Blob, crop + rotate +
 * flip + brightness/contrast/exposure all baked in. */
export async function renderMediaItem(item) {
  const { transform } = item;
  const workingUrl = await buildWorkingImageUrl(
    item.previewUrl,
    transform.rotationDegrees,
    transform.flipHorizontal,
    transform.flipVertical,
  );
  const img = await loadImage(workingUrl);
  const area = transform.croppedAreaPixels || { x: 0, y: 0, width: img.naturalWidth, height: img.naturalHeight };

  const canvas = document.createElement('canvas');
  canvas.width = area.width;
  canvas.height = area.height;
  const ctx = canvas.getContext('2d');
  ctx.filter = filterStringFor(transform);
  ctx.drawImage(img, area.x, area.y, area.width, area.height, 0, 0, area.width, area.height);

  if (workingUrl !== item.previewUrl) URL.revokeObjectURL(workingUrl);

  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error('Could not render image'))), 'image/jpeg', 0.92);
  });
}

/** Renders every image item, in array order (order is meaningful — index 0
 * becomes the cover). Video items are never passed here — usePostForm's
 * publish() uploads video files untouched. */
export async function renderAllMediaItems(items) {
  const blobs = [];
  for (const item of items) {
    blobs.push(await renderMediaItem(item));
  }
  return blobs;
}
