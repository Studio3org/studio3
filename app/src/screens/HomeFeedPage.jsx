import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bookmark, ChevronDown } from 'lucide-react';
import { apiFetch } from '../services/apiClient';
import { useBreakpoint } from '../hooks/useBreakpoint';
import { NavIcon } from '../components/icons/NavIcon';
import { fetchUnreadConversationCount, fetchUnreadNotificationCount } from '../services/inboxApi';
import { InboxRail, RIGHT_RAIL_WIDTH } from '../components/layout/InboxRail';

const MAIN_COLUMN_WIDTH = 630;

const FILTERS = ['All', 'Piece', 'Scene'];

const FALLBACK_ITEMS = [
  { id: 1, title: 'Coastal Forms #3', medium: 'Oil', artistName: 'Jordan Lee', authorUsername: 'jordanlee', aspect: '3 / 4', status: 'available' },
  { id: 2, title: 'Studio Notes — January', medium: 'Mixed Media', artistName: 'Alex Chen', authorUsername: 'alexchen', aspect: '16 / 9', status: null },
  { id: 3, title: 'Untitled (Series 12)', medium: 'Photography', artistName: 'Sam Rivera', authorUsername: 'samrivera', aspect: '3 / 4', status: 'collected' },
];

function statusFor(item) {
  if (item.type !== 'piece') return null;
  if (item.status === 'sold' || item.status === 'reserved') return 'collected';
  if (item.isForSale && item.status === 'live') return 'available';
  return null;
}

function mapFeedItem(item) {
  return {
    id: item.id,
    title: item.title || item.caption || 'Untitled',
    medium: item.medium || (item.type === 'post' ? 'Scene' : ''),
    artistName: item.author?.name || item.authorName || 'Artist',
    authorUsername: item.author?.username || item.authorUsername || '',
    authorAvatarUrl: item.author?.profilePhotoUrl || item.authorAvatarUrl,
    aspect: item.mediaType === 'video' ? '16 / 9' : '3 / 4',
    status: statusFor(item),
    mediaUrl: item.mediaUrl,
  };
}

export function HomeFeedPage() {
  const navigate = useNavigate();
  const { railLabeled } = useBreakpoint();
  const [filter, setFilter] = useState('All');
  const [filterOpen, setFilterOpen] = useState(false);
  const [items, setItems] = useState(null);
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const page = await apiFetch('/api/feed/for-you', { auth: true });
        if (!cancelled) setItems(page.items.map(mapFeedItem));
      } catch {
        try {
          const page = await apiFetch('/api/feed/explore', { auth: true });
          if (!cancelled) setItems(page.items.map(mapFeedItem));
        } catch {
          if (!cancelled) setItems(FALLBACK_ITEMS);
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    Promise.all([fetchUnreadNotificationCount(), fetchUnreadConversationCount()])
      .then(([notifs, chats]) => !cancelled && setUnreadCount(notifs + chats))
      .catch(() => {
        /* fail silent */
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const visibleItems = (items || []).filter((item) => {
    if (filter === 'Piece') return item.medium !== 'Scene';
    if (filter === 'Scene') return item.medium === 'Scene';
    return true;
  });

  return (
    <div style={{ background: 'var(--cream-bg)', minHeight: '100vh', paddingBottom: 96 }}>
      <div
        style={{
          maxWidth: railLabeled ? MAIN_COLUMN_WIDTH + RIGHT_RAIL_WIDTH + 48 : MAIN_COLUMN_WIDTH,
          margin: '0 auto',
          display: 'flex',
          gap: 48,
        }}
      >
        <div style={{ flex: 1, minWidth: 0 }}>
          <header
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              height: 52,
              padding: '0 10px',
              borderBottom: '1px solid var(--cream-divider)',
              background: 'var(--cream-bg)',
              position: 'sticky',
              top: 0,
              zIndex: 10,
            }}
          >
            <div style={{ position: 'relative' }}>
              <button
                type="button"
                onClick={() => setFilterOpen((open) => !open)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 4,
                  fontFamily: 'var(--font-geist)',
                  fontSize: 16,
                  fontWeight: 600,
                  color: 'var(--cream-text)',
                }}
              >
                {filter} <ChevronDown size={16} strokeWidth={2.25} />
              </button>
              {filterOpen && (
                <>
                  <div style={{ position: 'fixed', inset: 0, zIndex: 20 }} onClick={() => setFilterOpen(false)} />
                  <div
                    style={{
                      position: 'absolute',
                      top: 36,
                      left: 0,
                      zIndex: 21,
                      background: 'var(--cream-bg-detail)',
                      border: '1px solid var(--cream-divider)',
                      borderRadius: 12,
                      padding: 6,
                      boxShadow: 'var(--shadow-float)',
                      minWidth: 140,
                    }}
                  >
                    {FILTERS.map((f) => (
                      <button
                        key={f}
                        type="button"
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

            <img src="/logo/logo_text_black.png" alt="Studio 3" height={34} style={{ height: 34, width: 'auto' }} />

            <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
              <button aria-label="Saved" style={{ color: 'var(--cream-text)' }}>
                <Bookmark size={22} strokeWidth={1.75} />
              </button>
              <button
                aria-label="Inbox"
                onClick={() => navigate('/inbox')}
                style={{ position: 'relative', color: 'var(--cream-text)' }}
              >
                <NavIcon id="bell" size={22} />
                {unreadCount > 0 && (
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
                    {unreadCount > 9 ? '9+' : unreadCount}
                  </span>
                )}
              </button>
            </div>
          </header>

          {items === null ? (
            <HomeFeedSkeleton />
          ) : visibleItems.length === 0 ? (
            <p style={{ textAlign: 'center', fontFamily: 'var(--font-inter)', fontSize: 14, color: 'var(--cream-text-secondary)', padding: 48 }}>
              Nothing here yet.
            </p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '10px 10px 0 10px' }}>
              {visibleItems.map((item) => (
                <FeedTile key={item.id} item={item} onOpen={() => navigate(`/piece/${item.id}`)} />
              ))}
            </div>
          )}
        </div>
        {railLabeled && <InboxRail />}
      </div>
    </div>
  );
}

function HomeFeedSkeleton() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '10px 10px 0 10px' }}>
      <FeedTileSkeleton aspect="3 / 4" />
      <FeedTileSkeleton aspect="16 / 9" />
      <FeedTileSkeleton aspect="3 / 4" />
    </div>
  );
}

function FeedTileSkeleton({ aspect = '3 / 4' }) {
  return (
    <div
      className="feed-skeleton-block"
      style={{
        width: '100%',
        borderRadius: 10,
        position: 'relative',
        aspectRatio: aspect,
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: 0,
          height: 56,
          background: 'linear-gradient(to top, rgba(35,31,27,0.6), rgba(35,31,27,0))',
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
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div className="feed-skeleton-block" style={{ width: 28, height: 28, borderRadius: '50%' }} />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <div className="feed-skeleton-block" style={{ width: 90, height: 12, borderRadius: 4 }} />
            <div className="feed-skeleton-block" style={{ width: 60, height: 10, borderRadius: 4 }} />
          </div>
        </div>
        <div className="feed-skeleton-block" style={{ width: 64, height: 20, borderRadius: 22 }} />
      </div>
    </div>
  );
}

function FeedTile({ item, onOpen }) {
  const navigate = useNavigate();

  const handleArtistClick = (e) => {
    e.stopPropagation();
    const uname = item.authorUsername || item.artistName;
    if (uname) {
      navigate(`/profile?username=${encodeURIComponent(uname)}`);
    }
  };

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
      {item.mediaUrl ? (
        <img src={item.mediaUrl} alt={item.title} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
      ) : (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: 'linear-gradient(135deg, #d9d4cc 0%, #e2ded6 50%, #cfc9bf 100%)',
          }}
        />
      )}
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
        <div
          style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0, cursor: 'pointer' }}
          onClick={handleArtistClick}
        >
          {item.authorAvatarUrl ? (
            <img
              src={item.authorAvatarUrl}
              alt={item.artistName}
              style={{ width: 28, height: 28, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }}
            />
          ) : (
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
              {item.artistName ? item.artistName[0] : 'A'}
            </span>
          )}
          <span style={{ minWidth: 0, textAlign: 'left' }}>
            <div
              style={{
                fontFamily: 'var(--font-geist)',
                fontSize: 12,
                color: 'var(--cream-text-inverse)',
                fontWeight: 600,
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
