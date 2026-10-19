import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { Link2, MapPin, Smartphone } from 'lucide-react';

import { useAuth } from '../context/AuthContext';
import { useRequireLogin } from '../hooks/useRequireLogin';
import { ApiError, apiFetch, APP_BASE_URL } from '../services/apiClient';
import { friendlyError, setFollowing, setLiked as apiSetLiked, setSaved as apiSetSaved } from '../services/socialApi';
import { profileHref } from '../utils/contentLinks';
import { ContentActionsSheet } from '../components/moderation/ContentActions';
import { CommentsSection } from '../components/content/CommentsSection';
import { EngagementBar } from '../components/content/EngagementBar';
// Same split layout, overlay, artist row and tokens as the piece page.
import './PieceDetailPage.css';
import './SceneDetailPage.css';

import heroBack from '../assets/piece/hero_back.svg';
import heroBookmark from '../assets/piece/hero_bookmark.svg';
import heroBookmarkFill from '../assets/piece/hero_bookmark_fill.svg';
import heroShare from '../assets/piece/hero_share.svg';
import heroMore from '../assets/piece/hero_more.svg';
import likeHeart from '../assets/piece/like_heart.svg';

function isVideo(post) {
  return (post?.mediaType || '').toLowerCase() === 'video';
}

/// Frame ratio from the post's own `mediaAspectRatio` ("9:16", "3:4", …); scenes are
/// usually vertical video, so that is the fallback for videos. Landscape media is
/// letterboxed in a square frame so the desktop card keeps room for its side panel.
function frameRatio(post) {
  const match = /^(\d+(?:\.\d+)?):(\d+(?:\.\d+)?)$/.exec(post?.mediaAspectRatio || '');
  if (match) {
    const w = Number(match[1]);
    const h = Number(match[2]);
    if (w > 0 && h > 0) return w > h ? '1 / 1' : `${w} / ${h}`;
  }
  return isVideo(post) ? '9 / 16' : '3 / 4';
}

/// `/scene/:id` — a single scene (backend "post"): photo or video, the artist, caption,
/// the piece it's linked to, and comments. Public; account actions are login-gated.
export function SceneDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { user, status } = useAuth();
  const requireLogin = useRequireLogin();

  const [post, setPost] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null); // null | 'missing' | message
  const [liked, setLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(0);
  const [saved, setSaved] = useState(false);
  const [commentCount, setCommentCount] = useState(0);
  const [followState, setFollowState] = useState('none');
  const [followBusy, setFollowBusy] = useState(false);
  const [moreOpen, setMoreOpen] = useState(false);
  const [blocked, setBlocked] = useState(false);
  const [burst, setBurst] = useState(false);
  const [toast, setToast] = useState(null);
  const likeBusy = useRef(false);
  const lastTap = useRef(0);
  const toastTimer = useRef(null);
  const commentsRef = useRef(null);

  const showToast = useCallback((text) => {
    setToast(text);
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), text.length > 40 ? 3200 : 1800);
  }, []);

  useEffect(() => () => clearTimeout(toastTimer.current), []);

  useEffect(() => {
    if (status === 'loading') return undefined;
    let cancelled = false;
    setLoading(true);
    setError(null);
    setBlocked(false);
    apiFetch(`/api/posts/${id}`, { auth: true })
      .then((json) => {
        if (cancelled) return;
        setPost(json);
        setLiked(Boolean(json.isLiked));
        setLikeCount(json.likeCount ?? 0);
        setSaved(Boolean(json.isSaved));
        setCommentCount(json.commentCount ?? 0);
        setFollowState(json.author?.isFollowing ? 'following' : 'none');
      })
      .catch((e) => {
        if (cancelled) return;
        setPost(null);
        // 404 covers deleted, someone else's draft, and blocked-either-way; 400 a malformed id.
        setError(e instanceof ApiError && (e.status === 404 || e.status === 400) ? 'missing' : friendlyError(e));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [id, status]);

  const author = post?.author ?? {};
  const authorHandle = (author.username || '').replace(/^@/, '');
  const authorName = author.name || authorHandle || 'Artist';
  const viewerHandle = (user?.username || '').toLowerCase();
  const isOwner = Boolean(viewerHandle && authorHandle && viewerHandle === authorHandle.toLowerCase());
  const showFollow = Boolean(authorHandle) && !isOwner;
  const appHref = `studio3://scene/${id}`;
  const webHref = `${APP_BASE_URL}/scene/${id}`;
  const piece = post?.piece;
  const caption = (post?.caption || '').trim();
  const location = (post?.location || '').trim();

  const goBack = () => {
    if (window.history.length > 1) navigate(-1);
    else navigate('/home');
  };

  /// Optimistic like/unlike; the response's likeCount is authoritative.
  const applyLike = async (next) => {
    if (likeBusy.current) return;
    likeBusy.current = true;
    const prevLiked = liked;
    const prevCount = likeCount;
    setLiked(next);
    setLikeCount((n) => Math.max(0, n + (next ? 1 : -1)));
    try {
      const res = await apiSetLiked('post', id, next);
      setLiked(Boolean(res?.liked ?? next));
      if (typeof res?.likeCount === 'number') setLikeCount(res.likeCount);
    } catch (e) {
      setLiked(prevLiked);
      setLikeCount(prevCount);
      showToast(friendlyError(e));
    } finally {
      likeBusy.current = false;
    }
  };

  const toggleLike = () => {
    if (!requireLogin()) return;
    applyLike(!liked);
  };

  /// Double-tap a photo to like (never unlikes). Videos keep their native controls.
  const onMediaTap = () => {
    if (isVideo(post)) return;
    const now = Date.now();
    if (now - lastTap.current < 280) {
      lastTap.current = 0;
      if (!requireLogin()) return;
      setBurst(true);
      setTimeout(() => setBurst(false), 700);
      if (!liked) applyLike(true);
      return;
    }
    lastTap.current = now;
  };

  const toggleSave = async () => {
    if (!requireLogin()) return;
    const next = !saved;
    setSaved(next);
    try {
      await apiSetSaved('post', id, next);
      showToast(next ? 'Saved' : 'Removed from saved');
    } catch (e) {
      setSaved(!next);
      showToast(friendlyError(e));
    }
  };

  const toggleFollow = async () => {
    if (!requireLogin()) return;
    if (followBusy || !authorHandle) return;
    setFollowBusy(true);
    try {
      const result = await setFollowing(authorHandle, followState === 'none');
      setFollowState(result?.following ? 'following' : result?.requested ? 'pending' : 'none');
    } catch (e) {
      showToast(friendlyError(e));
    } finally {
      setFollowBusy(false);
    }
  };

  const copyLink = async () => {
    try {
      await navigator.clipboard.writeText(webHref);
      showToast('Link copied');
    } catch {
      showToast('Could not copy link');
    }
  };

  const share = async () => {
    if (!navigator.share) return copyLink();
    try {
      await navigator.share({ title: 'Studio 3', text: `A scene by ${authorName} on Studio`, url: webHref });
    } catch (err) {
      if (err?.name !== 'AbortError') copyLink();
    }
  };

  if (status === 'loading' || loading) {
    return <div className="piece-detail-page"><div className="piece-detail-state">Loading…</div></div>;
  }
  if (error || !post) {
    return (
      <StateScreen
        text={error === 'missing' || !error ? "This scene couldn't be found." : error}
        onHome={() => navigate('/home')}
      />
    );
  }
  if (blocked) {
    return (
      <StateScreen
        text={`You blocked @${authorHandle}. Their pieces, scenes and comments are hidden.`}
        onHome={() => navigate('/home')}
      />
    );
  }

  const followLabel = followState === 'following' ? 'Following' : followState === 'pending' ? 'Requested' : 'Follow';

  return (
    <div className="piece-detail-page scene-detail-page">
      <div className="piece-detail-card">
        <div
          className="piece-detail-media scene-detail-media"
          style={{ aspectRatio: frameRatio(post) }}
          onClick={onMediaTap}
        >
          {isVideo(post) ? (
            <video
              className="scene-detail-video"
              src={post.mediaUrl}
              poster={post.thumbnailUrl || undefined}
              controls
              playsInline
              preload="metadata"
            />
          ) : post.mediaUrl ? (
            <img className="piece-detail-slide" src={post.mediaUrl} alt={caption || 'Scene'} />
          ) : (
            <div className="piece-detail-slide" />
          )}

          <div className="piece-detail-overlay" onClick={(e) => e.stopPropagation()}>
            <button type="button" className="piece-detail-overlay-hit" style={{ width: 24 }} aria-label="Back" onClick={goBack}>
              <img src={heroBack} alt="" width={11} height={20} />
            </button>
            <div className="piece-detail-overlay-actions">
              <button type="button" className="piece-detail-overlay-hit" style={{ width: 32 }} aria-label={saved ? 'Unsave' : 'Save'} onClick={toggleSave}>
                <img src={saved ? heroBookmarkFill : heroBookmark} alt="" width={16} height={20} />
              </button>
              <button type="button" className="piece-detail-overlay-hit" style={{ width: 32 }} aria-label="Share" onClick={share}>
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
            <Link
              to={authorHandle ? profileHref(authorHandle) : '#'}
              className="scene-detail-artist-link"
              onClick={(e) => !authorHandle && e.preventDefault()}
            >
              {author.profilePhotoUrl ? (
                <img className="piece-detail-avatar" src={author.profilePhotoUrl} alt={authorName} />
              ) : (
                <span className="piece-detail-avatar is-fallback">{authorName.slice(0, 1)}</span>
              )}
              <div className="piece-detail-artist-text">
                <div className="piece-detail-artist-name">{authorName}</div>
                <div className="piece-detail-artist-handle">@{authorHandle || 'artist'}</div>
              </div>
            </Link>
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
            {(caption || location || post.isProcess) && (
              <div className="scene-detail-caption-block">
                {post.isProcess && <span className="scene-detail-badge">Process</span>}
                {caption && <p className="piece-detail-story">{caption}</p>}
                {location && (
                  <p className="scene-detail-location">
                    <MapPin size={13} strokeWidth={1.6} />
                    <span>{location}</span>
                  </p>
                )}
              </div>
            )}

            <EngagementBar
              liked={liked}
              likeCount={likeCount}
              onLike={toggleLike}
              commentCount={commentCount}
              onComments={() => commentsRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' })}
            />

            {piece?.id && (
              <div className="piece-detail-story-block">
                <p className="piece-detail-story-header">The piece behind this scene</p>
                <Link to={`/piece/${piece.id}`} className="scene-detail-piece">
                  {piece.mediaUrl ? (
                    <img className="scene-detail-piece-thumb" src={piece.mediaUrl} alt="" />
                  ) : (
                    <span className="scene-detail-piece-thumb" />
                  )}
                  <span className="scene-detail-piece-copy">
                    <span className="scene-detail-piece-title">{piece.title || 'Untitled'}</span>
                    {piece.medium ? <span className="scene-detail-piece-meta">{piece.medium}</span> : null}
                    <span className="scene-detail-piece-cta">View piece →</span>
                  </span>
                </Link>
              </div>
            )}

            <div ref={commentsRef}>
              <CommentsSection
                type="post"
                id={id}
                onCountChange={(delta) => setCommentCount((n) => Math.max(0, n + delta))}
              />
            </div>
            <div className="piece-detail-spacer" />
          </div>
        </div>
      </div>

      {moreOpen && (
        <ContentActionsSheet
          target={{ type: 'post', id }}
          authorUsername={authorHandle || undefined}
          items={[
            { label: 'Copy link', icon: <Link2 size={18} />, onClick: copyLink },
            { label: 'Open in app', icon: <Smartphone size={18} />, onClick: () => { window.location.href = appHref; } },
          ]}
          onClose={() => setMoreOpen(false)}
          onNotice={showToast}
          onBlocked={() => setBlocked(true)}
        />
      )}

      {toast && <div className="piece-detail-toast">{toast}</div>}
    </div>
  );
}

function StateScreen({ text, onHome }) {
  return (
    <div className="piece-detail-page">
      <div className="piece-detail-state is-column">
        <p>{text}</p>
        <button type="button" className="piece-detail-state-btn" onClick={onHome}>
          Back to home
        </button>
      </div>
    </div>
  );
}
