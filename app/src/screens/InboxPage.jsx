import React, { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { ChevronLeft, Search } from 'lucide-react';

const TABS = [
  { id: 'notifications', label: 'Notifications', count: 2 },
  { id: 'chats', label: 'Chats', count: 1 },
  { id: 'requests', label: 'Requests', count: 1 },
];

const NOTIFICATIONS = {
  Today: [
    { id: 1, name: 'Alex Chen', text: "saved your piece 'Coastal Forms #3'", unread: true },
    { id: 2, name: 'Jordan Lee', text: 'sent an inquiry about Untitled #12', pill: 'Inquiry', unread: true },
  ],
  Earlier: [
    { id: 3, name: 'Sam Rivera', text: "purchased 'Coastal Forms #3'", pill: 'Sale', time: '2d' },
    { id: 4, name: 'Riley W.', text: 'started following you', time: '4d' },
  ],
};

const CONVERSATIONS = [
  { id: 'c1', name: 'Alex Chen', preview: 'Hi, I’m interested in this piece…', time: '2h', unread: true },
  { id: 'c2', name: 'Sam Rivera', preview: 'Sounds great, thank you!', time: '1d', unread: false },
];

const FOLLOW_REQUESTS = [
  { id: 'r1', name: 'Maya K.', handle: '@maya_k' },
];

export function InboxPage() {
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const [tab, setTab] = useState(params.get('tab') || 'notifications');

  return (
    <div style={{ background: 'var(--cream-bg)', minHeight: '100vh', paddingBottom: 40 }}>
      <div style={{ display: 'flex', alignItems: 'center', padding: '10px 8px 4px', position: 'relative' }}>
        <button onClick={() => navigate(-1)} aria-label="Back" style={{ color: 'var(--cream-text)', padding: 8 }}>
          <ChevronLeft size={20} strokeWidth={2} />
        </button>
        <div style={{ flex: 1, display: 'flex', justifyContent: 'center', gap: 24 }}>
          {TABS.map((t) => (
            <TabButton key={t.id} tab={t} active={tab === t.id} onClick={() => setTab(t.id)} />
          ))}
        </div>
        <div style={{ width: 36 }} />
      </div>

      {tab === 'notifications' && <NotificationsBody />}
      {tab === 'chats' && <ChatsBody onOpen={(id) => navigate(`/inbox/thread/${id}`)} />}
      {tab === 'requests' && <RequestsBody />}
    </div>
  );
}

function TabButton({ tab, active, onClick }) {
  return (
    <button onClick={onClick} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, padding: '6px 0' }}>
      <span style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
        <span
          style={{
            fontFamily: 'var(--font-inter)',
            fontSize: 15,
            color: active ? 'var(--cream-text)' : 'var(--cream-text-secondary)',
          }}
        >
          {tab.label}
        </span>
        {tab.count > 0 && (
          <span
            style={{
              minWidth: 16,
              height: 16,
              padding: '0 4px',
              borderRadius: 8,
              background: '#E05252',
              color: '#fff',
              fontSize: 9,
              fontWeight: 600,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            {tab.count}
          </span>
        )}
      </span>
      <span style={{ width: '100%', height: 1.5, background: active ? 'var(--cream-text)' : 'transparent' }} />
    </button>
  );
}

function GlassRow({ children, onClick }) {
  const Tag = onClick ? 'button' : 'div';
  return (
    <Tag
      onClick={onClick}
      className="glass-light"
      style={{
        width: '100%',
        textAlign: 'left',
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        padding: 12,
        marginBottom: 8,
      }}
    >
      {children}
    </Tag>
  );
}

function NotificationsBody() {
  return (
    <div style={{ padding: '16px 16px 24px' }}>
      {Object.entries(NOTIFICATIONS).map(([section, items]) => (
        <section key={section} style={{ marginBottom: 16 }}>
          <p style={{ fontFamily: 'var(--font-inter)', fontSize: 12, fontWeight: 500, color: 'var(--slate-400)', padding: '4px 4px 8px' }}>
            {section}
          </p>
          {items.map((item) => (
            <GlassRow key={item.id}>
              <span style={{ width: 36, height: 36, borderRadius: '50%', background: 'var(--cream-cta-fill)', flexShrink: 0 }} />
              <span style={{ flex: 1, minWidth: 0, fontFamily: 'var(--font-inter)', fontSize: 14, color: 'var(--slate-700)' }}>
                <strong style={{ color: 'var(--slate-900)', fontWeight: 600 }}>{item.name}</strong> {item.text}
                {item.pill && (
                  <span
                    style={{
                      marginLeft: 6,
                      padding: '2px 8px',
                      borderRadius: 9999,
                      fontSize: 11,
                      background: item.pill === 'Sale' ? 'var(--slate-900)' : 'var(--slate-100)',
                      color: item.pill === 'Sale' ? '#fff' : 'var(--slate-600)',
                      fontWeight: item.pill === 'Sale' ? 600 : 400,
                    }}
                  >
                    {item.pill}
                  </span>
                )}
                {item.unread && (
                  <span style={{ display: 'inline-block', width: 6, height: 6, borderRadius: '50%', background: 'var(--slate-900)', marginLeft: 6 }} />
                )}
              </span>
              {item.time && (
                <span style={{ fontFamily: 'var(--font-inter)', fontSize: 11, color: 'var(--slate-400)', flexShrink: 0 }}>{item.time}</span>
              )}
            </GlassRow>
          ))}
        </section>
      ))}
    </div>
  );
}

function ChatsBody({ onOpen }) {
  const [query, setQuery] = useState('');
  return (
    <div style={{ padding: '12px 16px 24px' }}>
      <div
        style={{
          height: 40,
          borderRadius: 9999,
          background: 'rgba(140,136,128,0.15)',
          display: 'flex',
          alignItems: 'center',
          padding: '0 14px',
          gap: 8,
          marginBottom: 16,
        }}
      >
        <Search size={16} color="var(--cream-text-secondary)" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search your connections"
          style={{ flex: 1, background: 'transparent', outline: 'none', fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text)' }}
        />
      </div>
      {CONVERSATIONS.map((c) => (
        <GlassRow key={c.id} onClick={() => onOpen(c.id)}>
          <span style={{ width: 48, height: 48, borderRadius: '50%', background: 'var(--cream-cta-fill)', flexShrink: 0 }} />
          <span style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontFamily: 'var(--font-inter)', fontSize: 14, fontWeight: 600, color: 'var(--slate-900)' }}>{c.name}</div>
            <div style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--slate-500)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
              {c.preview}
            </div>
          </span>
          <span style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4, flexShrink: 0 }}>
            <span style={{ fontFamily: 'var(--font-inter)', fontSize: 11, color: 'var(--slate-400)' }}>{c.time}</span>
            {c.unread && <span style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--slate-900)' }} />}
          </span>
        </GlassRow>
      ))}
    </div>
  );
}

function RequestsBody() {
  return (
    <div style={{ padding: '12px 16px 24px' }}>
      {FOLLOW_REQUESTS.map((r) => (
        <GlassRow key={r.id}>
          <span style={{ width: 48, height: 48, borderRadius: '50%', background: 'var(--cream-cta-fill)', flexShrink: 0 }} />
          <span style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontFamily: 'var(--font-inter)', fontSize: 14, fontWeight: 600, color: 'var(--slate-900)' }}>{r.name}</div>
            <div style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--slate-500)' }}>{r.handle}</div>
          </span>
          <span style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
            <button style={{ padding: '6px 14px', borderRadius: 9999, background: 'var(--slate-900)', color: '#fff', fontSize: 12, fontWeight: 600 }}>Accept</button>
            <button style={{ padding: '6px 14px', borderRadius: 9999, background: 'var(--slate-100)', color: 'var(--slate-700)', fontSize: 12, fontWeight: 500 }}>Decline</button>
          </span>
        </GlassRow>
      ))}
    </div>
  );
}
