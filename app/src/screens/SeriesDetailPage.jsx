import React, { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';

import { useAuth } from '../context/AuthContext';
import { apiFetch } from '../services/apiClient';
import { friendlyError } from '../services/socialApi';
import { profileHref } from '../utils/contentLinks';

/// `/series/:id` — a series and its pieces. Also the web fallback for a shared series
/// link (Android App Links / iOS Universal Links open it when the app isn't installed).
export function SeriesDetailPage() {
  const { id } = useParams();
  const { status } = useAuth();
  const [series, setSeries] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Wait for auth so the owner (or a follower of a private account) gets their view.
    if (status === 'loading') return undefined;
    let cancelled = false;
    setLoading(true);
    setError(null);

    apiFetch(`/api/series/${id}`, { auth: true })
      .then((json) => {
        if (!cancelled) setSeries(json);
      })
      .catch((e) => {
        if (cancelled) return;
        setSeries(null);
        setError(e?.status === 404 || e?.status === 400 ? "This series couldn't be found." : friendlyError(e));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [id, status]);

  if (status === 'loading' || loading) {
    return <StateScreen text="Loading…" />;
  }
  if (error || !series) {
    return <StateScreen text={error || "This series couldn't be found."} />;
  }

  const author = series.author ?? {};
  // `pieces` is the full newest-first list; `previewPieces` is all a summary carries.
  const pieces = (Array.isArray(series.pieces) && series.pieces.length ? series.pieces : series.previewPieces) || [];
  const pieceCount = series.pieceCount ?? pieces.length;
  const description = (series.description || '').trim();

  return (
    <div style={{ background: 'var(--cream-bg-detail)', minHeight: '100vh' }}>
      <div style={{ maxWidth: 935, margin: '0 auto' }}>
        {series.coverUrl && (
          <img
            src={series.coverUrl}
            alt={series.name ?? ''}
            style={{ width: '100%', aspectRatio: '4 / 5', maxHeight: '70vh', objectFit: 'cover', display: 'block', background: 'var(--cream-skeleton)' }}
          />
        )}
        <div style={{ padding: 16 }}>
          <h1 style={{ fontFamily: 'var(--font-geist)', fontSize: 24, fontWeight: 500, color: 'var(--cream-text)', marginBottom: 4 }}>
            {series.name}
          </h1>
          <p style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text-secondary)' }}>
            {pieceCount} {pieceCount === 1 ? 'piece' : 'pieces'}
          </p>
          {description && (
            <p style={{ fontFamily: 'var(--font-geist)', fontSize: 14, lineHeight: '20px', color: 'var(--cream-text)', marginTop: 12, whiteSpace: 'pre-wrap' }}>
              {description}
            </p>
          )}
          {author.username && (
            <Link
              to={profileHref(author.username)}
              style={{ display: 'inline-flex', alignItems: 'center', gap: 8, marginTop: 16, color: 'inherit' }}
            >
              {author.profilePhotoUrl ? (
                <img src={author.profilePhotoUrl} alt="" style={{ width: 32, height: 32, borderRadius: '50%', objectFit: 'cover' }} />
              ) : (
                <span
                  style={{
                    width: 32,
                    height: 32,
                    borderRadius: '50%',
                    background: 'var(--cream-skeleton)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontFamily: 'var(--font-geist)',
                    fontSize: 12,
                    color: 'var(--cream-text-secondary)',
                  }}
                >
                  {(author.name || author.username).slice(0, 1).toUpperCase()}
                </span>
              )}
              <span style={{ display: 'flex', flexDirection: 'column' }}>
                <span style={{ fontFamily: 'var(--font-geist)', fontSize: 14, fontWeight: 500, color: 'var(--cream-text)' }}>
                  {author.name || author.username}
                </span>
                <span style={{ fontFamily: 'var(--font-geist)', fontSize: 12, color: 'var(--cream-text-secondary)' }}>
                  @{author.username}
                </span>
              </span>
            </Link>
          )}
        </div>

        {pieces.length > 0 ? (
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))',
              gap: 8,
              padding: '0 16px 16px',
            }}
          >
            {pieces.map((p) => (
              <Link key={p.id} to={`/piece/${p.id}`} style={{ display: 'block', color: 'inherit', minWidth: 0 }}>
                <div style={{ aspectRatio: '3 / 4', borderRadius: 8, overflow: 'hidden', background: 'var(--cream-skeleton)' }}>
                  {p.mediaUrl && (
                    <img
                      src={p.mediaUrl}
                      alt={p.title ?? ''}
                      loading="lazy"
                      style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
                    />
                  )}
                </div>
                {p.title && (
                  <p
                    style={{
                      fontFamily: 'var(--font-geist)',
                      fontSize: 12,
                      lineHeight: '16px',
                      color: 'var(--cream-text)',
                      marginTop: 6,
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {p.title}
                  </p>
                )}
              </Link>
            ))}
          </div>
        ) : (
          <p style={{ padding: '0 16px 16px', fontFamily: 'var(--font-inter)', fontSize: 14, color: 'var(--cream-text-secondary)' }}>
            No pieces in this series yet.
          </p>
        )}

        <div style={{ padding: '0 16px 24px' }}>
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
