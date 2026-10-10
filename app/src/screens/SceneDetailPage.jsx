import React, { useEffect, useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { ChevronRight, MapPin } from 'lucide-react';
import { normalizeItem } from '../lib/content';
import { useSession } from '../lib/session';
import { friendlyError } from '../lib/social';
import { ContentActionsMenu } from '../components/moderation/ContentActionsMenu';
import { PriceBadge } from '../components/content/FeedCard';
import { CommentsSection } from '../components/content/CommentsSection';
import {
  ArtistRow,
  BackButton,
  DetailState,
  EngagementBar,
  sameUser,
  useAuthorBlocked,
  useDetail,
} from './PieceDetailPage';

const containerStyle = {
  maxWidth: 480,
  margin: '0 auto',
  minHeight: '100vh',
  background: 'var(--white)',
};

const divider = { height: 1, background: 'var(--slate-100)', border: 'none' };

/// Web view of a scene (`/scene/:id`) — an image or video post, optionally
/// linked to the piece it shows.
export function SceneDetailPage() {
  const { id } = useParams();
  const { user } = useSession();
  const { data, loading, error } = useDetail(`/api/posts/${id}`);
  const item = useMemo(() => normalizeItem(data, 'post'), [data]);
  const piece = useMemo(() => normalizeItem(data?.piece, 'piece'), [data]);
  const [commentCount, setCommentCount] = useState(0);
  const [blocked, setBlocked] = useAuthorBlocked(item?.author?.username);

  useEffect(() => setCommentCount(item?.commentCount ?? 0), [item]);

  if (loading) return <DetailState>Loading…</DetailState>;
  if (error || !item) {
    return <DetailState>{error?.status === 404 || !error ? "This scene couldn't be found." : friendlyError(error)}</DetailState>;
  }

  const author = item.author;
  if (blocked) {
    return <DetailState>You blocked @{author?.username}. You won't see their work anymore.</DetailState>;
  }

  const isMine = sameUser(author?.username, user?.username);
  const raw = item.raw;
  const mediaBox = {
    width: '100%',
    aspectRatio: String(item.aspectRatio),
    background: item.isVideo ? 'var(--black)' : 'var(--slate-100)',
    display: 'block',
  };

  return (
    <div style={containerStyle}>
      <div style={{ position: 'relative' }}>
        {item.isVideo ? (
          <video
            src={item.videoUrl}
            poster={raw.thumbnailUrl ?? undefined}
            controls
            playsInline
            preload="metadata"
            style={{ ...mediaBox, objectFit: 'contain' }}
          />
        ) : item.mediaUrl ? (
          <img src={item.mediaUrl} alt={item.caption ?? 'Scene'} style={{ ...mediaBox, objectFit: 'cover' }} />
        ) : (
          <div style={mediaBox} />
        )}
        <div style={{ position: 'absolute', top: 12, left: 12 }}>
          <BackButton />
        </div>
        {!isMine && (
          <div style={{ position: 'absolute', top: 12, right: 12 }}>
            <ContentActionsMenu
              target={{ type: 'post', id: item.id }}
              authorUsername={author?.username}
              onBlocked={() => setBlocked(true)}
            />
          </div>
        )}
      </div>

      <EngagementBar item={item} commentCount={commentCount} />
      <hr style={divider} />
      <ArtistRow author={author} isMine={isMine} subtitle={raw.isProcess ? 'Process' : undefined} />

      {(item.caption || raw.location) && (
        <div style={{ padding: '4px 16px 16px' }}>
          {item.caption && (
            <p style={{ fontSize: 16, color: 'var(--slate-900)', lineHeight: 1.45, whiteSpace: 'pre-wrap' }}>{item.caption}</p>
          )}
          {raw.location && (
            <p style={{ fontSize: 14, color: 'var(--slate-500)', display: 'flex', alignItems: 'center', gap: 4, marginTop: 8 }}>
              <MapPin size={14} /> {raw.location}
            </p>
          )}
        </div>
      )}

      {piece && (
        <div style={{ padding: '0 16px 16px' }}>
          <Link
            to={piece.href}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 12,
              padding: 10,
              borderRadius: 16,
              background: 'var(--white)',
              boxShadow: 'var(--shadow-card)',
            }}
          >
            <div style={{ width: 56, height: 56, borderRadius: 10, overflow: 'hidden', background: 'var(--slate-100)', flexShrink: 0 }}>
              {piece.imageUrl && (
                <img src={piece.imageUrl} alt={piece.title} loading="lazy" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
              )}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--slate-400)', textTransform: 'uppercase', letterSpacing: 0.4 }}>
                The piece
              </div>
              <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--slate-900)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {piece.title}
              </div>
              {piece.medium && <div style={{ fontSize: 12, color: 'var(--slate-500)' }}>{piece.medium}</div>}
            </div>
            <PriceBadge item={piece} />
            <ChevronRight size={18} color="var(--slate-400)" />
          </Link>
        </div>
      )}

      <hr style={divider} />
      <CommentsSection item={item} onAdded={() => setCommentCount((c) => c + 1)} />
    </div>
  );
}
