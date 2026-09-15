import React, { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { apiFetch } from '../services/apiClient';
import './ProfilePage.css';

const FALLBACK_ASSETS = {
  banner: '/profile/banner.png',
  avatar: '/profile/avatar.jpg',
};
const ICONS = {
  back: '/profile/icon-back.svg',
  more: '/profile/icon-more.svg',
};

const RATIO = {
  portrait: '181 / 270',
  square: '1 / 1',
  wide: '181 / 113',
};

// Scenes/Series aren't wired to a real endpoint yet (time-boxed for this pass — see
// GET /api/users/:username/posts and /series for the real data once that's worth doing).
const SCENES = {
  left: [
    { src: '/profile/piece-r2.png', ratio: RATIO.wide },
    { src: '/profile/piece-l2.png', ratio: RATIO.square },
  ],
  right: [
    { src: '/profile/piece-r1.png', ratio: RATIO.square },
    { src: '/profile/piece-l1.png', ratio: RATIO.portrait },
  ],
};
const SERIES = { left: [], right: [] };

/** Splits a flat, newest-first piece list into the two masonry columns (alternating by
 * index), same visual pattern as the original Figma-derived mock columns. */
function toMasonryColumns(pieces) {
  const left = [];
  const right = [];
  pieces.forEach((piece, index) => {
    const entry = {
      src: piece.mediaUrl,
      ratio: piece.mediaAspectRatio || RATIO.portrait,
      priceLabel: piece.isForSale && piece.priceCents ? `US$ ${Math.round(piece.priceCents / 100)}` : null,
    };
    (index % 2 === 0 ? left : right).push(entry);
  });
  return { left, right };
}

function MasonryGrid({ columns }) {
  return (
    <div className="profile-masonry">
      {['left', 'right'].map((side) => (
        <div key={side} className="profile-masonry-col">
          {(columns[side] || []).map((item) => (
            <button
              key={`${side}-${item.src}-${item.ratio}`}
              type="button"
              className={`profile-card${item.bordered ? ' is-bordered' : ''}`}
              style={{ aspectRatio: item.ratio, position: 'relative' }}
              aria-label="Artwork"
            >
              <img src={item.src} alt="" draggable={false} />
              {item.priceLabel && (
                <span
                  style={{
                    position: 'absolute',
                    left: 6,
                    bottom: 6,
                    padding: '3px 8px',
                    borderRadius: 6,
                    background: 'rgba(35,31,27,0.65)',
                    color: '#fafaf7',
                    fontSize: 11,
                    fontWeight: 600,
                    fontFamily: 'var(--font-geist)',
                  }}
                >
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

function ProfileTabs({ tabs, active, onChange }) {
  const rowRef = useRef(null);
  const labelRefs = useRef({});
  const [indicator, setIndicator] = useState({ left: 10, width: 41 });

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
    <div className="profile-tabs" ref={rowRef} role="tablist" aria-label="Profile content">
      {tabs.map((tab) => {
        const isActive = tab.id === active;
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
  );
}

/** The logged-in user's own profile — real data from GET /api/user/me + their pieces. */
export function ProfilePage() {
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const [pieces, setPieces] = useState(null);
  const [tab, setTab] = useState('pieces');
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    if (!user?.username) return;
    let cancelled = false;
    apiFetch(`/api/users/${user.username}/pieces`, { auth: true })
      .then((list) => {
        if (!cancelled) setPieces(Array.isArray(list) ? list : []);
      })
      .catch(() => {
        if (!cancelled) setPieces([]);
      });
    return () => {
      cancelled = true;
    };
  }, [user?.username]);

  const showCollect = Boolean(user?.isSeller || user?.sellerEnabled);
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

  const handleShare = async () => {
    setMenuOpen(false);
    const url = user?.username ? `${window.location.origin}/profile` : window.location.href;
    try {
      if (navigator.share) {
        await navigator.share({ title: user?.name, url });
        return;
      }
    } catch {
      return; // user cancelled the native share sheet
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

  const piecesColumns = useMemo(() => toMasonryColumns(pieces || []), [pieces]);
  const grid = activeTab === 'scenes' ? SCENES : activeTab === 'series' ? SERIES : activeTab === 'pieces' ? piecesColumns : { left: [], right: [] };

  if (!user) return null;

  const stats = [
    { value: String(user.piecesCount ?? 0), label: 'pieces' },
    { value: String(user.savesCount ?? 0), label: 'saves' },
    { value: String(user.collectedCount ?? 0), label: 'collected' },
  ];

  return (
    <div className="profile-page">
      <div className="profile-hero">
        <img className="profile-banner" src={user.coverPhotoUrl || FALLBACK_ASSETS.banner} alt="" draggable={false} />
        <div className="profile-banner-scrim" />

        <div className="profile-topbar">
          <button
            type="button"
            className="profile-icon-hit profile-back"
            aria-label="Back"
            onClick={() => navigate(-1)}
          >
            <img src={ICONS.back} alt="" width={9} height={16.5} />
          </button>
          <button
            type="button"
            className="profile-icon-hit profile-more"
            aria-label="More options"
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen((open) => !open)}
          >
            <img src={ICONS.more} alt="" width={16} height={2.4} />
          </button>
          {menuOpen && (
            <>
              <div
                style={{ position: 'absolute', inset: 0, zIndex: 3 }}
                onClick={() => setMenuOpen(false)}
              />
              <div className="profile-more-menu" role="menu">
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

        <img
          className="profile-avatar"
          src={user.profilePhotoUrl || FALLBACK_ASSETS.avatar}
          alt={user.name}
          draggable={false}
        />
      </div>

      <div className="profile-identity">
        <h1 className="profile-name">{user.name}</h1>
        <div className="profile-handle-block">
          <p className="profile-handle">@{user.username}</p>
          <p className="profile-follow-line">
            {user.followersCount ?? 0} followers · {user.followingCount ?? 0} following
          </p>
        </div>
      </div>

      {user.bio && <p className="profile-bio">{user.bio}</p>}

      <div className="profile-stats">
        {stats.map((stat, index) => (
          <React.Fragment key={stat.label}>
            {index > 0 && <div className="profile-stat-divider" />}
            <div className="profile-stat">
              <p className="profile-stat-value">{stat.value}</p>
              <p className="profile-stat-label">{stat.label}</p>
            </div>
          </React.Fragment>
        ))}
      </div>

      <ProfileTabs tabs={tabs} active={activeTab} onChange={setTab} />

      {pieces === null && activeTab === 'pieces' ? (
        <p className="profile-empty">Loading…</p>
      ) : grid.left.length === 0 && grid.right.length === 0 ? (
        <p className="profile-empty">Nothing here yet.</p>
      ) : (
        <MasonryGrid columns={grid} />
      )}
    </div>
  );
}
