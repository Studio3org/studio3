import React, { useState } from 'react';
import { GlassCard } from '../components/design/GlassCard';
import { SafeArea } from '../components/layout/SafeArea';

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

const mockInquiries = [
  { id: 1, pieceTitle: 'Coastal Forms #3', subject: 'Purchase inquiry', preview: 'Hi, I’m interested in this piece...', time: '2h', unread: true },
  { id: 2, pieceTitle: 'Untitled (Series 12)', subject: 'Commission', preview: 'Would you consider a similar...', time: '1d', unread: false },
];

export function ChatPage() {
  const [selected, setSelected] = useState(null);
  const [reply, setReply] = useState('');

  return (
    <SafeArea style={{ paddingTop: 0 }}>
      <header style={{ paddingBottom: 16 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700, color: 'var(--slate-900)' }}>Inquiries</h1>
      </header>

      {mockInquiries.length === 0 ? (
        <div style={emptyStateStyle}>
          <div style={{ fontSize: 48, marginBottom: 16 }}>✉</div>
          <p style={{ fontSize: 14, color: 'var(--slate-500)' }}>No inquiries yet</p>
        </div>
      ) : (
        <>
          {mockInquiries.map((inq) => (
            <button
              key={inq.id}
              className="glass-light"
              style={{ ...inboxCardStyle, width: '100%', textAlign: 'left' }}
              onClick={() => setSelected(inq)}
            >
              <div
                style={{
                  width: 48,
                  height: 48,
                  borderRadius: 8,
                  background: 'var(--slate-100)',
                  flexShrink: 0,
                }}
              />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--slate-900)' }}>{inq.pieceTitle}</div>
                <div style={{ fontSize: 13, color: 'var(--slate-500)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {inq.subject} — {inq.preview}
                </div>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
                <span style={{ fontSize: 11, color: 'var(--slate-400)' }}>{inq.time}</span>
                {inq.unread && (
                  <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--slate-900)' }} />
                )}
              </div>
            </button>
          ))}
        </>
      )}

      {selected && (
        <>
          <div
            style={{
              position: 'fixed',
              inset: 0,
              background: 'rgba(15,23,42,0.3)',
              zIndex: 50,
            }}
            onClick={() => setSelected(null)}
          />
          <div
            style={{
              position: 'fixed',
              bottom: 0,
              left: '50%',
              transform: 'translateX(-50%)',
              width: '100%',
              maxWidth: 375,
              borderTopLeftRadius: 'var(--radius-xl)',
              borderTopRightRadius: 'var(--radius-xl)',
              padding: 'var(--space-lg)',
              background: 'rgba(255,255,255,0.72)',
              backdropFilter: 'blur(16px)',
              border: '1px solid rgba(255,255,255,0.45)',
              zIndex: 51,
              maxHeight: '80vh',
              overflow: 'auto',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
              <div style={{ width: 48, height: 48, borderRadius: 8, background: 'var(--slate-100)' }} />
              <div>
                <div style={{ fontSize: 14, fontWeight: 600 }}>{selected.pieceTitle}</div>
                <span style={{ fontSize: 12, padding: '2px 8px', borderRadius: 9999, background: 'var(--slate-100)', color: 'var(--slate-600)' }}>
                  {selected.subject}
                </span>
              </div>
            </div>
            <p style={{ fontSize: 14, color: 'var(--slate-700)', marginBottom: 16 }}>{selected.preview}</p>
            <textarea
              placeholder="Reply..."
              value={reply}
              onChange={(e) => setReply(e.target.value)}
              style={{
                width: '100%',
                minHeight: 80,
                borderRadius: 12,
                border: '1.5px solid var(--slate-200)',
                padding: 12,
                fontSize: 14,
                marginBottom: 12,
              }}
            />
            <button
              style={{
                width: '100%',
                height: 52,
                borderRadius: 9999,
                background: 'var(--slate-900)',
                color: 'var(--white)',
                fontSize: 15,
                fontWeight: 600,
              }}
            >
              Send Reply
            </button>
          </div>
        </>
      )}
    </SafeArea>
  );
}
