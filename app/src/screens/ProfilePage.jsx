import React, { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { Navigate, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { Lock, Share2 } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useBreakpoint } from '../hooks/useBreakpoint';
import { useRequireLogin } from '../hooks/useRequireLogin';
import { InboxRail } from '../components/layout/InboxRail';
import { ContentActionsSheet } from '../components/moderation/ContentActions';
import { useToast } from '../components/common/ActionSheet';
import { friendlyError, setFollowing } from '../services/socialApi';
import { isBlockedAuthor, onAuthorBlocked } from '../services/blockedAuthors';
import { getProfile, listFollows, listUserPieces, listUserPosts, listUserSeries } from '../services/profileApi';
import { contentHref, profileHref } from '../utils/contentLinks';
import './ProfilePage.css';

const RATIO = {
  portrait: '181 / 270',
  square: '1 / 1',
  wide: '181 / 113',
};

/** Backend sends "3:4" / "16:9"; CSS aspect-ratio wants "3 / 4". */
function toRatio(value, fallback) {
  if (!value || typeof value !== 'string') return fallback;
  const m = value.match(/^\s*(\d+(?:\.\d+)?)\s*[:/]\s*(\d+(?:\.\d+)?)\s*$/);
  return m ? `${m[1]} / ${m[2]}` : fallback;
}

function initialOf(name) {
  return (name || '?').trim().charAt(0).toUpperCase() || '?';
}

/// Neutral stand-in when an account has no photo — never a stock image.
function AvatarImage({ src, name, className }) {
  if (src) return <img className={className} src={src} alt={name || ''} draggable={false} />;
  return (
    <span className={`${className} profile-avatar-empty`} aria-label={name || ''}>
      {initialOf(name)}
    </span>
  );
}

function splitIntoColumns(items, count) {
  const columns = Array.from({ length: count }, () => []);
  items.forEach((item, index) => {
    columns[index % count].push(item);
  });
  return columns;
}

function isSoldPiece(piece) {
  return piece.listingState === 'collected' || piece.status === 'sold';
}

function toMasonryColumns(pieces, count) {
  const entries = pieces.map((piece) => ({
    id: piece.id,
    src: piece.images?.[0]?.mediaUrl || piece.mediaUrl || piece.coverUrl || null,
    ratio: toRatio(piece.mediaAspectRatio || piece.images?.[0]?.mediaAspectRatio, RATIO.portrait),
    title: piece.title || 'Untitled',
    priceLabel:
      piece.isForSale && piece.priceCents && !isSoldPiece(piece)
        ? `US$ ${Math.round(piece.priceCents / 100).toLocaleString()}`
        : null,
    isForSale: piece.isForSale,
  }));
  return splitIntoColumns(entries, count);
}

// Chevron SVG helper
function ChevronIcon({ direction = 'down', width = 10, height = 6, color = 'currentColor' }) {
  const rotations = { up: 180, down: 0, left: 90, right: 270 };
  return (
    <svg
      width={width}
      height={height}
      viewBox="0 0 10 6"
      fill="none"
      style={{ transform: `rotate(${rotations[direction]}deg)`, transition: 'transform 0.15s ease' }}
    >
      <path d="M1 1L5 5L9 1" stroke={color} strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

// Back Arrow Icon
function BackIcon({ width = 9, height = 16.5, color = 'currentColor' }) {
  return (
    <svg width={width} height={height} viewBox="0 0 9 17" fill="none">
      <path d="M8.25 1.25L1.25 8.25L8.25 15.25" stroke={color} strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

// More Dots Icon
function MoreIcon({ color = 'currentColor' }) {
  return (
    <svg width="18" height="4" viewBox="0 0 18 4" fill="none">
      <circle cx="2" cy="2" r="2" fill={color} />
      <circle cx="9" cy="2" r="2" fill={color} />
      <circle cx="16" cy="2" r="2" fill={color} />
    </svg>
  );
}

function GridLoading() {
  return (
    <div className="profile-modal-loading">
      <span className="profile-spinner" />
    </div>
  );
}

function GridEmpty({ title, sub }) {
  return (
    <div className="profile-empty">
      <p className="profile-empty-title">{title}</p>
      {sub && <p className="profile-empty-sub">{sub}</p>}
    </div>
  );
}

function MasonryGrid({ columns, onOpen, emptyTitle = 'No pieces yet', emptySub = 'Artwork shared will appear here' }) {
  if (!columns || columns.every((col) => col.length === 0)) {
    return <GridEmpty title={emptyTitle} sub={emptySub} />;
  }

  return (
    <div className="profile-masonry">
      {columns.map((column, i) => (
        <div key={i} className="profile-masonry-col">
          {column.map((item) => (
            <button
              key={item.id || `${item.src}-${item.ratio}`}
              type="button"
              className={`profile-card${item.bordered ? ' is-bordered' : ''}`}
              style={{ aspectRatio: item.ratio, position: 'relative' }}
              aria-label={item.title || 'Artwork'}
              onClick={() => item.id && onOpen?.(item.id)}
            >
              {item.src ? (
                <img src={item.src} alt={item.title || ''} draggable={false} />
              ) : (
                <span className="profile-media-empty" />
              )}
              {item.priceLabel && (
                <span className="profile-card-price">
                  {item.priceLabel}
                </span>
              )}
            </button>
          ))}
        </div>
      ))}
    </div>
  );
}

function ScenesGrid({ scenes, onOpen }) {
  if (!scenes || scenes.length === 0) {
    return <GridEmpty title="No scenes yet" sub="Studio moments and process videos will appear here" />;
  }

  return (
    <div className="profile-scenes-grid">
      {scenes.map((item) => {
        const isVideo = item.mediaType === 'video';
        const still = item.thumbnailUrl || (!isVideo ? item.mediaUrl : null);
        return (
          <div
            key={item.id}
            className="profile-scene-card"
            style={{ aspectRatio: toRatio(item.mediaAspectRatio, RATIO.square) }}
            onClick={() => onOpen?.(item.id)}
            role="button"
            tabIndex={0}
            onKeyDown={(e) => e.key === 'Enter' && onOpen?.(item.id)}
          >
            {still ? (
              <img src={still} alt={item.caption || ''} draggable={false} />
            ) : isVideo && item.mediaUrl ? (
              // No poster frame stored — let the browser pull the first frame.
              <video src={item.mediaUrl} muted playsInline preload="metadata" />
            ) : (
              <span className="profile-media-empty" />
            )}
            {isVideo && (
              <div className="profile-scene-overlay">
                <span className="profile-scene-play">
                  <svg width="12" height="14" viewBox="0 0 12 14" fill="none">
                    <path d="M11 7L1 13V1L11 7Z" fill="#FAF3ED" />
                  </svg>
                </span>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

function SeriesGrid({ series, onOpen }) {
  if (!series || series.length === 0) {
    return <GridEmpty title="No series yet" sub="Curated artwork collections will appear here" />;
  }

  return (
    <div className="profile-series-grid">
      {series.map((item) => {
        const cover = item.coverUrl || item.previewPieces?.[0]?.mediaUrl || item.mediaUrl;
        const count = item.pieceCount ?? item.piecesCount ?? 0;
        return (
          <div key={item.id} className="profile-series-card" onClick={() => onOpen?.(item.id)}>
            <div className="profile-series-deck">
              {cover ? <img src={cover} alt="" draggable={false} /> : <span className="profile-media-empty" />}
            </div>
            <div className="profile-series-info">
              <h4 className="profile-series-title">{item.name || item.title}</h4>
              <p className="profile-series-count">{count} {count === 1 ? 'piece' : 'pieces'}</p>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function ProfileTabs({ tabs, active, onChange, showCollectFilter, collectSegment, onCollectSegmentChange }) {
  const rowRef = useRef(null);
  const labelRefs = useRef({});
  const [indicator, setIndicator] = useState({ left: 10, width: 41 });
  const [collectMenuOpen, setCollectMenuOpen] = useState(false);

  const updateIndicator = useCallback(() => {
    const row = rowRef.current;
    const label = labelRefs.current[active];
    if (!row || !label) return;
    const rowBox = row.getBoundingClientRect();
    const box = label.getBoundingClientRect();
    setIndicator({
      left: box.left - rowBox.left,
      width: box.width,
    });
  }, [active]);

  useLayoutEffect(() => {
    updateIndicator();
    window.addEventListener('resize', updateIndicator);
    return () => window.removeEventListener('resize', updateIndicator);
  }, [updateIndicator, tabs]);

  return (
    <div className="profile-tabs-wrapper">
      <div className="profile-tabs" ref={rowRef} role="tablist" aria-label="Profile content">
        {tabs.map((tab) => {
          const isActive = tab.id === active;
          if (tab.id === 'collect' && showCollectFilter) {
            return (
              <div key={tab.id} className="profile-tab-collect-container">
                <button
                  type="button"
                  role="tab"
                  aria-selected={isActive}
                  className={`profile-tab${isActive ? ' is-active' : ''}`}
                  onClick={() => onChange(tab.id)}
                >
                  <span
                    ref={(node) => {
                      labelRefs.current[tab.id] = node;
                    }}
                  >
                    {tab.label}
                  </span>
                </button>
                <button
                  type="button"
                  className="profile-tab-filter-btn"
                  onClick={() => setCollectMenuOpen((open) => !open)}
                  aria-label="Filter collect tab"
                >
                  <ChevronIcon direction={collectMenuOpen ? 'up' : 'down'} width={8} height={5} color={isActive ? '#231F1B' : '#8C8880'} />
                </button>
                {collectMenuOpen && (
                  <>
                    <div className="profile-menu-backdrop" onClick={() => setCollectMenuOpen(false)} />
                    <div className="profile-collect-menu" role="menu">
                      {['all', 'available', 'sold'].map((seg) => (
                        <button
                          key={seg}
                          type="button"
                          className={`profile-collect-menu-item${collectSegment === seg ? ' is-selected' : ''}`}
                          onClick={() => {
                            onCollectSegmentChange?.(seg);
                            onChange('collect');
                            setCollectMenuOpen(false);
                          }}
                        >
                          {seg.charAt(0).toUpperCase() + seg.slice(1)}
                        </button>
                      ))}
                    </div>
                  </>
                )}
              </div>
            );
          }

          return (
            <button
              key={tab.id}
              type="button"
              role="tab"
              aria-selected={isActive}
              className={`profile-tab${isActive ? ' is-active' : ''}`}
              onClick={() => onChange(tab.id)}
            >
              <span
                ref={(node) => {
                  labelRefs.current[tab.id] = node;
                }}
              >
                {tab.label}
              </span>
            </button>
          );
        })}
        <span
          className="profile-tab-indicator"
          style={{ left: indicator.left, width: indicator.width }}
          aria-hidden
        />
      </div>
    </div>
  );
}

// Followers / Following Modal — cursor-paginated, rows open that profile.
function FollowListModal({ isOpen, onClose, username, initialTab = 'followers', onOpenProfile }) {
  const [activeTab, setActiveTab] = useState(initialTab);
  const [list, setList] = useState([]);
  const [cursor, setCursor] = useState(null);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState(null);
  const [, bump] = useState(0);

  useEffect(() => onAuthorBlocked(() => bump((n) => n + 1)), []);

  useEffect(() => {
    if (!isOpen || !username) return;
    setActiveTab(initialTab);
  }, [isOpen, initialTab, username]);

  useEffect(() => {
    if (!isOpen || !username) return undefined;
    let cancelled = false;
    setLoading(true);
    setError(null);
    setList([]);
    setCursor(null);
    listFollows(username, activeTab)
      .then(({ items, nextCursor }) => {
        if (cancelled) return;
        setList(items);
        setCursor(nextCursor);
      })
      .catch((e) => {
        if (!cancelled) setError(e?.status === 403 ? 'This account is private.' : friendlyError(e));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [isOpen, username, activeTab]);

  const loadMore = async () => {
    if (!cursor || loadingMore) return;
    setLoadingMore(true);
    try {
      const { items, nextCursor } = await listFollows(username, activeTab, cursor);
      setList((prev) => [...prev, ...items]);
      setCursor(nextCursor);
    } catch (e) {
      setError(friendlyError(e));
    } finally {
      setLoadingMore(false);
    }
  };

  if (!isOpen) return null;

  const visible = list.filter((u) => !isBlockedAuthor(u.username));

  return (
    <div className="profile-modal-overlay" onClick={onClose}>
      <div className="profile-modal-box" onClick={(e) => e.stopPropagation()}>
        <div className="profile-modal-header">
          <div className="profile-modal-tabs">
            <button
              type="button"
              className={`profile-modal-tab${activeTab === 'followers' ? ' is-active' : ''}`}
              onClick={() => setActiveTab('followers')}
            >
              Followers
            </button>
            <button
              type="button"
              className={`profile-modal-tab${activeTab === 'following' ? ' is-active' : ''}`}
              onClick={() => setActiveTab('following')}
            >
              Following
            </button>
          </div>
          <button type="button" className="profile-modal-close" onClick={onClose} aria-label="Close">
            &times;
          </button>
        </div>

        <div className="profile-modal-body">
          {loading ? (
            <div className="profile-modal-loading">
              <span className="profile-spinner" />
            </div>
          ) : error && visible.length === 0 ? (
            <p className="profile-modal-empty">{error}</p>
          ) : visible.length === 0 ? (
            <p className="profile-modal-empty">No {activeTab} yet</p>
          ) : (
            <div className="profile-user-list">
              {visible.map((u) => (
                <button
                  key={u.username || u.id}
                  type="button"
                  className="profile-user-row is-clickable"
                  onClick={() => onOpenProfile?.(u.username)}
                >
                  <AvatarImage
                    className="profile-user-avatar"
                    src={u.profilePhotoUrl || u.avatarUrl}
                    name={u.name || u.username}
                  />
                  <div className="profile-user-info">
                    <p className="profile-user-name">{u.name || u.displayName || u.username}</p>
                    <p className="profile-user-handle">@{u.username}</p>
                  </div>
                </button>
              ))}
              {error && <p className="profile-modal-empty">{error}</p>}
              {cursor && (
                <button
                  type="button"
                  className="profile-load-more"
                  onClick={loadMore}
                  disabled={loadingMore}
                >
                  {loadingMore ? 'Loading…' : 'Load more'}
                </button>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function followStateOf(data) {
  if (data?.isFollowing) return 'following';
  if (data?.followRequestPending) return 'requested';
  return 'none';
}

/** The old `?username=` / `?user=` links still work — they redirect to /profile/:username. */
export function ProfilePage() {
  const { username: routeUsername } = useParams();
  const [searchParams] = useSearchParams();
  const legacyUsername = searchParams.get('username') || searchParams.get('user');

  if (!routeUsername && legacyUsername) {
    return <Navigate to={profileHref(legacyUsername)} replace />;
  }
  return <ProfileView key={routeUsername || 'me'} routeUsername={routeUsername} />;
}

function ProfileView({ routeUsername }) {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const requireLogin = useRequireLogin();
  const [toast, showToast] = useToast();

  const { user: currentUser, logout, refreshUser } = useAuth();
  const [otherUser, setOtherUser] = useState(null);
  const [loadingProfile, setLoadingProfile] = useState(false);
  const [profileError, setProfileError] = useState(null); // null | 'unavailable' | message
  const [reloadKey, setReloadKey] = useState(0);
  const [pieces, setPieces] = useState(null);
  const [scenes, setScenes] = useState(null);
  const [series, setSeries] = useState(null);
  const [tab, setTab] = useState('pieces');
  const [collectSegment, setCollectSegment] = useState('all');
  const [menuOpen, setMenuOpen] = useState(false);
  const [actionsOpen, setActionsOpen] = useState(false);
  const [statsPage, setStatsPage] = useState(0); // 0 = pieces/scenes/saves, 1 = available/sold/collected
  const [followBusy, setFollowBusy] = useState(false);
  const [followState, setFollowState] = useState('none'); // none | following | requested
  const [followModalOpen, setFollowModalOpen] = useState(false);
  const [followModalTab, setFollowModalTab] = useState('followers');
  const [, bumpBlocked] = useState(0);

  useEffect(() => onAuthorBlocked(() => bumpBlocked((n) => n + 1)), []);

  const viewingOwnUsername =
    Boolean(routeUsername) &&
    Boolean(currentUser?.username) &&
    routeUsername.toLowerCase() === currentUser.username.toLowerCase();
  /// "See profile as viewer" (settings) opens your own profile the way a signed-out visitor sees it.
  const previewAsViewer = viewingOwnUsername && searchParams.get('view') === 'public';
  const isSelf = !previewAsViewer && (!routeUsername || viewingOwnUsername);
  const targetUsername = isSelf ? currentUser?.username : routeUsername;
  const activeUser = isSelf ? currentUser : otherUser;
  const isLocked = !isSelf && otherUser?.profileVisibility === 'private' && otherUser.followersCount === undefined;
  const blocked = !isSelf && isBlockedAuthor(routeUsername);

  // Own profile: counts on the cached session user go stale after posting/following.
  useEffect(() => {
    if (isSelf) refreshUser?.().catch?.(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSelf]);

  // Someone else's profile (or your own in viewer preview).
  useEffect(() => {
    if (isSelf || !routeUsername) {
      setOtherUser(null);
      return undefined;
    }
    let cancelled = false;
    setLoadingProfile(true);
    setProfileError(null);

    getProfile(routeUsername, { auth: !previewAsViewer })
      .then((data) => {
        if (cancelled || !data) return;
        // Old usernames resolve via history — move to the canonical URL.
        if (data.redirectToUsername && data.redirectToUsername.toLowerCase() !== routeUsername.toLowerCase()) {
          navigate(profileHref(data.redirectToUsername), { replace: true });
          return;
        }
        setOtherUser({
          ...data,
          name: data.name || data.username || routeUsername,
          username: data.username || routeUsername,
        });
        setFollowState(followStateOf(data));
      })
      .catch((e) => {
        if (cancelled) return;
        setOtherUser(null);
        setProfileError(e?.status === 404 ? 'unavailable' : friendlyError(e));
      })
      .finally(() => {
        if (!cancelled) setLoadingProfile(false);
      });
    return () => {
      cancelled = true;
    };
  }, [routeUsername, isSelf, previewAsViewer, reloadKey, navigate]);

  // Pieces, scenes, series — skipped while the account is locked to this viewer.
  const canFetchTabs = isSelf ? Boolean(targetUsername) : Boolean(otherUser) && !isLocked;
  useEffect(() => {
    if (!canFetchTabs || !targetUsername) return undefined;
    const controller = new AbortController();
    const opts = { signal: controller.signal, ...(previewAsViewer ? { auth: false } : {}) };
    setPieces(null);
    setScenes(null);
    setSeries(null);

    const settle = (promise, setter) =>
      promise.then(setter).catch((e) => {
        if (e?.name !== 'AbortError') setter([]);
      });
    settle(listUserPieces(targetUsername, opts), setPieces);
    settle(listUserPosts(targetUsername, opts), setScenes);
    settle(listUserSeries(targetUsername, opts), setSeries);

    return () => controller.abort();
  }, [canFetchTabs, targetUsername, previewAsViewer, reloadKey]);

  const showCollect = !isLocked && Boolean(activeUser?.sellerEnabled || activeUser?.isSeller);
  const tabs = useMemo(
    () => [
      { id: 'pieces', label: 'Pieces' },
      { id: 'scenes', label: 'Scenes' },
      { id: 'series', label: 'Series' },
      ...(showCollect ? [{ id: 'collect', label: 'Collect' }] : []),
    ],
    [showCollect],
  );
  const activeTab = tabs.some((item) => item.id === tab) ? tab : 'pieces';

  const handleToggleFollow = async () => {
    if (!activeUser?.username || followBusy || previewAsViewer) return;
    if (!requireLogin()) return;
    setFollowBusy(true);
    const wasFollowing = followState === 'following';
    try {
      if (followState === 'none') {
        const res = await setFollowing(activeUser.username, true);
        const next = res?.following ? 'following' : res?.requested ? 'requested' : 'none';
        setFollowState(next);
        if (next === 'following') {
          setOtherUser((prev) => (prev && prev.followersCount !== undefined
            ? { ...prev, followersCount: (prev.followersCount || 0) + 1 }
            : prev));
        }
      } else {
        // Unfollow, or withdraw a pending request.
        await setFollowing(activeUser.username, false);
        setFollowState('none');
        if (wasFollowing) {
          setOtherUser((prev) => (prev && prev.followersCount !== undefined
            ? { ...prev, followersCount: Math.max(0, (prev.followersCount || 1) - 1) }
            : prev));
          // Unfollowing a private account takes its content away — reload to show the lock.
          if (activeUser.profileVisibility === 'private') setReloadKey((k) => k + 1);
        }
      }
    } catch (e) {
      showToast(friendlyError(e));
    } finally {
      setFollowBusy(false);
    }
  };

  const shareUrl = activeUser?.username
    ? `${window.location.origin}${profileHref(activeUser.username)}`
    : window.location.href;

  const handleShare = async () => {
    setMenuOpen(false);
    try {
      if (navigator.share) {
        await navigator.share({ title: activeUser?.name, url: shareUrl });
        return;
      }
    } catch {
      return;
    }
    try {
      await navigator.clipboard.writeText(shareUrl);
      showToast('Profile link copied');
    } catch {
      /* clipboard unavailable */
    }
  };

  const handleLogout = async () => {
    setMenuOpen(false);
    await logout();
    navigate('/login', { replace: true });
  };

  const handleMessage = () => {
    if (!activeUser?.username || previewAsViewer) return;
    if (!requireLogin()) return;
    navigate(`/inbox?user=${encodeURIComponent(activeUser.username)}`);
  };

  const openFollowModal = (tabName) => {
    if (isLocked) return;
    setFollowModalTab(tabName);
    setFollowModalOpen(true);
  };

  const { showRail, railLabeled } = useBreakpoint();
  const masonryColumnCount = railLabeled ? 4 : showRail ? 3 : 2;

  const piecesColumns = useMemo(
    () => toMasonryColumns(pieces || [], masonryColumnCount),
    [pieces, masonryColumnCount],
  );

  const forSalePieces = useMemo(() => (pieces || []).filter((p) => p.isForSale || isSoldPiece(p)), [pieces]);
  const filteredCollectPieces = useMemo(() => {
    if (collectSegment === 'available') return forSalePieces.filter((p) => !isSoldPiece(p));
    if (collectSegment === 'sold') return forSalePieces.filter(isSoldPiece);
    return forSalePieces;
  }, [forSalePieces, collectSegment]);

  const collectColumns = useMemo(
    () => toMasonryColumns(filteredCollectPieces, masonryColumnCount),
    [filteredCollectPieces, masonryColumnCount],
  );

  if (loadingProfile || (isSelf && !currentUser)) {
    return (
      <div style={{ minHeight: '80vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <span
          style={{
            width: 24,
            height: 24,
            borderRadius: '50%',
            border: '2px solid var(--cream-divider)',
            borderTopColor: 'var(--cream-cta-fill)',
            animation: 'app-spin 0.7s linear infinite',
          }}
        />
      </div>
    );
  }

  if (blocked || profileError) {
    const unavailable = blocked || profileError === 'unavailable';
    return (
      <div className="profile-page">
        <div className="profile-unavailable">
          <p className="profile-empty-title">
            {unavailable ? "This account isn't available" : "Couldn't load this profile"}
          </p>
          <p className="profile-empty-sub">
            {unavailable ? 'The link may be broken, or the account may have been removed.' : profileError}
          </p>
          <div className="profile-unavailable-actions">
            {!unavailable && (
              <button type="button" className="profile-btn profile-btn-follow" onClick={() => setReloadKey((k) => k + 1)}>
                Try again
              </button>
            )}
            <button type="button" className="profile-btn profile-btn-message" onClick={() => navigate('/home')}>
              Go home
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (!activeUser) return null;
  const userDisplay = activeUser;

  const piecesCount = userDisplay.piecesCount ?? pieces?.length;
  // Page 0 stats (standard)
  const contentStats = [
    { value: isLocked ? '—' : String(piecesCount ?? 0), label: 'pieces' },
    { value: isLocked ? '—' : String(scenes?.length ?? 0), label: 'scenes' },
    { value: isLocked ? '—' : String(userDisplay.savesCount ?? 0), label: 'saves' },
  ];

  // Page 1 stats (seller mode)
  const sellerStats = [
    { value: String(forSalePieces.filter((p) => !isSoldPiece(p)).length), label: 'available' },
    { value: String(forSalePieces.filter(isSoldPiece).length), label: 'sold' },
    { value: String(userDisplay.collectedCount ?? 0), label: 'collected' },
  ];

  const currentStats = showCollect && statsPage === 1 ? sellerStats : contentStats;
  const followLabel = followState === 'following' ? 'Following' : followState === 'requested' ? 'Requested' : 'Follow';
  const banner = userDisplay.coverPhotoUrl || userDisplay.banner?.mediaUrl;

  return (
    <div className="profile-page">
      <div style={{ display: 'flex', gap: 48, maxWidth: railLabeled ? 935 + 320 + 48 : 935, margin: '0 auto' }}>
      <div className="profile-inner" style={{ margin: 0, flex: 1, minWidth: 0 }}>
        {previewAsViewer && (
          <div className="profile-preview-note">
            Previewing your profile as a visitor sees it.{' '}
            <button type="button" onClick={() => navigate('/profile')}>Exit preview</button>
          </div>
        )}
        <div className="profile-hero">
          {banner ? (
            <img className="profile-banner" src={banner} alt="" draggable={false} />
          ) : (
            <span className="profile-banner profile-banner-empty" />
          )}
          <div className="profile-banner-scrim" />

          <div className="profile-topbar">
            {(!isSelf || routeUsername) && (
              <button
                type="button"
                className="profile-icon-hit profile-back"
                aria-label="Back"
                onClick={() => navigate(-1)}
              >
                <BackIcon color="#FAFAF7" />
              </button>
            )}
            <button
              type="button"
              className="profile-icon-hit profile-more"
              aria-label="More options"
              aria-expanded={isSelf ? menuOpen : actionsOpen}
              onClick={() => (isSelf ? setMenuOpen((open) => !open) : setActionsOpen(true))}
            >
              <MoreIcon color="#FAFAF7" />
            </button>
            {isSelf && menuOpen && (
              <>
                <div
                  style={{ position: 'fixed', inset: 0, zIndex: 10 }}
                  onClick={() => setMenuOpen(false)}
                />
                <div className="profile-more-menu" role="menu">
                  <button
                    type="button"
                    role="menuitem"
                    onClick={() => {
                      setMenuOpen(false);
                      navigate('/profile/edit');
                    }}
                  >
                    Edit profile
                  </button>
                  <button type="button" role="menuitem" onClick={handleShare}>
                    Share profile
                  </button>
                  <button type="button" role="menuitem" onClick={handleLogout}>
                    Log out
                  </button>
                </div>
              </>
            )}
          </div>

          <AvatarImage className="profile-avatar" src={userDisplay.profilePhotoUrl} name={userDisplay.name} />
        </div>

        <div className="profile-identity">
          <h1 className="profile-name">{userDisplay.name}</h1>
          <div className="profile-handle-block">
            <p className="profile-handle">@{userDisplay.username}</p>
            {!isLocked && (
              <p className="profile-follow-line">
                <span className="profile-follow-stat" onClick={() => openFollowModal('followers')}>
                  {userDisplay.followersCount ?? 0} followers
                </span>
                {' · '}
                <span className="profile-follow-stat" onClick={() => openFollowModal('following')}>
                  {userDisplay.followingCount ?? 0} following
                </span>
              </p>
            )}
          </div>
          {userDisplay.bio && <p className="profile-bio">{userDisplay.bio}</p>}

          {/* Stats Section with optional Seller Pager */}
          <div className="profile-stats-container">
            {showCollect && (
              <button
                type="button"
                className="profile-stat-chevron"
                onClick={() => setStatsPage((p) => (p === 0 ? 1 : 0))}
                aria-label="Previous stats page"
              >
                <ChevronIcon direction="left" width={8} height={5} color={statsPage === 1 ? '#231F1B' : '#8C8880'} />
              </button>
            )}
            <div className="profile-stats">
              {currentStats.map((stat, i) => (
                <React.Fragment key={stat.label}>
                  {i > 0 && <span className="profile-stat-sep" aria-hidden />}
                  <div className="profile-stat-cell">
                    <span className="profile-stat-val">{stat.value}</span>
                    <span className="profile-stat-lbl">{stat.label}</span>
                  </div>
                </React.Fragment>
              ))}
            </div>
            {showCollect && (
              <button
                type="button"
                className="profile-stat-chevron"
                onClick={() => setStatsPage((p) => (p === 0 ? 1 : 0))}
                aria-label="Next stats page"
              >
                <ChevronIcon direction="right" width={8} height={5} color={statsPage === 0 ? '#231F1B' : '#8C8880'} />
              </button>
            )}
          </div>

          {/* Action Row: Own Profile vs Other Artist */}
          <div className="profile-actions">
            {isSelf ? (
              <button
                type="button"
                className="profile-btn profile-btn-edit"
                onClick={() => navigate('/profile/edit')}
              >
                Edit profile
              </button>
            ) : (
              <>
                {!isLocked && (
                  <button
                    type="button"
                    className="profile-btn profile-btn-message"
                    onClick={handleMessage}
                    disabled={previewAsViewer}
                  >
                    Message
                  </button>
                )}
                <button
                  type="button"
                  className={`profile-btn profile-btn-follow${followState !== 'none' ? ' is-following' : ''}`}
                  onClick={handleToggleFollow}
                  disabled={followBusy || previewAsViewer}
                >
                  {followBusy ? '...' : followLabel}
                </button>
              </>
            )}
          </div>

          {!isLocked && (
            <ProfileTabs
              tabs={tabs}
              active={activeTab}
              onChange={setTab}
              showCollectFilter={showCollect}
              collectSegment={collectSegment}
              onCollectSegmentChange={setCollectSegment}
            />
          )}
        </div>

        {isLocked ? (
          <div className="profile-locked">
            <span className="profile-locked-icon"><Lock size={20} /></span>
            <p className="profile-empty-title">This account is private</p>
            <p className="profile-empty-sub">
              {followState === 'requested'
                ? 'Your follow request is pending. You’ll see their pieces and scenes once they accept.'
                : 'Follow this account to see their pieces, scenes and series.'}
            </p>
          </div>
        ) : (
          <>
            {activeTab === 'pieces' && (pieces === null ? <GridLoading /> : (
              <MasonryGrid columns={piecesColumns} onOpen={(id) => navigate(contentHref({ id, type: 'piece' }))} />
            ))}
            {activeTab === 'scenes' && (scenes === null ? <GridLoading /> : (
              <ScenesGrid scenes={scenes} onOpen={(id) => navigate(contentHref({ id, type: 'post' }))} />
            ))}
            {activeTab === 'series' && (series === null ? <GridLoading /> : (
              <SeriesGrid series={series} onOpen={(id) => navigate(`/series/${id}`)} />
            ))}
            {activeTab === 'collect' && (pieces === null ? <GridLoading /> : (
              <MasonryGrid
                columns={collectColumns}
                onOpen={(id) => navigate(contentHref({ id, type: 'piece' }))}
                emptyTitle={collectSegment === 'sold' ? 'Nothing sold yet' : 'Nothing for sale yet'}
                emptySub="Pieces listed for sale will appear here"
              />
            ))}
          </>
        )}
      </div>
      {railLabeled && <InboxRail />}
      </div>

      <FollowListModal
        isOpen={followModalOpen}
        onClose={() => setFollowModalOpen(false)}
        username={userDisplay.username}
        initialTab={followModalTab}
        onOpenProfile={(username) => {
          setFollowModalOpen(false);
          navigate(profileHref(username));
        }}
      />

      {actionsOpen && !isSelf && (
        <ContentActionsSheet
          target={{ type: 'user', id: userDisplay.username }}
          authorUsername={previewAsViewer ? undefined : userDisplay.username}
          items={[{ label: 'Share profile', icon: <Share2 size={18} />, onClick: handleShare }]}
          onClose={() => setActionsOpen(false)}
          onBlocked={() => navigate('/home')}
          onNotice={showToast}
        />
      )}
      {toast}
    </div>
  );
}
