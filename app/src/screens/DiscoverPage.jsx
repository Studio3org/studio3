import React, { useState } from 'react';
import { Search, SlidersHorizontal } from 'lucide-react';

const CATEGORIES = ['All', 'Pieces', 'Scenes'];

const NEARBY = [
  { name: 'Maya K.', distance: '0.4 mi' },
  { name: 'James T.', distance: '1.1 mi' },
  { name: 'Riley W.', distance: '2.3 mi' },
];

const GRID_TILES = [
  { ratio: '3 / 4' },
  { ratio: '1 / 1' },
  { ratio: '16 / 9' },
  { ratio: '3 / 4' },
  { ratio: '1 / 1' },
  { ratio: '1 / 1' },
];

const cardShadow = '0 4px 12px rgba(35,31,27,0.08)';

export function DiscoverPage() {
  const [category, setCategory] = useState('All');
  const [query, setQuery] = useState('');

  return (
    <div style={{ background: 'var(--cream-bg)', minHeight: '100vh', paddingBottom: 96 }}>
      <div
        style={{
          position: 'sticky',
          top: 0,
          zIndex: 10,
          background: 'var(--cream-bg)',
          padding: '8px 10px 12px',
        }}
      >
        <div
          style={{
            height: 48,
            borderRadius: 10,
            background: 'rgba(140,136,128,0.2)',
            display: 'flex',
            alignItems: 'center',
            padding: '0 14px',
            gap: 10,
          }}
        >
          <Search size={22} color="var(--cream-text-secondary)" strokeWidth={1.75} />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search artists, pieces, genres"
            style={{
              flex: 1,
              fontFamily: 'var(--font-inter)',
              fontSize: 14,
              background: 'transparent',
              color: 'var(--cream-text)',
              outline: 'none',
            }}
          />
          <SlidersHorizontal size={22} color="var(--cream-text)" strokeWidth={1.75} />
        </div>

        <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
          {CATEGORIES.map((c) => {
            const active = c === category;
            return (
              <button
                key={c}
                onClick={() => setCategory(c)}
                style={{
                  height: 32,
                  padding: '0 16px',
                  borderRadius: 35,
                  border: '1px solid var(--cream-text)',
                  background: active ? 'var(--cream-text)' : 'transparent',
                  color: active ? 'var(--cream-text-inverse)' : 'var(--cream-text)',
                  fontFamily: 'var(--font-inter)',
                  fontSize: 12,
                  fontWeight: 500,
                }}
              >
                {c}
              </button>
            );
          })}
        </div>
      </div>

      <div style={{ padding: '0 10px' }}>
        {/* Featured hero */}
        <div
          style={{
            position: 'relative',
            height: 208,
            borderRadius: 10,
            overflow: 'hidden',
            boxShadow: cardShadow,
            marginBottom: 16,
            background: 'linear-gradient(135deg,#d9d4cc,#cfc9bf)',
          }}
        >
          <span
            style={{
              position: 'absolute',
              top: 12,
              left: 12,
              padding: '4px 10px',
              borderRadius: 4,
              background: 'rgba(35,31,27,0.72)',
              color: 'var(--cream-text-inverse)',
              fontSize: 10,
              fontWeight: 600,
              fontFamily: 'var(--font-inter)',
            }}
          >
            Featured for You
          </span>
          <div
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              bottom: 0,
              padding: 16,
              background: 'linear-gradient(to top, rgba(35,31,27,0.75), rgba(35,31,27,0))',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
              <span style={{ width: 24, height: 24, borderRadius: '50%', background: 'var(--cream-cta-fill)' }} />
              <span style={{ fontFamily: 'var(--font-geist)', fontSize: 12, color: '#fff' }}>Maya K.</span>
            </div>
            <div style={{ fontFamily: 'var(--font-inter)', fontSize: 14, fontWeight: 600, color: '#fff' }}>
              Golden Hour Study
            </div>
            <div style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'rgba(255,255,255,0.85)' }}>
              A quiet study in warmth and light.
            </div>
          </div>
        </div>

        {/* Sellers near you */}
        <div style={{ marginBottom: 20 }}>
          <div style={{ fontFamily: 'var(--font-inter)', fontSize: 15, fontWeight: 600, color: 'var(--cream-text)', marginBottom: 12 }}>
            Sellers near you
          </div>
          <div style={{ display: 'flex', gap: 16, overflowX: 'auto' }}>
            {NEARBY.map((s) => (
              <div key={s.name} style={{ width: 72, flexShrink: 0, textAlign: 'center' }}>
                <span
                  style={{
                    display: 'block',
                    width: 56,
                    height: 56,
                    borderRadius: '50%',
                    margin: '0 auto 6px',
                    background: 'var(--cream-cta-fill)',
                  }}
                />
                <div
                  style={{
                    fontFamily: 'var(--font-inter)',
                    fontSize: 11,
                    fontWeight: 500,
                    color: 'var(--cream-text)',
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                  }}
                >
                  {s.name}
                </div>
                <div style={{ fontFamily: 'var(--font-inter)', fontSize: 10, color: 'var(--cream-text-secondary)' }}>
                  {s.distance}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Feed grid */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          {GRID_TILES.map((tile, i) => (
            <div
              key={i}
              style={{
                aspectRatio: tile.ratio,
                borderRadius: 8,
                boxShadow: cardShadow,
                background: i % 2 === 0 ? 'linear-gradient(135deg,#e2ded6,#cfc9bf)' : 'linear-gradient(135deg,#d9d4cc,#e2ded6)',
              }}
            />
          ))}
        </div>
      </div>
    </div>
  );
}
