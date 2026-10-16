import React, { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { User as UserIcon } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useBreakpoint } from '../hooks/useBreakpoint';
import {
  acceptConversationRequest,
  declineConversationRequest,
  fetchConversationThread,
  sendConversationMessage,
} from '../services/inboxApi';
import { uploadMedia } from '../services/postingApi';
import { friendlyError } from '../services/socialApi';
import { useToast } from '../components/common/ActionSheet';
import { ContentActionsSheet } from '../components/moderation/ContentActions';
import { ChatComposer, isSendableImage } from '../components/inbox/ChatComposer';
import { ChatHeader } from '../components/inbox/ChatHeader';
import { profileHref } from '../utils/contentLinks';
import { formatClockTime, formatDayLabel } from '../utils/time';

const POLL_MS = 4000;
const NEAR_BOTTOM_PX = 120;

/// Whichever ancestor actually scrolls the thread: the inbox's right pane on desktop,
/// the window on phones (the page itself grows).
function getScrollParent(node) {
  for (let el = node?.parentElement; el; el = el.parentElement) {
    const { overflowY } = getComputedStyle(el);
    if ((overflowY === 'auto' || overflowY === 'scroll') && el.scrollHeight > el.clientHeight) return el;
  }
  return document.scrollingElement || document.documentElement;
}

/// Appends messages we don't have yet (by id), oldest-first.
function mergeNewer(current, incoming) {
  const known = new Set(current.map((m) => m.id));
  const fresh = incoming.filter((m) => !known.has(m.id));
  if (fresh.length === 0) return current;
  return [...current, ...fresh].sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
}

export function ChatThreadPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { showRail } = useBreakpoint();
  const { user } = useAuth();
  const [thread, setThread] = useState(null);
  const [loadError, setLoadError] = useState(null);
  const [messages, setMessages] = useState([]);
  const [olderCursor, setOlderCursor] = useState(null);
  const [loadingOlder, setLoadingOlder] = useState(false);
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const [responding, setResponding] = useState(false);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [toast, showToast] = useToast();
  const rootRef = useRef(null);
  /// What the next messages render should do to the scroll position.
  const scrollIntent = useRef(null); // {kind:'bottom'} | {kind:'keep', height, top} | null
  const pollBusy = useRef(false);
  const requestReceivedRef = useRef(false);

  const scroller = () => getScrollParent(rootRef.current);
  const isNearBottom = () => {
    const el = scroller();
    return el.scrollHeight - el.scrollTop - el.clientHeight < NEAR_BOTTOM_PX;
  };

  useEffect(() => {
    let cancelled = false;
    setThread(null);
    setLoadError(null);
    setMessages([]);
    setOlderCursor(null);
    // Fetching the thread also marks it read server-side.
    fetchConversationThread(id)
      .then((data) => {
        if (cancelled) return;
        scrollIntent.current = { kind: 'bottom' };
        setThread(data);
        setMessages(data.messages);
        setOlderCursor(data.nextCursor);
      })
      .catch((e) => !cancelled && setLoadError(friendlyError(e)));
    return () => {
      cancelled = true;
    };
  }, [id]);

  useLayoutEffect(() => {
    const intent = scrollIntent.current;
    if (!intent || !rootRef.current) return;
    scrollIntent.current = null;
    const el = scroller();
    if (intent.kind === 'bottom') {
      el.scrollTop = el.scrollHeight;
    } else if (intent.kind === 'keep') {
      // Older page prepended: hold the messages the reader was looking at in place.
      el.scrollTop = intent.top + (el.scrollHeight - intent.height);
    }
  }, [messages]);

  const hasThread = Boolean(thread);

  /// Poll for new messages every 4s while the tab is visible — REST only, merged by id.
  useEffect(() => {
    if (!hasThread) return undefined;
    let cancelled = false;
    const poll = async () => {
      if (document.visibilityState !== 'visible' || pollBusy.current) return;
      pollBusy.current = true;
      try {
        const data = await fetchConversationThread(id, { limit: 30 });
        if (cancelled) return;
        const near = isNearBottom();
        setThread((t) => (t ? { ...t, status: data.status, otherPartyReadAt: data.otherPartyReadAt } : t));
        setMessages((current) => {
          const next = mergeNewer(current, data.messages);
          if (next !== current && near) scrollIntent.current = { kind: 'bottom' };
          return next;
        });
      } catch {
        /* transient — the next tick retries */
      } finally {
        pollBusy.current = false;
      }
    };
    const timer = setInterval(poll, POLL_MS);
    const onVisible = () => document.visibilityState === 'visible' && poll();
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      cancelled = true;
      clearInterval(timer);
      document.removeEventListener('visibilitychange', onVisible);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id, hasThread]);

  const loadOlder = async () => {
    if (!olderCursor || loadingOlder) return;
    setLoadingOlder(true);
    try {
      const data = await fetchConversationThread(id, { cursor: olderCursor });
      const el = scroller();
      scrollIntent.current = { kind: 'keep', height: el.scrollHeight, top: el.scrollTop };
      setMessages((current) => {
        const known = new Set(current.map((m) => m.id));
        return [...data.messages.filter((m) => !known.has(m.id)), ...current];
      });
      setOlderCursor(data.nextCursor);
    } catch (e) {
      showToast(friendlyError(e));
    } finally {
      setLoadingOlder(false);
    }
  };

  /// Optimistic bubble → real message. If a poll already delivered the real one, just
  /// drop the placeholder.
  const sendOptimistic = useCallback(
    async (optimistic, doSend, onFail) => {
      scrollIntent.current = { kind: 'bottom' };
      setMessages((m) => [...m, optimistic]);
      setSending(true);
      try {
        const sent = await doSend();
        setMessages((m) =>
          m.some((msg) => msg.id === sent.id)
            ? m.filter((msg) => msg.id !== optimistic.id)
            : m.map((msg) => (msg.id === optimistic.id ? sent : msg)),
        );
        // Replying to a request you received accepts it server-side (your own follow-ups
        // to a request you sent don't).
        if (requestReceivedRef.current) setThread((t) => (t && t.status === 'pending' ? { ...t, status: 'open' } : t));
      } catch (e) {
        setMessages((m) => m.filter((msg) => msg.id !== optimistic.id));
        showToast(friendlyError(e));
        onFail?.();
      } finally {
        setSending(false);
      }
    },
    [showToast],
  );

  const send = () => {
    const body = draft.trim();
    if (!body || sending) return;
    setDraft('');
    const optimistic = {
      id: `pending-${Date.now()}`,
      body,
      sender: { username: user?.username },
      createdAt: new Date().toISOString(),
      isPending: true,
    };
    sendOptimistic(optimistic, () => sendConversationMessage(id, { body }), () => setDraft(body));
  };

  const sendImage = (file) => {
    if (sending) return;
    if (!isSendableImage(file)) {
      showToast('Choose a JPEG, PNG or WebP image.');
      return;
    }
    const localUrl = URL.createObjectURL(file);
    const optimistic = {
      id: `pending-${Date.now()}`,
      imageUrl: localUrl,
      sender: { username: user?.username },
      createdAt: new Date().toISOString(),
      isPending: true,
    };
    sendOptimistic(optimistic, async () => {
      try {
        const imageUrl = await uploadMedia(file, 'chat');
        return await sendConversationMessage(id, { imageUrl });
      } finally {
        // The bubble is replaced (or removed) right after this resolves.
        setTimeout(() => URL.revokeObjectURL(localUrl), 1000);
      }
    });
  };

  const respond = async (accept) => {
    if (responding) return;
    setResponding(true);
    try {
      const res = accept ? await acceptConversationRequest(id) : await declineConversationRequest(id);
      setThread((t) => ({ ...t, status: res?.status || (accept ? 'open' : 'closed') }));
    } catch (e) {
      showToast(friendlyError(e));
    } finally {
      setResponding(false);
    }
  };

  // On the desktop two-pane layout (InboxLayout), back returns to the empty
  // state instead of popping browser history, which would be surprising when
  // the list is already visible beside the thread.
  const goBack = () => (showRail ? navigate('/inbox?tab=chats') : navigate(-1));

  if (!thread) {
    return (
      <div style={{ background: 'var(--chat-bg)', minHeight: '100vh', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 12 }}>
        {loadError ? (
          <>
            <p style={{ fontFamily: 'var(--font-inter)', fontSize: 14, color: 'var(--cream-text-secondary)' }}>{loadError}</p>
            <button
              onClick={goBack}
              style={{ padding: '6px 14px', borderRadius: 9999, background: 'var(--slate-900)', color: '#fff', fontSize: 12, fontWeight: 600 }}
            >
              Back to inbox
            </button>
          </>
        ) : (
          <span
            style={{
              width: 20,
              height: 20,
              borderRadius: '50%',
              border: '2px solid var(--slate-200)',
              borderTopColor: 'var(--slate-900)',
              animation: 'app-spin 0.7s linear infinite',
            }}
          />
        )}
      </div>
    );
  }

  const me = user?.username?.toLowerCase();
  // A missing sender (deleted account) is never us; our optimistic bubbles always are.
  const fromOther = (m) => !m.isPending && (m.sender?.username || '').toLowerCase() !== me;
  // Only the initiator can have messages in a pending thread (a reply accepts it), so a
  // pending thread with their messages is a request we received.
  const requestReceived = thread.status === 'pending' && messages.some(fromOther);
  const requestSent = thread.status === 'pending' && !requestReceived;
  requestReceivedRef.current = requestReceived;
  const otherName = thread.otherPartyName || thread.otherPartyUsername || 'them';

  let lastDay = null;

  return (
    <div ref={rootRef} style={{ background: 'var(--chat-bg)', minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <ChatHeader
        onBack={goBack}
        name={thread.otherPartyName}
        username={thread.otherPartyUsername}
        avatarUrl={thread.otherPartyAvatarUrl}
        onMore={thread.otherPartyUsername ? () => setSheetOpen(true) : undefined}
      />

      <div style={{ flex: 1, padding: '16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {olderCursor && (
          <button
            onClick={loadOlder}
            disabled={loadingOlder}
            style={{
              alignSelf: 'center',
              padding: '4px 12px',
              borderRadius: 999,
              background: 'var(--slate-200)',
              fontFamily: 'var(--font-inter)',
              fontSize: 12,
              fontWeight: 500,
              color: 'var(--slate-600)',
            }}
          >
            {loadingOlder ? 'Loading…' : 'Load earlier messages'}
          </button>
        )}
        {messages.length === 0 && (
          <p style={{ textAlign: 'center', fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--chat-timestamp)', marginTop: 24 }}>
            Say hello — this is the start of your conversation.
          </p>
        )}
        {messages.map((m) => {
          const mine = !fromOther(m);
          const dayLabel = formatDayLabel(m.createdAt);
          const showDivider = dayLabel !== lastDay;
          lastDay = dayLabel;
          const seen = mine && thread.otherPartyReadAt && new Date(m.createdAt) <= new Date(thread.otherPartyReadAt);
          return (
            <React.Fragment key={m.id}>
              {showDivider && (
                <div
                  style={{
                    alignSelf: 'center',
                    padding: '4px 12px',
                    borderRadius: 999,
                    background: 'var(--slate-200)',
                    fontFamily: 'var(--font-inter)',
                    fontSize: 12,
                    fontWeight: 500,
                    color: 'var(--slate-600)',
                  }}
                >
                  {dayLabel}
                </div>
              )}
              <div style={{ display: 'flex', justifyContent: mine ? 'flex-end' : 'flex-start' }}>
                <div style={{ maxWidth: '70%', opacity: m.isPending ? 0.6 : 1 }}>
                  {m.imageUrl && (
                    <img
                      src={m.imageUrl}
                      alt=""
                      onLoad={() => {
                        // Images grow the thread after layout; stay pinned if we were at the end.
                        const el = scroller();
                        if (m.isPending || el.scrollHeight - el.scrollTop - el.clientHeight < NEAR_BOTTOM_PX + 400) {
                          el.scrollTop = el.scrollHeight;
                        }
                      }}
                      style={{ maxWidth: '100%', maxHeight: 360, borderRadius: 16, marginBottom: m.body ? 4 : 0, display: 'block' }}
                    />
                  )}
                  {m.body && (
                    <div
                      style={{
                        padding: '8px 12px',
                        borderRadius: 16,
                        background: mine ? 'var(--chat-sent-bg)' : 'var(--chat-received-bg)',
                        color: mine ? '#fff' : 'var(--slate-800)',
                        fontFamily: 'var(--font-inter)',
                        fontSize: 14,
                        whiteSpace: 'pre-wrap',
                        overflowWrap: 'anywhere',
                      }}
                    >
                      {m.body}
                    </div>
                  )}
                  <div
                    style={{
                      display: 'flex',
                      justifyContent: mine ? 'flex-end' : 'flex-start',
                      gap: 4,
                      marginTop: 4,
                      fontFamily: 'var(--font-inter)',
                      fontSize: 11,
                      color: 'var(--chat-timestamp)',
                    }}
                  >
                    {m.isPending ? 'Sending…' : formatClockTime(m.createdAt)}
                    {mine && !m.isPending && (
                      <span style={{ color: seen ? 'var(--chat-seen-blue)' : 'var(--chat-timestamp)' }}>&#10003;&#10003;</span>
                    )}
                  </div>
                </div>
              </div>
            </React.Fragment>
          );
        })}
      </div>

      {requestReceived && (
        <div
          style={{
            background: 'var(--chat-header-bg)',
            borderTop: '1px solid var(--slate-200)',
            padding: '12px 16px',
            display: 'flex',
            alignItems: 'center',
            gap: 12,
          }}
        >
          <span style={{ flex: 1, minWidth: 0, fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--slate-600)' }}>
            {otherName} wants to send you a message.
          </span>
          <button
            onClick={() => respond(true)}
            disabled={responding}
            style={{ padding: '6px 14px', borderRadius: 9999, background: 'var(--slate-900)', color: '#fff', fontSize: 12, fontWeight: 600 }}
          >
            Accept
          </button>
          <button
            onClick={() => respond(false)}
            disabled={responding}
            style={{ padding: '6px 14px', borderRadius: 9999, background: 'var(--slate-100)', color: 'var(--slate-700)', fontSize: 12, fontWeight: 500 }}
          >
            Decline
          </button>
        </div>
      )}
      {requestSent && (
        <p
          style={{
            textAlign: 'center',
            padding: '8px 16px',
            fontFamily: 'var(--font-inter)',
            fontSize: 12,
            color: 'var(--chat-timestamp)',
          }}
        >
          {otherName} hasn't accepted your message request yet.
        </p>
      )}

      <ChatComposer
        value={draft}
        onChange={setDraft}
        onSend={send}
        onPickImage={sendImage}
        busy={sending}
        disabledNote={thread.status === 'closed' ? 'This conversation is closed. You can’t send messages here.' : null}
      />

      {sheetOpen && (
        <ContentActionsSheet
          target={{ type: 'user', id: thread.otherPartyUsername }}
          authorUsername={thread.otherPartyUsername}
          items={[
            {
              label: 'View profile',
              icon: <UserIcon size={18} />,
              onClick: () => {
                setSheetOpen(false);
                navigate(profileHref(thread.otherPartyUsername));
              },
            },
          ]}
          onClose={() => setSheetOpen(false)}
          onBlocked={() => navigate('/inbox?tab=chats')}
          onNotice={showToast}
        />
      )}
      {toast}
    </div>
  );
}
