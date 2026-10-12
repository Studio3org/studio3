import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Search, X } from 'lucide-react';
import { TileGrid, MediaThumb, PriceBadge } from '../components/content/FeedCard';
import { Avatar } from '../components/common/Avatar';
import { StateMessage } from '../components/common/StateMessage';
import { SafeArea } from '../components/layout/SafeArea';
import { useCursorList, useInfiniteScroll } from '../lib/useCursorList';
import { friendlyError } from '../lib/social';
import { fetchExplore, searchUsers, useVisibleItems } from '../lib/feedApi';

const searchBarStyle = {
  height: 44,
  borderRadius: 9999,
  background: 'var(--slate-100)',
  padding: '0 16px',
  display: 'flex',
  alignItems: 'center',
  gap: 8,
  flex: 1,
  fontSize: 14,
  color: 'var(--slate-500)',
};

const chipScroll = {
  display: 'flex',
  gap: 8,
  overflowX: 'auto',
  paddingBottom: 4,
  marginBottom: 20,
};
const chipStyle = (active) => ({
  height: 32,
  padding: '0 16px',
  borderRadius: 9999,
  flexShrink: 0,
  fontSize: 13,
  fontWeight: 500,
  background: active ? 'var(--slate-900)' : 'var(--slate-100)',
  color: active ? 'var(--white)' : 'var(--slate-600)',
  border: '1.5px solid',
  borderColor: active ? 'var(--slate-900)' : 'var(--slate-200)',
});

const sectionTitle = {
  fontSize: 16,
  fontWeight: 600,
  color: 'var(--slate-900)',
  marginBottom: 12,
};

const MEDIUMS = ['Painting', 'Sculpture', 'Photography', 'Digital', 'Drawing', 'Mixed media'];
const FILTERS = ['All', 'Pieces', 'Scenes', 'Videos', ...MEDIUMS];

/// Which explore query a chip maps to. All / Pieces / Scenes share the
/// unfiltered feed (Pieces and Scenes narrow it client-side), so switching
/// between them doesn't refetch.
function mediumFor(filter) {
  if (filter === 'Videos') return 'video';
  if (MEDIUMS.includes(filter)) return filter.toLowerCase();
  return null;
}

export function DiscoverPage() {
  const [filter, setFilter] = useState('All');
  const [query, setQuery] = useState('');
  const searching = query.trim().length > 0;

  return (
    <SafeArea style={{ paddingTop: 12 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
        <label style={searchBarStyle}>
          <Search size={18} strokeWidth={1.75} />
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search people"
            style={{ flex: 1, minWidth: 0, border: 'none', outline: 'none', background: 'transparent', fontSize: 14, color: 'var(--slate-900)' }}
          />
          {searching && (
            <button type="button" aria-label="Clear search" onClick={() => setQuery('')} style={{ display: 'flex', color: 'var(--slate-500)' }}>
              <X size={16} />
            </button>
          )}
        </label>
      </div>

      {searching ? (
        <PeopleResults query={query.trim()} />
      ) : (
        <>
          <div style={chipScroll}>
            {FILTERS.map((f) => (
              <button key={f} style={chipStyle(filter === f)} onClick={() => setFilter(f)}>{f}</button>
            ))}
          </div>
          <ExploreGrid key={mediumFor(filter) ?? 'all'} filter={filter} />
        </>
      )}
    </SafeArea>
  );
}

function ExploreGrid({ filter }) {
  const medium = mediumFor(filter);
  const { items, loading, loadingMore, error, reload, loadMore, nextCursor } = useCursorList(
    (cursor) => fetchExplore(cursor, medium),
    [medium],
  );
  const visible = useVisibleItems(items);
  const shown = visible.filter((item) => {
    if (filter === 'Pieces') return item.type === 'piece';
    if (filter === 'Scenes') return item.type === 'post';
    if (filter === 'Videos') return item.isVideo;
    return true;
  });
  const sentinel = useInfiniteScroll(loadMore, Boolean(nextCursor) && !loading);

  if (loading) return <StateMessage>Loading…</StateMessage>;
  if (error) return <StateMessage action="Try again" onAction={reload}>{friendlyError(error)}</StateMessage>;

  const [featured, ...rest] = shown;
  return (
    <>
      {!featured && !nextCursor && <StateMessage>Nothing to explore here yet.</StateMessage>}
      {featured && (
        <section style={{ marginBottom: 24 }}>
          <div style={sectionTitle}>Featured</div>
          <FeaturedCard item={featured} />
        </section>
      )}
      {rest.length > 0 && (
        <section>
          <div style={sectionTitle}>{filter === 'All' ? 'Explore' : filter}</div>
          <TileGrid items={rest} />
        </section>
      )}
      <div ref={sentinel} style={{ height: 1 }} />
      {loadingMore && <StateMessage style={{ padding: 16 }}>Loading more…</StateMessage>}
    </>
  );
}

/// Large lead card: media with a frosted caption strip, like the old
/// "Studio 3 Picks" cards but backed by the first explore result.
function FeaturedCard({ item }) {
  return (
    <Link to={item.href} style={{ display: 'block', position: 'relative', borderRadius: 16, overflow: 'hidden', boxShadow: 'var(--shadow-card)' }}>
      <MediaThumb item={item} aspectRatio={item.aspectRatio > 1 ? item.aspectRatio : 4 / 5} />
      <div
        style={{
          position: 'absolute',
          bottom: 0,
          left: 0,
          right: 0,
          padding: '10px 12px',
          background: 'rgba(15,23,42,0.55)',
          backdropFilter: 'blur(12px)',
          color: 'var(--white)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 8,
        }}
      >
        <div style={{ minWidth: 0 }}>
          <div style={{ fontSize: 14, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.title}</div>
          {item.author?.name && <div style={{ fontSize: 12, opacity: 0.8 }}>{item.author.name}</div>}
        </div>
        <PriceBadge item={item} />
      </div>
    </Link>
  );
}

/// People search, debounced 300ms; stale responses are ignored.
function PeopleResults({ query }) {
  const [state, setState] = useState({ loading: true, users: [], error: null });

  useEffect(() => {
    let alive = true;
    setState((s) => ({ ...s, loading: true, error: null }));
    const timer = setTimeout(() => {
      searchUsers(query)
        .then((users) => alive && setState({ loading: false, users, error: null }))
        .catch((e) => alive && setState({ loading: false, users: [], error: friendlyError(e) }));
    }, 300);
    return () => {
      alive = false;
      clearTimeout(timer);
    };
  }, [query]);

  if (state.error) return <StateMessage>{state.error}</StateMessage>;
  if (state.loading && state.users.length === 0) return <StateMessage>Searching…</StateMessage>;
  if (state.users.length === 0) return <StateMessage>No people match “{query}”.</StateMessage>;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
      {state.users.map((u) => (
        <Link
          key={u.username}
          to={`/u/${encodeURIComponent(u.username)}`}
          style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 4px', borderRadius: 12 }}
        >
          <Avatar src={u.profilePhotoUrl} name={u.name || u.username} size={44} />
          <div style={{ minWidth: 0 }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--slate-900)' }}>{u.name || u.username}</div>
            <div style={{ fontSize: 13, color: 'var(--slate-500)' }}>@{u.username}</div>
          </div>
        </Link>
      ))}
    </div>
  );
}
