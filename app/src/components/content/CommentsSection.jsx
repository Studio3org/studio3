import React, { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Avatar } from '../common/Avatar';
import { StateMessage } from '../common/StateMessage';
import { ContentActionsMenu } from '../moderation/ContentActionsMenu';
import { isBlockedAuthor, onAuthorBlocked } from '../../lib/api';
import { useRequireLogin, useSession } from '../../lib/session';
import { useCursorList } from '../../lib/useCursorList';
import { addComment, friendlyError, listComments } from '../../lib/social';
import { timeAgo } from '../../lib/content';

const MAX_LENGTH = 1000;

const pillButton = {
  padding: '10px 18px',
  borderRadius: 9999,
  border: 'none',
  background: 'var(--slate-900)',
  color: 'var(--white)',
  fontSize: 14,
  fontWeight: 600,
  cursor: 'pointer',
  flexShrink: 0,
};

const sameUser = (a, b) => Boolean(a) && Boolean(b) && a.toLowerCase() === b.toLowerCase();

/// Comments on a piece or scene, newest first like the app's comment sheet.
/// `onAdded` lets the page bump its comment count after a successful post.
export function CommentsSection({ item, onAdded }) {
  const { loggedIn, user } = useSession();
  const requireLogin = useRequireLogin();
  const [draft, setDraft] = useState('');
  const [posting, setPosting] = useState(false);
  const [postError, setPostError] = useState(null);
  const [, setBlockTick] = useState(0);

  const fetchPage = useCallback((cursor) => listComments(item, cursor), [item.type, item.id]);
  const { items, setItems, nextCursor, loading, loadingMore, error, reload, loadMore } = useCursorList(
    fetchPage,
    [fetchPage],
  );

  // Blocking a commenter from their row's menu hides all of their comments at once.
  useEffect(() => onAuthorBlocked(() => setBlockTick((t) => t + 1)), []);

  const submit = async (e) => {
    e.preventDefault();
    const body = draft.trim();
    if (!body || posting || !requireLogin()) return;
    const tempId = `pending-${Date.now()}`;
    const optimistic = {
      id: tempId,
      body,
      createdAt: new Date().toISOString(),
      author: {
        username: user?.username ?? null,
        name: user?.name || user?.username || 'You',
        profilePhotoUrl: user?.profilePhotoUrl ?? null,
      },
      pending: true,
    };
    setPosting(true);
    setPostError(null);
    setItems((prev) => [optimistic, ...prev]);
    setDraft('');
    try {
      const saved = await addComment(item, body);
      setItems((prev) => prev.map((c) => (c.id === tempId ? saved : c)));
      onAdded?.(saved);
    } catch (err) {
      setItems((prev) => prev.filter((c) => c.id !== tempId));
      setDraft(body);
      setPostError(friendlyError(err));
    } finally {
      setPosting(false);
    }
  };

  const visible = items.filter((c) => !isBlockedAuthor(c.author?.username));

  return (
    <section id="comments" style={{ padding: '16px 16px 32px' }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, color: 'var(--slate-900)', marginBottom: 12 }}>Comments</h2>

      {loggedIn ? (
        <form onSubmit={submit} style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <Avatar src={user?.profilePhotoUrl} name={user?.name} size={32} />
          <input
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            maxLength={MAX_LENGTH}
            placeholder="Add a comment…"
            aria-label="Add a comment"
            style={{
              flex: 1,
              minWidth: 0,
              height: 40,
              padding: '0 14px',
              borderRadius: 9999,
              border: '1px solid var(--slate-200)',
              background: 'var(--slate-50)',
              fontSize: 14,
              color: 'var(--slate-900)',
              outline: 'none',
            }}
          />
          <button
            type="submit"
            disabled={!draft.trim() || posting}
            style={{ ...pillButton, opacity: !draft.trim() || posting ? 0.5 : 1 }}
          >
            Post
          </button>
        </form>
      ) : (
        <button type="button" onClick={() => requireLogin()} style={{ ...pillButton, width: '100%' }}>
          Log in to comment
        </button>
      )}
      {postError && <p style={{ fontSize: 12, color: '#E05252', marginTop: 8 }}>{postError}</p>}

      {loading ? (
        <StateMessage style={{ padding: '24px 0' }}>Loading comments…</StateMessage>
      ) : error ? (
        <StateMessage style={{ padding: '24px 0' }} action="Try again" onAction={reload}>
          {friendlyError(error)}
        </StateMessage>
      ) : visible.length === 0 ? (
        <StateMessage style={{ padding: '24px 0' }}>No comments yet. Be the first to say something.</StateMessage>
      ) : (
        <ul style={{ listStyle: 'none', marginTop: 16, display: 'flex', flexDirection: 'column', gap: 16 }}>
          {visible.map((c) => (
            <CommentRow key={c.id} comment={c} mine={sameUser(c.author?.username, user?.username)} />
          ))}
        </ul>
      )}

      {!loading && !error && nextCursor && (
        <button
          type="button"
          onClick={loadMore}
          disabled={loadingMore}
          style={{
            display: 'block',
            margin: '16px auto 0',
            padding: '8px 16px',
            borderRadius: 9999,
            border: '1px solid var(--slate-200)',
            background: 'var(--white)',
            color: 'var(--slate-700)',
            fontSize: 13,
            fontWeight: 600,
            cursor: 'pointer',
          }}
        >
          {loadingMore ? 'Loading…' : 'Load more comments'}
        </button>
      )}
    </section>
  );
}

function CommentRow({ comment, mine }) {
  const author = comment.author;
  const name = author?.name || author?.username || 'Someone';
  return (
    <li style={{ display: 'flex', gap: 10, alignItems: 'flex-start', opacity: comment.pending ? 0.6 : 1 }}>
      {author?.username ? (
        <Link to={`/u/${author.username}`}>
          <Avatar src={author.profilePhotoUrl} name={name} size={32} />
        </Link>
      ) : (
        <Avatar src={author?.profilePhotoUrl} name={name} size={32} />
      )}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, fontSize: 13 }}>
          {author?.username ? (
            <Link to={`/u/${author.username}`} style={{ fontWeight: 600, color: 'var(--slate-900)' }}>{name}</Link>
          ) : (
            <span style={{ fontWeight: 600, color: 'var(--slate-900)' }}>{name}</span>
          )}
          <span style={{ color: 'var(--slate-400)', fontSize: 12 }}>
            {comment.pending ? 'Posting…' : timeAgo(comment.createdAt)}
          </span>
        </div>
        <p style={{ fontSize: 14, color: 'var(--slate-700)', lineHeight: 1.45, marginTop: 2, whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}>
          {comment.body}
        </p>
      </div>
      {!mine && !comment.pending && (
        <ContentActionsMenu
          target={{ type: 'comment', id: comment.id }}
          authorUsername={author?.username}
          buttonStyle={{ width: 28, height: 28, background: 'transparent', color: 'var(--slate-400)' }}
        />
      )}
    </li>
  );
}
