import React, { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { PenSquare, Search, X } from 'lucide-react';
import { SafeArea } from '../components/layout/SafeArea';
import { Avatar } from '../components/common/Avatar';
import { GuestPrompt, StateMessage } from '../components/common/StateMessage';
import { getSessionUser, isBlockedAuthor, onAuthorBlocked } from '../lib/api';
import { listInbox, listRequests, searchUsers } from '../lib/chatApi';
import { useSession } from '../lib/session';
import { timeAgo } from '../lib/content';
import { friendlyError } from '../lib/social';
import { useCursorList, useInfiniteScroll } from '../lib/useCursorList';

const inboxCardStyle = {
  padding: 12,
  display: 'flex',
  alignItems: 'center',
  gap: 12,
  marginBottom: 8,
  boxShadow: 'var(--shadow-card)',
};

const emptyStateStyle = {
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  justifyContent: 'center',
  padding: 48,
  color: 'var(--slate-200)',
};

const tabStyle = (active) => ({
  height: 34,
  padding: '0 16px',
  borderRadius: 9999,
  fontSize: 14,
  fontWeight: 600,
  background: active ? 'var(--slate-900)' : 'var(--slate-100)',
  color: active ? 'var(--white)' : 'var(--slate-600)',
  cursor: 'pointer',
});

export function ChatPage() {
  const { loggedIn } = useSession();
  if (!loggedIn) {
    return (
      <SafeArea style={{ paddingTop: 0 }}>
        <GuestPrompt title="Messages" message="Log in to message artists and collectors." next="/chat" />
      </SafeArea>
    );
  }
  return <Inbox />;
}

function Inbox() {
  const navigate = useNavigate();
  const [tab, setTab] = useState('chats'); // 'chats' | 'requests'
  const [composeOpen, setComposeOpen] = useState(false);
  const [, setBlockTick] = useState(0);

  const fetchPage = useCallback((cursor) => (tab === 'chats' ? listInbox(cursor) : listRequests(cursor)), [tab]);
  const { items, nextCursor, loading, loadingMore, error, reload, loadMore } = useCursorList(fetchPage, [tab]);
  const sentinel = useInfiniteScroll(loadMore, Boolean(nextCursor) && !loading);

  useEffect(() => onAuthorBlocked(() => setBlockTick((t) => t + 1)), []);

  const visible = items.filter((c) => !isBlockedAuthor(c.otherParty?.username));

  return (
    <SafeArea style={{ paddingTop: 0 }}>
      <header style={{ paddingBottom: 16, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <h1 style={{ fontSize: 22, fontWeight: 700, color: 'var(--slate-900)' }}>Messages</h1>
        <button
          type="button"
          aria-label="New message"
          onClick={() => setComposeOpen(true)}
          style={{ width: 40, height: 40, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--slate-900)', cursor: 'pointer' }}
        >
          <PenSquare size={22} />
        </button>
      </header>

      <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
        <button type="button" style={tabStyle(tab === 'chats')} onClick={() => setTab('chats')}>
          Chats
        </button>
        <button type="button" style={tabStyle(tab === 'requests')} onClick={() => setTab('requests')}>
          Requests
        </button>
      </div>

      {loading ? (
        <StateMessage>Loading…</StateMessage>
      ) : error ? (
        <StateMessage action="Try again" onAction={reload}>{friendlyError(error)}</StateMessage>
      ) : visible.length === 0 ? (
        <div style={emptyStateStyle}>
          <div style={{ fontSize: 48, marginBottom: 16 }}>✉</div>
          <p style={{ fontSize: 14, color: 'var(--slate-500)', textAlign: 'center' }}>
            {tab === 'chats' ? 'No messages yet' : 'No message requests'}
          </p>
        </div>
      ) : (
        <>
          {visible.map((c) => (
            <ConversationRow key={c.id} convo={c} onOpen={() => navigate(`/chat/${c.id}`)} />
          ))}
          <div ref={sentinel} style={{ height: 1 }} />
          {loadingMore && <StateMessage style={{ padding: 16 }}>Loading…</StateMessage>}
        </>
      )}

      {composeOpen && <NewMessageSheet onClose={() => setComposeOpen(false)} />}
    </SafeArea>
  );
}

function ConversationRow({ convo, onOpen }) {
  const other = convo.otherParty;
  const name = other?.name || other?.username || 'Studio3 member';
  return (
    <button
      type="button"
      className="glass-light"
      style={{ ...inboxCardStyle, width: '100%', textAlign: 'left', cursor: 'pointer' }}
      onClick={onOpen}
    >
      <Avatar src={other?.profilePhotoUrl} name={name} size={48} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 14, fontWeight: convo.unread ? 700 : 600, color: 'var(--slate-900)' }}>{name}</div>
        <div
          style={{
            fontSize: 13,
            color: convo.unread ? 'var(--slate-800)' : 'var(--slate-500)',
            fontWeight: convo.unread ? 500 : 400,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {convo.preview || (convo.status === 'pending' ? 'Message request' : 'No messages yet')}
        </div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
        <span style={{ fontSize: 11, color: 'var(--slate-400)' }}>{timeAgo(convo.updatedAt)}</span>
        {convo.unread && <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--slate-900)' }} />}
      </div>
    </button>
  );
}

/// People search → /messages/:username, which reuses an existing thread or
/// starts a new one on first send.
function NewMessageSheet({ onClose }) {
  const navigate = useNavigate();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const me = getSessionUser()?.username?.toLowerCase();

  useEffect(() => {
    const q = query.trim();
    if (!q) {
      setResults([]);
      setError(null);
      setLoading(false);
      return undefined;
    }
    let alive = true;
    setLoading(true);
    // Debounce so each keystroke doesn't hit the backend.
    const timer = setTimeout(async () => {
      try {
        const users = await searchUsers(q);
        if (!alive) return;
        setResults(users.filter((u) => u.username?.toLowerCase() !== me && !isBlockedAuthor(u.username)));
        setError(null);
      } catch (e) {
        if (alive) setError(friendlyError(e));
      } finally {
        if (alive) setLoading(false);
      }
    }, 300);
    return () => {
      alive = false;
      clearTimeout(timer);
    };
  }, [query, me]);

  return (
    <>
      <div style={{ position: 'fixed', inset: 0, background: 'rgba(15,23,42,0.3)', zIndex: 50 }} onClick={onClose} />
      <div
        role="dialog"
        aria-modal="true"
        aria-label="New message"
        style={{
          position: 'fixed',
          bottom: 0,
          left: '50%',
          transform: 'translateX(-50%)',
          width: '100%',
          maxWidth: 390,
          boxSizing: 'border-box',
          borderTopLeftRadius: 'var(--radius-xl)',
          borderTopRightRadius: 'var(--radius-xl)',
          padding: 'var(--space-lg)',
          background: 'rgba(255,255,255,0.92)',
          backdropFilter: 'blur(16px)',
          border: '1px solid rgba(255,255,255,0.45)',
          zIndex: 51,
          height: '75vh',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
          <div style={{ fontSize: 16, fontWeight: 600, color: 'var(--slate-900)' }}>New message</div>
          <button type="button" aria-label="Close" onClick={onClose} style={{ color: 'var(--slate-500)', cursor: 'pointer' }}>
            <X size={20} />
          </button>
        </div>
        <label
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            height: 44,
            padding: '0 14px',
            borderRadius: 9999,
            border: '1.5px solid var(--slate-200)',
            background: 'var(--white)',
            marginBottom: 12,
          }}
        >
          <Search size={16} color="var(--slate-400)" />
          <input
            autoFocus
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search people"
            style={{ flex: 1, border: 'none', outline: 'none', fontSize: 15, background: 'transparent', color: 'var(--slate-700)' }}
          />
        </label>
        <div style={{ flex: 1, overflowY: 'auto' }}>
          {error ? (
            <StateMessage style={{ padding: 24 }}>{error}</StateMessage>
          ) : loading ? (
            <StateMessage style={{ padding: 24 }}>Searching…</StateMessage>
          ) : query.trim() && results.length === 0 ? (
            <StateMessage style={{ padding: 24 }}>No people found.</StateMessage>
          ) : (
            results.map((u) => (
              <button
                key={u.username}
                type="button"
                onClick={() => navigate(`/messages/${encodeURIComponent(u.username)}`)}
                style={{ display: 'flex', alignItems: 'center', gap: 12, width: '100%', padding: '10px 4px', textAlign: 'left', cursor: 'pointer' }}
              >
                <Avatar src={u.profilePhotoUrl} name={u.name} size={40} />
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--slate-900)' }}>{u.name || u.username}</div>
                  <div style={{ fontSize: 12, color: 'var(--slate-500)' }}>@{u.username}</div>
                </div>
              </button>
            ))
          )}
        </div>
      </div>
    </>
  );
}
