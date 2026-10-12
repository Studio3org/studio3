import React, { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ChevronRight, UserPlus } from 'lucide-react';
import { GlassCard } from '../components/design/GlassCard';
import { SafeArea } from '../components/layout/SafeArea';
import { Avatar } from '../components/common/Avatar';
import { GuestPrompt, StateMessage } from '../components/common/StateMessage';
import { apiFetch, isBlockedAuthor, onAuthorBlocked } from '../lib/api';
import { useSession } from '../lib/session';
import { timeAgo } from '../lib/content';
import { friendlyError } from '../lib/social';
import { useCursorList, useInfiniteScroll } from '../lib/useCursorList';

const rowStyle = {
  display: 'flex',
  alignItems: 'center',
  gap: 12,
  padding: 12,
  marginBottom: 8,
  boxShadow: 'var(--shadow-card)',
  width: '100%',
  textAlign: 'left',
  cursor: 'pointer',
};

const sectionTitle = { fontSize: 12, fontWeight: 500, color: 'var(--slate-400)', marginBottom: 8 };

/// Backend says "post"; the product calls them scenes.
const noun = (target) => (target?.type === 'post' ? 'scene' : target?.type || 'piece');

/// Display rules shared with the app: `{ text, highlight }` where highlight is
/// the bolded piece title / comment snippet, if any.
function describe(n) {
  const p = n.payload ?? {};
  switch (n.type) {
    case 'follow':
      return { text: 'started following you' };
    case 'follow_request':
      return { text: 'requested to follow you' };
    case 'like':
      return { text: `liked your ${noun(n.target)}` };
    case 'save':
      return { text: `saved your ${noun(n.target)}` };
    case 'comment':
      return { text: 'commented:', highlight: p.commentPreview };
    case 'inquiry':
      return { text: 'sent an inquiry about', highlight: p.pieceTitle ? `'${p.pieceTitle}'` : null };
    case 'purchase':
      return { text: 'purchased', highlight: p.pieceTitle ? `'${p.pieceTitle}'` : null };
    default:
      return { text: n.message ?? 'sent you a notification' };
  }
}

function destination(n) {
  const t = n.target;
  const contentHref = t?.id ? (t.type === 'post' ? `/scene/${t.id}` : t.type === 'piece' ? `/piece/${t.id}` : null) : null;
  switch (n.type) {
    case 'like':
    case 'save':
    case 'comment':
      return contentHref;
    case 'follow':
    case 'follow_request':
      return n.actor?.username ? `/u/${n.actor.username}` : null;
    case 'inquiry':
    case 'purchase':
      return t?.id ? `/piece/${t.id}` : null;
    default:
      return contentHref;
  }
}

/// Today = same calendar day; This week = the last 7 days; Earlier = the rest.
function bucket(iso) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return 'earlier';
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);
  if (d >= startOfToday) return 'today';
  if (Date.now() - d.getTime() < 7 * 24 * 3600 * 1000) return 'week';
  return 'earlier';
}

const SECTIONS = [
  ['today', 'Today'],
  ['week', 'This Week'],
  ['earlier', 'Earlier'],
];

export function NotificationsPage() {
  const { loggedIn } = useSession();
  if (!loggedIn) {
    return (
      <SafeArea style={{ paddingTop: 0 }}>
        <GuestPrompt
          title="Your activity"
          message="Log in to see likes, follows, comments, and sales on your work."
          next="/notifications"
        />
      </SafeArea>
    );
  }
  return <Notifications />;
}

function Notifications() {
  const navigate = useNavigate();
  const [, setBlockTick] = useState(0);
  const [requestCount, setRequestCount] = useState(0);
  const [markAllBusy, setMarkAllBusy] = useState(false);
  const [actionError, setActionError] = useState(null);

  const fetchPage = useCallback(async (cursor) => {
    const q = cursor ? `?cursor=${encodeURIComponent(cursor)}&limit=20` : '?limit=20';
    const data = await apiFetch(`/api/notifications${q}`, { auth: true });
    return { items: data?.items ?? [], nextCursor: data?.nextCursor ?? null };
  }, []);
  const { items, setItems, nextCursor, loading, loadingMore, error, reload, loadMore } = useCursorList(fetchPage, []);
  const sentinel = useInfiniteScroll(loadMore, Boolean(nextCursor) && !loading);

  useEffect(() => onAuthorBlocked(() => setBlockTick((t) => t + 1)), []);

  useEffect(() => {
    let alive = true;
    apiFetch('/api/users/follow-requests', { auth: true })
      .then((list) => alive && setRequestCount(Array.isArray(list) ? list.length : 0))
      .catch(() => {}); // the banner is a shortcut; failing silently is fine
    return () => {
      alive = false;
    };
  }, []);

  const visible = items.filter((n) => !isBlockedAuthor(n.actor?.username));
  const grouped = { today: [], week: [], earlier: [] };
  visible.forEach((n) => grouped[bucket(n.createdAt)].push(n));
  const hasUnread = visible.some((n) => !n.read);

  const markLocal = (pred) => setItems((prev) => prev.map((n) => (pred(n) ? { ...n, read: true } : n)));

  const openNotification = (n) => {
    if (!n.read) {
      markLocal((x) => x.id === n.id);
      apiFetch(`/api/notifications/${n.id}/read`, { method: 'PATCH', auth: true }).catch(() => {});
    }
    const href = destination(n);
    if (href) navigate(href);
  };

  const markAllRead = async () => {
    if (markAllBusy) return;
    setMarkAllBusy(true);
    setActionError(null);
    try {
      await apiFetch('/api/notifications/read-all', { method: 'POST', auth: true });
      markLocal(() => true);
    } catch (e) {
      setActionError(friendlyError(e));
    } finally {
      setMarkAllBusy(false);
    }
  };

  return (
    <SafeArea style={{ paddingTop: 0 }}>
      <header style={{ paddingBottom: 16, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <h1 style={{ fontSize: 22, fontWeight: 700, color: 'var(--slate-900)' }}>Activity</h1>
        {hasUnread && (
          <button
            type="button"
            onClick={markAllRead}
            disabled={markAllBusy}
            style={{ fontSize: 13, fontWeight: 600, color: 'var(--slate-600)', background: 'none', border: 'none', cursor: 'pointer' }}
          >
            {markAllBusy ? 'Marking…' : 'Mark all read'}
          </button>
        )}
      </header>

      {actionError && <p style={{ color: '#E05252', fontSize: 13, marginBottom: 12 }}>{actionError}</p>}

      {requestCount > 0 && (
        <Link to="/follow-requests" style={{ display: 'block', marginBottom: 16 }}>
          <GlassCard style={{ ...rowStyle, marginBottom: 0 }}>
            <span
              style={{
                width: 36,
                height: 36,
                borderRadius: '50%',
                background: 'var(--slate-900)',
                color: 'var(--white)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                flexShrink: 0,
              }}
            >
              <UserPlus size={18} />
            </span>
            <span style={{ flex: 1, fontSize: 14, fontWeight: 600, color: 'var(--slate-900)' }}>
              Follow requests ({requestCount})
            </span>
            <ChevronRight size={18} color="var(--slate-400)" />
          </GlassCard>
        </Link>
      )}

      {loading ? (
        <StateMessage>Loading…</StateMessage>
      ) : error ? (
        <StateMessage action="Try again" onAction={reload}>{friendlyError(error)}</StateMessage>
      ) : visible.length === 0 ? (
        <p style={{ textAlign: 'center', color: 'var(--slate-400)', padding: 48 }}>No activity yet</p>
      ) : (
        <>
          {SECTIONS.map(([key, label]) =>
            grouped[key].length > 0 ? (
              <section key={key} style={{ marginBottom: 24 }}>
                <h2 style={sectionTitle}>{label}</h2>
                {grouped[key].map((n) => (
                  <ActivityRow key={n.id} item={n} onOpen={() => openNotification(n)} />
                ))}
              </section>
            ) : null,
          )}
          <div ref={sentinel} style={{ height: 1 }} />
          {loadingMore && <StateMessage style={{ padding: 16 }}>Loading…</StateMessage>}
        </>
      )}
    </SafeArea>
  );
}

function ActivityRow({ item, onOpen }) {
  const { text, highlight } = describe(item);
  const actorName = item.actor?.name || item.actor?.username || 'Someone';
  return (
    <div
      role="button"
      tabIndex={0}
      onClick={onOpen}
      onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && onOpen()}
    >
      <GlassCard style={rowStyle}>
        <Avatar src={item.actor?.profilePhotoUrl} name={actorName} size={36} />
        <div style={{ flex: 1, minWidth: 0, fontSize: 14, color: 'var(--slate-700)', lineHeight: 1.4 }}>
          <span style={{ fontWeight: 600, color: 'var(--slate-900)' }}>{actorName}</span> {text}
          {highlight && (
            <>
              {' '}
              <strong style={{ color: 'var(--slate-900)' }}>{highlight}</strong>
            </>
          )}
          {item.type === 'inquiry' && (
            <span style={{ marginLeft: 6, padding: '2px 8px', borderRadius: 9999, background: 'var(--slate-100)', fontSize: 11, color: 'var(--slate-600)' }}>Inquiry</span>
          )}
          {item.type === 'purchase' && (
            <span style={{ marginLeft: 6, padding: '2px 8px', borderRadius: 9999, background: 'var(--slate-900)', color: 'var(--white)', fontSize: 11, fontWeight: 600 }}>Sale</span>
          )}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
          <span style={{ fontSize: 11, color: 'var(--slate-400)' }}>{timeAgo(item.createdAt)}</span>
          {!item.read && (
            <span aria-label="Unread" style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--slate-900)' }} />
          )}
        </div>
      </GlassCard>
    </div>
  );
}
