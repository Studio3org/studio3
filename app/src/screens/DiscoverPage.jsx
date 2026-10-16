import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, SlidersHorizontal, X, Play, Check } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useBreakpoint } from '../hooks/useBreakpoint';
import { InboxRail } from '../components/layout/InboxRail';
import { ActionSheet, SheetItem } from '../components/common/ActionSheet';
import { fetchFeed, fetchNearbySellers, formatPrice, isVideoItem, searchUsers } from '../services/feedApi';
import { friendlyError } from '../services/socialApi';
import { isBlockedAuthor } from '../services/blockedAuthors';
import { contentHref, profileHref } from '../utils/contentLinks';
import { useBlockedAuthorsTick } from '../components/feed/useFeedEngagement';
import './DiscoverPage.css';

/**
 * Explore chips, matching explore_category_filter.dart. `medium` is what the explore
 * endpoint gets (`video` → video scenes only, a medium → pieces of that medium); All /
 * Pieces / Scenes load everything and filter on this side, since the backend has no
 * pieces/scenes medium.
 */
const CATEGORIES = [
  { label: 'All', key: 'all' },
  { label: 'Pieces', key: 'pieces' },
  { label: 'Scenes', key: 'scenes' },
  { label: 'Videos', key: 'videos', medium: 'video' },
  ...['Painting', 'Sculpture', 'Photography', 'Digital', 'Drawing', 'Mixed media'].map((label) => ({
    label,
    key: label.toLowerCase(),
    medium: label.toLowerCase(),
  })),
];

const categoryByKey = (key) => CATEGORIES.find((c) => c.key === key) || CATEGORIES[0];

/**
 * Filter items matching Flutter's explore_category_filter.dart:
 * - 'pieces': pieces that are not video
 * - 'scenes': posts or any video items
 * - 'videos': video scenes (the server already narrowed it; this drops strays)
 * - everything else: as the server returned it
 */
function filterExploreItems(items, category) {
  if (!items || items.length === 0) return [];
  if (category === 'pieces') {
    return items.filter((item) => item.type === 'piece' && !item.isVideo);
  }
  if (category === 'scenes') {
    return items.filter((item) => item.type === 'post' || item.isVideo);
  }
  if (category === 'videos') {
    return items.filter((item) => item.isVideo);
  }
  return items;
}

/**
 * Featured Ranker matching Flutter's explore_featured_ranker.dart:
 * Scores items based on liked status (+40), saved status (+35), for sale (+5),
 * taste preferences (+25), and tiebreaker.
 */
function pickFeatured(items, userProfile) {
  if (!items || items.length === 0) return null;
  let best = null;
  let bestScore = -1;

  items.forEach((item) => {
    let score = 0;
    if (item.isLiked) score += 40;
    if (item.isSaved) score += 35;
    if (item.type === 'piece') {
      if (item.isForSale) score += 5;
      const prefs = userProfile?.tastePreferences?.mediums;
      if (item.medium && Array.isArray(prefs)) {
        const mediumLower = item.medium.toLowerCase();
        const hasMatch = prefs.some((p) => {
          const prefStr = String(p).toLowerCase();
          return mediumLower.includes(prefStr) || prefStr.includes(mediumLower);
        });
        if (hasMatch) score += 25;
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

/** FeedItem (piece or post) → the tile's view model. */
function mapExploreItem(item) {
  const isPost = item.type === 'post';
  const isVideo = isVideoItem(item);
  const collected = item.listingState === 'collected' || item.listingState === 'auction_ended';
  return {
    id: item.id,
    type: isPost ? 'post' : 'piece',
    title: item.title || item.caption || 'Untitled',
    caption: item.caption || '',
    medium: item.medium || (isPost ? 'Scene' : ''),
    authorName: item.author?.name || item.author?.username || 'Artist',
    authorUsername: item.author?.username || '',
    authorAvatarUrl: item.author?.profilePhotoUrl,
    mediaUrl: item.mediaUrl,
    mediaType: item.mediaType || 'image',
    isVideo,
    // Never fall back to the .mp4 for an <img>; a missing poster shows the skeleton.
    thumbnailUrl: isVideo ? item.thumbnailUrl : item.thumbnailUrl || item.mediaUrl,
    isForSale: Boolean(item.isForSale),
    isLiked: Boolean(item.isLiked),
    isSaved: Boolean(item.isSaved),
    status: collected ? 'sold' : item.listingState === 'auction_live' ? 'auction' : null,
    priceDisplay: formatPrice(item.priceCents, item.currency),
  };
}

export function DiscoverPage() {
  const navigate = useNavigate();
  const { user, status: authStatus } = useAuth();
  const authenticated = authStatus === 'authenticated';
  const [category, setCategory] = useState('all');
  const [categorySheetOpen, setCategorySheetOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [allItems, setAllItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [loadError, setLoadError] = useState(null);
  const [nextCursor, setNextCursor] = useState(null);
  const [reloadKey, setReloadKey] = useState(0);
  useBlockedAuthorsTick();

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
  const searchSeq = useRef(0);

  // The featured ranker reads taste preferences off the signed-in profile. AuthContext
  // already holds GET /api/user/me for a signed-in viewer (the old /api/users/me call
  // 404'd), and a guest has no profile at all — so no extra request here.
  const userProfile = authenticated ? user : null;

  // Explore pages. `exploreSeq` invalidates in-flight pages when the chip changes, so a
  // slow "All" page can't land in "Painting".
  const exploreSeq = useRef(0);
  const medium = categoryByKey(category).medium;

  useEffect(() => {
    if (authStatus === 'loading') return undefined;
    const seq = ++exploreSeq.current;
    const controller = new AbortController();
    setLoading(true);
    setLoadError(null);
    setAllItems([]);
    setNextCursor(null);
    fetchFeed('explore', { medium, signal: controller.signal })
      .then((page) => {
        if (seq !== exploreSeq.current) return;
        setAllItems(page.items.map(mapExploreItem));
        setNextCursor(page.nextCursor);
      })
      .catch((e) => {
        if (seq !== exploreSeq.current || e.name === 'AbortError') return;
        setLoadError(friendlyError(e));
      })
      .finally(() => {
        if (seq === exploreSeq.current) setLoading(false);
      });
    return () => controller.abort();
  }, [medium, authStatus, reloadKey]);

  const loadMore = useCallback(() => {
    if (loading || loadingMore || !nextCursor) return;
    const seq = exploreSeq.current;
    setLoadingMore(true);
    fetchFeed('explore', { medium, cursor: nextCursor })
      .then((page) => {
        if (seq !== exploreSeq.current) return;
        setAllItems((prev) => {
          const seen = new Set(prev.map((i) => `${i.type}:${i.id}`));
          return [...prev, ...page.items.map(mapExploreItem).filter((i) => !seen.has(`${i.type}:${i.id}`))];
        });
        setNextCursor(page.nextCursor);
      })
      .catch(() => {
        // Stop paging on failure rather than hammering a failing endpoint on every scroll.
        if (seq === exploreSeq.current) setNextCursor(null);
      })
      .finally(() => {
        if (seq === exploreSeq.current) setLoadingMore(false);
      });
  }, [loading, loadingMore, nextCursor, medium]);

  // 3. Nearby sellers (/api/users/nearby — optional auth, works for guests)
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
          const sellers = await fetchNearbySellers(pos.coords.latitude, pos.coords.longitude);
          setNearbySellers(
            sellers.map((s) => ({
              id: s.id || s.username,
              displayName: s.name || s.username,
              username: s.username,
              distanceDisplay: typeof s.distanceKm === 'number' ? `${s.distanceKm.toFixed(1)} km away` : 'Nearby',
              profilePhotoUrl: s.profilePhotoUrl,
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
      return undefined;
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

  // 4. Live user search (/api/conversations/search-users — optional auth)
  const handleSearchChange = (e) => {
    const value = e.target.value;
    setSearchQuery(value);

    if (searchDebounceRef.current) {
      clearTimeout(searchDebounceRef.current);
    }

    const trimmed = value.trim();
    const seq = ++searchSeq.current;
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
        const list = await searchUsers(trimmed);
        // Typing on while a request is in flight: only the newest query may land.
        if (seq !== searchSeq.current) return;
        setUserResults(
          list.map((u) => ({
            displayName: u.name || u.username,
            username: u.username,
            profilePhotoUrl: u.profilePhotoUrl,
          }))
        );
      } catch (err) {
        if (seq === searchSeq.current) setUserSearchError(friendlyError(err));
      } finally {
        if (seq === searchSeq.current) setUserSearchLoading(false);
      }
    }, 300);
  };

  const clearSearch = () => {
    searchSeq.current += 1;
    setSearchQuery('');
    setUserResults([]);
    setUserSearchLoading(false);
    setUserSearchError(null);
  };

  useEffect(() => () => clearTimeout(searchDebounceRef.current), []);

  // 5. Scroll listener for infinite scroll pagination
  useEffect(() => {
    const handleScroll = () => {
      if (window.innerHeight + window.scrollY >= document.body.offsetHeight - 350) loadMore();
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, [loadMore]);

  // Filter & Layout Calculations matching Flutter's ExplorePage logic
  const filteredItems = filterExploreItems(
    allItems.filter((i) => !isBlockedAuthor(i.authorUsername)),
    category
  );
  const featured = pickFeatured(filteredItems, userProfile);
  const feedItems = featured ? filteredItems.filter((i) => i !== featured) : filteredItems;
  const blocks = buildBlocks(feedItems);

  // A client-side chip (Pieces / Scenes) can filter a whole page away; keep paging
  // until something shows or the feed runs out, since there may be no scroll to trigger it.
  useEffect(() => {
    if (!loading && !loadingMore && nextCursor && filteredItems.length < 6) loadMore();
  }, [loading, loadingMore, nextCursor, filteredItems.length, loadMore]);

  const isSearchingUsers = searchQuery.trim().length > 0;

  // Videos open in the Reels player at that clip; image scenes and pieces open their page.
  const handleTileClick = (item) => {
    if (item.isVideo && item.type === 'post') {
      navigate(`/reels?start=${encodeURIComponent(item.id)}`);
    } else {
      navigate(contentHref(item));
    }
  };

  const handleUserClick = (username) => {
    if (username) navigate(profileHref(username));
  };

  const { railLabeled } = useBreakpoint();
  const showRail = railLabeled && authenticated;
  const featuredImg = featured ? (featured.isVideo ? featured.thumbnailUrl : featured.mediaUrl || featured.thumbnailUrl) : null;

  return (
    <div className="discover-page">
      <div style={{ display: 'flex', gap: 48, maxWidth: showRail ? 935 + 320 + 48 : 935, margin: '0 auto' }}>
      <div className="discover-container" style={{ margin: 0, flex: 1, minWidth: 0 }}>
        {/* Sticky Header with Search Input & Category Pills */}
        <div className="discover-sticky-header">
          <div className="discover-search-bar">
            <Search size={20} color="var(--cream-text-secondary)" strokeWidth={1.8} />
            <input
              type="text"
              className="discover-search-input"
              value={searchQuery}
              onChange={handleSearchChange}
              placeholder="Search artists, collectors, or usernames"
              aria-label="Search people"
            />
            {searchQuery ? (
              <button className="discover-clear-btn" onClick={clearSearch} aria-label="Clear search">
                <X size={12} strokeWidth={2.5} />
              </button>
            ) : (
              <button
                type="button"
                className="discover-filter-btn"
                onClick={() => setCategorySheetOpen(true)}
                aria-label="Categories"
              >
                <SlidersHorizontal size={20} color="var(--cream-text-secondary)" strokeWidth={1.8} />
              </button>
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
                Searching people...
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
              userResults
                .filter((u) => !isBlockedAuthor(u.username))
                .map((u) => (
                  <div
                    key={u.username}
                    className="discover-user-card"
                    role="link"
                    tabIndex={0}
                    onClick={() => handleUserClick(u.username)}
                    onKeyDown={(e) => e.key === 'Enter' && handleUserClick(u.username)}
                  >
                    {u.profilePhotoUrl ? (
                      <img src={u.profilePhotoUrl} alt={u.displayName} className="discover-user-avatar" />
                    ) : (
                      <div className="discover-user-avatar-placeholder">
                        {(u.displayName || u.username || 'A')[0].toUpperCase()}
                      </div>
                    )}
                    <div>
                      <div className="discover-user-name">{u.displayName || u.username}</div>
                      <div className="discover-user-username">@{u.username}</div>
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
                {featuredImg && (
                  <img src={featuredImg} alt={featured.title} className="discover-hero-img" loading="lazy" />
                )}
                {featured.isVideo && (
                  <div className="discover-video-overlay">
                    <div className="discover-play-btn">
                      <Play size={20} fill="#ffffff" color="#ffffff" />
                    </div>
                  </div>
                )}
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
                  {featured.caption && featured.caption !== featured.title && (
                    <div className="discover-hero-subtitle">{featured.caption}</div>
                  )}
                </div>
              </div>
            )}

            {/* Reels entry: video scenes in the full-screen vertical player. */}
            {['all', 'scenes', 'videos'].includes(category) && (
            <button
              type="button"
              className="discover-reels-entry"
              onClick={() => navigate('/reels')}
            >
              <span className="discover-reels-entry-icon">
                <Play size={14} fill="currentColor" />
              </span>
              <span className="discover-reels-entry-text">
                <span className="discover-reels-entry-title">Watch reels</span>
                <span className="discover-reels-entry-sub">Studio visits, process and new work, full screen</span>
              </span>
            </button>
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

            {!nearbyLoading && nearbySellers.some((s) => !isBlockedAuthor(s.username)) && (
              <div className="discover-sellers-section">
                <div className="discover-section-title">Sellers near you</div>
                <div className="discover-sellers-scroll">
                  {nearbySellers
                    .filter((s) => !isBlockedAuthor(s.username))
                    .map((seller) => (
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
            {loading || (filteredItems.length === 0 && nextCursor) ? (
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
            ) : loadError ? (
              <div style={{ padding: '64px 0', textAlign: 'center', color: 'var(--cream-text-secondary)', fontSize: 14 }}>
                <div>{loadError}</div>
                <button type="button" className="discover-chip" style={{ marginTop: 16 }} onClick={() => setReloadKey((k) => k + 1)}>
                  Try again
                </button>
              </div>
            ) : blocks.length === 0 && !featured ? (
              <div style={{ padding: '64px 0', textAlign: 'center', color: 'var(--cream-text-secondary)', fontSize: 14 }}>
                {category === 'all' ? 'Nothing to explore yet.' : `No ${categoryByKey(category).label.toLowerCase()} to explore yet.`}
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
      {/* The rail reads notifications + chats, which are account-only. */}
      {showRail && <InboxRail />}
      </div>

      {categorySheetOpen && (
        <ActionSheet title="Browse" onClose={() => setCategorySheetOpen(false)}>
          {CATEGORIES.map((c) => (
            <SheetItem
              key={c.key}
              icon={<Check size={18} style={{ opacity: c.key === category ? 1 : 0 }} />}
              onClick={() => {
                setCategory(c.key);
                setCategorySheetOpen(false);
              }}
            >
              {c.label}
            </SheetItem>
          ))}
        </ActionSheet>
      )}
    </div>
  );
}

function TileView({ tile, onClick }) {
  if (!tile || !tile.item) return null;
  const { item, ratio } = tile;
  const displayUrl = item.isVideo ? item.thumbnailUrl : item.mediaUrl;

  return (
    <div
      className="discover-tile"
      style={{ aspectRatio: ratio }}
      role="link"
      tabIndex={0}
      aria-label={item.title}
      onClick={() => onClick(item)}
      onKeyDown={(e) => e.key === 'Enter' && onClick(item)}
    >
      {displayUrl ? (
        <img src={displayUrl} alt={item.title} className="discover-tile-img" loading="lazy" />
      ) : (
        <div className="discover-skeleton-tile" style={{ width: '100%', height: '100%' }} />
      )}

      {item.isVideo && (
        <div className="discover-video-overlay">
          <div className="discover-play-btn">
            <Play size={20} fill="#ffffff" color="#ffffff" />
          </div>
        </div>
      )}

      {item.isForSale && (
        <div className={`discover-tile-badge ${item.status === 'sold' ? 'collected' : 'available'}`}>
          {item.status === 'sold'
            ? 'Collected'
            : item.status === 'auction'
              ? 'Live auction'
              : item.priceDisplay || 'For Sale'}
        </div>
      )}
    </div>
  );
}
