import React, { useCallback, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './ProfilePage.css';

const ASSETS = {
  banner: '/profile/banner.png',
  avatar: '/profile/avatar.jpg',
  back: '/profile/icon-back.svg',
  more: '/profile/icon-more.svg',
};

/** Viewer non-seller artist from Figma 2650:1892. Set `isSeller` to show Collect. */
const DEFAULT_PROFILE = {
  isSeller: false,
  name: 'Sarah Osmei',
  handle: '@sarahsunnyart',
  followers: '100',
  following: '60',
  bio: "I'm Sarah Olson, an artist based in Dallas, TX. My paintings reflect the beauty of the natural world.",
  stats: [
    { value: '24', label: 'pieces' },
    { value: '15', label: 'scenes' },
    { value: '1.2k', label: 'saves' },
  ],
};

const RATIO = {
  portrait: '181 / 270',
  square: '1 / 1',
  wide: '181 / 113',
};

const PIECES = {
  left: [
    { src: '/profile/piece-l1.png', ratio: RATIO.portrait },
    { src: '/profile/piece-l2.png', ratio: RATIO.square },
    { src: '/profile/piece-l3.png', ratio: RATIO.square },
    { src: '/profile/piece-l4.png', ratio: RATIO.portrait },
  ],
  right: [
    { src: '/profile/piece-r1.png', ratio: RATIO.square },
    { src: '/profile/piece-r2.png', ratio: RATIO.wide },
    { src: '/profile/piece-r3.png', ratio: RATIO.portrait, bordered: true },
    { src: '/profile/piece-r4.png', ratio: RATIO.wide },
    { src: '/profile/piece-r5.png', ratio: RATIO.portrait },
  ],
};

const SCENES = {
  left: [
    { src: '/profile/piece-r2.png', ratio: RATIO.wide },
    { src: '/profile/piece-l2.png', ratio: RATIO.square },
    { src: '/profile/piece-r4.png', ratio: RATIO.wide },
    { src: '/profile/piece-l3.png', ratio: RATIO.square },
  ],
  right: [
    { src: '/profile/piece-r1.png', ratio: RATIO.square },
    { src: '/profile/piece-l1.png', ratio: RATIO.portrait },
    { src: '/profile/piece-r5.png', ratio: RATIO.portrait },
  ],
};

const SERIES = {
  left: [
    { src: '/profile/piece-l1.png', ratio: RATIO.portrait },
    { src: '/profile/piece-l4.png', ratio: RATIO.portrait },
  ],
  right: [
    { src: '/profile/piece-r3.png', ratio: RATIO.portrait },
    { src: '/profile/piece-r5.png', ratio: RATIO.portrait },
  ],
};

const COLLECT = {
  left: [
    { src: '/profile/piece-l2.png', ratio: RATIO.square },
    { src: '/profile/piece-l3.png', ratio: RATIO.square },
    { src: '/profile/piece-r1.png', ratio: RATIO.square },
  ],
  right: [
    { src: '/profile/piece-r3.png', ratio: RATIO.square },
    { src: '/profile/piece-l1.png', ratio: RATIO.square },
    { src: '/profile/piece-r5.png', ratio: RATIO.square },
  ],
};

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
              style={{ aspectRatio: item.ratio }}
              aria-label="Artwork"
            >
              <img src={item.src} alt="" draggable={false} />
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

/**
 * @param {object} [props]
 * @param {boolean} [props.isSeller] — sellers also get a Collect tab
 * @param {typeof DEFAULT_PROFILE} [props.profile]
 */
export function ProfilePage({ isSeller = false, profile = DEFAULT_PROFILE } = {}) {
  const navigate = useNavigate();
  const showCollect = Boolean(isSeller || profile.isSeller);
  const [tab, setTab] = useState('pieces');
  const [following, setFollowing] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

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
    const url = window.location.href;
    try {
      if (navigator.share) {
        await navigator.share({ title: profile.name, url });
        return;
      }
    } catch {
      /* user cancelled */
      return;
    }
    try {
      await navigator.clipboard.writeText(url);
    } catch {
      /* ignore */
    }
  };

  const grid =
    activeTab === 'scenes'
      ? SCENES
      : activeTab === 'series'
        ? SERIES
        : activeTab === 'collect'
          ? COLLECT
          : PIECES;

  return (
    <div className="profile-page">
      <div className="profile-hero">
        <img className="profile-banner" src={ASSETS.banner} alt="" draggable={false} />
        <div className="profile-banner-scrim" />

        <div className="profile-topbar">
          <button
            type="button"
            className="profile-icon-hit profile-back"
            aria-label="Back"
            onClick={() => navigate(-1)}
          >
            <img src={ASSETS.back} alt="" width={9} height={16.5} />
          </button>
          <button
            type="button"
            className="profile-icon-hit profile-more"
            aria-label="More options"
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen((open) => !open)}
          >
            <img src={ASSETS.more} alt="" width={16} height={2.4} />
          </button>
          {menuOpen && (
            <>
              <div
                style={{ position: 'fixed', inset: 0, zIndex: 3 }}
                onClick={() => setMenuOpen(false)}
              />
              <div className="profile-more-menu" role="menu">
                <button type="button" role="menuitem" onClick={handleShare}>
                  Share profile
                </button>
                <button
                  type="button"
                  role="menuitem"
                  onClick={() => {
                    setMenuOpen(false);
                    navigate('/chat');
                  }}
                >
                  Message
                </button>
              </div>
            </>
          )}
        </div>

        <img
          className="profile-avatar"
          src={ASSETS.avatar}
          alt={profile.name}
          draggable={false}
        />
      </div>

      <div className="profile-identity">
        <h1 className="profile-name">{profile.name}</h1>
        <div className="profile-handle-block">
          <p className="profile-handle">{profile.handle}</p>
          <p className="profile-follow-line">
            {profile.followers} followers · {profile.following} following
          </p>
        </div>
      </div>

      <p className="profile-bio">{profile.bio}</p>

      <div className="profile-stats">
        {profile.stats.map((stat, index) => (
          <React.Fragment key={stat.label}>
            {index > 0 && <div className="profile-stat-divider" />}
            <div className="profile-stat">
              <p className="profile-stat-value">{stat.value}</p>
              <p className="profile-stat-label">{stat.label}</p>
            </div>
          </React.Fragment>
        ))}
      </div>

      <div className="profile-actions">
        <button
          type="button"
          className="profile-btn profile-btn-message"
          onClick={() => navigate('/chat')}
        >
          Message
        </button>
        <button
          type="button"
          className={`profile-btn profile-btn-follow${following ? ' is-following' : ''}`}
          onClick={() => setFollowing((value) => !value)}
        >
          {following ? 'Following' : 'Follow'}
        </button>
      </div>

      <ProfileTabs tabs={tabs} active={activeTab} onChange={setTab} />

      {grid.left.length === 0 && grid.right.length === 0 ? (
        <p className="profile-empty">Nothing here yet.</p>
      ) : (
        <MasonryGrid columns={grid} />
      )}
    </div>
  );
}
