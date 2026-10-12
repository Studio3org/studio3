import React, { useEffect, useRef, useState } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';

const arrowStyle = {
  position: 'absolute',
  top: '50%',
  transform: 'translateY(-50%)',
  width: 32,
  height: 32,
  borderRadius: '50%',
  border: 'none',
  background: 'rgba(255, 255, 255, 0.8)',
  color: 'var(--slate-900)',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  cursor: 'pointer',
  boxShadow: 'var(--shadow-card)',
};

/// Swipeable image carousel for a piece's `images[]` (cover first), like the
/// app's DetailHeroImage. Native scroll-snap gives touch swiping for free;
/// arrows are for mouse users, dots show position.
export function MediaGallery({ images, alt = '', aspectRatio = 3 / 4 }) {
  const scroller = useRef(null);
  const [index, setIndex] = useState(0);
  const urls = (images ?? []).filter(Boolean);
  const many = urls.length > 1;

  // A new piece (same component instance, new route param) starts at its cover.
  useEffect(() => {
    setIndex(0);
    if (scroller.current) scroller.current.scrollLeft = 0;
  }, [urls[0]]);

  const onScroll = () => {
    const el = scroller.current;
    if (!el || !el.clientWidth) return;
    setIndex(Math.round(el.scrollLeft / el.clientWidth));
  };

  const go = (to) => {
    const el = scroller.current;
    if (!el) return;
    const next = Math.max(0, Math.min(urls.length - 1, to));
    el.scrollTo({ left: next * el.clientWidth, behavior: 'smooth' });
  };

  if (!urls.length) {
    return <div style={{ width: '100%', aspectRatio: String(aspectRatio), background: 'var(--slate-100)' }} />;
  }

  return (
    <div style={{ position: 'relative', width: '100%', aspectRatio: String(aspectRatio), background: 'var(--slate-100)' }}>
      <div
        ref={scroller}
        onScroll={many ? onScroll : undefined}
        style={{
          display: 'flex',
          width: '100%',
          height: '100%',
          overflowX: many ? 'auto' : 'hidden',
          scrollSnapType: 'x mandatory',
          scrollbarWidth: 'none',
        }}
      >
        {urls.map((src, i) => (
          <img
            key={`${src}-${i}`}
            src={src}
            alt={many ? `${alt} (${i + 1} of ${urls.length})` : alt}
            loading={i === 0 ? 'eager' : 'lazy'}
            style={{
              flex: '0 0 100%',
              width: '100%',
              height: '100%',
              objectFit: 'cover',
              display: 'block',
              scrollSnapAlign: 'start',
            }}
          />
        ))}
      </div>

      {many && index > 0 && (
        <button type="button" aria-label="Previous image" onClick={() => go(index - 1)} style={{ ...arrowStyle, left: 10 }}>
          <ChevronLeft size={18} />
        </button>
      )}
      {many && index < urls.length - 1 && (
        <button type="button" aria-label="Next image" onClick={() => go(index + 1)} style={{ ...arrowStyle, right: 10 }}>
          <ChevronRight size={18} />
        </button>
      )}
      {many && (
        <div style={{ position: 'absolute', bottom: 10, left: 0, right: 0, display: 'flex', justifyContent: 'center', gap: 6 }}>
          {urls.map((src, i) => (
            <button
              key={`dot-${i}`}
              type="button"
              aria-label={`Show image ${i + 1}`}
              onClick={() => go(i)}
              style={{
                width: i === index ? 16 : 6,
                height: 6,
                padding: 0,
                border: 'none',
                borderRadius: 9999,
                background: i === index ? 'var(--white)' : 'rgba(255, 255, 255, 0.55)',
                boxShadow: '0 1px 3px rgba(15, 23, 42, 0.3)',
                cursor: 'pointer',
                transition: 'width 0.2s',
              }}
            />
          ))}
        </div>
      )}
    </div>
  );
}
