import React, { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, Bookmark, Heart, MapPin, MessageCircle, Pencil, Share2, Smartphone } from 'lucide-react';
import { apiFetch, isBlockedAuthor, onAuthorBlocked } from '../lib/api';
import { normalizeItem, normalizeList } from '../lib/content';
import { useRequireLogin, useSession } from '../lib/session';
import { useEngagement } from '../lib/useEngagement';
import { friendlyError, setFollowing } from '../lib/social';
import { ContentActionsMenu } from '../components/moderation/ContentActionsMenu';
import { AuthorLink, MediaThumb, PriceBadge } from '../components/content/FeedCard';
import { MediaGallery } from '../components/content/MediaGallery';
import { CommentsSection } from '../components/content/CommentsSection';
import { StateMessage } from '../components/common/StateMessage';

const containerStyle = {
  maxWidth: 480,
  margin: '0 auto',
  minHeight: '100vh',
  background: 'var(--white)',
};

const overlayButton = {
  width: 40,
  height: 40,
  borderRadius: '50%',
  border: 'none',
  background: 'rgba(255, 255, 255, 0.8)',
  color: 'var(--slate-900)',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  cursor: 'pointer',
};

const actionButton = {
  display: 'inline-flex',
  alignItems: 'center',
  gap: 5,
  padding: 4,
  border: 'none',
  background: 'none',
  color: 'var(--slate-700)',
  fontSize: 14,
  cursor: 'pointer',
};

const divider = { height: 1, background: 'var(--slate-100)', border: 'none' };
const secondaryText = { fontSize: 14, color: 'var(--slate-500)', lineHeight: 1.5 };
const sectionTitle = { fontSize: 16, fontWeight: 600, color: 'var(--slate-900)' };

export const sameUser = (a, b) => Boolean(a) && Boolean(b) && a.toLowerCase() === b.toLowerCase();

/// Loads a detail payload (piece or scene). Signed in → the token goes along so
/// the backend fills isLiked/isSaved/isFollowing and hides blocked accounts.
export function useDetail(path) {
  const [state, setState] = useState({ data: null, loading: true, error: null });
  useEffect(() => {
    let cancelled = false;
    setState({ data: null, loading: true, error: null });
    apiFetch(path, { auth: true })
      .then((data) => !cancelled && setState({ data, loading: false, error: null }))
      .catch((error) => !cancelled && setState({ data: null, loading: false, error }));
    return () => {
      cancelled = true;
    };
  }, [path]);
  return state;
}

/// True once the author is blocked — from this page's menu or anywhere else
/// in this tab — so the page swaps to the "you blocked them" state.
export function useAuthorBlocked(username) {
  const [blocked, setBlocked] = useState(() => isBlockedAuthor(username));
  useEffect(() => {
    setBlocked(isBlockedAuthor(username));
    return onAuthorBlocked(() => setBlocked(isBlockedAuthor(username)));
  }, [username]);
  return [blocked, setBlocked];
}

/// Back to wherever the visitor came from; a shared link opened cold has no
/// in-app history, so fall back to the home feed.
export function BackButton() {
  const navigate = useNavigate();
  const goBack = () => {
    if ((window.history.state?.idx ?? 0) > 0) navigate(-1);
    else navigate('/home');
  };
  return (
    <button type="button" aria-label="Back" onClick={goBack} style={overlayButton}>
      <ArrowLeft size={20} />
    </button>
  );
}

export function DetailState({ children }) {
  return (
    <div style={containerStyle}>
      <div style={{ padding: 12 }}>
        <BackButton />
      </div>
      <StateMessage>
        {children}
        <div style={{ marginTop: 16 }}>
          <Link to="/home" style={{ fontWeight: 600, color: 'var(--slate-900)' }}>Back to Studio3</Link>
        </div>
      </StateMessage>
    </div>
  );
}

/// Artist avatar + name, with Follow for anyone else's work (guests go to login).
export function ArtistRow({ author, subtitle, isMine }) {
  const requireLogin = useRequireLogin();
  const [follow, setFollow] = useState({ following: Boolean(author?.isFollowing), requested: false });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    setFollow({ following: Boolean(author?.isFollowing), requested: false });
  }, [author?.username, author?.isFollowing]);

  const toggle = async () => {
    if (!author?.username || busy || !requireLogin()) return;
    const next = !(follow.following || follow.requested);
    setBusy(true);
    setError(null);
    try {
      const res = await setFollowing(author.username, next);
      setFollow({ following: Boolean(res?.following), requested: Boolean(res?.requested) });
    } catch (e) {
      setError(friendlyError(e));
    } finally {
      setBusy(false);
    }
  };

  const active = follow.following || follow.requested;
  const label = follow.following ? 'Following' : follow.requested ? 'Requested' : 'Follow';

  return (
    <div style={{ padding: '12px 16px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <AuthorLink author={author} subtitle={subtitle} size={40} />
        {!isMine && author?.username && (
          <button
            type="button"
            onClick={toggle}
            disabled={busy}
            style={{
              padding: '8px 18px',
              borderRadius: 9999,
              border: active ? '1px solid var(--slate-200)' : 'none',
              background: active ? 'var(--white)' : 'var(--slate-900)',
              color: active ? 'var(--slate-700)' : 'var(--white)',
              fontSize: 13,
              fontWeight: 600,
              cursor: 'pointer',
              opacity: busy ? 0.6 : 1,
              flexShrink: 0,
            }}
          >
            {label}
          </button>
        )}
      </div>
      {error && <p style={{ fontSize: 12, color: '#E05252', marginTop: 6 }}>{error}</p>}
    </div>
  );
}

/// Like · comments · share · save, matching the app's PieceActionBar.
export function EngagementBar({ item, commentCount }) {
  const { liked, likeCount, saved, toggleLike, toggleSave, error } = useEngagement(item);
  const [shareNote, setShareNote] = useState(null);

  const share = async () => {
    const url = `${window.location.origin}${item.href}`;
    if (navigator.share) {
      try {
        await navigator.share({ title: item.title, url });
        return;
      } catch (e) {
        if (e?.name === 'AbortError') return;
      }
    }
    try {
      await navigator.clipboard.writeText(url);
      setShareNote('Link copied');
    } catch {
      setShareNote(url);
    }
    setTimeout(() => setShareNote(null), 2500);
  };

  const scrollToComments = () => document.getElementById('comments')?.scrollIntoView({ behavior: 'smooth' });

  return (
    <div style={{ padding: '8px 12px' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', gap: 14 }}>
          <button type="button" style={actionButton} onClick={toggleLike} aria-label={liked ? 'Unlike' : 'Like'}>
            <Heart size={22} fill={liked ? '#FF3040' : 'none'} color={liked ? '#FF3040' : 'currentColor'} />
            {likeCount > 0 && likeCount}
          </button>
          <button type="button" style={actionButton} onClick={scrollToComments} aria-label="Comments">
            <MessageCircle size={22} />
            {commentCount > 0 && commentCount}
          </button>
          <button type="button" style={actionButton} onClick={share} aria-label="Share">
            <Share2 size={22} />
          </button>
        </div>
        <button type="button" style={actionButton} onClick={toggleSave} aria-label={saved ? 'Unsave' : 'Save'}>
          <Bookmark size={22} fill={saved ? 'currentColor' : 'none'} />
        </button>
      </div>
      {shareNote && <p style={{ fontSize: 12, color: 'var(--slate-500)', marginTop: 4, overflowWrap: 'anywhere' }}>{shareNote}</p>}
      {error && <p style={{ fontSize: 12, color: '#E05252', marginTop: 4 }}>{error}</p>}
    </div>
  );
}

/// Shown instead of a checkout: buying happens in the iOS/Android app only.
export function AppNotice({ icon: Icon = Smartphone, title, children }) {
  return (
    <div
      style={{
        display: 'flex',
        gap: 12,
        alignItems: 'flex-start',
        margin: '0 16px',
        padding: 14,
        borderRadius: 16,
        background: 'var(--slate-50)',
        border: '1px solid var(--slate-200)',
      }}
    >
      <Icon size={20} style={{ flexShrink: 0, color: 'var(--slate-700)', marginTop: 1 }} />
      <div>
        <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--slate-900)' }}>{title}</div>
        {children && <div style={{ fontSize: 13, color: 'var(--slate-500)', marginTop: 2, lineHeight: 1.45 }}>{children}</div>}
      </div>
    </div>
  );
}

const LISTING_LABELS = {
  available: 'Available',
  auction_live: 'Auction live',
  auction_ended: 'Auction ended',
  collected: 'Collected',
};
const STATUS_LABELS = { sold: 'Sold', auction_won: 'Sold', reserved: 'Reserved', delisted: 'Not for sale' };

/// Availability copy, same precedence as the app: sold/collected first, then
/// the listing state, then other non-live statuses.
function availabilityFor(item) {
  if (item.isSold) return 'Collected';
  if (STATUS_LABELS[item.status]) return STATUS_LABELS[item.status];
  if (item.listingState && LISTING_LABELS[item.listingState]) return LISTING_LABELS[item.listingState];
  return item.isForSale ? 'Available' : null;
}

function isCollectable(item) {
  return (
    item.isForSale &&
    !item.isSold &&
    item.status === 'live' &&
    (item.listingState == null || item.listingState === 'available' || item.listingState === 'auction_live')
  );
}

/// Web view of a piece (`/piece/:id`) — also what shared links / App Links
/// open when the Studio3 app isn't installed. Mirrors piece_detail_page.dart
/// and available_piece_detail_page.dart, minus checkout (app only).
export function PieceDetailPage() {
  const { id } = useParams();
  const { user } = useSession();
  const { data, loading, error } = useDetail(`/api/pieces/${id}`);
  const item = useMemo(() => normalizeItem(data, 'piece'), [data]);
  const related = useMemo(() => normalizeList(data?.relatedPosts, 'post'), [data]);
  const [commentCount, setCommentCount] = useState(0);
  const [blocked, setBlocked] = useAuthorBlocked(item?.author?.username);

  useEffect(() => setCommentCount(item?.commentCount ?? 0), [item]);

  if (loading) return <DetailState>Loading…</DetailState>;
  if (error || !item) {
    return <DetailState>{error?.status === 404 || !error ? "This piece couldn't be found." : friendlyError(error)}</DetailState>;
  }

  const author = item.author;
  if (blocked) {
    return <DetailState>You blocked @{author?.username}. You won't see their work anymore.</DetailState>;
  }

  const isMine = sameUser(author?.username, user?.username);
  const raw = item.raw;
  const year = raw.yearCreated ? String(raw.yearCreated) : null;
  const mediumLine = [item.medium, year].filter(Boolean).join(' · ');
  const materials = Array.isArray(raw.materials) ? raw.materials.filter(Boolean) : [];
  const availability = availabilityFor(item);
  const series = raw.series;
  const seriesThumbs = (series?.previewPieces ?? []).filter((p) => p?.mediaUrl).slice(0, 4);

  return (
    <div style={containerStyle}>
      <div style={{ position: 'relative' }}>
        <MediaGallery images={item.images} alt={item.title} aspectRatio={item.aspectRatio} />
        <div style={{ position: 'absolute', top: 12, left: 12 }}>
          <BackButton />
        </div>
        {!isMine && (
          <div style={{ position: 'absolute', top: 12, right: 12 }}>
            <ContentActionsMenu
              target={{ type: 'piece', id: item.id }}
              authorUsername={author?.username}
              onBlocked={() => setBlocked(true)}
            />
          </div>
        )}
      </div>

      <EngagementBar item={item} commentCount={commentCount} />
      <hr style={divider} />
      <ArtistRow author={author} isMine={isMine} />

      <div style={{ padding: '4px 16px 16px' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 12 }}>
          <h1 style={{ fontSize: 24, fontWeight: 400, color: 'var(--slate-900)', lineHeight: 1.25 }}>{item.title}</h1>
          <div style={{ marginTop: 4, flexShrink: 0 }}>
            <PriceBadge item={item} />
          </div>
        </div>
        {mediumLine && <p style={{ ...secondaryText, marginTop: 6 }}>{mediumLine}</p>}
        {raw.dimensions && <p style={secondaryText}>{raw.dimensions}</p>}
        {materials.length > 0 && <p style={secondaryText}>Materials: {materials.join(', ')}</p>}
        {raw.location && (
          <p style={{ ...secondaryText, display: 'flex', alignItems: 'center', gap: 4, marginTop: 4 }}>
            <MapPin size={14} /> {raw.location}
          </p>
        )}
        {availability && (
          <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--slate-700)', marginTop: 8 }}>
            {availability}
            {item.priceLabel && !item.isSold && item.isForSale ? ` · ${item.priceLabel}` : ''}
          </p>
        )}
        {item.caption && (
          <p style={{ fontSize: 16, color: 'var(--slate-900)', lineHeight: 1.45, marginTop: 16, whiteSpace: 'pre-wrap' }}>
            {item.caption}
          </p>
        )}
      </div>

      {isMine ? (
        <AppNotice icon={Pencil} title="Edit in the Studio3 app">
          Editing, pricing and publishing your pieces happens in the app.
        </AppNotice>
      ) : (
        isCollectable(item) && (
          <AppNotice title="Collect in the Studio3 app">
            {item.priceLabel ? `${item.priceLabel} · ` : ''}Open this piece in the Studio3 app on iOS or Android to collect it.
          </AppNotice>
        )
      )}

      {series && (
        <>
          <hr style={{ ...divider, marginTop: 16 }} />
          <div style={{ padding: 16 }}>
            <div style={sectionTitle}>Part of a series</div>
            <p style={{ ...secondaryText, marginTop: 2 }}>
              {series.name}
              {series.pieceCount ? ` · ${series.pieceCount} pieces` : ''}
            </p>
            {seriesThumbs.length > 0 && (
              <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
                {seriesThumbs.map((p) => (
                  <Link
                    key={p.id}
                    to={`/piece/${p.id}`}
                    aria-label={p.title || 'Series piece'}
                    style={{
                      width: 64,
                      height: 64,
                      borderRadius: 10,
                      overflow: 'hidden',
                      background: 'var(--slate-100)',
                      outline: p.id === item.id ? '2px solid var(--slate-900)' : 'none',
                      outlineOffset: 1,
                    }}
                  >
                    <img src={p.mediaUrl} alt={p.title || ''} loading="lazy" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
                  </Link>
                ))}
              </div>
            )}
          </div>
        </>
      )}

      {related.length > 0 && (
        <>
          <hr style={{ ...divider, marginTop: series ? 0 : 16 }} />
          <div style={{ padding: '16px 0' }}>
            <div style={{ ...sectionTitle, padding: '0 16px' }}>Related scenes</div>
            <div style={{ display: 'flex', gap: 10, overflowX: 'auto', padding: '10px 16px 4px', scrollbarWidth: 'none' }}>
              {related.map((scene) => (
                <Link key={scene.id} to={scene.href} style={{ flex: '0 0 120px', display: 'block' }}>
                  <MediaThumb item={scene} aspectRatio={3 / 4} rounded={12} />
                </Link>
              ))}
            </div>
          </div>
        </>
      )}

      <hr style={{ ...divider, marginTop: related.length || series ? 0 : 16 }} />
      <CommentsSection item={item} onAdded={() => setCommentCount((c) => c + 1)} />
    </div>
  );
}
