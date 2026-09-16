import React, { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { apiFetch } from '../services/apiClient';
import { useBreakpoint } from '../hooks/useBreakpoint';
import { InboxRail } from '../components/layout/InboxRail';
import './ProfilePage.css';

const FALLBACK_ASSETS = {
  banner: '/profile/banner.png',
  avatar: '/profile/avatar.jpg',
};

const RATIO = {
  portrait: '181 / 270',
  square: '1 / 1',
  wide: '181 / 113',
};

// Default fallback items for demo fallback if user hasn't posted items yet
const DEMO_SCENE_ITEMS = [
  { id: 's1', src: '/profile/piece-r2.png', title: 'Studio Session', ratio: RATIO.wide, duration: '0:45' },
  { id: 's2', src: '/profile/piece-r1.png', title: 'Process Reel', ratio: RATIO.square, duration: '1:12' },
  { id: 's3', src: '/profile/piece-l2.png', title: 'Exhibition', ratio: RATIO.square, duration: '0:30' },
  { id: 's4', src: '/profile/piece-l1.png', title: 'Painting Details', ratio: RATIO.portrait, duration: '0:58' },
];

function splitIntoColumns(items, count) {
  const columns = Array.from({ length: count }, () => []);
  items.forEach((item, index) => {
    columns[index % count].push(item);
  });
  return columns;
}

function toMasonryColumns(pieces, count) {
  const entries = pieces.map((piece) => ({
    id: piece.id,
    src: piece.mediaUrl || piece.coverUrl || piece.imageUrl || '/profile/piece-r1.png',
    ratio: piece.mediaAspectRatio || RATIO.portrait,
    title: piece.title || 'Untitled',
    priceLabel: piece.isForSale && piece.priceCents ? `US$ ${Math.round(piece.priceCents / 100)}` : null,
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

// Gear Icon for Settings
function GearIcon({ size = 18, color = 'currentColor' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z" />
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

function MasonryGrid({ columns, onOpen }) {
  if (!columns || columns.every((col) => col.length === 0)) {
    return (
      <div className="profile-empty">
        <p className="profile-empty-title">No pieces yet</p>
        <p className="profile-empty-sub">Artwork shared will appear here</p>
      </div>
    );
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
              <img src={item.src} alt={item.title || ''} draggable={false} />
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
  const displayScenes = scenes && scenes.length > 0 ? scenes : DEMO_SCENE_ITEMS;

  return (
    <div className="profile-scenes-grid">
      {displayScenes.map((item) => (
        <div
          key={item.id}
          className="profile-scene-card"
          style={{ aspectRatio: item.ratio || RATIO.square }}
          onClick={() => onOpen?.(item.id)}
        >
          <img src={item.src || item.mediaUrl || item.thumbnailUrl} alt={item.title || ''} draggable={false} />
          <div className="profile-scene-overlay">
            <span className="profile-scene-play">
              <svg width="12" height="14" viewBox="0 0 12 14" fill="none">
                <path d="M11 7L1 13V1L11 7Z" fill="#FAF3ED" />
              </svg>
            </span>
            {item.duration && <span className="profile-scene-duration">{item.duration}</span>}
          </div>
          {item.title && <p className="profile-scene-title">{item.title}</p>}
        </div>
      ))}
    </div>
  );
}

function SeriesGrid({ series, onOpen }) {
  if (!series || series.length === 0) {
    return (
      <div className="profile-empty">
        <p className="profile-empty-title">No series yet</p>
        <p className="profile-empty-sub">Curated artwork collections will appear here</p>
      </div>
    );
  }

  return (
    <div className="profile-series-grid">
      {series.map((item) => (
        <div key={item.id} className="profile-series-card" onClick={() => onOpen?.(item.id)}>
          <div className="profile-series-deck">
            <img src={item.coverUrl || item.mediaUrl || '/profile/piece-r1.png'} alt="" draggable={false} />
          </div>
          <div className="profile-series-info">
            <h4 className="profile-series-title">{item.title || item.name}</h4>
            <p className="profile-series-count">{item.pieceCount || item.piecesCount || 0} pieces</p>
          </div>
        </div>
      ))}
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

// Followers / Following Modal
function FollowListModal({ isOpen, onClose, username, initialTab = 'followers' }) {
  const [activeTab, setActiveTab] = useState(initialTab);
  const [list, setList] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!isOpen || !username) return;
    setActiveTab(initialTab);
  }, [isOpen, initialTab, username]);

  useEffect(() => {
    if (!isOpen || !username) return;
    setLoading(true);
    const endpoint = activeTab === 'followers' ? `/api/users/${username}/followers` : `/api/users/${username}/following`;
    apiFetch(endpoint, { auth: true })
      .then((data) => {
        const items = Array.isArray(data) ? data : data?.items || [];
        setList(items);
      })
      .catch(() => setList([]))
      .finally(() => setLoading(false));
  }, [isOpen, username, activeTab]);

  if (!isOpen) return null;

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
          ) : list.length === 0 ? (
            <p className="profile-modal-empty">No {activeTab} yet</p>
          ) : (
            <div className="profile-user-list">
              {list.map((u) => (
                <div key={u.username || u.id} className="profile-user-row">
                  <img className="profile-user-avatar" src={u.profilePhotoUrl || u.avatarUrl || FALLBACK_ASSETS.avatar} alt="" />
                  <div className="profile-user-info">
                    <p className="profile-user-name">{u.name || u.displayName || u.username}</p>
                    <p className="profile-user-handle">@{u.username}</p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export function ProfilePage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const targetUsername = searchParams.get('username') || searchParams.get('user');

  const { user: currentUser, logout } = useAuth();
  const [otherUser, setOtherUser] = useState(null);
  const [loadingProfile, setLoadingProfile] = useState(false);
  const [pieces, setPieces] = useState(null);
  const [scenes, setScenes] = useState(null);
  const [series, setSeries] = useState(null);
  const [tab, setTab] = useState('pieces');
  const [collectSegment, setCollectSegment] = useState('all');
  const [menuOpen, setMenuOpen] = useState(false);
  const [statsPage, setStatsPage] = useState(0); // 0 = pieces/scenes/saves, 1 = available/collected/rating
  const [followBusy, setFollowBusy] = useState(false);
  const [isFollowing, setIsFollowing] = useState(false);
  const [followModalOpen, setFollowModalOpen] = useState(false);
  const [followModalTab, setFollowModalTab] = useState('followers');

  const isSelf = !targetUsername || (currentUser?.username && targetUsername.toLowerCase() === currentUser.username.toLowerCase());
  const activeUser = isSelf ? currentUser : otherUser;

  // Fetch target user public profile if viewing another artist
  useEffect(() => {
    if (isSelf) {
      setOtherUser(null);
      return;
    }
    if (!targetUsername) return;

    let cancelled = false;
    setLoadingProfile(true);

    apiFetch(`/api/user/${targetUsername}`, { auth: true })
      .then((data) => {
        if (!cancelled && data) {
          setOtherUser({
            ...data,
            name: data.name || data.displayName || targetUsername,
            username: data.username || targetUsername,
            bio: data.bio || '',
            coverPhotoUrl: data.coverPhotoUrl || data.bannerUrl,
            profilePhotoUrl: data.profilePhotoUrl || data.avatarUrl,
            followersCount: data.followersCount ?? 0,
            followingCount: data.followingCount ?? 0,
            isFollowing: data.isFollowing || false,
          });
          setIsFollowing(Boolean(data.isFollowing));
        }
      })
      .catch(() => {
        if (!cancelled) {
          setOtherUser({
            name: targetUsername,
            username: targetUsername,
            bio: 'Artist profile',
            followersCount: 0,
            followingCount: 0,
          });
        }
      })
      .finally(() => {
        if (!cancelled) setLoadingProfile(false);
      });
  }, [targetUsername, isSelf]);

  // Fetch artist pieces, scenes, series
  useEffect(() => {
    const usernameToFetch = isSelf ? currentUser?.username : targetUsername;
    if (!usernameToFetch) return;
    let cancelled = false;

    // Pieces
    apiFetch(`/api/users/${usernameToFetch}/pieces`, { auth: true })
      .then((list) => {
        if (!cancelled) setPieces(Array.isArray(list) ? list : []);
      })
      .catch(() => {
        if (!cancelled) setPieces([]);
      });

    // Scenes
    apiFetch(`/api/users/${usernameToFetch}/posts`, { auth: true })
      .then((list) => {
        if (!cancelled) setScenes(Array.isArray(list) ? list : []);
      })
      .catch(() => {
        if (!cancelled) setScenes([]);
      });

    // Series
    apiFetch(`/api/users/${usernameToFetch}/series`, { auth: true })
      .then((list) => {
        if (!cancelled) setSeries(Array.isArray(list) ? list : []);
      })
      .catch(() => {
        if (!cancelled) setSeries([]);
      });

    return () => {
      cancelled = true;
    };
  }, [currentUser?.username, targetUsername, isSelf]);

  const showCollect = Boolean(activeUser?.isSeller || activeUser?.sellerEnabled);
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
    if (!activeUser?.username || followBusy) return;
    setFollowBusy(true);
    try {
      if (isFollowing) {
        await apiFetch(`/api/users/${activeUser.username}/follow`, { method: 'DELETE', auth: true });
        setIsFollowing(false);
        setOtherUser((prev) => prev ? { ...prev, followersCount: Math.max(0, (prev.followersCount || 1) - 1) } : prev);
      } else {
        await apiFetch(`/api/users/${activeUser.username}/follow`, { method: 'POST', auth: true });
        setIsFollowing(true);
        setOtherUser((prev) => prev ? { ...prev, followersCount: (prev.followersCount || 0) + 1 } : prev);
      }
    } catch {
      /* ignore toggle error */
    } finally {
      setFollowBusy(false);
    }
  };

  const handleShare = async () => {
    setMenuOpen(false);
    const url = activeUser?.username ? `${window.location.origin}/profile?username=${activeUser.username}` : window.location.href;
    try {
      if (navigator.share) {
        await navigator.share({ title: activeUser?.name, url });
        return;
      }
    } catch {
      return;
    }
    try {
      await navigator.clipboard.writeText(url);
    } catch {
      /* ignore */
    }
  };

  const handleLogout = async () => {
    setMenuOpen(false);
    await logout();
    navigate('/login', { replace: true });
  };

  const handleMessage = () => {
    if (activeUser?.username) {
      navigate(`/inbox?user=${activeUser.username}`);
    }
  };

  const openFollowModal = (tabName) => {
    setFollowModalTab(tabName);
    setFollowModalOpen(true);
  };

  const { showRail, railLabeled } = useBreakpoint();
  const masonryColumnCount = railLabeled ? 4 : showRail ? 3 : 2;

  const piecesColumns = useMemo(
    () => toMasonryColumns(pieces || [], masonryColumnCount),
    [pieces, masonryColumnCount],
  );

  const filteredCollectPieces = useMemo(() => {
    const list = pieces || [];
    if (collectSegment === 'available') return list.filter((p) => p.isForSale && p.status !== 'sold');
    if (collectSegment === 'sold') return list.filter((p) => p.status === 'sold');
    return list.filter((p) => p.isForSale);
  }, [pieces, collectSegment]);

  const collectColumns = useMemo(
    () => toMasonryColumns(filteredCollectPieces, masonryColumnCount),
    [filteredCollectPieces, masonryColumnCount],
  );

  if (loadingProfile) {
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

  if (!activeUser && !isSelf) return null;
  const userDisplay = activeUser || { name: targetUsername || 'Artist', username: targetUsername || 'artist' };

  // Page 0 stats (standard)
  const contentStats = [
    { value: String(userDisplay.piecesCount ?? pieces?.length ?? 0), label: 'pieces' },
    { value: String(userDisplay.scenesCount ?? scenes?.length ?? 0), label: 'scenes' },
    { value: String(userDisplay.savesCount ?? 0), label: 'saves' },
  ];

  // Page 1 stats (seller mode)
  const sellerStats = [
    { value: String(userDisplay.availableCount ?? (pieces || []).filter((p) => p.isForSale).length), label: 'available' },
    { value: String(userDisplay.collectedCount ?? 0), label: 'collected' },
    { value: userDisplay.rating ? String(userDisplay.rating) : '—', label: 'rating' },
  ];

  const currentStats = showCollect && statsPage === 1 ? sellerStats : contentStats;

  return (
    <div className="profile-page">
      <div style={{ display: 'flex', gap: 48, maxWidth: railLabeled ? 935 + 320 + 48 : 935, margin: '0 auto' }}>
      <div className="profile-inner" style={{ margin: 0, flex: 1, minWidth: 0 }}>
        <div className="profile-hero">
          <img className="profile-banner" src={userDisplay.coverPhotoUrl || FALLBACK_ASSETS.banner} alt="" draggable={false} />
          <div className="profile-banner-scrim" />

          <div className="profile-topbar">
            {!isSelf && (
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
              aria-expanded={menuOpen}
              onClick={() => setMenuOpen((open) => !open)}
            >
              <MoreIcon color="#FAFAF7" />
            </button>
            {menuOpen && (
              <>
                <div
                  style={{ position: 'fixed', inset: 0, zIndex: 10 }}
                  onClick={() => setMenuOpen(false)}
                />
                <div className="profile-more-menu" role="menu">
                  {isSelf ? (
                    <>
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
                    </>
                  ) : (
                    <>
                      <button type="button" role="menuitem" onClick={handleShare}>
                        Share profile
                      </button>
                      <button
                        type="button"
                        role="menuitem"
                        onClick={() => {
                          setMenuOpen(false);
                          alert(`User @${userDisplay.username} reported/blocked`);
                        }}
                      >
                        Block user
                      </button>
                    </>
                  )}
                </div>
              </>
            )}
          </div>

          <img
            className="profile-avatar"
            src={userDisplay.profilePhotoUrl || FALLBACK_ASSETS.avatar}
            alt={userDisplay.name}
            draggable={false}
          />
        </div>

        <div className="profile-identity">
          <h1 className="profile-name">{userDisplay.name}</h1>
          <div className="profile-handle-block">
            <p className="profile-handle">@{userDisplay.username}</p>
            <p className="profile-follow-line">
              <span className="profile-follow-stat" onClick={() => openFollowModal('followers')}>
                {userDisplay.followersCount ?? 0} followers
              </span>
              {' · '}
              <span className="profile-follow-stat" onClick={() => openFollowModal('following')}>
                {userDisplay.followingCount ?? 0} following
              </span>
            </p>
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
                <button
                  type="button"
                  className="profile-btn profile-btn-message"
                  onClick={handleMessage}
                >
                  Message
                </button>
                <button
                  type="button"
                  className={`profile-btn profile-btn-follow${isFollowing ? ' is-following' : ''}`}
                  onClick={handleToggleFollow}
                  disabled={followBusy}
                >
                  {followBusy ? '...' : isFollowing ? 'Following' : 'Follow'}
                </button>
              </>
            )}
          </div>

          <ProfileTabs
            tabs={tabs}
            active={activeTab}
            onChange={setTab}
            showCollectFilter={showCollect}
            collectSegment={collectSegment}
            onCollectSegmentChange={setCollectSegment}
          />
        </div>

        {activeTab === 'pieces' && (
          <MasonryGrid columns={piecesColumns} onOpen={(id) => navigate(`/piece/${id}`)} />
        )}
        {activeTab === 'scenes' && (
          <ScenesGrid scenes={scenes} onOpen={(id) => navigate(`/post`)} />
        )}
        {activeTab === 'series' && (
          <SeriesGrid series={series} onOpen={(id) => navigate(`/series/${id}`)} />
        )}
        {activeTab === 'collect' && (
          <MasonryGrid columns={collectColumns} onOpen={(id) => navigate(`/piece/${id}`)} />
        )}
      </div>
      {railLabeled && <InboxRail />}
      </div>

      <FollowListModal
        isOpen={followModalOpen}
        onClose={() => setFollowModalOpen(false)}
        username={userDisplay.username}
        initialTab={followModalTab}
      />
    </div>
  );
}

