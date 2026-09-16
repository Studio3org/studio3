import React, { useEffect, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ChevronLeft, ImageIcon, Send } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useBreakpoint } from '../hooks/useBreakpoint';
import { fetchConversationThread, markConversationRead, sendConversationMessage } from '../services/inboxApi';
import { formatClockTime, formatDayLabel } from '../utils/time';

export function ChatThreadPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { showRail } = useBreakpoint();
  const { user } = useAuth();
  const [thread, setThread] = useState(null);
  const [messages, setMessages] = useState([]);
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const scrollRef = useRef(null);

  useEffect(() => {
    let cancelled = false;
    setThread(null);
    setMessages([]);
    fetchConversationThread(id).then((data) => {
      if (cancelled) return;
      setThread(data);
      setMessages(data.messages);
    });
    markConversationRead(id).catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [id]);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight });
  }, [messages]);

  const send = async () => {
    const body = draft.trim();
    if (!body || sending) return;
    setDraft('');
    setSending(true);
    const optimistic = { id: `pending-${Date.now()}`, body, sender: { username: user?.username }, createdAt: new Date().toISOString(), isPending: true };
    setMessages((m) => [...m, optimistic]);
    try {
      const sent = await sendConversationMessage(id, { body });
      setMessages((m) => m.map((msg) => (msg.id === optimistic.id ? sent : msg)));
    } catch {
      setMessages((m) => m.filter((msg) => msg.id !== optimistic.id));
      setDraft(body);
    } finally {
      setSending(false);
    }
  };

  // On the desktop two-pane layout (InboxLayout), back returns to the empty
  // state instead of popping browser history, which would be surprising when
  // the list is already visible beside the thread.
  const goBack = () => (showRail ? navigate('/inbox') : navigate(-1));

  if (!thread) {
    return (
      <div style={{ background: 'var(--chat-bg)', minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
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
      </div>
    );
  }

  let lastDay = null;

  return (
    <div style={{ background: 'var(--chat-bg)', minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <div style={{ background: 'var(--chat-header-bg)', display: 'flex', alignItems: 'center', padding: '8px 16px 8px 4px', gap: 12 }}>
        <button onClick={goBack} aria-label="Back" style={{ color: 'var(--cream-text)', padding: 8 }}>
          <ChevronLeft size={20} strokeWidth={2} />
        </button>
        <div
          style={{ display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer', flex: 1 }}
          onClick={() => thread.otherPartyUsername && navigate(`/profile?username=${encodeURIComponent(thread.otherPartyUsername)}`)}
        >
          {thread.otherPartyAvatarUrl ? (
            <img
              src={thread.otherPartyAvatarUrl}
              alt=""
              width={36}
              height={36}
              style={{ width: 36, height: 36, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }}
            />
          ) : (
            <span style={{ width: 36, height: 36, borderRadius: '50%', background: 'var(--cream-cta-fill)', flexShrink: 0 }} />
          )}
          <span>
            <div style={{ fontFamily: 'var(--font-inter)', fontSize: 16, fontWeight: 700, color: 'var(--cream-text)' }}>
              {thread.otherPartyName || 'Someone'}
            </div>
            <div style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--chat-username)' }}>
              @{thread.otherPartyUsername || 'unknown'}
            </div>
          </span>
        </div>
      </div>

      <div ref={scrollRef} style={{ flex: 1, padding: '16px', display: 'flex', flexDirection: 'column', gap: 8, overflowY: 'auto' }}>
        {messages.length === 0 && (
          <p style={{ textAlign: 'center', fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--chat-timestamp)', marginTop: 24 }}>
            Say hello — this is the start of your conversation.
          </p>
        )}
        {messages.map((m) => {
          const mine = m.sender?.username === user?.username;
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
                      style={{ maxWidth: '100%', borderRadius: 16, marginBottom: m.body ? 4 : 0, display: 'block' }}
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
                    {formatClockTime(m.createdAt)}
                    {mine && <span style={{ color: seen ? 'var(--chat-seen-blue)' : 'var(--chat-timestamp)' }}>&#10003;&#10003;</span>}
                  </div>
                </div>
              </div>
            </React.Fragment>
          );
        })}
      </div>

      <div style={{ background: 'var(--chat-header-bg)', padding: '12px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <button aria-label="Attach image" style={{ color: 'var(--cream-text)' }}>
          <ImageIcon size={22} strokeWidth={1.75} />
        </button>
        <input
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && send()}
          placeholder="Message..."
          style={{
            flex: 1,
            height: 40,
            borderRadius: 9999,
            border: '1px solid var(--slate-200)',
            background: '#fff',
            padding: '0 16px',
            fontFamily: 'var(--font-inter)',
            fontSize: 14,
            outline: 'none',
          }}
        />
        <button onClick={send} aria-label="Send" style={{ color: 'var(--slate-900)' }}>
          <Send size={20} strokeWidth={1.75} />
        </button>
      </div>
    </div>
  );
}
