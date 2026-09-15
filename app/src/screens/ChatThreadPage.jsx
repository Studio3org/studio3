import React, { useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ChevronLeft, ImageIcon, Send } from 'lucide-react';

const MOCK_THREAD = {
  c1: {
    name: 'Alex Chen',
    username: 'alexchen',
    online: true,
    messages: [
      { id: 1, mine: false, text: 'Hi! I love your recent piece.', time: '10:02 AM' },
      { id: 2, mine: false, text: 'Is it still available?', time: '10:02 AM' },
      { id: 3, mine: true, text: 'Yes, it is! Thanks for asking.', time: '10:14 AM', seen: true },
    ],
  },
};

export function ChatThreadPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const thread = MOCK_THREAD[id] || MOCK_THREAD.c1;
  const [draft, setDraft] = useState('');
  const [messages, setMessages] = useState(thread.messages);

  const send = () => {
    if (!draft.trim()) return;
    setMessages((m) => [...m, { id: Date.now(), mine: true, text: draft.trim(), time: 'now', seen: false }]);
    setDraft('');
  };

  return (
    <div style={{ background: 'var(--chat-bg)', minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <div style={{ background: 'var(--chat-header-bg)', display: 'flex', alignItems: 'center', padding: '8px 16px 8px 4px', gap: 12 }}>
        <button onClick={() => navigate(-1)} aria-label="Back" style={{ color: 'var(--cream-text)', padding: 8 }}>
          <ChevronLeft size={20} strokeWidth={2} />
        </button>
        <span style={{ position: 'relative', width: 36, height: 36, borderRadius: '50%', background: 'var(--cream-cta-fill)', flexShrink: 0 }}>
          {thread.online && (
            <span
              style={{
                position: 'absolute',
                bottom: -1,
                right: -1,
                width: 10,
                height: 10,
                borderRadius: '50%',
                background: '#22c55e',
                border: '2px solid var(--chat-header-bg)',
              }}
            />
          )}
        </span>
        <span>
          <div style={{ fontFamily: 'var(--font-inter)', fontSize: 16, fontWeight: 700, color: 'var(--cream-text)' }}>{thread.name}</div>
          <div style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--chat-username)' }}>@{thread.username}</div>
        </span>
      </div>

      <div style={{ flex: 1, padding: '16px', display: 'flex', flexDirection: 'column', gap: 8, overflowY: 'auto' }}>
        <div style={{ alignSelf: 'center', padding: '4px 12px', borderRadius: 999, background: 'var(--slate-200)', fontFamily: 'var(--font-inter)', fontSize: 12, fontWeight: 500, color: 'var(--slate-600)' }}>
          Today
        </div>
        {messages.map((m) => (
          <div key={m.id} style={{ display: 'flex', justifyContent: m.mine ? 'flex-end' : 'flex-start' }}>
            <div style={{ maxWidth: '70%' }}>
              <div
                style={{
                  padding: '8px 12px',
                  borderRadius: 16,
                  background: m.mine ? 'var(--chat-sent-bg)' : 'var(--chat-received-bg)',
                  color: m.mine ? '#fff' : 'var(--slate-800)',
                  fontFamily: 'var(--font-inter)',
                  fontSize: 14,
                }}
              >
                {m.text}
              </div>
              <div
                style={{
                  display: 'flex',
                  justifyContent: m.mine ? 'flex-end' : 'flex-start',
                  gap: 4,
                  marginTop: 4,
                  fontFamily: 'var(--font-inter)',
                  fontSize: 11,
                  color: 'var(--chat-timestamp)',
                }}
              >
                {m.time}
                {m.mine && <span style={{ color: m.seen ? 'var(--chat-seen-blue)' : 'var(--chat-timestamp)' }}>&#10003;&#10003;</span>}
              </div>
            </div>
          </div>
        ))}
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
