import React, { useState } from 'react';
import { GlassDark } from '../design/GlassCard';

const cardStyle = {
  width: '100%',
  borderRadius: 16,
  overflow: 'hidden',
  boxShadow: '0 2px 16px rgba(15,23,42,0.08), 0 1px 4px rgba(15,23,42,0.04)',
  background: 'var(--white)',
};

const imageWrap = {
  position: 'relative',
  aspectRatio: '4/3',
  background: 'var(--slate-100)',
};

const stripStyle = {
  position: 'absolute',
  bottom: 0,
  left: 0,
  right: 0,
  padding: '10px 12px',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
};

const bodyStyle = {
  padding: '12px 16px',
};

export function PieceCard({ image, title, storyPreview, artistName, medium, forSale, price, isProcess }) {
  const [saved, setSaved] = useState(false);

  return (
    <article style={cardStyle}>
      <div style={imageWrap}>
        {image ? (
          <img src={image} alt={title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        ) : (
          <div style={{ width: '100%', height: '100%', background: 'var(--slate-100)' }} />
        )}
        {isProcess && (
          <span
            style={{
              position: 'absolute',
              top: 12,
              left: 12,
              padding: '4px 10px',
              borderRadius: 9999,
              background: 'var(--slate-100)',
              color: 'var(--slate-600)',
              fontSize: 11,
              fontWeight: 500,
            }}
          >
            Process
          </span>
        )}
        <GlassDark style={stripStyle}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div
              style={{
                width: 24,
                height: 24,
                borderRadius: '50%',
                background: 'var(--slate-400)',
              }}
            />
            <div>
              <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--white)' }}>{artistName}</div>
              <div style={{ fontSize: 11, color: 'var(--slate-300)' }}>{medium}</div>
            </div>
          </div>
          <button
            onClick={() => setSaved((s) => !s)}
            style={{ color: 'var(--white)', padding: 4 }}
            aria-label={saved ? 'Unsave' : 'Save'}
          >
            {saved ? '🔖' : '📑'}
          </button>
        </GlassDark>
      </div>
      <div style={bodyStyle}>
        <h3 style={{ fontSize: 16, fontWeight: 600, color: 'var(--slate-900)', marginBottom: 4 }}>{title}</h3>
        <p style={{ fontSize: 13, color: 'var(--slate-500)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', marginBottom: 8 }}>
          {storyPreview}
        </p>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', gap: 12, color: 'var(--slate-400)' }}>
            <span>♥</span>
            <span>💬</span>
          </div>
          {forSale && price && (
            <span
              style={{
                padding: '4px 10px',
                borderRadius: 9999,
                background: 'var(--slate-900)',
                color: 'var(--white)',
                fontSize: 12,
                fontWeight: 600,
              }}
            >
              ${price}
            </span>
          )}
        </div>
      </div>
    </article>
  );
}
