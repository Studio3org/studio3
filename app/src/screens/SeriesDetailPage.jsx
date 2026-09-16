import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';

import { API_BASE_URL } from '../services/apiClient';

/// Web fallback for a shared series link (`/series/:id`) — mirrors
/// PieceDetailPage.jsx. This is what Android App Links / iOS Universal
/// Links open when the Studio 3 app isn't installed, and what a plain
/// browser tap resolves to either way.
export function SeriesDetailPage() {
  const { id } = useParams();
  const [series, setSeries] = useState(null);
  const [error, setError] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(false);

    fetch(`${API_BASE_URL}/api/series/${id}`)
      .then((res) => {
        if (!res.ok) throw new Error(`Request failed: ${res.status}`);
        return res.json();
      })
      .then((json) => {
        if (cancelled) return;
        setSeries(json.data ?? json);
      })
      .catch(() => {
        if (!cancelled) setError(true);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [id]);

  if (loading) {
    return <StateScreen text="Loading…" />;
  }
  if (error || !series) {
    return <StateScreen text="This series couldn't be found." />;
  }

  const author = series.author ?? {};

  return (
    <div style={{ background: 'var(--cream-bg-detail)', minHeight: '100vh' }}>
      <div style={{ maxWidth: 935, margin: '0 auto' }}>
      {series.coverUrl && (
        <img
          src={series.coverUrl}
          alt={series.name ?? ''}
          style={{ width: '100%', aspectRatio: '4 / 5', objectFit: 'cover', display: 'block', background: 'var(--cream-skeleton)' }}
        />
      )}
      <div style={{ padding: 16 }}>
        <h1 style={{ fontFamily: 'var(--font-geist)', fontSize: 24, fontWeight: 500, color: 'var(--cream-text)', marginBottom: 4 }}>
          {series.name}
        </h1>
        <p style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text-secondary)' }}>
          {series.pieceCount} {series.pieceCount === 1 ? 'piece' : 'pieces'}
        </p>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 16 }}>
          {author.profilePhotoUrl && (
            <img src={author.profilePhotoUrl} alt={author.name ?? ''} style={{ width: 32, height: 32, borderRadius: '50%', objectFit: 'cover' }} />
          )}
          <span style={{ fontFamily: 'var(--font-geist)', fontSize: 14, fontWeight: 500, color: 'var(--cream-text)' }}>
            {author.name}
          </span>
        </div>
      </div>

      <div style={{ padding: '0 16px 16px' }}>
        <a
          href={`studio3://series/${id}`}
          style={{
            display: 'block',
            textAlign: 'center',
            height: 40,
            lineHeight: '40px',
            borderRadius: 8,
            background: 'var(--cream-cta-fill)',
            color: 'var(--cream-text-inverse)',
            fontFamily: 'var(--font-inter)',
            fontSize: 16,
          }}
        >
          Open in app
        </a>
      </div>
      </div>
    </div>
  );
}

function StateScreen({ text }) {
  return (
    <div
      style={{
        background: 'var(--cream-bg-detail)',
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontFamily: 'var(--font-inter)',
        fontSize: 14,
        color: 'var(--cream-text-secondary)',
        padding: 48,
        textAlign: 'center',
      }}
    >
      {text}
    </div>
  );
}
