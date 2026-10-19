import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { MoreHorizontal } from 'lucide-react';

import { useAuth } from '../../context/AuthContext';
import { useRequireLogin } from '../../hooks/useRequireLogin';
import { addComment, friendlyError, listComments } from '../../services/socialApi';
import { isBlockedAuthor, onAuthorBlocked } from '../../services/blockedAuthors';
import { profileHref } from '../../utils/contentLinks';
import { formatRelativeTime } from '../../utils/time';
import { ContentActionsSheet } from '../moderation/ContentActions';
import { useToast } from '../common/ActionSheet';
import './CommentsSection.css';

const MAX_LENGTH = 1000;

/**
 * Comments under a piece or scene, newest first, in the piece page's type and tokens.
 *
 * @param {object} props
 * @param {'piece'|'post'} props.type
 * @param {string} props.id
 * @param {(delta: number) => void} [props.onCountChange] — +1 when the viewer posts, so
 *   the parent's commentCount stays in step without a refetch.
 */
export function CommentsSection({ type, id, onCountChange }) {
  const { user, status } = useAuth();
  const requireLogin = useRequireLogin();
  const authenticated = status === 'authenticated';

  const [items, setItems] = useState([]);
  const [nextCursor, setNextCursor] = useState(null);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState(null);
  const [draft, setDraft] = useState('');
  const [posting, setPosting] = useState(false);
  const [postError, setPostError] = useState(null);
  const [menuFor, setMenuFor] = useState(null);
  const [, setBlockTick] = useState(0);
  const [toast, showToast] = useToast();
  const requestRef = useRef(0);

  // A block elsewhere on the page (or in this list) hides that author's comments at once.
  useEffect(() => onAuthorBlocked(() => setBlockTick((n) => n + 1)), []);

  // Wait for auth to settle — the token decides which blocked authors the backend drops.
  useEffect(() => {
    if (status === 'loading' || !id) return;
    const req = ++requestRef.current;
    setLoading(true);
    setError(null);
    setItems([]);
    setNextCursor(null);
    listComments(type, id)
      .then((page) => {
        if (req !== requestRef.current) return;
        setItems(page.items);
        setNextCursor(page.nextCursor);
      })
      .catch((e) => {
        if (req === requestRef.current) setError(friendlyError(e));
      })
      .finally(() => {
        if (req === requestRef.current) setLoading(false);
      });
  }, [type, id, status]);

  const loadMore = useCallback(async () => {
    if (!nextCursor || loadingMore) return;
    const req = requestRef.current;
    setLoadingMore(true);
    try {
      const page = await listComments(type, id, nextCursor);
      if (req !== requestRef.current) return;
      setItems((prev) => {
        const seen = new Set(prev.map((c) => c.id));
        return [...prev, ...page.items.filter((c) => !seen.has(c.id))];
      });
      setNextCursor(page.nextCursor);
    } catch (e) {
      showToast(friendlyError(e));
    } finally {
      setLoadingMore(false);
    }
  }, [type, id, nextCursor, loadingMore, showToast]);

  const submit = async (e) => {
    e.preventDefault();
    if (!requireLogin()) return;
    const body = draft.trim();
    if (!body || posting) return;

    // Optimistic row — the create response has no author object, so it comes from the session.
    const tempId = `tmp-${Date.now()}`;
    const optimistic = {
      id: tempId,
      body,
      createdAt: new Date().toISOString(),
      author: {
        username: user?.username,
        name: user?.name,
        profilePhotoUrl: user?.profilePhotoUrl,
      },
      pending: true,
    };
    setItems((prev) => [optimistic, ...prev]);
    setDraft('');
    setPosting(true);
    setPostError(null);
    try {
      const created = await addComment(type, id, body);
      setItems((prev) => prev.map((c) => (
        c.id === tempId
          ? { ...optimistic, id: created?.id ?? tempId, createdAt: created?.createdAt ?? optimistic.createdAt, pending: false }
          : c
      )));
      onCountChange?.(1);
    } catch (err) {
      setItems((prev) => prev.filter((c) => c.id !== tempId));
      setDraft(body);
      setPostError(friendlyError(err));
    } finally {
      setPosting(false);
    }
  };

  const viewer = (user?.username || '').toLowerCase();
  const visible = items.filter((c) => !isBlockedAuthor(c.author?.username));

  return (
    <section className="s3-comments" aria-label="Comments">
      <h2 className="s3-comments-header">Comments</h2>

      {authenticated ? (
        <form className="s3-comments-composer" onSubmit={submit}>
          <Avatar url={user?.profilePhotoUrl} name={user?.name || user?.username} />
          <textarea
            className="s3-comments-input"
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) submit(e);
            }}
            maxLength={MAX_LENGTH}
            rows={1}
            placeholder="Add a comment…"
            aria-label="Add a comment"
          />
          <button type="submit" className="s3-comments-post" disabled={!draft.trim() || posting}>
            Post
          </button>
        </form>
      ) : (
        <button type="button" className="s3-comments-login" onClick={() => requireLogin()}>
          Log in to comment
        </button>
      )}
      {postError && <p className="s3-comments-error">{postError}</p>}

      {loading ? (
        <p className="s3-comments-state">Loading comments…</p>
      ) : error ? (
        <p className="s3-comments-state">{error}</p>
      ) : visible.length === 0 ? (
        <p className="s3-comments-state">No comments yet.</p>
      ) : (
        <ul className="s3-comments-list">
          {visible.map((comment) => {
            const handle = comment.author?.username;
            const name = comment.author?.name || handle || 'Studio3 member';
            const isMine = Boolean(viewer && handle && handle.toLowerCase() === viewer);
            return (
              <li key={comment.id} className={`s3-comment${comment.pending ? ' is-pending' : ''}`}>
                {handle ? (
                  <Link to={profileHref(handle)} className="s3-comment-avatar-link" aria-label={name}>
                    <Avatar url={comment.author?.profilePhotoUrl} name={name} />
                  </Link>
                ) : (
                  <Avatar url={null} name={name} />
                )}
                <div className="s3-comment-main">
                  <div className="s3-comment-meta">
                    {handle ? (
                      <Link to={profileHref(handle)} className="s3-comment-name">{name}</Link>
                    ) : (
                      <span className="s3-comment-name">{name}</span>
                    )}
                    <span className="s3-comment-time">
                      {comment.pending ? 'Posting…' : formatRelativeTime(comment.createdAt)}
                    </span>
                  </div>
                  <p className="s3-comment-body">{comment.body}</p>
                </div>
                {!isMine && !comment.pending && (
                  <button
                    type="button"
                    className="s3-comment-more"
                    aria-label="Comment options"
                    onClick={() => setMenuFor(comment)}
                  >
                    <MoreHorizontal size={16} />
                  </button>
                )}
              </li>
            );
          })}
        </ul>
      )}

      {!loading && nextCursor && (
        <button type="button" className="s3-comments-more" onClick={loadMore} disabled={loadingMore}>
          {loadingMore ? 'Loading…' : 'Load more comments'}
        </button>
      )}

      {menuFor && (
        <ContentActionsSheet
          target={{ type: 'comment', id: menuFor.id }}
          authorUsername={menuFor.author?.username}
          onClose={() => setMenuFor(null)}
          onNotice={showToast}
        />
      )}
      {toast}
    </section>
  );
}

function Avatar({ url, name }) {
  if (url) return <img className="s3-comment-avatar" src={url} alt="" />;
  return <span className="s3-comment-avatar is-fallback">{(name || '?').slice(0, 1).toUpperCase()}</span>;
}
