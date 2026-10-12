import React, { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom';
import { ChevronLeft, ImagePlus, Send } from 'lucide-react';
import { Avatar } from '../components/common/Avatar';
import { GuestPrompt, StateMessage } from '../components/common/StateMessage';
import { ContentActionsMenu } from '../components/moderation/ContentActionsMenu';
import { getSessionUser } from '../lib/api';
import {
  acceptConversation,
  declineConversation,
  findConversationWith,
  getThread,
  getUserProfile,
  sendMessage,
  startConversation,
  uploadChatImage,
} from '../lib/chatApi';
import { useSession } from '../lib/session';
import { friendlyError } from '../lib/social';

const POLL_MS = 4000;
const DANGER = '#E05252';
/// A centered timestamp is shown when this much time passes between messages.
const GAP_MS = 15 * 60 * 1000;

const pageStyle = {
  height: '100dvh',
  display: 'flex',
  flexDirection: 'column',
  background: 'var(--white)',
};

const headerStyle = {
  display: 'flex',
  alignItems: 'center',
  gap: 8,
  padding: '12px 12px 12px 8px',
  borderBottom: '1px solid var(--slate-100)',
  flexShrink: 0,
};

const iconButton = {
  width: 36,
  height: 36,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  color: 'var(--slate-900)',
  cursor: 'pointer',
  flexShrink: 0,
};

const barButton = (dark) => ({
  flex: 1,
  height: 40,
  borderRadius: 9999,
  fontSize: 14,
  fontWeight: 600,
  border: dark ? 'none' : '1.5px solid var(--slate-200)',
  background: dark ? 'var(--slate-900)' : 'var(--white)',
  color: dark ? 'var(--white)' : 'var(--slate-700)',
  cursor: 'pointer',
});

const sameUser = (a, b) => Boolean(a) && Boolean(b) && a.toLowerCase() === b.toLowerCase();

function formatStamp(iso) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const now = new Date();
  const time = d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  if (d.toDateString() === now.toDateString()) return time;
  const sameYear = d.getFullYear() === now.getFullYear();
  const date = d.toLocaleDateString([], { month: 'short', day: 'numeric', ...(sameYear ? {} : { year: 'numeric' }) });
  return `${date}, ${time}`;
}

/// Merges fetched messages into what's on screen by id (keeps older pages and
/// unsent optimistic messages), sorted oldest → newest.
function mergeMessages(current, incoming) {
  const byId = new Map(current.map((m) => [m.id, m]));
  incoming.forEach((m) => byId.set(m.id, m));
  return [...byId.values()].sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
}

export function ConversationPage() {
  const { conversationId, username } = useParams();
  const { loggedIn } = useSession();
  const location = useLocation();
  if (!loggedIn) {
    return (
      <div style={pageStyle}>
        <GuestPrompt title="Messages" message="Log in to message artists and collectors." next={location.pathname} />
      </div>
    );
  }
  // Keyed so switching /messages/:username → /chat/:id starts fresh.
  return conversationId ? (
    <Thread key={`c:${conversationId}`} conversationId={conversationId} />
  ) : (
    <NewThread key={`u:${username}`} username={username} />
  );
}

function useBack() {
  const navigate = useNavigate();
  return () => (window.history.state?.idx > 0 ? navigate(-1) : navigate('/chat', { replace: true }));
}

function Header({ otherParty, username }) {
  const navigate = useNavigate();
  const back = useBack();
  const handle = otherParty?.username || username;
  const name = otherParty?.name || handle || 'Conversation';
  const isMe = sameUser(handle, getSessionUser()?.username);
  return (
    <header style={headerStyle}>
      <button type="button" aria-label="Back" onClick={back} style={iconButton}>
        <ChevronLeft size={24} />
      </button>
      {handle ? (
        <Link to={`/u/${handle}`} style={{ display: 'flex', alignItems: 'center', gap: 10, flex: 1, minWidth: 0 }}>
          <Avatar src={otherParty?.profilePhotoUrl} name={name} size={36} />
          <div style={{ minWidth: 0 }}>
            <div style={{ fontSize: 15, fontWeight: 600, color: 'var(--slate-900)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {name}
            </div>
            <div style={{ fontSize: 12, color: 'var(--slate-500)' }}>@{handle}</div>
          </div>
        </Link>
      ) : (
        <div style={{ flex: 1 }} />
      )}
      {handle && !isMe && (
        <ContentActionsMenu
          target={{ type: 'user', id: handle }}
          authorUsername={handle}
          onBlocked={() => navigate('/chat', { replace: true })}
          buttonStyle={{ background: 'var(--slate-100)', width: 36, height: 36 }}
        />
      )}
    </header>
  );
}

/// An existing conversation: history, polling, accept/decline, composer.
function Thread({ conversationId }) {
  const me = getSessionUser()?.username;
  const [thread, setThread] = useState(null); // {id, otherParty, otherPartyReadAt, status}
  const [messages, setMessages] = useState([]);
  const [olderCursor, setOlderCursor] = useState(null);
  const [loadingOlder, setLoadingOlder] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [actionError, setActionError] = useState(null);
  const [deciding, setDeciding] = useState(false);
  const polling = useRef(false);
  const scroller = useRef(null);
  const stickToBottom = useRef(true);

  const applyThread = useCallback((data) => {
    setThread({ id: data.id, otherParty: data.otherParty, otherPartyReadAt: data.otherPartyReadAt, status: data.status });
  }, []);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const data = await getThread(conversationId);
        if (!alive) return;
        applyThread(data);
        setMessages(data.messages);
        setOlderCursor(data.olderCursor);
      } catch (e) {
        if (alive) setError(e);
      } finally {
        if (alive) setLoading(false);
      }
    })();
    return () => {
      alive = false;
    };
  }, [conversationId, applyThread]);

  // Poll for new messages / read receipts while the tab is visible.
  useEffect(() => {
    if (loading || error) return undefined;
    let alive = true;
    const poll = async () => {
      if (polling.current || document.visibilityState !== 'visible') return;
      polling.current = true;
      try {
        const data = await getThread(conversationId);
        if (!alive) return;
        applyThread(data);
        setMessages((prev) => mergeMessages(prev, data.messages));
      } catch {
        // Transient — try again on the next tick.
      } finally {
        polling.current = false;
      }
    };
    const timer = setInterval(poll, POLL_MS);
    const onVisible = () => document.visibilityState === 'visible' && poll();
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      alive = false;
      clearInterval(timer);
      document.removeEventListener('visibilitychange', onVisible);
    };
  }, [conversationId, loading, error, applyThread]);

  // Follow the conversation down unless the reader scrolled up to read history.
  useLayoutEffect(() => {
    const el = scroller.current;
    if (el && stickToBottom.current) el.scrollTop = el.scrollHeight;
  }, [messages]);

  const onScroll = () => {
    const el = scroller.current;
    if (el) stickToBottom.current = el.scrollHeight - el.scrollTop - el.clientHeight < 80;
  };

  const loadOlder = async () => {
    if (!olderCursor || loadingOlder) return;
    setLoadingOlder(true);
    const el = scroller.current;
    const fromBottom = el ? el.scrollHeight - el.scrollTop : 0;
    try {
      const data = await getThread(conversationId, olderCursor);
      stickToBottom.current = false;
      setMessages((prev) => mergeMessages(prev, data.messages));
      setOlderCursor(data.olderCursor);
      // Keep the reader's place after older messages are prepended.
      requestAnimationFrame(() => {
        if (el) el.scrollTop = el.scrollHeight - fromBottom;
      });
    } catch (e) {
      setActionError(friendlyError(e));
    } finally {
      setLoadingOlder(false);
    }
  };

  const send = async ({ body, imageUrl }) => {
    const tempId = `temp-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    stickToBottom.current = true;
    setMessages((prev) => [
      ...prev,
      {
        id: tempId,
        body: body ?? null,
        imageUrl: imageUrl ?? null,
        sender: { username: me },
        createdAt: new Date().toISOString(),
        pending: true,
      },
    ]);
    try {
      const saved = await sendMessage(conversationId, { body, imageUrl });
      setMessages((prev) => mergeMessages(prev.filter((m) => m.id !== tempId), [saved]));
      // Replying to a request accepts it on the backend.
      setThread((t) => (t && t.status === 'pending' ? { ...t, status: 'open' } : t));
    } catch (e) {
      setMessages((prev) => prev.filter((m) => m.id !== tempId));
      throw e;
    }
  };

  const decide = async (accept) => {
    if (deciding) return;
    setDeciding(true);
    setActionError(null);
    try {
      const res = accept ? await acceptConversation(conversationId) : await declineConversation(conversationId);
      setThread((t) => ({ ...t, status: res?.status ?? (accept ? 'open' : 'closed') }));
    } catch (e) {
      setActionError(friendlyError(e));
    } finally {
      setDeciding(false);
    }
  };

  if (loading) {
    return (
      <div style={pageStyle}>
        <Header />
        <StateMessage>Loading…</StateMessage>
      </div>
    );
  }
  if (error) {
    return (
      <div style={pageStyle}>
        <Header />
        <StateMessage>{error.status === 404 ? 'This conversation is no longer available.' : friendlyError(error)}</StateMessage>
      </div>
    );
  }

  const mine = (m) => m.pending || sameUser(m.sender?.username, me);
  const isRequestForMe = thread.status === 'pending' && messages.length > 0 && !messages.some(mine);
  const closed = thread.status === 'closed';
  const lastMineIndex = messages.map(mine).lastIndexOf(true);
  const lastMine = lastMineIndex >= 0 ? messages[lastMineIndex] : null;
  const seen =
    lastMine &&
    !lastMine.pending &&
    thread.otherPartyReadAt &&
    new Date(thread.otherPartyReadAt) >= new Date(lastMine.createdAt);

  return (
    <div style={pageStyle}>
      <Header otherParty={thread.otherParty} />
      <div ref={scroller} onScroll={onScroll} style={{ flex: 1, overflowY: 'auto', padding: '12px 12px 8px' }}>
        {olderCursor && (
          <div style={{ textAlign: 'center', marginBottom: 12 }}>
            <button
              type="button"
              onClick={loadOlder}
              disabled={loadingOlder}
              style={{ fontSize: 13, fontWeight: 600, color: 'var(--slate-500)', cursor: 'pointer' }}
            >
              {loadingOlder ? 'Loading…' : 'Load earlier messages'}
            </button>
          </div>
        )}
        {messages.length === 0 && <StateMessage>No messages yet. Say hello.</StateMessage>}
        {messages.map((m, i) => {
          const prev = messages[i - 1];
          const showStamp = !prev || new Date(m.createdAt) - new Date(prev.createdAt) > GAP_MS;
          return (
            <React.Fragment key={m.id}>
              {showStamp && (
                <div style={{ textAlign: 'center', fontSize: 11, color: 'var(--slate-400)', margin: '12px 0 8px' }}>
                  {formatStamp(m.createdAt)}
                </div>
              )}
              <Bubble message={m} mine={mine(m)} />
              {m === lastMine && seen && (
                <div style={{ textAlign: 'right', fontSize: 11, color: 'var(--slate-400)', margin: '2px 4px 0' }}>Seen</div>
              )}
            </React.Fragment>
          );
        })}
      </div>

      {actionError && <div style={{ color: DANGER, fontSize: 13, padding: '0 16px 8px' }}>{actionError}</div>}

      {isRequestForMe && (
        <div style={{ padding: '12px 16px', borderTop: '1px solid var(--slate-100)', flexShrink: 0 }}>
          <div style={{ fontSize: 13, color: 'var(--slate-600)', marginBottom: 10, textAlign: 'center' }}>
            {thread.otherParty?.name || thread.otherParty?.username || 'This person'} wants to message you.
            Accept to move this into your chats, or decline to close it.
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button type="button" style={barButton(false)} disabled={deciding} onClick={() => decide(false)}>
              Decline
            </button>
            <button type="button" style={barButton(true)} disabled={deciding} onClick={() => decide(true)}>
              Accept
            </button>
          </div>
        </div>
      )}

      {closed ? (
        <div style={{ padding: '14px 16px calc(14px + env(safe-area-inset-bottom))', borderTop: '1px solid var(--slate-100)', textAlign: 'center', fontSize: 13, color: 'var(--slate-500)', flexShrink: 0 }}>
          This conversation is closed. You can't send new messages here.
        </div>
      ) : (
        <Composer onSend={send} />
      )}
    </div>
  );
}

/// /messages/:username — reuse an existing thread, or start one on first send.
function NewThread({ username }) {
  const navigate = useNavigate();
  const me = getSessionUser()?.username;
  const [profile, setProfile] = useState(null);
  const [checking, setChecking] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const existing = await findConversationWith(username);
        if (!alive) return;
        if (existing?.id) {
          navigate(`/chat/${existing.id}`, { replace: true });
          return;
        }
        const user = await getUserProfile(username).catch((e) => {
          if (e.status === 404) throw e;
          return null; // header falls back to the handle
        });
        if (alive) setProfile(user);
      } catch (e) {
        if (alive) setError(e);
      } finally {
        if (alive) setChecking(false);
      }
    })();
    return () => {
      alive = false;
    };
  }, [username, navigate]);

  const send = async ({ body, imageUrl }) => {
    const res = await startConversation(username, { message: body, imageUrl });
    navigate(`/chat/${res.id}`, { replace: true });
  };

  const otherParty = profile ? { username: profile.username, name: profile.name, profilePhotoUrl: profile.profilePhotoUrl } : { username };

  let body;
  if (sameUser(username, me)) body = <StateMessage>You can't message yourself.</StateMessage>;
  else if (checking) body = <StateMessage>Loading…</StateMessage>;
  else if (error) body = <StateMessage>{error.status === 404 ? 'This account isn’t available.' : friendlyError(error)}</StateMessage>;
  else body = <StateMessage>Send a message to start the conversation.</StateMessage>;

  const canCompose = !checking && !error && !sameUser(username, me);
  return (
    <div style={pageStyle}>
      <Header otherParty={otherParty} username={username} />
      <div style={{ flex: 1, overflowY: 'auto' }}>{body}</div>
      {canCompose && <Composer onSend={send} />}
    </div>
  );
}

function Bubble({ message, mine }) {
  return (
    <div style={{ display: 'flex', justifyContent: mine ? 'flex-end' : 'flex-start', marginBottom: 4 }}>
      <div
        title={formatStamp(message.createdAt)}
        style={{
          maxWidth: '75%',
          borderRadius: 18,
          borderBottomRightRadius: mine ? 6 : 18,
          borderBottomLeftRadius: mine ? 18 : 6,
          background: mine ? 'var(--slate-900)' : 'var(--slate-100)',
          color: mine ? 'var(--white)' : 'var(--slate-900)',
          fontSize: 14,
          lineHeight: 1.4,
          overflow: 'hidden',
          opacity: message.pending ? 0.6 : 1,
          wordBreak: 'break-word',
          whiteSpace: 'pre-wrap',
        }}
      >
        {message.imageUrl && (
          <a href={message.imageUrl} target="_blank" rel="noreferrer">
            <img
              src={message.imageUrl}
              alt="Photo"
              style={{ display: 'block', width: '100%', maxWidth: 240, maxHeight: 320, objectFit: 'cover' }}
            />
          </a>
        )}
        {message.body && <div style={{ padding: '8px 14px' }}>{message.body}</div>}
      </div>
    </div>
  );
}

/// Text + photo composer. `onSend({body?, imageUrl?})` may throw; the error is
/// shown here (incl. 403s when the recipient doesn't accept messages).
function Composer({ onSend }) {
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState(null);
  const fileInput = useRef(null);

  const showError = (e) => setError(e?.status === 403 && !/onboarding/i.test(e.message) ? e.message : friendlyError(e));

  const submit = async (e) => {
    e?.preventDefault();
    const body = text.trim();
    if (!body || busy) return;
    setBusy(true);
    setError(null);
    setText('');
    try {
      await onSend({ body });
    } catch (err) {
      setText(body); // give the draft back so nothing is lost
      showError(err);
    } finally {
      setBusy(false);
    }
  };

  const pickImage = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file || busy) return;
    setBusy(true);
    setUploading(true);
    setError(null);
    try {
      const imageUrl = await uploadChatImage(file);
      setUploading(false);
      await onSend({ imageUrl });
    } catch (err) {
      showError(err);
    } finally {
      setBusy(false);
      setUploading(false);
    }
  };

  return (
    <form
      onSubmit={submit}
      style={{ padding: '8px 12px calc(10px + env(safe-area-inset-bottom))', borderTop: '1px solid var(--slate-100)', flexShrink: 0, background: 'var(--white)' }}
    >
      {error && <div role="alert" style={{ color: DANGER, fontSize: 13, margin: '0 4px 8px' }}>{error}</div>}
      {uploading && <div style={{ color: 'var(--slate-500)', fontSize: 12, margin: '0 4px 8px' }}>Uploading photo…</div>}
      <div style={{ display: 'flex', alignItems: 'flex-end', gap: 8 }}>
        <button type="button" aria-label="Send a photo" disabled={busy} onClick={() => fileInput.current?.click()} style={{ ...iconButton, color: 'var(--slate-600)', height: 44 }}>
          <ImagePlus size={22} />
        </button>
        <input ref={fileInput} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={pickImage} />
        <textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) submit(e);
          }}
          rows={1}
          maxLength={2000}
          placeholder="Message…"
          style={{
            flex: 1,
            minHeight: 44,
            maxHeight: 120,
            resize: 'none',
            borderRadius: 22,
            border: '1.5px solid var(--slate-200)',
            padding: '11px 16px',
            fontSize: 15,
            fontFamily: 'inherit',
            color: 'var(--slate-700)',
            outline: 'none',
            boxSizing: 'border-box',
          }}
        />
        <button
          type="submit"
          aria-label="Send"
          disabled={!text.trim() || busy}
          style={{
            width: 44,
            height: 44,
            borderRadius: '50%',
            background: text.trim() && !busy ? 'var(--slate-900)' : 'var(--slate-200)',
            color: 'var(--white)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
            cursor: text.trim() && !busy ? 'pointer' : 'default',
          }}
        >
          <Send size={18} />
        </button>
      </div>
    </form>
  );
}
