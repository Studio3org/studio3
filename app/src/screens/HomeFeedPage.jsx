import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bookmark, ChevronDown, Heart, Link as LinkIcon, MoreHorizontal, Play } from 'lucide-react';
import { APP_BASE_URL } from '../services/apiClient';
import { useAuth } from '../context/AuthContext';
import { useBreakpoint } from '../hooks/useBreakpoint';
import { useRequireLogin } from '../hooks/useRequireLogin';
import { NavIcon } from '../components/icons/NavIcon';
import { fetchUnreadConversationCount, fetchUnreadNotificationCount } from '../services/inboxApi';
import { InboxRail, RIGHT_RAIL_WIDTH } from '../components/layout/InboxRail';
import { fetchFeed, isAvailablePiece, isVideoItem } from '../services/feedApi';
import { friendlyError } from '../services/socialApi';
import { isBlockedAuthor } from '../services/blockedAuthors';
import { contentHref, profileHref } from '../utils/contentLinks';
import { useToast } from '../components/common/ActionSheet';
import { ContentActionsSheet } from '../components/moderation/ContentActions';
import { useBlockedAuthorsTick, useFeedEngagement } from '../components/feed/useFeedEngagement';

const MAIN_COLUMN_WIDTH = 630;

const TABS = [
  { key: 'forYou', label: 'For You' },
  { key: 'following', label: 'Following' },
];

const FILTERS = ['All', 'Pieces', 'Scenes', 'Available'];

/** Feed badge from the backend's `listingState` (pieces_dao.piece_listing_state), falling
 * back to raw status for older payloads. Scenes never carry one. */
function statusFor(item) {
  if (item.type !== 'piece') return null;
  switch (item.listingState) {
    case 'available':
      return 'available';
    case 'auction_live':
      return 'auction';
    case 'collected':
    case 'auction_ended':
      return 'collected';
    default:
      break;
  }
  if (item.status === 'sold' || item.status === 'reserved') return 'collected';
  if (item.isForSale && item.status === 'live') return 'available';
  return null;
}

const STATUS_LABELS = { available: 'Available', auction: 'Live auction', collected: 'Collected' };

/** Mirrors home_feed_page.dart's `_resolveAspectRatio`: the baked-at-publish
 * `mediaAspectRatio` ('16:9' or '3:4') is authoritative when present, so a
 * piece/scene renders at the ratio it was actually uploaded/cropped at
 * instead of a size guessed from its media type. Only videos (which skip
 * the crop step, so never get a stored ratio) and legacy content published
 * before this field existed fall back to a type-based guess. */
function aspectFor(item) {
  if (item.mediaAspectRatio) return item.mediaAspectRatio === '16:9' ? '16 / 9' : '3 / 4';
  return isVideoItem(item) ? '16 / 9' : '3 / 4';
}

function mapFeedItem(item) {
  return {
    id: item.id,
    type: item.type === 'post' ? 'post' : 'piece',
    title: item.title || item.caption || 'Untitled',
    medium: item.medium || (item.type === 'post' ? 'Scene' : ''),
    artistName: item.author?.name || item.author?.username || 'Artist',
    authorUsername: item.author?.username || '',
    authorAvatarUrl: item.author?.profilePhotoUrl,
    aspect: aspectFor(item),
    status: statusFor(item),
    available: isAvailablePiece(item),
    mediaUrl: item.mediaUrl,
    // A video's mediaUrl is an .mp4 — rendered in an <img> (as this card does) that
    // shows nothing at all, not even a broken-image icon. isVideo/thumbnailUrl let the
    // card show the poster frame instead, the same fix DiscoverPage's tile already has.
    isVideo: isVideoItem(item),
    thumbnailUrl: item.thumbnailUrl,
    isLiked: item.isLiked,
    likeCount: item.likeCount,
    isSaved: item.isSaved,
  };
}

function matchesFilter(item, filter) {
  if (filter === 'Pieces') return item.type === 'piece';
  if (filter === 'Scenes') return item.type === 'post';
  if (filter === 'Available') return item.available;
  return true;
}

const EMPTY_FEED = { items: [], nextCursor: null, loading: true, loadingMore: false, error: null, moreError: null };

export function HomeFeedPage() {
  const navigate = useNavigate();
  const { status } = useAuth();
  const requireLogin = useRequireLogin();
  const { showRail, railLabeled } = useBreakpoint();
  const [tab, setTab] = useState('forYou');
  const [filter, setFilter] = useState('All');
  const [filterOpen, setFilterOpen] = useState(false);
  const [feed, setFeed] = useState(EMPTY_FEED);
  const [unreadCount, setUnreadCount] = useState(0);
  const [reloadKey, setReloadKey] = useState(0);
  const [actionsFor, setActionsFor] = useState(null);
  const [toast, showToast] = useToast();
  const engagement = useFeedEngagement(showToast);
  useBlockedAuthorsTick();

  const authenticated = status === 'authenticated';
  const guestOnFollowing = tab === 'following' && status === 'guest';
  // Bumped on every fresh load so a slow page from the previous tab can't land on this one.
  const requestId = useRef(0);
  const sentinelRef = useRef(null);

  useEffect(() => {
    // Wait for the session check so For You comes back personalised, and never ask
    // the onboarded-only Following feed on a guest's behalf.
    if (status === 'loading' || guestOnFollowing) return undefined;
    const id = ++requestId.current;
    const controller = new AbortController();
    setFeed(EMPTY_FEED);
    fetchFeed(tab, { signal: controller.signal })
      .then((page) => {
        if (id !== requestId.current) return;
        setFeed({ ...EMPTY_FEED, items: page.items.map(mapFeedItem), nextCursor: page.nextCursor, loading: false });
      })
      .catch((e) => {
        if (id !== requestId.current || e.name === 'AbortError') return;
        setFeed({ ...EMPTY_FEED, loading: false, error: friendlyError(e) });
      });
    return () => controller.abort();
  }, [tab, status, guestOnFollowing, reloadKey]);

  const loadMore = useCallback(() => {
    if (feed.loading || feed.loadingMore || !feed.nextCursor || feed.error || feed.moreError) return;
    const id = requestId.current;
    setFeed((f) => ({ ...f, loadingMore: true }));
    fetchFeed(tab, { cursor: feed.nextCursor })
      .then((page) => {
        if (id !== requestId.current) return;
        setFeed((f) => {
          const seen = new Set(f.items.map((i) => `${i.type}:${i.id}`));
          const fresh = page.items.map(mapFeedItem).filter((i) => !seen.has(`${i.type}:${i.id}`));
          return { ...f, items: [...f.items, ...fresh], nextCursor: page.nextCursor, loadingMore: false };
        });
      })
      .catch((e) => {
        if (id !== requestId.current) return;
        setFeed((f) => ({ ...f, loadingMore: false, moreError: friendlyError(e) }));
      });
  }, [feed, tab]);

  // Infinite scroll. Re-observing whenever the list grows means a filter that hides most
  // of a page (e.g. Available) keeps pulling pages while the sentinel is still on screen.
  useEffect(() => {
    const el = sentinelRef.current;
    if (!el || !feed.nextCursor || feed.moreError || feed.loadingMore) return undefined;
    const io = new IntersectionObserver((entries) => entries[0]?.isIntersecting && loadMore(), {
      rootMargin: '600px 0px',
    });
    io.observe(el);
    return () => io.disconnect();
  }, [feed.items.length, feed.nextCursor, feed.moreError, feed.loadingMore, loadMore]);

  useEffect(() => {
    // Unread counts are account-only; asking as a guest would just trip the 401 handling.
    if (!authenticated) {
      setUnreadCount(0);
      return undefined;
    }
    let cancelled = false;
    Promise.all([fetchUnreadNotificationCount(), fetchUnreadConversationCount()])
      .then(([notifs, chats]) => !cancelled && setUnreadCount(notifs + chats))
      .catch(() => {
        /* fail silent */
      });
    return () => {
      cancelled = true;
    };
  }, [authenticated]);

  const visibleItems = feed.items.filter((item) => !isBlockedAuthor(item.authorUsername) && matchesFilter(item, filter));

  const goAccount = (path) => {
    if (requireLogin()) navigate(path);
  };

  const copyLink = (item) => {
    const url = `${APP_BASE_URL}${contentHref(item)}`;
    if (!navigator.clipboard) {
      showToast(url);
      return;
    }
    navigator.clipboard.writeText(url).then(
      () => showToast('Link copied'),
      () => showToast(url),
    );
  };

  return (
    <div style={{ background: 'var(--cream-bg)', minHeight: '100vh', paddingBottom: 96 }}>
      <div
        style={{
          maxWidth: railLabeled && authenticated ? MAIN_COLUMN_WIDTH + RIGHT_RAIL_WIDTH + 48 : MAIN_COLUMN_WIDTH,
          margin: '0 auto',
          display: 'flex',
          gap: 48,
        }}
      >
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ position: 'sticky', top: 0, zIndex: 10, background: 'var(--cream-bg)' }}>
            <header
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                height: 52,
                padding: '0 10px',
                background: 'var(--cream-bg)',
              }}
            >
              <div style={{ position: 'relative' }}>
                <button
                  type="button"
                  onClick={() => setFilterOpen((open) => !open)}
                  aria-haspopup="menu"
                  aria-expanded={filterOpen}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 4,
                    fontFamily: 'var(--font-geist)',
                    fontSize: 16,
                    fontWeight: 600,
                    color: 'var(--cream-text)',
                  }}
                >
                  {filter} <ChevronDown size={16} strokeWidth={2.25} />
                </button>
                {filterOpen && (
                  <>
                    <div style={{ position: 'fixed', inset: 0, zIndex: 20 }} onClick={() => setFilterOpen(false)} />
                    <div
                      role="menu"
                      style={{
                        position: 'absolute',
                        top: 36,
                        left: 0,
                        zIndex: 21,
                        background: 'var(--cream-bg-detail)',
                        border: '1px solid var(--cream-divider)',
                        borderRadius: 12,
                        padding: 6,
                        boxShadow: 'var(--shadow-float)',
                        minWidth: 140,
                      }}
                    >
                      {FILTERS.map((f) => (
                        <button
                          key={f}
                          type="button"
                          role="menuitemradio"
                          aria-checked={f === filter}
                          onClick={() => {
                            setFilter(f);
                            setFilterOpen(false);
                          }}
                          style={{
                            display: 'block',
                            width: '100%',
                            textAlign: 'left',
                            padding: '10px 12px',
                            borderRadius: 10,
                            fontFamily: 'var(--font-geist)',
                            fontSize: 14,
                            fontWeight: f === filter ? 600 : 400,
                            color: 'var(--cream-text)',
                          }}
                        >
                          {f}
                        </button>
                      ))}
                    </div>
                  </>
                )}
              </div>

              <img src="/logo/logo_text_black.png" alt="Studio 3" height={34} style={{ height: 34, width: 'auto' }} />

              <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
                <button aria-label="Saved" onClick={() => goAccount('/saved')} style={{ color: 'var(--cream-text)' }}>
                  <Bookmark size={22} strokeWidth={1.75} />
                </button>
                <button
                  aria-label="Inbox"
                  onClick={() => goAccount('/inbox')}
                  style={{ position: 'relative', color: 'var(--cream-text)' }}
                >
                  <NavIcon id="bell" size={22} />
                  {unreadCount > 0 && (
                    <span
                      style={{
                        position: 'absolute',
                        top: -4,
                        right: -6,
                        minWidth: 14,
                        height: 14,
                        padding: '0 3px',
                        borderRadius: 7,
                        background: '#E05252',
                        color: '#fff',
                        fontSize: 9,
                        fontWeight: 600,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      {unreadCount > 9 ? '9+' : unreadCount}
                    </span>
                  )}
                </button>
                {status === 'guest' && <GuestAuthLinks compact={!showRail} />}
              </div>
            </header>

            <div
              role="tablist"
              aria-label="Feed"
              style={{ display: 'flex', height: 40, borderBottom: '1px solid var(--cream-divider)' }}
            >
              {TABS.map((t) => {
                const active = t.key === tab;
                return (
                  <button
                    key={t.key}
                    type="button"
                    role="tab"
                    aria-selected={active}
                    onClick={() => setTab(t.key)}
                    style={{
                      flex: 1,
                      position: 'relative',
                      fontFamily: 'var(--font-geist)',
                      fontSize: 14,
                      fontWeight: active ? 600 : 500,
                      color: active ? 'var(--cream-text)' : 'var(--cream-text-secondary)',
                    }}
                  >
                    {t.label}
                    {active && (
                      <span
                        style={{
                          position: 'absolute',
                          left: '50%',
                          bottom: -1,
                          transform: 'translateX(-50%)',
                          width: 56,
                          height: 2,
                          borderRadius: 1,
                          background: 'var(--cream-text)',
                        }}
                      />
                    )}
                  </button>
                );
              })}
            </div>
          </div>

          {guestOnFollowing ? (
            <FeedMessage
              title="See who you follow"
              body="Log in to get a feed of new pieces and scenes from the artists you follow."
              action="Log in"
              onAction={() => requireLogin()}
              secondary="Create an account"
              onSecondary={() => navigate('/signup')}
            />
          ) : status === 'loading' || feed.loading ? (
            <HomeFeedSkeleton />
          ) : feed.error ? (
            <FeedMessage
              title="Couldn't load your feed"
              body={feed.error}
              action="Try again"
              onAction={() => setReloadKey((k) => k + 1)}
            />
          ) : visibleItems.length === 0 && !feed.nextCursor ? (
            <FeedMessage
              title={
                filter !== 'All'
                  ? `No ${filter === 'Available' ? 'available pieces' : filter.toLowerCase()} here yet`
                  : tab === 'following'
                    ? 'Nothing from people you follow yet'
                    : 'Nothing here yet'
              }
              body={
                tab === 'following'
                  ? 'Follow artists and collectors to see their new work here.'
                  : 'New pieces and scenes will show up here as artists post them.'
              }
              action="Explore"
              onAction={() => navigate('/discover')}
            />
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '10px 10px 0 10px' }}>
              {visibleItems.map((item) => (
                <FeedTile
                  key={`${item.type}:${item.id}`}
                  item={item}
                  engagement={engagement.stateFor(item)}
                  onOpen={() => navigate(contentHref(item))}
                  onLike={() => engagement.toggleLike(item)}
                  onSave={() => engagement.toggleSave(item)}
                  onMore={() => setActionsFor(item)}
                />
              ))}
            </div>
          )}

          {!guestOnFollowing && !feed.loading && !feed.error && (
            <>
              <div ref={sentinelRef} style={{ height: 1 }} />
              {feed.loadingMore && (
                <div style={{ padding: '10px 10px 0' }}>
                  <FeedTileSkeleton aspect="3 / 4" />
                </div>
              )}
              {feed.moreError && (
                <p style={{ textAlign: 'center', fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text-secondary)', padding: 24 }}>
                  {feed.moreError}{' '}
                  <button
                    type="button"
                    onClick={() => setFeed((f) => ({ ...f, moreError: null }))}
                    style={{ color: 'var(--cream-text)', fontWeight: 600, textDecoration: 'underline', fontSize: 13 }}
                  >
                    Retry
                  </button>
                </p>
              )}
            </>
          )}
        </div>
        {/* The rail reads notifications + chats, which are account-only. */}
        {railLabeled && authenticated && <InboxRail />}
      </div>

      {actionsFor && (
        <ContentActionsSheet
          target={{ type: actionsFor.type, id: actionsFor.id }}
          authorUsername={actionsFor.authorUsername || undefined}
          items={[{ label: 'Copy link', icon: <LinkIcon size={18} />, onClick: () => copyLink(actionsFor) }]}
          onClose={() => setActionsFor(null)}
          onNotice={showToast}
        />
      )}
      {toast}
    </div>
  );
}

/// Log in / Sign up in the header for guests — a text link + filled pill in the feed's
/// Geist type. Phones only get the one pill so the header row still fits at 360px.
function GuestAuthLinks({ compact }) {
  const navigate = useNavigate();
  const pill = {
    height: 30,
    padding: '0 14px',
    borderRadius: 22,
    fontFamily: 'var(--font-geist)',
    fontSize: 13,
    fontWeight: 600,
    whiteSpace: 'nowrap',
  };
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
      {!compact && (
        <button type="button" onClick={() => navigate('/login')} style={{ ...pill, color: 'var(--cream-text)' }}>
          Log in
        </button>
      )}
      <button
        type="button"
        onClick={() => navigate(compact ? '/login' : '/signup')}
        style={{ ...pill, background: 'var(--cream-cta-fill)', color: 'var(--cream-text-inverse)' }}
      >
        {compact ? 'Log in' : 'Sign up'}
      </button>
    </div>
  );
}

/// Empty / error / logged-out panel in the feed's quiet centered style.
function FeedMessage({ title, body, action, onAction, secondary, onSecondary }) {
  return (
    <div style={{ textAlign: 'center', padding: '56px 32px', fontFamily: 'var(--font-inter)' }}>
      <div style={{ fontFamily: 'var(--font-geist)', fontSize: 16, fontWeight: 600, color: 'var(--cream-text)' }}>{title}</div>
      {body && (
        <p style={{ margin: '8px auto 0', maxWidth: 340, fontSize: 14, lineHeight: 1.45, color: 'var(--cream-text-secondary)' }}>
          {body}
        </p>
      )}
      {action && (
        <button
          type="button"
          onClick={onAction}
          style={{
            marginTop: 20,
            height: 40,
            padding: '0 22px',
            borderRadius: 22,
            background: 'var(--cream-cta-fill)',
            color: 'var(--cream-text-inverse)',
            fontFamily: 'var(--font-geist)',
            fontSize: 14,
            fontWeight: 600,
          }}
        >
          {action}
        </button>
      )}
      {secondary && (
        <div>
          <button
            type="button"
            onClick={onSecondary}
            style={{ marginTop: 12, fontFamily: 'var(--font-geist)', fontSize: 13, color: 'var(--cream-text-secondary)', textDecoration: 'underline' }}
          >
            {secondary}
          </button>
        </div>
      )}
    </div>
  );
}

function HomeFeedSkeleton() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '10px 10px 0 10px' }}>
      <FeedTileSkeleton aspect="3 / 4" />
      <FeedTileSkeleton aspect="16 / 9" />
      <FeedTileSkeleton aspect="3 / 4" />
    </div>
  );
}

function FeedTileSkeleton({ aspect = '3 / 4' }) {
  return (
    <div
      className="feed-skeleton-block"
      style={{
        width: '100%',
        borderRadius: 10,
        position: 'relative',
        aspectRatio: aspect,
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: 0,
          height: 56,
          background: 'linear-gradient(to top, rgba(35,31,27,0.6), rgba(35,31,27,0))',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: 16,
          right: 16,
          bottom: 8,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          height: 40,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div className="feed-skeleton-block" style={{ width: 28, height: 28, borderRadius: '50%' }} />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <div className="feed-skeleton-block" style={{ width: 90, height: 12, borderRadius: 4 }} />
            <div className="feed-skeleton-block" style={{ width: 60, height: 10, borderRadius: 4 }} />
          </div>
        </div>
        <div className="feed-skeleton-block" style={{ width: 64, height: 20, borderRadius: 22 }} />
      </div>
    </div>
  );
}

/// Translucent round icon button for the tile's top-right action cluster.
function TileAction({ label, pressed, onClick, children }) {
  return (
    <button
      type="button"
      aria-label={label}
      aria-pressed={pressed}
      onClick={(e) => {
        e.stopPropagation();
        onClick();
      }}
      onKeyDown={(e) => e.stopPropagation()}
      style={{
        height: 32,
        minWidth: 32,
        padding: '0 8px',
        borderRadius: 16,
        background: 'rgba(35,31,27,0.45)',
        backdropFilter: 'blur(6px)',
        WebkitBackdropFilter: 'blur(6px)',
        color: 'var(--cream-text-inverse)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 4,
        fontFamily: 'var(--font-geist)',
        fontSize: 12,
        fontWeight: 600,
      }}
    >
      {children}
    </button>
  );
}

function FeedTile({ item, engagement, onOpen, onLike, onSave, onMore }) {
  const navigate = useNavigate();

  const handleArtistClick = (e) => {
    e.stopPropagation();
    if (item.authorUsername) navigate(profileHref(item.authorUsername));
  };

  // A div (not a <button>) so the like / save / more buttons inside stay valid markup.
  return (
    <div
      role="link"
      tabIndex={0}
      aria-label={item.title}
      onClick={onOpen}
      onKeyDown={(e) => {
        if (e.key === 'Enter') onOpen();
      }}
      style={{
        display: 'block',
        width: '100%',
        borderRadius: 10,
        overflow: 'hidden',
        position: 'relative',
        aspectRatio: item.aspect,
        background: 'var(--cream-skeleton)',
        cursor: 'pointer',
      }}
    >
      {(() => {
        // A video's mediaUrl is an .mp4 — an <img> given that src renders nothing at
        // all (not even a broken-image icon), which is why a scene video showed as a
        // blank card. Show its poster frame instead, same fix DiscoverPage already has.
        const displayUrl = item.isVideo ? item.thumbnailUrl : item.mediaUrl;
        return displayUrl ? (
          <img
            src={displayUrl}
            alt={item.title}
            loading="lazy"
            style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }}
          />
        ) : (
          <div
            style={{
              position: 'absolute',
              inset: 0,
              background: 'linear-gradient(135deg, #d9d4cc 0%, #e2ded6 50%, #cfc9bf 100%)',
            }}
          />
        );
      })()}
      {item.isVideo && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            background: 'rgba(35,31,27,0.15)',
          }}
        >
          <div
            style={{
              width: 44,
              height: 44,
              borderRadius: '50%',
              background: 'rgba(35,31,27,0.55)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Play size={18} fill="#ffffff" color="#ffffff" />
          </div>
        </div>
      )}

      <div style={{ position: 'absolute', top: 10, right: 10, display: 'flex', gap: 6 }}>
        <TileAction label={engagement.isLiked ? 'Unlike' : 'Like'} pressed={engagement.isLiked} onClick={onLike}>
          <Heart
            size={16}
            strokeWidth={2}
            fill={engagement.isLiked ? '#E05252' : 'none'}
            color={engagement.isLiked ? '#E05252' : 'currentColor'}
          />
          {engagement.likeCount > 0 && <span>{engagement.likeCount}</span>}
        </TileAction>
        <TileAction label={engagement.isSaved ? 'Unsave' : 'Save'} pressed={engagement.isSaved} onClick={onSave}>
          <Bookmark size={16} strokeWidth={2} fill={engagement.isSaved ? 'currentColor' : 'none'} />
        </TileAction>
        <TileAction label="More options" onClick={onMore}>
          <MoreHorizontal size={16} strokeWidth={2} />
        </TileAction>
      </div>

      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: 0,
          height: 56,
          background: 'linear-gradient(to top, rgba(35,31,27,0.8), rgba(35,31,27,0))',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: 16,
          right: 16,
          bottom: 8,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          height: 40,
        }}
      >
        <div
          style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0, cursor: 'pointer' }}
          onClick={handleArtistClick}
        >
          {item.authorAvatarUrl ? (
            <img
              src={item.authorAvatarUrl}
              alt={item.artistName}
              style={{ width: 28, height: 28, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }}
            />
          ) : (
            <span
              style={{
                width: 28,
                height: 28,
                borderRadius: '50%',
                flexShrink: 0,
                background: 'var(--cream-cta-fill)',
                color: 'var(--cream-text-inverse)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontFamily: 'var(--font-geist)',
                fontSize: 12,
                fontWeight: 600,
              }}
            >
              {item.artistName ? item.artistName[0] : 'A'}
            </span>
          )}
          <span style={{ minWidth: 0, textAlign: 'left' }}>
            <div
              style={{
                fontFamily: 'var(--font-geist)',
                fontSize: 12,
                color: 'var(--cream-text-inverse)',
                fontWeight: 600,
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {item.artistName}
            </div>
            <div
              style={{
                fontFamily: 'var(--font-geist)',
                fontSize: 11,
                color: 'rgba(250,250,247,0.6)',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {item.medium}
            </div>
          </span>
        </div>
        {item.status && (
          <span
            style={{
              flexShrink: 0,
              display: 'flex',
              alignItems: 'center',
              gap: 4,
              padding: '4px 8px',
              borderRadius: 22,
              background: 'rgba(35,31,27,0.6)',
              color: 'var(--cream-text-inverse)',
              fontSize: 11,
              fontFamily: 'var(--font-geist)',
            }}
          >
            {/* Both statuses use the app's green — filled dot for Available,
                hollow ring for Collected (assets/nav/available_dot.svg /
                collected_mark.svg) — there's no yellow status color in the
                real app. */}
            <NavIcon id={item.status === 'collected' ? 'collectedMark' : 'availableDot'} size={8} color="#00B46D" />
            {STATUS_LABELS[item.status]}
          </span>
        )}
      </div>
    </div>
  );
}
