import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';

import { useAuth } from '../context/AuthContext';
import { apiFetch, APP_BASE_URL } from '../services/apiClient';
import './PieceDetailPage.css';

import heroBack from '../assets/piece/hero_back.svg';
import heroBookmark from '../assets/piece/hero_bookmark.svg';
import heroBookmarkFill from '../assets/piece/hero_bookmark_fill.svg';
import heroShare from '../assets/piece/hero_share.svg';
import heroMore from '../assets/piece/hero_more.svg';
import detailsChevron from '../assets/piece/details_chevron.svg';
import seriesChevron from '../assets/piece/series_chevron.svg';
import messageBtn from '../assets/piece/message_btn.svg';
import likeHeart from '../assets/piece/like_heart.svg';

function formatUsd(cents) {
  if (cents == null) return '—';
  const dollars = cents / 100;
  const whole = Math.trunc(dollars);
  const frac = Math.abs(cents) % 100;
  const wholeStr = Math.abs(whole).toLocaleString();
  const signed = whole < 0 ? '-' : '';
  if (frac === 0) return `US$ ${signed}${wholeStr}`;
  return `US$ ${signed}${wholeStr}.${String(frac).padStart(2, '0')}`;
}

function formatTimeRemaining(iso) {
  if (!iso) return null;
  const diff = new Date(iso).getTime() - Date.now();
  if (diff <= 0) return null;
  const days = Math.floor(diff / 86400000);
  const hours = Math.floor((diff % 86400000) / 3600000);
  if (days > 0) return `${days}d ${hours}h`;
  const minutes = Math.floor((diff % 3600000) / 60000);
  if (hours > 0) return `${hours}h ${minutes}m`;
  return minutes > 0 ? `${minutes}m` : 'Ending soon';
}

function asList(payload) {
  if (Array.isArray(payload)) return payload;
  if (payload && typeof payload === 'object') {
    for (const key of ['items', 'posts', 'results']) {
      if (Array.isArray(payload[key])) return payload[key];
    }
  }
  return [];
}

function isVideoMedia(mediaType, mediaUrl) {
  const type = (mediaType || '').toLowerCase();
  if (type !== 'video' && type !== 'reel' && type !== 'reels') return false;
  if (!mediaUrl) return true;
  const ext = mediaUrl.split('?')[0].split('.').pop()?.toLowerCase();
  return !['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif'].includes(ext);
}

function dash(value) {
  const text = (value ?? '').toString().trim();
  return text || '—';
}

function statusLabel(status) {
  switch (status) {
    case 'sold':
      return 'Sold';
    case 'reserved':
      return 'Reserved';
    case 'delisted':
      return 'Not for sale';
    case 'auction_won':
      return 'Auction ended';
    default:
      return 'Unavailable';
  }
}

function galleryUrls(piece) {
  const images = Array.isArray(piece.images) ? [...piece.images] : [];
  images.sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
  const urls = images.map((img) => img.mediaUrl).filter(Boolean);
  if (urls.length) return urls;
  return piece.mediaUrl ? [piece.mediaUrl] : [];
}

export function PieceDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { user, status } = useAuth();
  const authenticated = status === 'authenticated';

  const [piece, setPiece] = useState(null);
  const [scenes, setScenes] = useState([]);
  const [error, setError] = useState(false);
  const [loading, setLoading] = useState(true);
  const [imageIndex, setImageIndex] = useState(0);
  const [detailsOpen, setDetailsOpen] = useState(true);
  const [materialsOpen, setMaterialsOpen] = useState(false);
  const [moreOpen, setMoreOpen] = useState(false);
  const [toast, setToast] = useState(null);
  const [saved, setSaved] = useState(false);
  const [liked, setLiked] = useState(false);
  const [followState, setFollowState] = useState('none');
  const [followBusy, setFollowBusy] = useState(false);
  const [burst, setBurst] = useState(false);
  const lastTap = useRef(0);
  const touchX = useRef(null);
  const toastTimer = useRef(null);

  const showToast = useCallback((text) => {
    setToast(text);
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 1800);
  }, []);

  useEffect(() => () => clearTimeout(toastTimer.current), []);

  useEffect(() => {
    if (status === 'loading') return undefined;
    let cancelled = false;
    setLoading(true);
    setError(false);
    setImageIndex(0);

    (async () => {
      try {
        const json = await apiFetch(`/api/pieces/${id}`, { auth: authenticated });
        if (cancelled) return;
        setPiece(json);
        setSaved(Boolean(json.isSaved));
        setLiked(Boolean(json.isLiked));
        setFollowState(json.author?.isFollowing || json.authorIsFollowing ? 'following' : 'none');
      } catch {
        if (!cancelled) setError(true);
      } finally {
        if (!cancelled) setLoading(false);
      }

      try {
        const related = await apiFetch(`/api/pieces/${id}/related-posts`, { auth: authenticated });
        if (!cancelled) setScenes(asList(related));
      } catch {
        if (!cancelled) setScenes([]);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [id, status, authenticated]);

  const urls = useMemo(() => (piece ? galleryUrls(piece) : []), [piece]);
  const author = piece?.author ?? {};
  const authorName = author.name || piece?.authorName || 'Artist';
  const authorHandle = (author.username || piece?.authorUsername || '').replace(/^@/, '');
  const avatarUrl = author.profilePhotoUrl || piece?.authorAvatarUrl;
  const viewerHandle = (user?.username || '').toLowerCase();
  const isOwner = Boolean(viewerHandle && authorHandle && viewerHandle === authorHandle.toLowerCase());
  const showFollow = Boolean(authorHandle) && !isOwner;
  const appHref = `studio3://piece/${id}`;
  const webHref = `${APP_BASE_URL}/piece/${id}`;

  const metaLine = useMemo(() => {
    if (!piece) return '';
    const parts = [
      (piece.medium || '').trim(),
      ...(Array.isArray(piece.styleTags) ? piece.styleTags : []),
    ].filter(Boolean);
    return parts.join(' · ');
  }, [piece]);

  const series = piece?.series;
  const seriesThumbs = (
    series?.previewPieces?.map((p) => p.mediaUrl)
    || series?.pieces?.map((p) => p.mediaUrl)
    || []
  ).filter(Boolean);
  const story = (piece?.caption || '').trim();
  const isAuction = piece?.listingType === 'auction';
  const isLive = !piece?.status || piece.status === 'live';
  const isAuctionWonByMe = piece?.status === 'auction_won' && piece?.isHighestBidder;
  const showCollect = Boolean(piece?.isForSale);
  const timeRemaining = formatTimeRemaining(piece?.auctionEndsAt);

  const goBack = () => {
    if (window.history.length > 1) navigate(-1);
    else navigate(authenticated ? '/home' : '/login');
  };

  const requireAuth = () => {
    navigate('/login', { state: { from: { pathname: `/piece/${id}` } } });
  };

  const toggleSave = async () => {
    if (!authenticated) return requireAuth();
    const next = !saved;
    setSaved(next);
    try {
      await apiFetch(`/api/pieces/${id}/save`, { method: next ? 'POST' : 'DELETE', auth: true });
      showToast(next ? 'Saved' : 'Removed from saved');
    } catch {
      setSaved(!next);
      showToast('Could not update save');
    }
  };

  const likePiece = async () => {
    if (!authenticated) return requireAuth();
    if (liked) return;
    setLiked(true);
    setBurst(true);
    setTimeout(() => setBurst(false), 700);
    try {
      await apiFetch(`/api/pieces/${id}/like`, { method: 'POST', auth: true });
    } catch {
      setLiked(false);
    }
  };

  const onMediaTap = () => {
    const now = Date.now();
    if (now - lastTap.current < 280) {
      lastTap.current = 0;
      likePiece();
      return;
    }
    lastTap.current = now;
  };

  const shiftImage = (delta) => {
    setImageIndex((i) => Math.min(urls.length - 1, Math.max(0, i + delta)));
  };

  const toggleFollow = async () => {
    if (!authenticated) return requireAuth();
    if (followBusy || !authorHandle) return;
    const wasFollowing = followState !== 'none';
    setFollowBusy(true);
    try {
      if (wasFollowing) {
        await apiFetch(`/api/users/${authorHandle}/follow`, { method: 'DELETE', auth: true });
        setFollowState('none');
      } else {
        const result = await apiFetch(`/api/users/${authorHandle}/follow`, { method: 'POST', auth: true });
        setFollowState(result?.following ? 'following' : result?.requested ? 'pending' : 'none');
      }
    } catch {
      showToast('Something went wrong');
    } finally {
      setFollowBusy(false);
    }
  };

  const copyLink = async () => {
    const text = `${piece?.title || 'Piece'} by ${authorName} on Studio\n\n${webHref}`;
    try {
      if (navigator.share) {
        await navigator.share({ title: piece?.title || 'Studio 3', text, url: webHref });
      } else {
        await navigator.clipboard.writeText(text);
        showToast('Link copied');
      }
    } catch (err) {
      if (err?.name === 'AbortError') return;
      try {
        await navigator.clipboard.writeText(webHref);
        showToast('Link copied');
      } catch {
        showToast('Could not copy link');
      }
    }
    setMoreOpen(false);
  };

  if (status === 'loading' || loading) {
    return <StateScreen text="Loading…" />;
  }
  if (error || !piece) {
    return <StateScreen text="This piece couldn't be found." />;
  }

  const collectLabel = isAuction
    ? (isLive ? 'Place a bid' : (isAuctionWonByMe ? 'Complete purchase' : statusLabel(piece.status)))
    : (isLive ? 'Collect' : statusLabel(piece.status));
  const collectEnabled = isAuction ? (isLive || isAuctionWonByMe) : isLive;
  const followLabel = followState === 'following' ? 'Following' : followState === 'pending' ? 'Requested' : 'Follow';

  return (
    <div className="piece-detail-page">
      <div className="piece-detail-card">
        <div
          className="piece-detail-media"
          onClick={onMediaTap}
          onTouchStart={(e) => {
            touchX.current = e.changedTouches[0].clientX;
          }}
          onTouchEnd={(e) => {
            if (touchX.current == null) return;
            const dx = e.changedTouches[0].clientX - touchX.current;
            touchX.current = null;
            if (Math.abs(dx) < 48) return;
            shiftImage(dx < 0 ? 1 : -1);
          }}
        >
          <div
            className="piece-detail-carousel"
            style={{ transform: `translateX(-${imageIndex * 100}%)` }}
          >
            {urls.length ? urls.map((url) => (
              <img key={url} className="piece-detail-slide" src={url} alt={piece.title || ''} />
            )) : (
              <div className="piece-detail-slide" />
            )}
          </div>

          {urls.length > 1 && (
            <>
              {imageIndex > 0 && (
                <button
                  type="button"
                  className="piece-detail-nav is-prev"
                  aria-label="Previous image"
                  onClick={(e) => {
                    e.stopPropagation();
                    shiftImage(-1);
                  }}
                >
                  ‹
                </button>
              )}
              {imageIndex < urls.length - 1 && (
                <button
                  type="button"
                  className="piece-detail-nav is-next"
                  aria-label="Next image"
                  onClick={(e) => {
                    e.stopPropagation();
                    shiftImage(1);
                  }}
                >
                  ›
                </button>
              )}
              <div className="piece-detail-dots">
                {urls.map((url, i) => (
                  <span key={url} className={`piece-detail-dot${i === imageIndex ? ' is-active' : ''}`} />
                ))}
              </div>
            </>
          )}

          <div className="piece-detail-overlay" onClick={(e) => e.stopPropagation()}>
            <button type="button" className="piece-detail-overlay-hit" style={{ width: 24 }} aria-label="Back" onClick={goBack}>
              <img src={heroBack} alt="" width={11} height={20} />
            </button>
            <div className="piece-detail-overlay-actions">
              <button type="button" className="piece-detail-overlay-hit" style={{ width: 32 }} aria-label={saved ? 'Unsave' : 'Save'} onClick={toggleSave}>
                <img src={saved ? heroBookmarkFill : heroBookmark} alt="" width={16} height={20} />
              </button>
              <button type="button" className="piece-detail-overlay-hit" style={{ width: 32 }} aria-label="Share" onClick={copyLink}>
                <img src={heroShare} alt="" width={18} height={22} />
              </button>
              <button type="button" className="piece-detail-overlay-hit" style={{ width: 28 }} aria-label="More" onClick={() => setMoreOpen(true)}>
                <img src={heroMore} alt="" width={21} height={4} />
              </button>
            </div>
          </div>

          {burst && (
            <div className="piece-detail-heart">
              <img src={likeHeart} alt="" width={80} height={73} />
            </div>
          )}
        </div>

        <div className="piece-detail-panel">
          <div className="piece-detail-artist">
            <div
              style={{ display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer', minWidth: 0, flex: 1 }}
              onClick={() => authorHandle && navigate(`/profile?username=${encodeURIComponent(authorHandle)}`)}
            >
              {avatarUrl ? (
                <img className="piece-detail-avatar" src={avatarUrl} alt={authorName} />
              ) : (
                <span className="piece-detail-avatar is-fallback">{authorName.slice(0, 1)}</span>
              )}
              <div className="piece-detail-artist-text">
                <div className="piece-detail-artist-name">{authorName}</div>
                <div className="piece-detail-artist-handle">@{authorHandle || 'artist'}</div>
              </div>
            </div>
            {showFollow && (
              <button
                type="button"
                className={`piece-detail-follow${followState === 'pending' ? ' is-pending' : ''}`}
                onClick={toggleFollow}
                disabled={followBusy}
              >
                {followBusy ? '…' : followLabel}
              </button>
            )}
          </div>

          <div className="piece-detail-scroll">
            <div className="piece-detail-title-block">
              <h1 className="piece-detail-title">{piece.title}</h1>
              {metaLine ? <p className="piece-detail-meta">{metaLine}</p> : null}
              {piece.dimensions ? <p className="piece-detail-dimensions">{piece.dimensions}</p> : null}
              <button type="button" className="piece-detail-materials" onClick={() => setMaterialsOpen(true)}>
                View Materials →
              </button>
            </div>

            <div className="piece-detail-details">
              <button type="button" className="piece-detail-details-toggle" onClick={() => setDetailsOpen((open) => !open)}>
                <span>Details</span>
                <img src={detailsChevron} alt="" width={8} height={4} className={detailsOpen ? 'is-open' : ''} />
              </button>
              {detailsOpen && (
                <>
                  <DetailRow label="Location" value={dash(piece.location)} />
                  <DetailRow label="Year created" value={piece.yearCreated != null ? String(piece.yearCreated) : '—'} />
                  <DetailRow label="Framing/mounting" value={dash(piece.framingMounting)} />
                  <DetailRow
                    label="Shipping"
                    value={piece.location?.trim() ? `Ships from ${piece.location.trim()}` : dash(piece.shippingRegion)}
                  />
                  <DetailRow label="Handling" value={dash(piece.handlingNotes)} />
                </>
              )}
            </div>

            {(story || scenes.length > 0 || (series?.name && seriesThumbs.length > 0)) && (
              <div className="piece-detail-story-block">
                {story ? <p className="piece-detail-story">{story}</p> : null}
                {scenes.length > 0 && (
                  <div className={story ? 'piece-detail-scenes' : undefined} style={story ? undefined : { marginTop: 0 }}>
                    <p className="piece-detail-story-header">The story behind this piece</p>
                    <div className="piece-detail-scenes-list">
                      {scenes.map((scene) => (
                        <div key={scene.id || scene.mediaUrl} className="piece-detail-scene">
                          {scene.mediaUrl ? (
                            <img src={scene.thumbnailUrl || scene.mediaUrl} alt="" />
                          ) : null}
                          {isVideoMedia(scene.mediaType, scene.mediaUrl) && (
                            <div className="piece-detail-scene-play"><span>▶</span></div>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                )}
                {series?.name && seriesThumbs.length > 0 && (
                  <Link
                    to={`/series/${series.id}`}
                    className="piece-detail-series"
                    style={{ marginTop: story || scenes.length ? 32 : 0 }}
                  >
                    <p className="piece-detail-story-header">Part of a series</p>
                    <div className="piece-detail-series-row">
                      <div
                        className="piece-detail-series-stack"
                        style={{ width: 117 + Math.max(0, Math.min(seriesThumbs.length, 3) - 1) * 35 }}
                      >
                        {seriesThumbs.slice(0, 3).map((url, i) => (
                          <img
                            key={url}
                            className="piece-detail-series-thumb"
                            src={url}
                            alt=""
                            style={{ left: i * 35, zIndex: i }}
                          />
                        ))}
                      </div>
                      <div className="piece-detail-series-copy">
                        <div className="piece-detail-series-name">{series.name}</div>
                        <div className="piece-detail-series-count">
                          {(series.pieceCount || series.pieceIds?.length || seriesThumbs.length)}{' '}
                          {(series.pieceCount || series.pieceIds?.length || seriesThumbs.length) === 1 ? 'piece' : 'pieces'}
                        </div>
                      </div>
                      <img className="piece-detail-series-chevron" src={seriesChevron} alt="" width={11} height={20} />
                    </div>
                  </Link>
                )}
              </div>
            )}

            {!showCollect && <div className="piece-detail-spacer" />}
          </div>

          {showCollect ? (
            <div className="piece-detail-cta">
              {isAuction ? (
                <div className="piece-detail-price-row">
                  <div>
                    <div className="piece-detail-price-label">
                      {piece.bidCount > 0 ? `Current bid · ${piece.bidCount} bids` : 'Starting bid'}
                    </div>
                    <div className="piece-detail-price">
                      {formatUsd(piece.highestBidCents ?? piece.priceCents)}
                    </div>
                  </div>
                  {timeRemaining && (
                    <div style={{ textAlign: 'right' }}>
                      <div className="piece-detail-price-label">Time remaining</div>
                      <div className="piece-detail-price is-error">{timeRemaining}</div>
                    </div>
                  )}
                </div>
              ) : (
                <div className="piece-detail-price" style={{ marginTop: 0 }}>{formatUsd(piece.priceCents)}</div>
              )}
              <div className="piece-detail-actions">
                <a
                  href={appHref}
                  className={`piece-detail-collect${collectEnabled ? '' : ' is-disabled'}`}
                >
                  {collectLabel}
                </a>
                {!isOwner && (
                  <a href={appHref} className="piece-detail-message" aria-label="Message artist">
                    <img src={messageBtn} alt="" width={40} height={40} />
                  </a>
                )}
              </div>
            </div>
          ) : null}
        </div>
      </div>

      {materialsOpen && (
        <Sheet onClose={() => setMaterialsOpen(false)}>
          <h2 className="piece-detail-sheet-title">Materials used</h2>
          {(piece.materials || []).length === 0 ? (
            <p className="piece-detail-material">No materials listed.</p>
          ) : (
            (piece.materials || []).map((material) => (
              <p key={material} className="piece-detail-material">{material}</p>
            ))
          )}
        </Sheet>
      )}

      {moreOpen && (
        <Sheet onClose={() => setMoreOpen(false)}>
          <button type="button" className="piece-detail-sheet-item" onClick={copyLink}>Copy link</button>
          <a className="piece-detail-sheet-item" href={appHref} onClick={() => setMoreOpen(false)}>Open in app</a>
        </Sheet>
      )}

      {toast && <div className="piece-detail-toast">{toast}</div>}
    </div>
  );
}

function DetailRow({ label, value }) {
  return (
    <div className="piece-detail-detail-row">
      <span className="piece-detail-detail-label">{label}</span>
      <span className="piece-detail-detail-value">{value}</span>
    </div>
  );
}

function Sheet({ onClose, children }) {
  return (
    <div className="piece-detail-sheet-backdrop" onClick={onClose} role="presentation">
      <div className="piece-detail-sheet" onClick={(e) => e.stopPropagation()} role="dialog">
        <div className="piece-detail-sheet-handle" />
        {children}
      </div>
    </div>
  );
}

function StateScreen({ text }) {
  return <div className="piece-detail-state">{text}</div>;
}
