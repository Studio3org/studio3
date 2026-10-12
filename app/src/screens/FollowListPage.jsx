import React, { useCallback } from 'react';
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom';
import { ChevronLeft } from 'lucide-react';
import { listFollows } from '../lib/profileApi';
import { friendlyError } from '../lib/social';
import { useCursorList, useInfiniteScroll } from '../lib/useCursorList';
import { Avatar } from '../components/common/Avatar';
import { StateMessage } from '../components/common/StateMessage';

/// Followers / following of `/u/:username` — which one comes from the path.
export function FollowListPage() {
  const { username } = useParams();
  const { pathname, key } = useLocation();
  const navigate = useNavigate();
  const which = pathname.endsWith('/following') ? 'following' : 'followers';

  const fetchPage = useCallback((cursor) => listFollows(username, which, cursor), [username, which]);
  const { items, nextCursor, loading, loadingMore, error, reload, loadMore } = useCursorList(fetchPage, [fetchPage]);
  const sentinel = useInfiniteScroll(loadMore, Boolean(nextCursor));

  // A link opened in a fresh tab has no in-app history to go back to.
  const goBack = () => (key === 'default' ? navigate(`/u/${username}`) : navigate(-1));

  return (
    <div style={{ minHeight: '100vh', background: 'var(--white)', padding: '0 16px 48px' }}>
      <header style={{ display: 'flex', alignItems: 'center', gap: 8, height: 56 }}>
        <button
          type="button"
          aria-label="Back"
          onClick={goBack}
          style={{ width: 36, height: 36, marginLeft: -8, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--slate-900)' }}
        >
          <ChevronLeft size={24} />
        </button>
        <div style={{ minWidth: 0 }}>
          <h1 style={{ fontSize: 18, fontWeight: 600, color: 'var(--slate-900)' }}>
            {which === 'followers' ? 'Followers' : 'Following'}
          </h1>
          <div style={{ fontSize: 12, color: 'var(--slate-500)' }}>@{username}</div>
        </div>
      </header>

      {loading ? (
        <StateMessage>Loading…</StateMessage>
      ) : error ? (
        <StateMessage action="Try again" onAction={reload}>
          {error.status === 403 ? 'This account is private.' : error.status === 404 ? "This account isn't available." : friendlyError(error)}
        </StateMessage>
      ) : items.length === 0 ? (
        <StateMessage>
          {which === 'followers' ? 'No followers yet.' : 'Not following anyone yet.'}
        </StateMessage>
      ) : (
        <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
          {items.map((u) => (
            <li key={u.username}>
              <Link
                to={`/u/${u.username}`}
                style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 0' }}
              >
                <Avatar src={u.profilePhotoUrl} name={u.name} size={44} />
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontSize: 15, fontWeight: 600, color: 'var(--slate-900)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {u.name || u.username}
                  </div>
                  <div style={{ fontSize: 13, color: 'var(--slate-500)' }}>@{u.username}</div>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}
      <div ref={sentinel} />
      {loadingMore && <StateMessage style={{ padding: 16 }}>Loading more…</StateMessage>}
    </div>
  );
}
