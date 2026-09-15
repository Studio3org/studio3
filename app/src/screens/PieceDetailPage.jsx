import React, { useEffect, useMemo, useState } from 'react';
import { useParams } from 'react-router-dom';

// Same deployed backend used by the Flutter app's ApiConfig fallback
// (lib/config/api_config.dart) — this web app has no env-driven config yet.
const API_BASE_URL = 'https://studio3-backend.onrender.com';

function formatUsd(cents) {
  if (cents == null) return '—';
  return `US$ ${Math.round(cents / 100).toLocaleString()}`;
}

function formatTimeRemaining(iso) {
  if (!iso) return null;
  const diff = new Date(iso).getTime() - Date.now();
  if (diff <= 0) return null;
  const days = Math.floor(diff / 86400000);
  const hours = Math.floor((diff % 86400000) / 3600000);
  if (days > 0) return `${days}d ${hours}h`;
  const minutes = Math.floor((diff % 3600000) / 60000);
  if (hours > 0) return `${hours}h ${minutes}m`;
  return minutes > 0 ? `${minutes}m` : 'Ending soon';
}

/** Web fallback for a shared piece link (`/piece/:id`) — what Android App Links / iOS
 * Universal Links open when the app isn't installed, and what a plain browser tap
 * resolves to either way. Read-only: no bid submission or collect flow from here. */
export function PieceDetailPage() {
  const { id } = useParams();
  const [piece, setPiece] = useState(null);
  const [error, setError] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(false);

    fetch(`${API_BASE_URL}/api/pieces/${id}`)
      .then((res) => {
        if (!res.ok) throw new Error(`Request failed: ${res.status}`);
        return res.json();
      })
      .then((json) => {
        if (cancelled) return;
        setPiece(json.data ?? json);
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

  const timeRemaining = useMemo(() => formatTimeRemaining(piece?.auctionEndsAt), [piece]);

  if (loading) {
    return <StateScreen text="Loading…" />;
  }
  if (error || !piece) {
    return <StateScreen text="This piece couldn't be found." />;
  }

  const author = piece.author ?? {};
  const isAuction = piece.listingType === 'auction';

  return (
    <div style={{ background: 'var(--cream-bg-detail)', minHeight: '100vh' }}>
      {piece.mediaUrl && (
        <img
          src={piece.mediaUrl}
          alt={piece.title ?? ''}
          style={{ width: '100%', aspectRatio: '4 / 5', objectFit: 'cover', display: 'block', background: 'var(--cream-skeleton)' }}
        />
      )}

      <div style={{ padding: 16 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
          {author.profilePhotoUrl && (
            <img src={author.profilePhotoUrl} alt={author.name ?? ''} style={{ width: 28, height: 28, borderRadius: '50%', objectFit: 'cover' }} />
          )}
          <span style={{ fontFamily: 'var(--font-geist)', fontSize: 12, fontWeight: 500, color: 'var(--cream-text)' }}>
            {author.name}
          </span>
        </div>

        <h1 style={{ fontFamily: 'var(--font-geist)', fontSize: 24, fontWeight: 500, color: 'var(--cream-text)', marginBottom: 4 }}>
          {piece.title}
        </h1>
        {piece.medium && (
          <p style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text-secondary)' }}>{piece.medium}</p>
        )}
        {piece.dimensions && (
          <p style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text)' }}>{piece.dimensions}</p>
        )}
        {piece.caption && (
          <p style={{ fontFamily: 'var(--font-inter)', fontSize: 15, color: 'var(--cream-text)', marginTop: 16, lineHeight: 1.4 }}>
            {piece.caption}
          </p>
        )}
      </div>

      {piece.isForSale && (
        <div style={{ padding: '16px', borderTop: `1px solid var(--cream-divider)` }}>
          {isAuction ? (
            <>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 12 }}>
                <span>
                  <div style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)' }}>
                    {piece.bidCount > 0 ? `Current bid · ${piece.bidCount} bids` : 'Starting bid'}
                  </div>
                  <div style={{ fontFamily: 'var(--font-geist)', fontSize: 20, color: 'var(--cream-text)' }}>
                    {formatUsd(piece.highestBidCents ?? piece.priceCents)}
                  </div>
                </span>
                {timeRemaining && (
                  <span style={{ textAlign: 'right' }}>
                    <div style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)' }}>Time remaining</div>
                    <div style={{ fontFamily: 'var(--font-geist)', fontSize: 20, color: 'var(--cream-status-error)' }}>{timeRemaining}</div>
                  </span>
                )}
              </div>
              <a
                href={`studio3://piece/${id}`}
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
                Open in app to bid
              </a>
            </>
          ) : (
            <>
              <div style={{ fontFamily: 'var(--font-geist)', fontSize: 20, color: 'var(--cream-text)', marginBottom: 12 }}>
                {formatUsd(piece.priceCents)}
              </div>
              <a
                href={`studio3://piece/${id}`}
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
                Open in app to collect
              </a>
            </>
          )}
        </div>
      )}
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
