import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bookmark, ChevronDown } from 'lucide-react';

/** Mock feed rows — Figma-derived shape, matches FeedPreviewItem's fields loosely. */
const feedItems = [
  {
    id: 1,
    title: 'Coastal Forms #3',
    medium: 'Oil',
    artistName: 'Jordan Lee',
    aspect: '3 / 4',
    status: 'available',
  },
  {
    id: 2,
    title: 'Studio Notes — January',
    medium: 'Mixed Media',
    artistName: 'Alex Chen',
    aspect: '16 / 9',
    status: null,
  },
  {
    id: 3,
    title: 'Untitled (Series 12)',
    medium: 'Photography',
    artistName: 'Sam Rivera',
    aspect: '3 / 4',
    status: 'collected',
  },
];

const FILTERS = ['All', 'Piece', 'Scene'];

export function HomeFeedPage() {
  const navigate = useNavigate();
  const [filter, setFilter] = useState('All');
  const [filterOpen, setFilterOpen] = useState(false);

  return (
    <div style={{ background: 'var(--cream-bg)', minHeight: '100vh', paddingBottom: 96 }}>
      <header
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '14px 16px 16px',
        }}
      >
        <div style={{ position: 'relative' }}>
          <button
            onClick={() => setFilterOpen((open) => !open)}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 4,
              fontFamily: 'var(--font-geist)',
              fontSize: 20,
              fontWeight: 600,
              color: 'var(--cream-text)',
            }}
          >
            {filter}
            <ChevronDown size={16} strokeWidth={2} />
          </button>
          {filterOpen && (
            <>
              <div style={{ position: 'fixed', inset: 0, zIndex: 20 }} onClick={() => setFilterOpen(false)} />
              <div
                className="glass-light"
                style={{ position: 'absolute', top: '100%', left: 0, marginTop: 8, minWidth: 120, padding: 6, zIndex: 21 }}
              >
                {FILTERS.map((f) => (
                  <button
                    key={f}
                    onClick={() => {
                      setFilter(f);
                      setFilterOpen(false);
                    }}
                    style={{
                      display: 'block',
                      width: '100%',
                      textAlign: 'left',
                      padding: '10px 12px',
                      borderRadius: 10,
                      fontFamily: 'var(--font-geist)',
                      fontSize: 14,
                      fontWeight: f === filter ? 600 : 400,
                      color: 'var(--cream-text)',
                    }}
                  >
                    {f}
                  </button>
                ))}
              </div>
            </>
          )}
        </div>

        <span
          style={{
            fontFamily: 'var(--font-geist)',
            fontSize: 28,
            fontWeight: 800,
            color: '#000000',
            lineHeight: 1,
          }}
        >
          studio 3
        </span>

        <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
          <button aria-label="Saved" style={{ color: 'var(--cream-text)' }}>
            <Bookmark size={22} strokeWidth={1.75} />
          </button>
          <button
            aria-label="Inbox"
            onClick={() => navigate('/inbox')}
            style={{ position: 'relative', color: 'var(--cream-text)' }}
          >
            <InboxIcon />
            <span
              style={{
                position: 'absolute',
                top: -4,
                right: -6,
                minWidth: 14,
                height: 14,
                padding: '0 3px',
                borderRadius: 7,
                background: '#E05252',
                color: '#fff',
                fontSize: 9,
                fontWeight: 600,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              3
            </span>
          </button>
        </div>
      </header>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '0 10px' }}>
        {feedItems.map((item) => (
          <FeedTile key={item.id} item={item} onOpen={() => navigate(`/piece/${item.id}`)} />
        ))}
      </div>
    </div>
  );
}

function InboxIcon() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden>
      <path
        d="M4 6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6Z"
        stroke="currentColor"
        strokeWidth="1.75"
      />
      <path d="M4.5 6.5 12 12.5l7.5-6" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" />
    </svg>
  );
}

function FeedTile({ item, onOpen }) {
  return (
    <button
      type="button"
      onClick={onOpen}
      style={{
        display: 'block',
        width: '100%',
        borderRadius: 10,
        overflow: 'hidden',
        position: 'relative',
        aspectRatio: item.aspect,
        background: 'var(--cream-skeleton)',
      }}
    >
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'linear-gradient(135deg, #d9d4cc 0%, #e2ded6 50%, #cfc9bf 100%)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: 0,
          height: 56,
          background: 'linear-gradient(to top, rgba(35,31,27,0.8), rgba(35,31,27,0))',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: 16,
          right: 16,
          bottom: 8,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          height: 40,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
          <span
            style={{
              width: 28,
              height: 28,
              borderRadius: '50%',
              flexShrink: 0,
              background: 'var(--cream-cta-fill)',
              color: 'var(--cream-text-inverse)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontFamily: 'var(--font-geist)',
              fontSize: 12,
              fontWeight: 600,
            }}
          >
            {item.artistName[0]}
          </span>
          <span style={{ minWidth: 0, textAlign: 'left' }}>
            <div
              style={{
                fontFamily: 'var(--font-geist)',
                fontSize: 12,
                color: 'var(--cream-text-inverse)',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {item.artistName}
            </div>
            <div
              style={{
                fontFamily: 'var(--font-geist)',
                fontSize: 11,
                color: 'rgba(250,250,247,0.6)',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {item.medium}
            </div>
          </span>
        </div>
        {item.status && (
          <span
            style={{
              flexShrink: 0,
              padding: '4px 8px',
              borderRadius: 22,
              background: 'rgba(35,31,27,0.6)',
              color: 'var(--cream-text-inverse)',
              fontSize: 11,
              fontFamily: 'var(--font-geist)',
            }}
          >
            {item.status === 'available' ? 'Available' : 'Collected'}
          </span>
        )}
      </div>
    </button>
  );
}
