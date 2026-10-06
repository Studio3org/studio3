import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { Bell, MessageCircle } from 'lucide-react';
import { PieceCard } from '../components/feed/PieceCard';
import { SafeArea } from '../components/layout/SafeArea';

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

const feedItems = [
  { id: 1, title: 'Coastal Forms #3', storyPreview: 'A meditation on erosion and time...', artistName: 'Jordan Lee', medium: 'Oil', forSale: true, price: '2,400' },
  { id: 2, title: 'Studio Notes — January', storyPreview: 'Exploring new pigments...', artistName: 'Alex Chen', medium: 'Mixed Media', isProcess: true },
  { id: 3, title: 'Untitled (Series 12)', storyPreview: 'Minimalist study in light.', artistName: 'Sam Rivera', medium: 'Photography', forSale: false },
];

export function HomeFeedPage() {
  const [tab, setTab] = useState('foryou');
  const [inboxOpen, setInboxOpen] = useState(false);

  return (
    <SafeArea style={{ paddingTop: 0 }}>
      <header style={headerStyle}>
        <h1 style={{ fontSize: 20, fontWeight: 700, color: 'var(--slate-900)' }}>Studio 3</h1>
        <div style={{ position: 'relative' }}>
          <button
            aria-label="Notifications and chats"
            onClick={() => setInboxOpen((open) => !open)}
            style={{ display: 'flex', alignItems: 'center', color: 'var(--slate-700)', padding: 4 }}
          >
            <Bell size={22} strokeWidth={1.75} />
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
                <InboxMenuLink
                  to="/notifications"
                  icon={<Bell size={17} strokeWidth={1.75} />}
                  label="Notifications"
                  onClick={() => setInboxOpen(false)}
                />
                <InboxMenuLink
                  to="/chat"
                  icon={<MessageCircle size={17} strokeWidth={1.75} />}
                  label="Chats"
                  onClick={() => setInboxOpen(false)}
                />
              </div>
            </>
          )}
        </div>
      </header>

      <div style={{ display: 'flex', gap: 8, marginBottom: 16, marginTop: 12 }}>
        <button style={tabStyle(tab === 'foryou')} onClick={() => setTab('foryou')}>For You</button>
        <button style={tabStyle(tab === 'following')} onClick={() => setTab('following')}>Following</button>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        {feedItems.map((item) => (
          <PieceCard key={item.id} {...item} />
        ))}
      </div>
    </SafeArea>
  );
}

function InboxMenuLink({ to, icon, label, onClick }) {
  return (
    <Link
      to={to}
      onClick={onClick}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        padding: '10px 12px',
        borderRadius: 'var(--radius-md)',
        fontSize: 14,
        fontWeight: 500,
        color: 'var(--slate-900)',
      }}
    >
      {icon}
      {label}
    </Link>
  );
}
