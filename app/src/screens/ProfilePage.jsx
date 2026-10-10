import React, { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom';
import { Lock, Share, User } from 'lucide-react';
import { useRequireLogin, useSession } from '../lib/session';
import { setFollowing as setFollowingApi, friendlyError } from '../lib/social';
import { getMe, getProfile, isLockedProfile, listProfileItems, listSeries } from '../lib/profileApi';
import { MediaThumb } from '../components/content/FeedCard';
import { ContentActionsMenu } from '../components/moderation/ContentActionsMenu';
import { GuestPrompt, StateMessage } from '../components/common/StateMessage';
import './ProfilePage.css';

const BACK_ICON = '/profile/icon-back.svg';

const EMPTY_COPY = {
  pieces: 'No pieces yet.',
  scenes: 'No scenes yet.',
  series: 'No series yet.',
  collect: 'Nothing for sale right now.',
};

/// 1234 → "1.2k", matching the app's compact counts.
function compact(n) {
  if (n == null) return '–';
  const v = Number(n);
  if (v >= 1_000_000) return `${(v / 1_000_000).toFixed(1).replace(/\.0$/, '')}m`;
  if (v >= 1_000) return `${(v / 1_000).toFixed(1).replace(/\.0$/, '')}k`;
  return String(v);
}

function splitColumns(list) {
  const cols = [[], []];
  list.forEach((entry, i) => cols[i % 2].push(entry));
  return cols;
}

function ItemMasonry({ items, showPrice }) {
  return (
    <div className="profile-masonry">
      {splitColumns(items).map((col, c) => (
        <div key={c} className="profile-masonry-col">
          {col.map((item) => (
            <Link
              key={`${item.type}-${item.id}`}
              to={item.href}
              className="profile-card"
              aria-label={item.title}
            >
              <MediaThumb item={item} rounded={6} />
              {showPrice && (item.isSold || item.priceLabel) && (
                <span className="profile-card-price">{item.isSold ? 'Collected' : item.priceLabel}</span>
              )}
            </Link>
          ))}
        </div>
      ))}
    </div>
  );
}

/// Series cards; tapping opens the series' first piece (the web has no series screen).
function SeriesMasonry({ series }) {
  return (
    <div className="profile-masonry">
      {splitColumns(series).map((col, c) => (
        <div key={c} className="profile-masonry-col">
          {col.map((s) => {
            const first = s.previewPieces?.[0]?.id;
            const cover = s.coverUrl ?? s.previewPieces?.[0]?.mediaUrl;
            const body = (
              <>
                <div className="profile-series-cover">
                  {cover && <img src={cover} alt="" loading="lazy" draggable={false} />}
                </div>
                <p className="profile-series-name">{s.name}</p>
                <p className="profile-series-count">
                  {s.pieceCount} {s.pieceCount === 1 ? 'piece' : 'pieces'}
                </p>
              </>
            );
            return first ? (
              <Link key={s.id} to={`/piece/${first}`} className="profile-series-card">
                {body}
              </Link>
            ) : (
              <div key={s.id} className="profile-series-card">
                {body}
              </div>
            );
          })}
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

const EMPTY_LISTS = { pieces: null, scenes: null, series: null, collect: null };

/// One screen for `/profile` (the viewer's own account) and `/u/:username`
/// (anyone — including the viewer, which is then treated as their own).
export function ProfilePage() {
  const { username: routeUsername } = useParams();
  const navigate = useNavigate();
  const location = useLocation();
  const requireLogin = useRequireLogin();
  const { loggedIn, user: me } = useSession();

  const myUsername = me?.username?.toLowerCase() ?? null;
  const isOwn = !routeUsername || (loggedIn && routeUsername.toLowerCase() === myUsername);
  const lookup = routeUsername ?? me?.username ?? null;

  const [profile, setProfile] = useState(null);
  const [status, setStatus] = useState('loading'); // loading | ready | notfound | error
  const [loadError, setLoadError] = useState(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [lists, setLists] = useState(EMPTY_LISTS);
  const [listErrors, setListErrors] = useState({});
  const [tab, setTab] = useState('pieces');
  const [following, setFollowing] = useState(false);
  const [requested, setRequested] = useState(false);
  const [followBusy, setFollowBusy] = useState(false);
  const [actionError, setActionError] = useState(null);
  const [shareNotice, setShareNotice] = useState(null);

  // Header.
  useEffect(() => {
    if (!routeUsername && !loggedIn) return undefined;
    let cancelled = false;
    setStatus('loading');
    setLoadError(null);
    setProfile(isOwn && me ? me : null);
    (isOwn ? getMe() : getProfile(lookup))
      .then((data) => {
        if (cancelled) return;
        if (data?.redirectToUsername && routeUsername && data.redirectToUsername !== routeUsername) {
          navigate(`/u/${data.redirectToUsername}`, { replace: true });
          return;
        }
        setProfile(data);
        setFollowing(Boolean(data?.isFollowing));
        setRequested(Boolean(data?.followRequestPending));
        setStatus('ready');
      })
      .catch((e) => {
        if (cancelled) return;
        if (e.status === 404) setStatus('notfound');
        else {
          setLoadError(friendlyError(e));
          setStatus('error');
        }
      });
    return () => {
      cancelled = true;
    };
    // `me` is only an instant placeholder for the own profile; refetch on identity change.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lookup, isOwn, loggedIn, reloadKey]);

  const locked = status === 'ready' && !isOwn && isLockedProfile(profile);
  const showCollect = Boolean(profile?.sellerEnabled);
  const profileUsername = profile?.username ?? lookup;

  // Tab content — fetched together so the scenes count is known up front.
  useEffect(() => {
    setLists(EMPTY_LISTS);
    setListErrors({});
    if (status !== 'ready' || locked || !profileUsername) return undefined;
    let cancelled = false;
    const load = (key, promise) =>
      promise
        .then((data) => !cancelled && setLists((prev) => ({ ...prev, [key]: data })))
        .catch((e) => {
          if (cancelled) return;
          setLists((prev) => ({ ...prev, [key]: [] }));
          setListErrors((prev) => ({ ...prev, [key]: friendlyError(e) }));
        });
    load('pieces', listProfileItems(profileUsername, 'pieces', profile));
    load('scenes', listProfileItems(profileUsername, 'scenes', profile));
    load('series', listSeries(profileUsername));
    if (showCollect) load('collect', listProfileItems(profileUsername, 'collect', profile));
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status, locked, profileUsername, showCollect]);

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

  const goBack = () => {
    // A shared link opened in a fresh tab has no in-app history to go back to.
    if (location.key === 'default') navigate('/home');
    else navigate(-1);
  };

  const handleShare = async () => {
    const url = `${window.location.origin}/u/${profileUsername}`;
    try {
      if (navigator.share) {
        await navigator.share({ title: profile?.name ?? profileUsername, url });
        return;
      }
    } catch {
      return; // user cancelled the share sheet
    }
    try {
      await navigator.clipboard.writeText(url);
      setShareNotice('Profile link copied.');
      setTimeout(() => setShareNotice(null), 2000);
    } catch {
      /* clipboard blocked — nothing else to do */
    }
  };

  const toggleFollow = async () => {
    if (!requireLogin() || followBusy) return;
    const wasActive = following || requested;
    setFollowBusy(true);
    setActionError(null);
    try {
      const res = await setFollowingApi(profileUsername, !wasActive);
      const nowFollowing = Boolean(res?.following);
      setFollowing(nowFollowing);
      setRequested(Boolean(res?.requested));
      if (locked && nowFollowing) {
        // Approved instantly (e.g. account went public) — load the full profile.
        setReloadKey((k) => k + 1);
      } else if (!locked && profile?.followersCount != null && nowFollowing !== following) {
        setProfile((p) => ({ ...p, followersCount: Math.max(0, p.followersCount + (nowFollowing ? 1 : -1)) }));
      }
    } catch (e) {
      setActionError(friendlyError(e));
    } finally {
      setFollowBusy(false);
    }
  };

  const openMessage = () => {
    if (!requireLogin()) return;
    navigate(`/messages/${profileUsername}`);
  };

  if (!routeUsername && !loggedIn) {
    return (
      <div className="profile-page">
        <GuestPrompt
          title="Your profile"
          message="Log in to see your pieces, scenes, and saves."
          next="/profile"
        />
      </div>
    );
  }

  if (status === 'notfound') {
    return (
      <div className="profile-page">
        <div className="profile-plain-topbar">
          <button type="button" className="profile-plain-back" aria-label="Back" onClick={goBack}>
            <img src={BACK_ICON} alt="" width={9} height={16.5} />
          </button>
        </div>
        <StateMessage>This account isn't available.</StateMessage>
      </div>
    );
  }

  if (status === 'error' || (status === 'loading' && !profile)) {
    return (
      <div className="profile-page">
        {status === 'error' ? (
          <StateMessage action="Try again" onAction={() => setReloadKey((k) => k + 1)}>
            {loadError}
          </StateMessage>
        ) : (
          <StateMessage>Loading profile…</StateMessage>
        )}
      </div>
    );
  }

  const followLabel = following ? 'Following' : requested ? 'Requested' : 'Follow';
  const activeItems = lists[activeTab];
  const stats = [
    { value: compact(profile.piecesCount), label: 'pieces' },
    { value: compact(lists.scenes?.length), label: 'scenes' },
    { value: compact(profile.savesCount), label: 'saves' },
  ];

  return (
    <div className="profile-page">
      <div className="profile-hero">
        {profile.coverPhotoUrl ? (
          <img className="profile-banner" src={profile.coverPhotoUrl} alt="" draggable={false} />
        ) : (
          <div className="profile-banner profile-banner-empty" />
        )}
        <div className="profile-banner-scrim" />

        <div className="profile-topbar">
          {routeUsername && (
            <button
              type="button"
              className="profile-icon-hit profile-back"
              aria-label="Back"
              onClick={goBack}
            >
              <img src={BACK_ICON} alt="" width={9} height={16.5} />
            </button>
          )}
          <div className="profile-topbar-right">
            <button type="button" className="profile-round-btn" aria-label="Share profile" onClick={handleShare}>
              <Share size={18} />
            </button>
            {!isOwn && (
              <ContentActionsMenu
                target={{ type: 'user', id: profileUsername }}
                authorUsername={profileUsername}
                onBlocked={() => navigate('/home')}
                buttonStyle={{
                  width: 34,
                  height: 34,
                  background: 'rgba(35, 31, 27, 0.32)',
                  color: 'var(--profile-inverse)',
                }}
              />
            )}
          </div>
        </div>

        {profile.profilePhotoUrl ? (
          <img
            className="profile-avatar"
            src={profile.profilePhotoUrl}
            alt={profile.name ?? profileUsername}
            draggable={false}
          />
        ) : (
          <span className="profile-avatar profile-avatar-empty" aria-hidden>
            <User size={40} strokeWidth={1.5} />
          </span>
        )}
      </div>

      <div className="profile-identity">
        <h1 className="profile-name">{profile.name || profileUsername}</h1>
        <div className="profile-handle-block">
          <p className="profile-handle">@{profileUsername}</p>
          {!locked && (
            <p className="profile-follow-line">
              <Link to={`/u/${profileUsername}/followers`}>{compact(profile.followersCount)} followers</Link>
              {' · '}
              <Link to={`/u/${profileUsername}/following`}>{compact(profile.followingCount)} following</Link>
            </p>
          )}
        </div>
      </div>

      {!locked && profile.bio && <p className="profile-bio">{profile.bio}</p>}

      {!locked && (
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
      )}

      <div className="profile-actions">
        {isOwn ? (
          <>
            <button type="button" className="profile-btn profile-btn-message" onClick={() => navigate('/settings/profile')}>
              Edit profile
            </button>
            <button type="button" className="profile-btn profile-btn-message" onClick={() => navigate('/settings')}>
              Settings
            </button>
          </>
        ) : (
          <>
            {!locked && (
              <button type="button" className="profile-btn profile-btn-message" onClick={openMessage}>
                Message
              </button>
            )}
            <button
              type="button"
              className={`profile-btn profile-btn-follow${following || requested ? ' is-following' : ''}`}
              onClick={toggleFollow}
              disabled={followBusy}
            >
              {followLabel}
            </button>
          </>
        )}
      </div>
      {actionError && <p className="profile-error">{actionError}</p>}

      {locked ? (
        <div className="profile-locked">
          <Lock size={22} strokeWidth={1.5} />
          <p className="profile-locked-title">This account is private</p>
          <p className="profile-locked-body">
            {requested
              ? 'Your follow request is pending.'
              : 'Follow this account to see their pieces and scenes.'}
          </p>
        </div>
      ) : (
        <>
          <ProfileTabs tabs={tabs} active={activeTab} onChange={setTab} />
          {activeItems == null ? (
            <p className="profile-empty">Loading…</p>
          ) : listErrors[activeTab] ? (
            <p className="profile-empty">{listErrors[activeTab]}</p>
          ) : activeItems.length === 0 ? (
            <p className="profile-empty">{EMPTY_COPY[activeTab]}</p>
          ) : activeTab === 'series' ? (
            <SeriesMasonry series={activeItems} />
          ) : (
            <ItemMasonry items={activeItems} showPrice={activeTab === 'collect'} />
          )}
        </>
      )}

      {shareNotice && (
        <div className="profile-toast" role="status">
          {shareNotice}
        </div>
      )}
    </div>
  );
}
