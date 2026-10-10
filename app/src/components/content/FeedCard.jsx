import React from 'react';
import { Link } from 'react-router-dom';
import { Heart, MessageCircle, Bookmark, Play } from 'lucide-react';
import { Avatar } from '../common/Avatar';
import { ContentActionsMenu } from '../moderation/ContentActionsMenu';
import { useEngagement } from '../../lib/useEngagement';
import { useSession } from '../../lib/session';

const cardStyle = {
  width: '100%',
  borderRadius: 16,
  overflow: 'hidden',
  boxShadow: 'var(--shadow-card)',
  background: 'var(--white)',
};

const iconButton = {
  display: 'inline-flex',
  alignItems: 'center',
  gap: 4,
  padding: 4,
  color: 'var(--slate-600)',
  fontSize: 13,
  background: 'none',
  border: 'none',
  cursor: 'pointer',
};

const ellipsis = { overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' };

/// Full-width feed card for a piece or scene (Home feed), with real like, save,
/// comment count, and the Report / Block menu.
export function FeedCard({ item }) {
  const { user } = useSession();
  const { liked, likeCount, saved, toggleLike, toggleSave, error } = useEngagement(item);
  const isMine = Boolean(user?.username) && item.author?.username === user.username;

  return (
    <article style={cardStyle}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 12px' }}>
        <AuthorLink author={item.author} subtitle={item.medium} />
        {!isMine && (
          <ContentActionsMenu
            target={{ type: item.type, id: item.id }}
            authorUsername={item.author?.username}
            buttonStyle={{ background: 'var(--slate-100)', width: 34, height: 34 }}
          />
        )}
      </div>

      <Link to={item.href} style={{ display: 'block' }}>
        <MediaThumb item={item} />
      </Link>

      <div style={{ padding: '10px 12px 14px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', gap: 12 }}>
            <button type="button" style={iconButton} onClick={toggleLike} aria-label={liked ? 'Unlike' : 'Like'}>
              <Heart size={20} fill={liked ? '#FF3040' : 'none'} color={liked ? '#FF3040' : 'currentColor'} />
              {likeCount > 0 && likeCount}
            </button>
            <Link to={item.href} style={iconButton} aria-label="Comments">
              <MessageCircle size={20} />
              {item.commentCount > 0 && item.commentCount}
            </Link>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <PriceBadge item={item} />
            <button type="button" style={iconButton} onClick={toggleSave} aria-label={saved ? 'Unsave' : 'Save'}>
              <Bookmark size={20} fill={saved ? 'currentColor' : 'none'} />
            </button>
          </div>
        </div>
        <Link to={item.href} style={{ display: 'block', marginTop: 6 }}>
          <h3 style={{ fontSize: 15, fontWeight: 600, color: 'var(--slate-900)', ...ellipsis }}>{item.title}</h3>
          {!item.isPost && item.caption && (
            <p style={{ fontSize: 13, color: 'var(--slate-500)', marginTop: 2, ...ellipsis }}>{item.caption}</p>
          )}
        </Link>
        {error && <p style={{ fontSize: 12, color: '#E05252', marginTop: 6 }}>{error}</p>}
      </div>
    </article>
  );
}

/// Avatar + name linking to the artist's profile.
export function AuthorLink({ author, subtitle, size = 32 }) {
  const content = (
    <>
      <Avatar src={author?.profilePhotoUrl} name={author?.name} size={size} />
      <div style={{ minWidth: 0 }}>
        <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--slate-900)', ...ellipsis }}>
          {author?.name ?? 'Artist'}
        </div>
        {subtitle && <div style={{ fontSize: 12, color: 'var(--slate-500)', ...ellipsis }}>{subtitle}</div>}
      </div>
    </>
  );
  const style = { display: 'flex', alignItems: 'center', gap: 10, flex: 1, minWidth: 0 };
  if (!author?.username) return <div style={style}>{content}</div>;
  return <Link to={`/u/${author.username}`} style={style}>{content}</Link>;
}

export function PriceBadge({ item }) {
  if (item.isSold) {
    return (
      <span style={{ padding: '4px 10px', borderRadius: 9999, background: 'var(--slate-200)', color: 'var(--slate-600)', fontSize: 12, fontWeight: 600 }}>
        Collected
      </span>
    );
  }
  if (!item.isForSale || !item.priceLabel) return null;
  return (
    <span style={{ padding: '4px 10px', borderRadius: 9999, background: 'var(--slate-900)', color: 'var(--white)', fontSize: 12, fontWeight: 600 }}>
      {item.priceLabel}
    </span>
  );
}

/// Image (or a video's poster with a play badge) at the item's aspect ratio.
export function MediaThumb({ item, aspectRatio, rounded = 0 }) {
  const ratio = aspectRatio ?? item.aspectRatio;
  return (
    <div style={{ position: 'relative', width: '100%', aspectRatio: String(ratio), background: 'var(--slate-100)', borderRadius: rounded, overflow: 'hidden' }}>
      {item.imageUrl ? (
        <img src={item.imageUrl} alt={item.title} loading="lazy" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
      ) : item.videoUrl ? (
        <video src={item.videoUrl} muted playsInline preload="metadata" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
      ) : null}
      {item.isVideo && (
        <span style={{ position: 'absolute', top: 8, right: 8, width: 28, height: 28, borderRadius: '50%', background: 'rgba(15,23,42,0.55)', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Play size={14} fill="white" />
        </span>
      )}
      {item.isDraft && (
        <span style={{ position: 'absolute', top: 8, left: 8, padding: '2px 8px', borderRadius: 9999, background: 'rgba(15,23,42,0.7)', color: 'white', fontSize: 11, fontWeight: 600 }}>
          Draft
        </span>
      )}
    </div>
  );
}

/// Compact tile for 2-column grids (Discover, profiles, Saved).
export function ContentTile({ item }) {
  return (
    <Link to={item.href} style={{ display: 'block', borderRadius: 14, overflow: 'hidden', background: 'var(--white)', boxShadow: 'var(--shadow-card)' }}>
      <MediaThumb item={item} />
      <div style={{ padding: '8px 10px' }}>
        <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--slate-900)', ...ellipsis }}>{item.title}</div>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 6, fontSize: 11, color: 'var(--slate-500)', marginTop: 2 }}>
          <span style={ellipsis}>{item.author?.name ?? item.medium ?? ''}</span>
          {item.priceLabel && item.isForSale && !item.isSold && (
            <span style={{ fontWeight: 600, color: 'var(--slate-900)' }}>{item.priceLabel}</span>
          )}
        </div>
      </div>
    </Link>
  );
}

/// Two-column masonry of tiles, alternating items between columns.
export function TileGrid({ items }) {
  const cols = [[], []];
  items.forEach((item, i) => cols[i % 2].push(item));
  return (
    <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
      {cols.map((col, c) => (
        <div key={c} style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 10 }}>
          {col.map((item) => <ContentTile key={`${item.type}-${item.id}`} item={item} />)}
        </div>
      ))}
    </div>
  );
}
