import React, { useState } from 'react';
import { PieceCard } from '../components/feed/PieceCard';
import { SafeArea } from '../components/layout/SafeArea';

const searchBarStyle = {
  height: 44,
  borderRadius: 9999,
  background: 'var(--slate-100)',
  padding: '0 16px',
  display: 'flex',
  alignItems: 'center',
  gap: 8,
  flex: 1,
  fontSize: 14,
  color: 'var(--slate-500)',
};

const chipScroll = {
  display: 'flex',
  gap: 8,
  overflowX: 'auto',
  paddingBottom: 4,
  marginBottom: 24,
};
const chipStyle = (active) => ({
  height: 32,
  padding: '0 16px',
  borderRadius: 9999,
  flexShrink: 0,
  fontSize: 13,
  fontWeight: 500,
  background: active ? 'var(--slate-900)' : 'var(--slate-100)',
  color: active ? 'var(--white)' : 'var(--slate-600)',
  border: '1.5px solid',
  borderColor: active ? 'var(--slate-900)' : 'var(--slate-200)',
});

const sectionTitle = {
  fontSize: 16,
  fontWeight: 600,
  color: 'var(--slate-900)',
  marginBottom: 12,
  display: 'flex',
  justifyContent: 'space-between',
  alignItems: 'center',
};
const horizontalScroll = {
  display: 'flex',
  gap: 12,
  overflowX: 'auto',
  paddingBottom: 8,
  marginBottom: 24,
};
const portraitCard = {
  width: 160,
  flexShrink: 0,
  height: 200,
  borderRadius: 16,
  overflow: 'hidden',
  position: 'relative',
  background: 'var(--slate-100)',
};
const artistChip = {
  display: 'flex',
  alignItems: 'center',
  gap: 10,
  padding: '8px 12px',
  borderRadius: 16,
  border: '1.5px solid var(--slate-200)',
  background: 'var(--white)',
  flexShrink: 0,
};

export function DiscoverPage() {
  const [filter, setFilter] = useState('All');
  const filters = ['All', 'Painting', 'Sculpture', 'Photography', 'Digital', 'Available'];

  return (
    <SafeArea style={{ paddingTop: 0 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
        <div style={searchBarStyle}>
          <span>🔍</span> Search
        </div>
        <button style={{ padding: 8, color: 'var(--slate-700)' }} aria-label="Filter">⚙</button>
      </div>

      <div style={chipScroll}>
        {filters.map((f) => (
          <button key={f} style={chipStyle(filter === f)} onClick={() => setFilter(f)}>{f}</button>
        ))}
      </div>

      <section>
        <div style={sectionTitle}>
          <span>Studio 3 Picks</span>
          <button style={{ fontSize: 13, color: 'var(--slate-500)', fontWeight: 400 }}>See all</button>
        </div>
        <div style={horizontalScroll}>
          {[1, 2, 3, 4].map((i) => (
            <div key={i} style={portraitCard}>
              <div style={{ width: '100%', height: '100%', background: 'var(--slate-200)' }} />
              <div
                style={{
                  position: 'absolute',
                  bottom: 0,
                  left: 0,
                  right: 0,
                  padding: 10,
                  background: 'rgba(15,23,42,0.55)',
                  backdropFilter: 'blur(12px)',
                  borderRadius: '0 0 16px 16px',
                  fontSize: 12,
                  fontWeight: 600,
                  color: 'var(--white)',
                }}
              >
                Piece title {i}
              </div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <div style={{ ...sectionTitle, marginBottom: 12 }}>Process Spotlight</div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginBottom: 24 }}>
          {[1, 2, 3, 4].map((i) => (
            <div key={i} style={{ borderRadius: 16, overflow: 'hidden', aspectRatio: '1', background: 'var(--slate-100)' }} />
          ))}
        </div>
      </section>

      <section>
        <div style={sectionTitle}>
          <span>New Voices</span>
          <button style={{ fontSize: 13, color: 'var(--slate-500)' }}>See all</button>
        </div>
        <div style={horizontalScroll}>
          {['Maya K.', 'James T.', 'Riley W.'].map((name, i) => (
            <div key={name} style={artistChip}>
              <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'var(--slate-300)' }} />
              <span style={{ fontSize: 13, fontWeight: 500 }}>{name}</span>
              <button
                style={{
                  padding: '4px 12px',
                  borderRadius: 9999,
                  background: i === 0 ? 'var(--slate-900)' : 'transparent',
                  color: i === 0 ? 'var(--white)' : 'var(--slate-700)',
                  border: '1.5px solid',
                  borderColor: i === 0 ? 'var(--slate-900)' : 'var(--slate-200)',
                  fontSize: 12,
                  fontWeight: 500,
                }}
              >
                {i === 0 ? 'Following' : 'Follow'}
              </button>
            </div>
          ))}
        </div>
      </section>

      <section>
        <div style={sectionTitle}>
          <span>Collector Favorites</span>
          <button style={{ fontSize: 13, color: 'var(--slate-500)' }}>See all</button>
        </div>
        <div style={horizontalScroll}>
          {[1, 2, 3].map((i) => (
            <div key={i} style={{ ...portraitCard, width: 140 }} />
          ))}
        </div>
      </section>
    </SafeArea>
  );
}
