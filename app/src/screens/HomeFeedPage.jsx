import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bell, MessageCircle, Plus } from 'lucide-react';
import { FeedCard } from '../components/content/FeedCard';
import { StateMessage, GuestPrompt } from '../components/common/StateMessage';
import { SafeArea } from '../components/layout/SafeArea';
import { useSession, useRequireLogin } from '../lib/session';
import { useCursorList, useInfiniteScroll } from '../lib/useCursorList';
import { friendlyError } from '../lib/social';
import { fetchForYou, fetchFollowing, fetchUnreadTotal, useVisibleItems } from '../lib/feedApi';

const headerStyle = {
  position: 'sticky',
  top: 0,
  zIndex: 10,
  background: 'rgba(255,255,255,0.72)',
  backdropFilter: 'blur(16px)',
  padding: '12px 16px',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  borderBottom: '1px solid var(--slate-100)',
  marginLeft: -16,
  marginRight: -16,
  paddingLeft: 16,
  paddingRight: 16,
};

const tabStyle = (active) => ({
  padding: '8px 20px',
  borderRadius: 9999,
  fontSize: 14,
  fontWeight: 500,
  background: active ? 'var(--slate-900)' : 'transparent',
  color: active ? 'var(--white)' : 'var(--slate-600)',
  boxShadow: active ? '0 2px 8px rgba(15,23,42,0.1)' : 'none',
});

const chipStyle = (active) => ({
  height: 28,
  padding: '0 14px',
  borderRadius: 9999,
  fontSize: 12,
  fontWeight: 500,
  background: active ? 'var(--slate-900)' : 'var(--slate-100)',
  color: active ? 'var(--white)' : 'var(--slate-600)',
  border: '1.5px solid',
  borderColor: active ? 'var(--slate-900)' : 'var(--slate-200)',
});

const headerIcon = { display: 'flex', alignItems: 'center', color: 'var(--slate-700)', padding: 4, position: 'relative' };

export function HomeFeedPage() {
  const { loggedIn } = useSession();
  const navigate = useNavigate();
  const requireLogin = useRequireLogin();
  const [tab, setTab] = useState('foryou');
  const [filter, setFilter] = useState('all');
  const [inboxOpen, setInboxOpen] = useState(false);
  const [unread, setUnread] = useState(0);

  useEffect(() => {
    if (!loggedIn) {
      setUnread(0);
      return undefined;
    }
    let alive = true;
    fetchUnreadTotal().then((n) => alive && setUnread(n)).catch(() => {});
    return () => {
      alive = false;
    };
  }, [loggedIn]);

  const goTo = (path) => {
    setInboxOpen(false);
    if (!requireLogin()) return;
    navigate(path);
  };

  const showGuestFollowing = tab === 'following' && !loggedIn;

  return (
    <SafeArea style={{ paddingTop: 0 }}>
      <header style={headerStyle}>
        <h1 style={{ fontSize: 20, fontWeight: 700, color: 'var(--slate-900)' }}>Studio 3</h1>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <button aria-label="Create" onClick={() => goTo('/post')} style={headerIcon}>
            <Plus size={24} strokeWidth={1.75} />
          </button>
          <div style={{ position: 'relative' }}>
            <button
              aria-label="Notifications and chats"
              onClick={() => setInboxOpen((open) => !open)}
              style={headerIcon}
            >
              <Bell size={22} strokeWidth={1.75} />
              {unread > 0 && <UnreadBadge count={unread} />}
            </button>

            {inboxOpen && (
              <>
                <div
                  style={{ position: 'fixed', inset: 0, zIndex: 20 }}
                  onClick={() => setInboxOpen(false)}
                />
                <div
                  className="glass-light"
                  style={{
                    position: 'absolute',
                    top: '100%',
                    right: 0,
                    marginTop: 8,
                    minWidth: 180,
                    padding: 6,
                    boxShadow: 'var(--shadow-float)',
                    zIndex: 21,
                  }}
                >
                  <InboxMenuButton
                    icon={<Bell size={17} strokeWidth={1.75} />}
                    label="Notifications"
                    onClick={() => goTo('/notifications')}
                  />
                  <InboxMenuButton
                    icon={<MessageCircle size={17} strokeWidth={1.75} />}
                    label="Chats"
                    onClick={() => goTo('/chat')}
                  />
                </div>
              </>
            )}
          </div>
        </div>
      </header>

      <div style={{ display: 'flex', gap: 8, marginBottom: 10, marginTop: 12 }}>
        <button style={tabStyle(tab === 'foryou')} onClick={() => setTab('foryou')}>For You</button>
        <button style={tabStyle(tab === 'following')} onClick={() => setTab('following')}>Following</button>
      </div>

      {!showGuestFollowing && (
        <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
          <button style={chipStyle(filter === 'all')} onClick={() => setFilter('all')}>All</button>
          <button style={chipStyle(filter === 'available')} onClick={() => setFilter('available')}>Available</button>
        </div>
      )}

      {showGuestFollowing ? (
        <GuestPrompt
          title="See artists you follow"
          message="Log in to get a feed of new work from the people you follow."
          next="/home"
        />
      ) : (
        // Keyed by tab so switching starts a fresh list (and fresh scroll sentinel).
        <FeedList key={tab} tab={tab} filter={filter} />
      )}
    </SafeArea>
  );
}

function FeedList({ tab, filter }) {
  const fetchPage = tab === 'following' ? fetchFollowing : fetchForYou;
  const { items, loading, loadingMore, error, reload, loadMore, nextCursor } = useCursorList(fetchPage, [tab]);
  const visible = useVisibleItems(items);
  /// Mirrors the app's "Available" filter: listed and not yet collected.
  const shown = filter === 'available' ? visible.filter((i) => i.isForSale && !i.isSold) : visible;
  const sentinel = useInfiniteScroll(loadMore, Boolean(nextCursor) && !loading);

  if (loading) return <StateMessage>Loading…</StateMessage>;
  if (error) return <StateMessage action="Try again" onAction={reload}>{friendlyError(error)}</StateMessage>;

  return (
    <>
      {shown.length === 0 && !nextCursor ? (
        <StateMessage>
          {filter === 'available'
            ? 'Nothing available for sale here yet.'
            : tab === 'following'
              ? 'Follow artists to see their new work here.'
              : 'Nothing here yet.'}
        </StateMessage>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {shown.map((item) => (
            <FeedCard key={`${item.type}-${item.id}`} item={item} />
          ))}
        </div>
      )}
      <div ref={sentinel} style={{ height: 1 }} />
      {loadingMore && <StateMessage style={{ padding: 16 }}>Loading more…</StateMessage>}
    </>
  );
}

function UnreadBadge({ count }) {
  return (
    <span
      style={{
        position: 'absolute',
        top: -2,
        right: -4,
        minWidth: 16,
        height: 16,
        padding: '0 4px',
        borderRadius: 9999,
        background: '#FF3040',
        color: 'var(--white)',
        fontSize: 10,
        fontWeight: 700,
        lineHeight: '16px',
        textAlign: 'center',
      }}
    >
      {count > 99 ? '99+' : count}
    </span>
  );
}

function InboxMenuButton({ icon, label, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        width: '100%',
        padding: '10px 12px',
        borderRadius: 'var(--radius-md)',
        fontSize: 14,
        fontWeight: 500,
        color: 'var(--slate-900)',
        textAlign: 'left',
      }}
    >
      {icon}
      {label}
    </button>
  );
}
