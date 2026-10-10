import { apiFetch } from './api';
import { captureVideoPoster, isVideoFile, uploadMedia } from './media';

/// Create-flow data and calls — mirrors lib/data/post_picker_options.dart,
/// lib/data/post_material_options.dart and
/// lib/services/post_publish_service.dart.

/// `id` is what the backend stores (the app sends the id, not the label).
export const MEDIUM_OPTIONS = [
  { id: 'acrylic', name: 'Acrylic' },
  { id: 'encaustic', name: 'Encaustic' },
  { id: 'fresco', name: 'Fresco' },
  { id: 'gouache', name: 'Gouache' },
  { id: 'oil', name: 'Oil' },
  { id: 'tempera', name: 'Tempera' },
  { id: 'watercolor', name: 'Watercolor' },
  { id: 'ink', name: 'Ink' },
  { id: 'charcoal', name: 'Charcoal' },
  { id: 'pastel', name: 'Pastel' },
  { id: 'mixed_media', name: 'Mixed media' },
  { id: 'digital', name: 'Digital' },
];

export const STYLE_MAX_SELECTIONS = 3;
export const STYLE_OPTIONS = [
  { id: 'abstract', name: 'Abstract' },
  { id: 'expressionist', name: 'Expressionist' },
  { id: 'figurative', name: 'Figurative' },
  { id: 'geometric', name: 'Geometric' },
  { id: 'landscape', name: 'Landscape' },
  { id: 'minimalist', name: 'Minimalist' },
  { id: 'portrait', name: 'Portrait' },
  { id: 'surrealist', name: 'Surrealist' },
  { id: 'realist', name: 'Realist' },
  { id: 'conceptual', name: 'Conceptual' },
  { id: 'street', name: 'Street art' },
  { id: 'pop', name: 'Pop art' },
];

/// Materials are sent by name; users can also add their own.
export const MATERIAL_OPTIONS = {
  Paint: [
    'Winsor & Newton Professional Watercolour',
    'Golden Heavy Body Acrylic',
    "Gamblin Artist's Oil Color",
    'M. Graham Oil Paint',
    'Liquitex Basics Acrylic',
    'Daniel Smith Extra Fine Watercolor',
    'Sennelier Oil Pastel',
    'Holbein Gouache',
    'Speedball Screen Printing Ink',
  ],
  Brushes: [
    'Princeton Velvetouch Round',
    'Winsor & Newton Series 7 Kolinsky Sable',
    'Escoda Clásico Flat',
    'Da Vinci Maestro Kolinsky',
    'Robert Simmons Signet Round',
    'Silver Brush Black Velvet',
    'Rosemary & Co Series 302',
    'Isabey Mongoose Bright',
  ],
  Surfaces: [
    'Fredrix Canvas',
    'Arches Watercolor Paper',
    'Strathmore Bristol Board',
    'Claessens Linen',
    'Ampersand Wood Panel',
    'Canson Mi-Teintes Paper',
    'Yupo Synthetic Paper',
    'RayMar Panels',
  ],
  'Drawing & Sketching': [
    'Faber-Castell Polychromos',
    'Staedtler Mars Lumograph',
    "General's Charcoal",
    'Prismacolor Premier Colored Pencil',
    'Derwent Pastel Pencil',
    'Copic Marker',
    'Sakura Pigma Micron Pen',
    'Conté à Paris Crayon',
  ],
  'Sculpture & 3D': [
    'Laguna Clay Stoneware',
    'Amaco Air-Dry Clay',
    'Sculpey Polymer Clay',
    'Plaster of Paris (US Gypsum)',
    'Smooth-On Resin',
    'EnvironTex Lite Epoxy',
    'Chavant Sculpting',
  ],
};

export const MAX_PIECE_IMAGES = 10;

function asList(data) {
  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.items)) return data.items;
  return [];
}

export async function listMySeries() {
  return asList(await apiFetch('/api/user/me/series', { auth: true }));
}

export async function listMyPieces(username) {
  return asList(await apiFetch(`/api/users/${encodeURIComponent(username)}/pieces`, { auth: true }));
}

/// Same as the app's `dimensionsString`: "WxHxD unit", "?" for blanks.
export function dimensionsString({ width, height, depth, unit }) {
  const part = (v) => (String(v ?? '').trim() || '?');
  return `${part(width)}x${part(height)}x${part(depth)} ${unit || 'in'}`;
}

/// Uploads every image in order (index 0 = cover) then creates the piece and,
/// optionally, assigns it to a series. `onProgress(done, total)` drives the
/// "Uploading 2 of 5…" label. Resolves to `{piece, seriesError}` — a series
/// failure happens after the piece exists, so it's reported, not thrown.
export async function publishPiece(draft, onProgress) {
  const { files, aspect } = draft;
  const images = [];
  for (let i = 0; i < files.length; i += 1) {
    onProgress?.(i, files.length);
    const mediaUrl = await uploadMedia(files[i], 'piece');
    images.push({ mediaUrl, mediaType: 'image', mediaAspectRatio: aspect });
  }
  onProgress?.(files.length, files.length);

  const trim = (s) => (s ?? '').trim();
  const body = {
    title: trim(draft.title) || 'Untitled',
    images,
    mediaUrl: images[0].mediaUrl,
    mediaType: 'image',
    mediaAspectRatio: aspect,
    status: draft.status,
    aiDisclosed: Boolean(draft.aiDisclosed),
  };
  if (trim(draft.caption)) body.caption = trim(draft.caption);
  if (draft.medium) body.medium = draft.medium;
  if (draft.yearCreated) body.yearCreated = Number(draft.yearCreated);
  if (draft.materials?.length) body.materials = draft.materials;
  if (draft.styleTags?.length) body.styleTags = draft.styleTags;
  if (trim(draft.location)) body.location = trim(draft.location);
  if (trim(draft.altText)) body.altText = trim(draft.altText);
  if (draft.forSale) {
    body.isForSale = true;
    body.priceCents = draft.priceCents;
    body.dimensions = draft.dimensions;
    if (trim(draft.shippingRegion)) body.shippingRegion = trim(draft.shippingRegion);
  }

  const piece = await apiFetch('/api/pieces', { method: 'POST', body, auth: true });

  let seriesError = null;
  try {
    const newName = trim(draft.newSeriesName);
    if (newName) {
      await apiFetch('/api/series', {
        method: 'POST',
        body: { name: newName, pieceIds: [piece.id] },
        auth: true,
      });
    } else if (draft.seriesId) {
      await apiFetch(`/api/series/${draft.seriesId}/pieces`, {
        method: 'POST',
        body: { pieceId: piece.id },
        auth: true,
      });
    }
  } catch (e) {
    seriesError = e?.message || 'Could not add the piece to the series.';
  }
  return { piece, seriesError };
}

/// Uploads the scene's single image/video (plus a best-effort poster for
/// video) and creates the post.
export async function publishScene(draft, onProgress) {
  const { file } = draft;
  const video = isVideoFile(file);
  const total = video ? 2 : 1;
  onProgress?.(0, total);
  const mediaUrl = await uploadMedia(file, 'post');

  let thumbnailUrl = null;
  if (video) {
    onProgress?.(1, total);
    try {
      const poster = await captureVideoPoster(file);
      if (poster) {
        thumbnailUrl = await uploadMedia(new File([poster], 'poster.jpg', { type: 'image/jpeg' }), 'post');
      }
    } catch {
      // A missing poster shouldn't block the scene.
    }
  }
  onProgress?.(total, total);

  const caption = (draft.caption ?? '').trim();
  const location = (draft.location ?? '').trim();
  const body = {
    mediaUrl,
    mediaType: video ? 'video' : 'image',
    isProcess: Boolean(draft.isProcess),
    status: draft.status,
  };
  if (caption) body.caption = caption;
  if (location) body.location = location;
  if (draft.linkedPieceId) body.linkedPieceId = draft.linkedPieceId;
  if (video) {
    if (thumbnailUrl) body.thumbnailUrl = thumbnailUrl;
  } else {
    body.mediaAspectRatio = draft.aspect;
  }
  return apiFetch('/api/posts', { method: 'POST', body, auth: true });
}
