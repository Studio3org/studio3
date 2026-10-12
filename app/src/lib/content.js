/// One display model for every piece / scene payload the backend sends (feed
/// items, detail responses, profile lists, saved lists, collection items),
/// mirroring how the Flutter app derives titles, media, price and links
/// (lib/models/feed_item.dart, feed_preview_item.dart).

const VIDEO_TYPES = new Set(['video', 'reel', 'reels']);

/// `kind` overrides type detection for payloads without a `type` key
/// (detail endpoints, profile lists, saved lists).
export function normalizeItem(raw, kind) {
  if (!raw) return null;
  const type = kind ?? raw.type ?? raw.targetType ?? guessType(raw);
  const isPost = type === 'post';
  const isVideo = isPost && VIDEO_TYPES.has(String(raw.mediaType ?? '').toLowerCase());
  const author = raw.author ?? raw.user ?? null;
  const images = Array.isArray(raw.images) && raw.images.length
    ? raw.images.map((img) => img.mediaUrl).filter(Boolean)
    : [raw.mediaUrl].filter(Boolean);
  const priceCents = !isPost && raw.priceCents != null ? Number(raw.priceCents) : null;
  const isForSale = !isPost && Boolean(raw.isForSale);

  return {
    raw,
    id: raw.id,
    type: isPost ? 'post' : 'piece',
    isPost,
    isVideo,
    title: isPost ? (raw.caption?.trim() || 'Scene') : (raw.title || 'Untitled'),
    caption: raw.caption ?? null,
    medium: isPost ? (isVideo ? 'Video' : 'Scene') : (raw.medium ?? null),
    mediaUrl: raw.mediaUrl ?? images[0] ?? null,
    // What to show in a grid/card: a video's poster frame, otherwise the image.
    imageUrl: isVideo ? (raw.thumbnailUrl ?? null) : (raw.mediaUrl ?? images[0] ?? null),
    videoUrl: isVideo ? raw.mediaUrl : null,
    images,
    aspectRatio: aspectRatioFor(raw, isVideo),
    author: author
      ? {
          username: author.username ?? null,
          name: author.name || author.username || 'Artist',
          profilePhotoUrl: author.profilePhotoUrl ?? null,
          isFollowing: Boolean(author.isFollowing),
        }
      : null,
    likeCount: Number(raw.likeCount ?? raw.likes ?? 0),
    commentCount: Number(raw.commentCount ?? raw.comments ?? 0),
    isLiked: Boolean(raw.isLiked),
    isSaved: Boolean(raw.isSaved),
    isForSale,
    priceCents,
    priceLabel: priceCents != null ? formatPrice(priceCents, raw.currency) : null,
    listingState: raw.listingState ?? null,
    isSold: !isPost && (raw.listingState === 'collected' || ['sold', 'auction_won'].includes(raw.status)),
    status: raw.status ?? 'live',
    isDraft: raw.status === 'draft',
    createdAt: raw.createdAt ?? null,
    href: isPost ? `/scene/${raw.id}` : `/piece/${raw.id}`,
  };
}

export function normalizeList(list, kind) {
  return (Array.isArray(list) ? list : []).map((r) => normalizeItem(r, kind)).filter(Boolean);
}

/// Attach a known author to profile-list items, which the backend sends without one.
export function withAuthor(items, profile) {
  if (!profile) return items;
  const author = {
    username: profile.username,
    name: profile.name || profile.username,
    profilePhotoUrl: profile.profilePhotoUrl ?? null,
    isFollowing: Boolean(profile.isFollowing),
  };
  return items.map((item) => (item.author ? item : { ...item, author }));
}

function guessType(raw) {
  if ('linkedPieceId' in raw) return 'post';
  if (raw.title == null && raw.caption != null) return 'post';
  return 'piece';
}

function aspectRatioFor(raw, isVideo) {
  const ratio = raw.mediaAspectRatio;
  if (ratio === '16:9') return 16 / 9;
  if (ratio) return 3 / 4;
  if (isVideo) return 16 / 9;
  const dims = /([\d.]+)\s*[x×]\s*([\d.]+)/i.exec(raw.dimensions ?? '');
  if (dims) {
    const w = Number(dims[1]);
    const h = Number(dims[2]);
    if (w > 0 && h > 0) return w / h > 1.2 ? 16 / 9 : 3 / 4;
  }
  return 3 / 4;
}

export function formatPrice(cents, currency = 'USD') {
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency || 'USD',
      maximumFractionDigits: 0,
    }).format(cents / 100);
  } catch {
    return `$${Math.round(cents / 100)}`;
  }
}

/// "now", "5m", "3h", "2d", "4w" — same buckets as the app.
export function timeAgo(iso) {
  if (!iso) return '';
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return '';
  const mins = Math.floor((Date.now() - then) / 60000);
  if (mins < 1) return 'now';
  if (mins < 60) return `${mins}m`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d`;
  return `${Math.floor(days / 7)}w`;
}
