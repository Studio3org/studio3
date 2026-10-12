import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { Heart, MessageCircle, Bookmark, Volume2, VolumeX } from 'lucide-react';
import { Avatar } from '../components/common/Avatar';
import { StateMessage } from '../components/common/StateMessage';
import { ContentActionsMenu } from '../components/moderation/ContentActionsMenu';
import { apiFetch } from '../lib/api';
import { normalizeItem } from '../lib/content';
import { useSession } from '../lib/session';
import { useCursorList } from '../lib/useCursorList';
import { useEngagement } from '../lib/useEngagement';
import { friendlyError } from '../lib/social';
import { fetchExplore, useVisibleItems } from '../lib/feedApi';

// Clears the floating bottom nav (56px pill + 16px offset + breathing room).
const NAV_CLEARANCE = 96;

const actionButton = {
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  gap: 2,
  color: 'var(--white)',
  fontSize: 12,
  fontWeight: 600,
  background: 'none',
  border: 'none',
  cursor: 'pointer',
  textShadow: '0 1px 4px rgba(0,0,0,0.5)',
};

async function fetchReels(cursor) {
  const page = await fetchExplore(cursor, 'video');
  return { ...page, items: page.items.filter((i) => i.type === 'post' && i.isVideo) };
}

export function ReelsPage() {
  const [params] = useSearchParams();
  const startId = params.get('start');
  const { items, setItems, loading, error, reload, loadMore, nextCursor } = useCursorList(fetchReels, []);
  const visible = useVisibleItems(items);
  const [activeId, setActiveId] = useState(null);
  const [muted, setMuted] = useState(true);
  const scrollerRef = useRef(null);
  const nodes = useRef(new Map());
  const startHandled = useRef(false);

  /// `?start=` may point at a video that isn't on the first explore page —
  /// fetch it and put it first so the link always lands on it.
  useEffect(() => {
    if (loading || !startId || startHandled.current) return;
    startHandled.current = true;
    if (items.some((i) => String(i.id) === startId)) return;
    apiFetch(`/api/posts/${encodeURIComponent(startId)}`, { auth: true })
      .then((raw) => {
        const item = normalizeItem(raw, 'post');
        if (item?.isVideo) setItems((prev) => [item, ...prev.filter((p) => p.id !== item.id)]);
      })
      .catch(() => {});
  }, [loading, startId, items, setItems]);

  // Scroll to the start item once it's rendered.
  const scrolledToStart = useRef(false);
  useEffect(() => {
    if (!startId || scrolledToStart.current) return;
    const node = nodes.current.get(startId);
    if (node) {
      scrolledToStart.current = true;
      node.scrollIntoView({ block: 'start' });
      setActiveId(startId);
    }
  }, [startId, visible]);

  // Track which reel fills most of the screen; that one plays.
  useEffect(() => {
    const root = scrollerRef.current;
    if (!root) return undefined;
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) setActiveId(e.target.dataset.id);
        });
      },
      { root, threshold: 0.6 },
    );
    nodes.current.forEach((node) => observer.observe(node));
    return () => observer.disconnect();
  }, [visible.length, loading]);

  // Fetch the next page a few reels before the end.
  useEffect(() => {
    const index = visible.findIndex((i) => String(i.id) === activeId);
    if (nextCursor && index >= visible.length - 3) loadMore();
  }, [activeId, visible, nextCursor, loadMore]);

  const register = useCallback((id) => (node) => {
    if (node) nodes.current.set(String(id), node);
    else nodes.current.delete(String(id));
  }, []);

  const shellStyle = { height: '100dvh', background: '#000', color: 'var(--white)' };

  if (loading) return <div style={shellStyle}><StateMessage style={{ color: 'var(--slate-300)', paddingTop: 160 }}>Loading…</StateMessage></div>;
  if (error) {
    return (
      <div style={shellStyle}>
        <StateMessage style={{ color: 'var(--slate-300)', paddingTop: 160 }} action="Try again" onAction={reload}>
          {friendlyError(error)}
        </StateMessage>
      </div>
    );
  }
  if (visible.length === 0) {
    return <div style={shellStyle}><StateMessage style={{ color: 'var(--slate-300)', paddingTop: 160 }}>No videos yet.</StateMessage></div>;
  }

  return (
    <div
      ref={scrollerRef}
      style={{ ...shellStyle, overflowY: 'auto', scrollSnapType: 'y mandatory', overscrollBehavior: 'contain' }}
    >
      {visible.map((item, index) => (
        <div
          key={item.id}
          ref={register(item.id)}
          data-id={String(item.id)}
          style={{ height: '100dvh', scrollSnapAlign: 'start', scrollSnapStop: 'always', position: 'relative' }}
        >
          <Reel
            item={item}
            active={activeId ? String(item.id) === activeId : index === 0}
            muted={muted}
            onToggleMute={() => setMuted((m) => !m)}
          />
        </div>
      ))}
    </div>
  );
}

function Reel({ item, active, muted, onToggleMute }) {
  const videoRef = useRef(null);
  const { user } = useSession();
  const { liked, likeCount, saved, toggleLike, toggleSave, error } = useEngagement(item);
  const isMine = Boolean(user?.username) && item.author?.username === user.username;

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    if (active) {
      video.play().catch(() => {}); // autoplay can be refused; the poster stays
    } else {
      video.pause();
    }
  }, [active]);

  return (
    <>
      <video
        ref={videoRef}
        src={item.videoUrl}
        poster={item.imageUrl ?? undefined}
        muted={muted}
        loop
        playsInline
        preload={active ? 'auto' : 'metadata'}
        onClick={onToggleMute}
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', background: '#000' }}
      />
      <button
        type="button"
        aria-label={muted ? 'Unmute' : 'Mute'}
        onClick={onToggleMute}
        style={{ position: 'absolute', top: 52, right: 16, width: 36, height: 36, borderRadius: '50%', background: 'rgba(15,23,42,0.45)', color: 'var(--white)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
      >
        {muted ? <VolumeX size={18} /> : <Volume2 size={18} />}
      </button>

      {/* Bottom gradient keeps the white overlay legible on bright footage. */}
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: 0,
          padding: `48px 72px ${NAV_CLEARANCE}px 16px`,
          background: 'linear-gradient(to top, rgba(0,0,0,0.65), rgba(0,0,0,0))',
          pointerEvents: 'none',
        }}
      >
        <div style={{ pointerEvents: 'auto' }}>
          {item.author?.username ? (
            <Link to={`/u/${item.author.username}`} style={{ display: 'inline-flex', alignItems: 'center', gap: 10, color: 'var(--white)' }}>
              <Avatar src={item.author.profilePhotoUrl} name={item.author.name} size={34} style={{ border: '1.5px solid rgba(255,255,255,0.8)' }} />
              <span style={{ fontSize: 14, fontWeight: 600 }}>{item.author.name}</span>
            </Link>
          ) : null}
          {item.caption && (
            <p style={{ marginTop: 8, fontSize: 14, lineHeight: 1.4, color: 'var(--white)', display: '-webkit-box', WebkitLineClamp: 3, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
              {item.caption}
            </p>
          )}
          {error && <p style={{ marginTop: 6, fontSize: 12, color: '#FF8A8A' }}>{error}</p>}
        </div>
      </div>

      <div style={{ position: 'absolute', right: 12, bottom: NAV_CLEARANCE, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18 }}>
        <button type="button" style={actionButton} onClick={toggleLike} aria-label={liked ? 'Unlike' : 'Like'}>
          <Heart size={28} fill={liked ? '#FF3040' : 'none'} color={liked ? '#FF3040' : 'currentColor'} />
          {likeCount > 0 && likeCount}
        </button>
        <Link to={item.href} style={actionButton} aria-label="Comments">
          <MessageCircle size={28} />
          {item.commentCount > 0 && item.commentCount}
        </Link>
        <button type="button" style={actionButton} onClick={toggleSave} aria-label={saved ? 'Unsave' : 'Save'}>
          <Bookmark size={28} fill={saved ? 'currentColor' : 'none'} />
        </button>
        {!isMine && (
          <ContentActionsMenu
            target={{ type: 'post', id: item.id }}
            authorUsername={item.author?.username}
            buttonStyle={{ background: 'rgba(15,23,42,0.45)', color: 'var(--white)', width: 36, height: 36 }}
          />
        )}
      </div>
    </>
  );
}
