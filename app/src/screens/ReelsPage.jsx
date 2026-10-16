import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import {
  Bookmark,
  ChevronLeft,
  Heart,
  Link as LinkIcon,
  MessageCircle,
  MoreHorizontal,
  Volume2,
  VolumeX,
} from 'lucide-react';
import { APP_BASE_URL } from '../services/apiClient';
import { useBreakpoint } from '../hooks/useBreakpoint';
import { fetchFeed, fetchPost, isVideoItem } from '../services/feedApi';
import { friendlyError } from '../services/socialApi';
import { isBlockedAuthor } from '../services/blockedAuthors';
import { profileHref } from '../utils/contentLinks';
import { useToast } from '../components/common/ActionSheet';
import { ContentActionsSheet } from '../components/moderation/ContentActions';
import { useBlockedAuthorsTick, useFeedEngagement } from '../components/feed/useFeedEngagement';
import './ReelsPage.css';

const isReel = (item) => item?.type === 'post' && isVideoItem(item) && Boolean(item.mediaUrl);
const sceneHref = (item) => `/scene/${item.id}`;

/// Compact counts for the action rail: 1.2k, 3.4m.
function compact(n) {
  if (!n) return '0';
  if (n < 1000) return String(n);
  if (n < 1_000_000) return `${(n / 1000).toFixed(n < 10_000 ? 1 : 0).replace(/\.0$/, '')}k`;
  return `${(n / 1_000_000).toFixed(1).replace(/\.0$/, '')}m`;
}

/**
 * /reels — full-height, snap-scrolling player for video scenes (explore `medium=video`),
 * the web twin of the app's reels tab. The visible clip autoplays muted; a tap toggles
 * sound for every clip. `?start=<postId>` opens at that clip, fetching it on its own
 * when it isn't in the first page (e.g. an older video tapped on Discover or a profile).
 */
export function ReelsPage() {
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const startId = params.get('start');
  const { showRail, railLabeled } = useBreakpoint();
  const [items, setItems] = useState([]);
  const [nextCursor, setNextCursor] = useState(null);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [active, setActive] = useState(0);
  const [muted, setMuted] = useState(true);
  const [actionsFor, setActionsFor] = useState(null);
  const [toast, showToast] = useToast();
  const engagement = useFeedEngagement(showToast);
  useBlockedAuthorsTick();

  const scrollerRef = useRef(null);
  const seq = useRef(0);
  const pendingScrollTo = useRef(null);

  const visible = items.filter((i) => !isBlockedAuthor(i.author?.username));

  // First page (+ the ?start clip when it isn't on it).
  useEffect(() => {
    const id = ++seq.current;
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setItems([]);
    setNextCursor(null);
    setActive(0);
    (async () => {
      try {
        const page = await fetchFeed('explore', { medium: 'video', signal: controller.signal });
        let reels = page.items.filter(isReel);
        if (startId) {
          const at = reels.findIndex((r) => String(r.id) === String(startId));
          if (at >= 0) {
            pendingScrollTo.current = at;
          } else {
            try {
              const post = await fetchPost(startId, { signal: controller.signal });
              if (isReel(post)) reels = [post, ...reels];
              else showToast('That video isn’t available.');
            } catch (e) {
              if (e.name === 'AbortError') throw e;
              showToast(friendlyError(e));
            }
          }
        }
        if (id !== seq.current) return;
        setItems(reels);
        setNextCursor(page.nextCursor);
      } catch (e) {
        if (id !== seq.current || e.name === 'AbortError') return;
        setError(friendlyError(e));
      } finally {
        if (id === seq.current) setLoading(false);
      }
    })();
    return () => controller.abort();
    // showToast is a state setter (stable).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [startId, reloadKey]);

  // Jump to the ?start clip once its slide exists.
  useEffect(() => {
    const at = pendingScrollTo.current;
    const el = scrollerRef.current;
    if (at == null || !el || loading) return;
    pendingScrollTo.current = null;
    const slide = el.querySelector(`[data-index="${at}"]`);
    if (slide) {
      el.scrollTop = slide.offsetTop;
      setActive(at);
    }
  }, [loading, items.length]);

  const loadMore = useCallback(() => {
    if (loading || loadingMore || !nextCursor) return;
    const id = seq.current;
    setLoadingMore(true);
    fetchFeed('explore', { medium: 'video', cursor: nextCursor })
      .then((page) => {
        if (id !== seq.current) return;
        setItems((prev) => {
          const seen = new Set(prev.map((p) => String(p.id)));
          return [...prev, ...page.items.filter((p) => isReel(p) && !seen.has(String(p.id)))];
        });
        setNextCursor(page.nextCursor);
      })
      .catch((e) => {
        if (id !== seq.current) return;
        // Stop paging instead of retrying on every swipe; the end card offers a retry.
        setNextCursor(null);
        showToast(friendlyError(e));
      })
      .finally(() => {
        if (id === seq.current) setLoadingMore(false);
      });
  }, [loading, loadingMore, nextCursor, showToast]);

  // Prefetch when two clips from the end (also keeps paging past a page with no videos).
  useEffect(() => {
    if (!loading && nextCursor && active >= visible.length - 3) loadMore();
  }, [active, visible.length, nextCursor, loading, loadMore]);

  // Which slide is on screen: the one at least 60% visible inside the scroller.
  useEffect(() => {
    const root = scrollerRef.current;
    if (!root) return undefined;
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) setActive(Number(entry.target.dataset.index));
        });
      },
      { root, threshold: 0.6 },
    );
    root.querySelectorAll('[data-index]').forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, [visible.length, loading]);

  const step = useCallback((dir) => {
    const el = scrollerRef.current;
    if (el) el.scrollBy({ top: dir * el.clientHeight, behavior: 'smooth' });
  }, []);

  // Desktop keys: ↑/↓ (or j/k) between clips, m to mute.
  useEffect(() => {
    const onKey = (e) => {
      if (actionsFor || /input|textarea|select/i.test(e.target?.tagName || '')) return;
      if (e.key === 'ArrowDown' || e.key === 'j') {
        e.preventDefault();
        step(1);
      } else if (e.key === 'ArrowUp' || e.key === 'k') {
        e.preventDefault();
        step(-1);
      } else if (e.key === 'm') {
        setMuted((m) => !m);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [step, actionsFor]);

  const goBack = () => {
    if (window.history.state?.idx > 0) navigate(-1);
    else navigate('/discover');
  };

  const copyLink = (item) => {
    const url = `${APP_BASE_URL}/reels?start=${encodeURIComponent(item.id)}`;
    if (!navigator.clipboard) {
      showToast(url);
      return;
    }
    navigator.clipboard.writeText(url).then(
      () => showToast('Link copied'),
      () => showToast(url),
    );
  };

  const left = showRail ? (railLabeled ? 244 : 72) : 0;

  return (
    <div className={`reels-page${showRail ? ' reels-page--wide' : ''}`} style={{ left }}>
      <header className="reels-header">
        <button type="button" className="reels-icon-btn" onClick={goBack} aria-label="Back">
          <ChevronLeft size={24} strokeWidth={2} />
        </button>
        <span className="reels-title">Reels</span>
        <button
          type="button"
          className="reels-icon-btn"
          onClick={() => setMuted((m) => !m)}
          aria-label={muted ? 'Unmute' : 'Mute'}
        >
          {muted ? <VolumeX size={20} strokeWidth={2} /> : <Volume2 size={20} strokeWidth={2} />}
        </button>
      </header>

      {loading ? (
        <div className="reels-state">
          <div className="reels-spinner" aria-label="Loading" />
        </div>
      ) : error ? (
        <div className="reels-state">
          <p className="reels-state-title">Couldn’t load reels</p>
          <p className="reels-state-body">{error}</p>
          <button type="button" className="reels-state-btn" onClick={() => setReloadKey((k) => k + 1)}>
            Try again
          </button>
        </div>
      ) : visible.length === 0 && !nextCursor && !loadingMore ? (
        <div className="reels-state">
          <p className="reels-state-title">No reels yet</p>
          <p className="reels-state-body">Video scenes from artists will play here.</p>
          <button type="button" className="reels-state-btn" onClick={() => navigate('/discover')}>
            Explore
          </button>
        </div>
      ) : (
        <div className="reels-scroller" ref={scrollerRef}>
          {visible.map((item, i) => (
            <ReelSlide
              key={item.id}
              index={i}
              item={item}
              isActive={i === active}
              // Mount the <video> only around the visible clip so a long list doesn't
              // download every file at once.
              shouldLoad={Math.abs(i - active) <= 1}
              muted={muted}
              onToggleMute={() => setMuted((m) => !m)}
              engagement={engagement.stateFor(item)}
              onLike={() => engagement.toggleLike(item)}
              onSave={() => engagement.toggleSave(item)}
              onMore={() => setActionsFor(item)}
            />
          ))}
          {(loadingMore || nextCursor) && (
            <section className="reels-slide reels-slide--end" data-index={visible.length}>
              <div className="reels-spinner" aria-label="Loading more" />
            </section>
          )}
          {!loadingMore && !nextCursor && visible.length > 0 && (
            <section className="reels-slide reels-slide--end" data-index={visible.length}>
              <p className="reels-state-title">You’re all caught up</p>
              <div className="reels-end-actions">
                <button type="button" className="reels-state-btn" onClick={() => setReloadKey((k) => k + 1)}>
                  Refresh
                </button>
                <button type="button" className="reels-state-btn reels-state-btn--ghost" onClick={() => navigate('/discover')}>
                  Back to Discover
                </button>
              </div>
            </section>
          )}
        </div>
      )}

      {actionsFor && (
        <ContentActionsSheet
          target={{ type: 'post', id: actionsFor.id }}
          authorUsername={actionsFor.author?.username || undefined}
          items={[
            { label: 'Open scene', icon: <MessageCircle size={18} />, onClick: () => navigate(sceneHref(actionsFor)) },
            { label: 'Copy link', icon: <LinkIcon size={18} />, onClick: () => copyLink(actionsFor) },
          ]}
          onClose={() => setActionsFor(null)}
          onNotice={showToast}
        />
      )}
      {toast}
    </div>
  );
}

function ReelSlide({ index, item, isActive, shouldLoad, muted, onToggleMute, engagement, onLike, onSave, onMore }) {
  const videoRef = useRef(null);
  const [portrait, setPortrait] = useState(item.mediaAspectRatio === '3:4');
  const [expanded, setExpanded] = useState(false);
  const [muteFlash, setMuteFlash] = useState(false);
  const author = item.author;
  const name = author?.name || author?.username || 'Artist';

  // Play the visible clip, pause the rest; pause too while the tab is hidden.
  useEffect(() => {
    const v = videoRef.current;
    if (!v) return undefined;
    const sync = () => {
      if (isActive && !document.hidden) {
        v.play().catch(() => {
          // Sound needs a user gesture in some browsers — fall back to muted playback.
          if (!v.muted) {
            v.muted = true;
            v.play().catch(() => {});
          }
        });
      } else {
        v.pause();
      }
    };
    sync();
    document.addEventListener('visibilitychange', sync);
    return () => document.removeEventListener('visibilitychange', sync);
  }, [isActive, shouldLoad]);

  useEffect(() => {
    if (videoRef.current) videoRef.current.muted = muted;
  }, [muted, shouldLoad]);

  useEffect(() => {
    if (!muteFlash) return undefined;
    const t = setTimeout(() => setMuteFlash(false), 700);
    return () => clearTimeout(t);
  }, [muteFlash]);

  // A tap toggles sound for every clip (the app's behaviour); clips always loop.
  const onTap = () => {
    onToggleMute();
    setMuteFlash(true);
  };

  return (
    <section className="reels-slide" data-index={index} aria-label={`Video by ${name}`}>
      <div className={`reels-frame${portrait ? ' reels-frame--portrait' : ''}`}>
        {shouldLoad ? (
          <video
            ref={videoRef}
            className="reels-video"
            src={item.mediaUrl}
            poster={item.thumbnailUrl || undefined}
            muted={muted}
            loop
            playsInline
            preload={isActive ? 'auto' : 'metadata'}
            onLoadedMetadata={(e) => setPortrait(e.currentTarget.videoHeight > e.currentTarget.videoWidth)}
            onClick={onTap}
            onContextMenu={(e) => e.preventDefault()}
          />
        ) : item.thumbnailUrl ? (
          <img className="reels-video" src={item.thumbnailUrl} alt="" />
        ) : (
          <div className="reels-video" />
        )}

        {muteFlash && (
          <div className="reels-center-icon" aria-hidden="true">
            {muted ? <VolumeX size={28} /> : <Volume2 size={28} />}
          </div>
        )}

        <div className="reels-info">
          {author?.username ? (
            <Link to={profileHref(author.username)} className="reels-author">
              {author.profilePhotoUrl ? (
                <img src={author.profilePhotoUrl} alt="" className="reels-avatar" />
              ) : (
                <span className="reels-avatar reels-avatar--initial">{name[0]?.toUpperCase()}</span>
              )}
              <span className="reels-author-name">{name}</span>
            </Link>
          ) : (
            <span className="reels-author">
              <span className="reels-avatar reels-avatar--initial">A</span>
              <span className="reels-author-name">{name}</span>
            </span>
          )}
          {item.caption && (
            <button
              type="button"
              className={`reels-caption${expanded ? ' reels-caption--open' : ''}`}
              onClick={() => setExpanded((x) => !x)}
            >
              {item.caption}
            </button>
          )}
        </div>

        <div className="reels-rail">
          <button
            type="button"
            className="reels-rail-btn"
            onClick={onLike}
            aria-label={engagement.isLiked ? 'Unlike' : 'Like'}
            aria-pressed={engagement.isLiked}
          >
            <span className="reels-rail-icon">
              <Heart
                size={26}
                strokeWidth={2}
                fill={engagement.isLiked ? '#E05252' : 'none'}
                color={engagement.isLiked ? '#E05252' : 'currentColor'}
              />
            </span>
            <span className="reels-rail-count">{compact(engagement.likeCount)}</span>
          </button>
          <Link to={sceneHref(item)} className="reels-rail-btn" aria-label="Comments">
            <span className="reels-rail-icon">
              <MessageCircle size={26} strokeWidth={2} />
            </span>
            <span className="reels-rail-count">{compact(item.commentCount)}</span>
          </Link>
          <button
            type="button"
            className="reels-rail-btn"
            onClick={onSave}
            aria-label={engagement.isSaved ? 'Unsave' : 'Save'}
            aria-pressed={engagement.isSaved}
          >
            <span className="reels-rail-icon">
              <Bookmark size={26} strokeWidth={2} fill={engagement.isSaved ? 'currentColor' : 'none'} />
            </span>
          </button>
          <button type="button" className="reels-rail-btn" onClick={onMore} aria-label="More options">
            <span className="reels-rail-icon">
              <MoreHorizontal size={26} strokeWidth={2} />
            </span>
          </button>
        </div>
      </div>
    </section>
  );
}
