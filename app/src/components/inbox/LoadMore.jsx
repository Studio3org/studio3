import React, { useEffect, useRef } from 'react';

/**
 * Cursor-pagination footer: loads the next page as it scrolls into view, with a
 * "Load more" button as the fallback (and a Retry after a failed page).
 *
 * @param {object} props
 * @param {boolean} props.hasMore Whether the last response had a `nextCursor`.
 * @param {boolean} props.loading
 * @param {string|null} [props.error]
 * @param {() => void} props.onLoad
 */
export function LoadMore({ hasMore, loading, error, onLoad }) {
  const ref = useRef(null);
  const onLoadRef = useRef(onLoad);
  onLoadRef.current = onLoad;

  useEffect(() => {
    const el = ref.current;
    if (!el || !hasMore || loading || error || typeof IntersectionObserver === 'undefined') return undefined;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) onLoadRef.current();
    }, { rootMargin: '200px' });
    io.observe(el);
    return () => io.disconnect();
  }, [hasMore, loading, error]);

  if (!hasMore) return null;

  return (
    <div ref={ref} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, padding: '12px 0 4px' }}>
      {loading ? (
        <span
          style={{
            width: 18,
            height: 18,
            borderRadius: '50%',
            border: '2px solid var(--cream-divider)',
            borderTopColor: 'var(--cream-cta-fill)',
            animation: 'app-spin 0.7s linear infinite',
          }}
        />
      ) : (
        <>
          {error && (
            <span style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)' }}>{error}</span>
          )}
          <button
            onClick={onLoad}
            style={{
              padding: '6px 14px',
              borderRadius: 9999,
              background: 'var(--slate-100)',
              color: 'var(--slate-700)',
              fontFamily: 'var(--font-inter)',
              fontSize: 12,
              fontWeight: 500,
            }}
          >
            {error ? 'Retry' : 'Load more'}
          </button>
        </>
      )}
    </div>
  );
}
