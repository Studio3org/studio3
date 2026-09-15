import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';

// Same deployed backend used by the Flutter app's ApiConfig fallback
// (lib/config/api_config.dart) — this web app has no env-driven config yet.
const API_BASE_URL = 'https://studio3-backend.onrender.com';

const containerStyle = {
  maxWidth: 480,
  margin: '0 auto',
  minHeight: '100vh',
  background: 'var(--white)',
};

const coverStyle = {
  width: '100%',
  aspectRatio: '4 / 5',
  objectFit: 'cover',
  background: 'var(--slate-100)',
  display: 'block',
};

const bodyStyle = {
  padding: 16,
};

const titleStyle = {
  fontSize: 18,
  fontWeight: 600,
  color: 'var(--slate-900)',
  marginBottom: 4,
};

const authorRowStyle = {
  display: 'flex',
  alignItems: 'center',
  gap: 8,
  marginTop: 12,
};

const avatarStyle = {
  width: 32,
  height: 32,
  borderRadius: '50%',
  background: 'var(--slate-200)',
  objectFit: 'cover',
};

const countStyle = {
  fontSize: 13,
  color: 'var(--slate-500)',
};

const stateStyle = {
  padding: 48,
  textAlign: 'center',
  color: 'var(--slate-500)',
  fontSize: 14,
};

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
    return <div style={stateStyle}>Loading…</div>;
  }

  if (error || !series) {
    return <div style={stateStyle}>This series couldn't be found.</div>;
  }

  const author = series.author ?? {};

  return (
    <div style={containerStyle}>
      {series.coverUrl && (
        <img src={series.coverUrl} alt={series.name ?? ''} style={coverStyle} />
      )}
      <div style={bodyStyle}>
        <div style={titleStyle}>{series.name}</div>
        <div style={countStyle}>
          {series.pieceCount} {series.pieceCount === 1 ? 'piece' : 'pieces'}
        </div>
        <div style={authorRowStyle}>
          {author.profilePhotoUrl && (
            <img src={author.profilePhotoUrl} alt={author.name ?? ''} style={avatarStyle} />
          )}
          <span style={{ fontSize: 14, fontWeight: 500, color: 'var(--slate-900)' }}>
            {author.name}
          </span>
        </div>
      </div>
    </div>
  );
}
