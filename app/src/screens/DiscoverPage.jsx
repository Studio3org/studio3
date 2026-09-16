import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, SlidersHorizontal, X, Play } from 'lucide-react';
import { apiFetch } from '../services/apiClient';
import './DiscoverPage.css';

const CATEGORIES = [
  { label: 'All', key: 'all' },
  { label: 'Pieces', key: 'pieces' },
  { label: 'Scenes', key: 'scenes' },
];

/**
 * Filter items matching Flutter's explore_category_filter.dart:
 * - 'all': all items
 * - 'pieces': pieces that are not video
 * - 'scenes': posts or any video items
 */
function filterExploreItems(items, category) {
  if (!items || items.length === 0) return [];
  if (category === 'pieces') {
    return items.filter((item) => item.type === 'piece' && !item.isVideo);
  }
  if (category === 'scenes') {
    return items.filter((item) => item.type === 'post' || item.isVideo);
  }
  return items;
}

/**
 * Featured Ranker matching Flutter's explore_featured_ranker.dart:
 * Scores items based on liked status (+40), saved status (+35), for sale (+5),
 * taste preferences (+25), author saved (+20), and tiebreaker.
 */
function pickFeatured(items, userProfile) {
  if (!items || items.length === 0) return null;
  let best = null;
  let bestScore = -1;

  items.forEach((item) => {
    let score = 0;
    if (item.type === 'piece') {
      if (item.isLiked) score += 40;
      if (item.isSaved) score += 35;
      if (item.isForSale) score += 5;
      if (item.medium && userProfile?.tastePreferences?.mediums) {
        const mediumLower = item.medium.toLowerCase();
        const prefs = userProfile.tastePreferences.mediums;
        if (Array.isArray(prefs)) {
          const hasMatch = prefs.some((p) => {
            const prefStr = String(p).toLowerCase();
            return mediumLower.includes(prefStr) || prefStr.includes(mediumLower);
          });
          if (hasMatch) score += 25;
        }
      }
    } else {
      if (item.isLiked) score += 40;
      if (item.isSaved) score += 35;
    }

    if (userProfile && item.authorName) {
      const author = item.authorName.toLowerCase();
      if (userProfile.savedPieces && Array.isArray(userProfile.savedPieces)) {
        const hasSavedAuthor = userProfile.savedPieces.some(
          (s) => s.authorName && s.authorName.toLowerCase() === author
        );
        if (hasSavedAuthor) score += 20;
      }
    }

    // Hash tiebreaker
    let hash = 0;
    const str = String(item.id || '');
    for (let i = 0; i < str.length; i++) {
      hash = (hash << 5) - hash + str.charCodeAt(i);
      hash |= 0;
    }
    score += Math.abs(hash) % 7;

    if (score > bestScore) {
      bestScore = score;
      best = item;
    }
  });

  return best;
}

/**
 * Explore Layout Engine matching Flutter's explore_layout_engine.dart:
 * Groups items into repeating 5-tile cycles:
 * - Quad block: TopLeft (3:4), TopRight (1:1), BottomLeft (1:1), BottomRight (3:4)
 * - FullWidth block: 16:9 banner
 * Remainder handling:
 * - 1 item: FullWidth (16:9)
 * - 2 items: TwoUp (1:1, 1:1)
 * - 3 items: TwoUp + FullWidth
 * - 4 items: Quad block
 */
function buildBlocks(items) {
  if (!items || items.length === 0) return [];
  const blocks = [];
  let index = 0;
  const tilesPerCycle = 5;

  while (index + tilesPerCycle <= items.length) {
    blocks.push({
      type: 'quad',
      topLeft: { item: items[index], ratio: '3 / 4' },
      topRight: { item: items[index + 1], ratio: '1 / 1' },
      bottomLeft: { item: items[index + 2], ratio: '1 / 1' },
      bottomRight: { item: items[index + 3], ratio: '3 / 4' },
    });
    blocks.push({
      type: 'fullwidth',
      tile: { item: items[index + 4], ratio: '16 / 9' },
    });
    index += tilesPerCycle;
  }

  const remainder = items.length - index;
  if (remainder > 0) {
    const rest = items.slice(index);
    if (remainder === 1) {
      blocks.push({ type: 'fullwidth', tile: { item: rest[0], ratio: '16 / 9' } });
    } else if (remainder === 2) {
      blocks.push({
        type: 'twoup',
        left: { item: rest[0], ratio: '1 / 1' },
        right: { item: rest[1], ratio: '1 / 1' },
      });
    } else if (remainder === 3) {
      blocks.push({
        type: 'twoup',
        left: { item: rest[0], ratio: '1 / 1' },
        right: { item: rest[1], ratio: '1 / 1' },
      });
      blocks.push({ type: 'fullwidth', tile: { item: rest[2], ratio: '16 / 9' } });
    } else if (remainder === 4) {
      blocks.push({
        type: 'quad',
        topLeft: { item: rest[0], ratio: '3 / 4' },
        topRight: { item: rest[1], ratio: '1 / 1' },
        bottomLeft: { item: rest[2], ratio: '1 / 1' },
        bottomRight: { item: rest[3], ratio: '3 / 4' },
      });
    }
  }

  return blocks;
}

export function DiscoverPage() {
  const navigate = useNavigate();
  const [category, setCategory] = useState('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [allItems, setAllItems] = useState([]);
  const [userProfile, setUserProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [nextCursor, setNextCursor] = useState(null);

  // Nearby sellers state
  const [nearbySellers, setNearbySellers] = useState([]);
  const [nearbyLoading, setNearbyLoading] = useState(true);
  const [permissionDenied, setPermissionDenied] = useState(false);
  // True until we know it's safe to auto-fetch — a browser's native location
  // prompt firing the instant this page loads, with no context, reads as a
  // site being pushy. We only skip straight to fetching (no prompt shown at
  // all) when the Permissions API says access was already granted; otherwise
  // we wait for the user to explicitly opt in via the CTA below.
  const [nearbyPrompt, setNearbyPrompt] = useState(true);

  // Live user search state
  const [userResults, setUserResults] = useState([]);
  const [userSearchLoading, setUserSearchLoading] = useState(false);
  const [userSearchError, setUserSearchError] = useState(null);
  const searchDebounceRef = useRef(null);

  // 1. Fetch User Profile
  useEffect(() => {
    let cancelled = false;
    apiFetch('/api/users/me', { auth: true })
      .then((profile) => {
        if (!cancelled && profile) setUserProfile(profile);
      })
      .catch(() => {
        /* guest or non-onboarded */
      });
    return () => {
      cancelled = true;
    };
  }, []);

  // 2. Fetch Explore Data from Backend API (/api/feed/explore)
  const loadExploreData = useCallback(async (cat = 'all', cursor = null, append = false) => {
    if (append) {
      if (loadingMore || !nextCursor) return;
      setLoadingMore(true);
    } else {
      setLoading(true);
    }

    try {
      const queryParams = new URLSearchParams();
      if (cat && cat !== 'all') queryParams.set('medium', cat);
      if (cursor) queryParams.set('cursor', cursor);

      const queryString = queryParams.toString();
      const path = `/api/feed/explore${queryString ? `?${queryString}` : ''}`;
      const res = await apiFetch(path, { auth: true });

      const rawItems = res?.items || (Array.isArray(res) ? res : []);
      const cursorVal = res?.nextCursor || null;

      const formatted = rawItems.map((item) => {
        const isPost = item.type === 'post';
        const isPiece = item.type === 'piece';
        const isVideo = item.mediaType === 'video' || item.isVideo;

        return {
          id: item.id || item._id,
          type: isPost ? 'post' : isPiece ? 'piece' : 'piece',
          title: item.title || item.caption || 'Untitled',
          caption: item.caption || item.title || '',
          medium: item.medium || (isPost ? 'Scene' : ''),
          authorName: item.author?.name || item.authorName || 'Artist',
          authorUsername: item.author?.username || item.authorUsername || '',
          authorAvatarUrl: item.author?.profilePhotoUrl || item.authorAvatarUrl,
          mediaUrl: item.mediaUrl,
          mediaType: item.mediaType || (isVideo ? 'video' : 'image'),
          isVideo: Boolean(isVideo),
          thumbnailUrl: item.thumbnailUrl || item.mediaUrl,
          isForSale: Boolean(item.isForSale || item.isAvailableListing),
          isLiked: Boolean(item.isLiked),
          isSaved: Boolean(item.isSaved),
          status: item.status === 'sold' || item.status === 'reserved' ? 'sold' : item.isAvailableListing ? 'live' : null,
          priceDisplay: item.priceDisplay || (item.price ? `$${item.price}` : null),
        };
      });

      setAllItems((prev) => (append ? [...prev, ...formatted] : formatted));
      setNextCursor(cursorVal);
    } catch {
      if (!append) {
        setAllItems([]);
        setNextCursor(null);
      }
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  }, [loadingMore, nextCursor]);

  // Initial explore load
  useEffect(() => {
    loadExploreData(category);
  }, [category, loadExploreData]);

  // 3. Fetch Nearby Sellers from Backend API (/api/users/nearby)
  const loadNearbySellers = useCallback(async () => {
    setNearbyPrompt(false);
    setNearbyLoading(true);
    setPermissionDenied(false);

    if (!('geolocation' in navigator)) {
      setNearbyLoading(false);
      return;
    }

    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          const lat = pos.coords.latitude;
          const lng = pos.coords.longitude;
          const res = await apiFetch(`/api/users/nearby?lat=${lat}&lng=${lng}`, { auth: true });
          const sellers = Array.isArray(res) ? res : res?.data || [];
          setNearbySellers(
            sellers.map((s) => ({
              id: s.id || s._id,
              displayName: s.displayName || s.name || s.username,
              username: s.username,
              distanceDisplay: s.distanceDisplay || (s.distanceKm ? `${s.distanceKm.toFixed(1)} km away` : 'Nearby'),
              profilePhotoUrl: s.profilePhotoUrl || s.avatarUrl,
            }))
          );
        } catch {
          setNearbySellers([]);
        } finally {
          setNearbyLoading(false);
        }
      },
      (err) => {
        if (err.code === err.PERMISSION_DENIED) {
          setPermissionDenied(true);
        }
        setNearbyLoading(false);
      },
      { timeout: 8000 }
    );
  }, []);

  useEffect(() => {
    let cancelled = false;
    if (!navigator.permissions?.query) {
      // Permissions API unsupported (Safari) — checking state would require
      // prompting, which is exactly what we're trying to avoid doing blindly.
      // Wait for the explicit opt-in below instead.
      setNearbyLoading(false);
      return;
    }
    navigator.permissions
      .query({ name: 'geolocation' })
      .then((status) => {
        if (cancelled) return;
        if (status.state === 'granted') {
          loadNearbySellers();
        } else {
          setNearbyLoading(false);
        }
      })
      .catch(() => {
        if (!cancelled) setNearbyLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [loadNearbySellers]);

  // 4. Live User Search (/api/conversations/search-users)
  const handleSearchChange = (e) => {
    const value = e.target.value;
    setSearchQuery(value);

    if (searchDebounceRef.current) {
      clearTimeout(searchDebounceRef.current);
    }

    const trimmed = value.trim();
    if (!trimmed) {
      setUserResults([]);
      setUserSearchLoading(false);
      setUserSearchError(null);
      return;
    }

    setUserSearchLoading(true);
    setUserSearchError(null);

    searchDebounceRef.current = setTimeout(async () => {
      try {
        const res = await apiFetch(`/api/conversations/search-users?q=${encodeURIComponent(trimmed)}`, { auth: true });
        const list = Array.isArray(res) ? res : res?.data || [];
        setUserResults(
          list.map((u) => ({
            id: u.id || u._id,
            displayName: u.displayName || u.name || u.username,
            username: u.username,
            profilePhotoUrl: u.profilePhotoUrl || u.avatarUrl,
          }))
        );
      } catch (err) {
        setUserSearchError(err.message || 'Search failed');
      } finally {
        setUserSearchLoading(false);
      }
    }, 300);
  };

  const clearSearch = () => {
    setSearchQuery('');
    setUserResults([]);
    setUserSearchLoading(false);
    setUserSearchError(null);
  };

  // 5. Scroll listener for infinite scroll pagination
  useEffect(() => {
    const handleScroll = () => {
      if (loading || loadingMore || !nextCursor) return;
      if (window.innerHeight + window.scrollY >= document.body.offsetHeight - 350) {
        loadExploreData(category, nextCursor, true);
      }
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, [loading, loadingMore, nextCursor, category, loadExploreData]);

  // Filter & Layout Calculations matching Flutter's ExplorePage logic
  const filteredItems = filterExploreItems(allItems, category);
  const featured = pickFeatured(filteredItems, userProfile);
  const feedItems = featured ? filteredItems.filter((i) => i.id !== featured.id) : filteredItems;
  const blocks = buildBlocks(feedItems);

  const isSearchingUsers = searchQuery.trim().length > 0;

  const handleTileClick = (item) => {
    if (item.type === 'piece') {
      navigate(`/piece/${item.id}`);
    } else {
      navigate(`/post`, { state: { postId: item.id } });
    }
  };

  const handleUserClick = (username) => {
    if (username) {
      navigate(`/profile?username=${username}`);
    }
  };

  return (
    <div className="discover-page">
      <div className="discover-container">
        {/* Sticky Header with Search Input & Category Pills */}
        <div className="discover-sticky-header">
          <div className="discover-search-bar">
            <Search size={20} color="var(--cream-text-secondary)" strokeWidth={1.8} />
            <input
              type="text"
              className="discover-search-input"
              value={searchQuery}
              onChange={handleSearchChange}
              placeholder="Search artists, pieces, or usernames"
            />
            {searchQuery ? (
              <button className="discover-clear-btn" onClick={clearSearch} aria-label="Clear search">
                <X size={12} strokeWidth={2.5} />
              </button>
            ) : (
              <SlidersHorizontal size={20} color="var(--cream-text-secondary)" strokeWidth={1.8} />
            )}
          </div>

          {!isSearchingUsers && (
            <div className="discover-category-row">
              {CATEGORIES.map((c) => (
                <button
                  key={c.key}
                  className={`discover-chip ${category === c.key ? 'active' : ''}`}
                  onClick={() => setCategory(c.key)}
                >
                  {c.label}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Live User Search Mode */}
        {isSearchingUsers ? (
          <div className="discover-user-results">
            {userSearchLoading && userResults.length === 0 ? (
              <div style={{ padding: '32px 0', textAlign: 'center', color: 'var(--cream-text-secondary)', fontSize: 14 }}>
                Searching artists...
              </div>
            ) : userSearchError ? (
              <div style={{ padding: '32px 0', textAlign: 'center', color: 'var(--cream-text-secondary)', fontSize: 14 }}>
                Search failed: {userSearchError}
              </div>
            ) : userResults.length === 0 ? (
              <div style={{ padding: '48px 0', textAlign: 'center', color: 'var(--cream-text-secondary)', fontSize: 14 }}>
                No users found for "{searchQuery}"
              </div>
            ) : (
              userResults.map((user) => (
                <div
                  key={user.id || user.username}
                  className="discover-user-card"
                  onClick={() => handleUserClick(user.username)}
                >
                  {user.profilePhotoUrl ? (
                    <img src={user.profilePhotoUrl} alt={user.displayName} className="discover-user-avatar" />
                  ) : (
                    <div className="discover-user-avatar-placeholder">
                      {(user.displayName || user.username || 'A')[0].toUpperCase()}
                    </div>
                  )}
                  <div>
                    <div className="discover-user-name">{user.displayName || user.username}</div>
                    <div className="discover-user-username">@{user.username}</div>
                  </div>
                </div>
              ))
            )}
          </div>
        ) : (
          <>
            {/* Featured Spotlight Card */}
            {!loading && featured && (
              <div className="discover-hero-card" onClick={() => handleTileClick(featured)}>
                <img
                  src={featured.mediaUrl || featured.thumbnailUrl}
                  alt={featured.title}
                  className="discover-hero-img"
                  loading="lazy"
                />
                <div className="discover-hero-badge">Featured for You</div>
                <div className="discover-hero-scrim">
                  <div className="discover-hero-artist">
                    {featured.authorAvatarUrl ? (
                      <img src={featured.authorAvatarUrl} alt={featured.authorName} className="discover-hero-avatar" />
                    ) : (
                      <div className="discover-user-avatar-placeholder" style={{ width: 26, height: 26, fontSize: 12 }}>
                        {(featured.authorName || 'A')[0]}
                      </div>
                    )}
                    <span className="discover-hero-artist-name">{featured.authorName}</span>
                  </div>
                  <div className="discover-hero-title">{featured.title}</div>
                  {featured.caption && <div className="discover-hero-subtitle">{featured.caption}</div>}
                </div>
              </div>
            )}

            {/* Sellers Near You Section */}
            {!nearbyLoading && nearbyPrompt && (
              <div
                style={{
                  padding: '12px 4px',
                  color: 'var(--cream-text-secondary)',
                  fontSize: 12,
                  cursor: 'pointer',
                }}
                onClick={loadNearbySellers}
              >
                See sellers near you — enable location
              </div>
            )}

            {!nearbyLoading && !nearbyPrompt && permissionDenied && (
              <div
                style={{
                  padding: '12px 4px',
                  color: 'var(--cream-text-secondary)',
                  fontSize: 12,
                  cursor: 'pointer',
                }}
                onClick={loadNearbySellers}
              >
                Location permission denied — tap to try again
              </div>
            )}

            {!nearbyLoading && nearbySellers.length > 0 && (
              <div className="discover-sellers-section">
                <div className="discover-section-title">Sellers near you</div>
                <div className="discover-sellers-scroll">
                  {nearbySellers.map((seller) => (
                    <div
                      key={seller.id || seller.username}
                      className="discover-seller-item"
                      onClick={() => handleUserClick(seller.username)}
                    >
                      <div className="discover-seller-avatar-ring">
                        {seller.profilePhotoUrl ? (
                          <img
                            src={seller.profilePhotoUrl}
                            alt={seller.displayName}
                            className="discover-seller-avatar"
                          />
                        ) : (
                          <div
                            className="discover-seller-avatar"
                            style={{
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              background: 'var(--cream-cta-fill)',
                              color: '#fff',
                              fontWeight: 600,
                              fontSize: 18,
                            }}
                          >
                            {(seller.displayName || 'S')[0].toUpperCase()}
                          </div>
                        )}
                      </div>
                      <div className="discover-seller-name">{seller.displayName}</div>
                      <div className="discover-seller-dist">{seller.distanceDisplay}</div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Main Explore Feed Block Grid */}
            {loading && allItems.length === 0 ? (
              <div className="discover-grid-container" style={{ marginTop: 16 }}>
                <div className="discover-quad-block">
                  <div className="discover-quad-col">
                    <div className="discover-skeleton-tile" style={{ aspectRatio: '3 / 4' }} />
                    <div className="discover-skeleton-tile" style={{ aspectRatio: '1 / 1' }} />
                  </div>
                  <div className="discover-quad-col">
                    <div className="discover-skeleton-tile" style={{ aspectRatio: '1 / 1' }} />
                    <div className="discover-skeleton-tile" style={{ aspectRatio: '3 / 4' }} />
                  </div>
                </div>
              </div>
            ) : blocks.length === 0 ? (
              <div style={{ padding: '64px 0', textAlign: 'center', color: 'var(--cream-text-secondary)', fontSize: 14 }}>
                Nothing to explore yet.
              </div>
            ) : (
              <div className="discover-grid-container">
                {blocks.map((block, idx) => {
                  if (block.type === 'quad') {
                    return (
                      <div key={`quad-${idx}`} className="discover-quad-block">
                        <div className="discover-quad-col">
                          <TileView tile={block.topLeft} onClick={handleTileClick} />
                          <TileView tile={block.bottomLeft} onClick={handleTileClick} />
                        </div>
                        <div className="discover-quad-col">
                          <TileView tile={block.topRight} onClick={handleTileClick} />
                          <TileView tile={block.bottomRight} onClick={handleTileClick} />
                        </div>
                      </div>
                    );
                  }
                  if (block.type === 'fullwidth') {
                    return (
                      <div key={`full-${idx}`} className="discover-fullwidth-block">
                        <TileView tile={block.tile} onClick={handleTileClick} />
                      </div>
                    );
                  }
                  if (block.type === 'twoup') {
                    return (
                      <div key={`two-${idx}`} className="discover-twoup-block">
                        <TileView tile={block.left} onClick={handleTileClick} />
                        <TileView tile={block.right} onClick={handleTileClick} />
                      </div>
                    );
                  }
                  return null;
                })}
              </div>
            )}

            {loadingMore && (
              <div style={{ textAlign: 'center', padding: '24px 0', color: 'var(--cream-text-secondary)', fontSize: 13 }}>
                Loading more items...
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}

function TileView({ tile, onClick }) {
  if (!tile || !tile.item) return null;
  const { item, ratio } = tile;
  const isVideo = item.isVideo || item.mediaType === 'video';
  const displayUrl = isVideo ? item.thumbnailUrl || item.mediaUrl : item.mediaUrl;

  return (
    <div className="discover-tile" style={{ aspectRatio: ratio }} onClick={() => onClick(item)}>
      {displayUrl ? (
        <img src={displayUrl} alt={item.title} className="discover-tile-img" loading="lazy" />
      ) : (
        <div className="discover-skeleton-tile" style={{ width: '100%', height: '100%' }} />
      )}

      {isVideo && (
        <div className="discover-video-overlay">
          <div className="discover-play-btn">
            <Play size={20} fill="#ffffff" color="#ffffff" />
          </div>
        </div>
      )}

      {item.isForSale && (
        <div className={`discover-tile-badge ${item.status === 'sold' ? 'collected' : 'available'}`}>
          {item.status === 'sold' ? 'Collected' : item.priceDisplay || 'For Sale'}
        </div>
      )}
    </div>
  );
}
