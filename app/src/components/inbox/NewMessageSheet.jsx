import React, { useEffect, useState } from 'react';
import { Search } from 'lucide-react';
import { ActionSheet } from '../common/ActionSheet';
import { useAuth } from '../../context/AuthContext';
import { searchUsers } from '../../services/inboxApi';
import { isBlockedAuthor } from '../../services/blockedAuthors';
import { friendlyError } from '../../services/socialApi';

const DEBOUNCE_MS = 300;

/**
 * "New message" people picker — debounced GET /api/conversations/search-users,
 * then `onPick(username)` (the inbox opens `/inbox?user=<username>`, which reuses
 * an existing thread or shows an empty composer).
 */
export function NewMessageSheet({ onPick, onClose }) {
  const { user } = useAuth();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState(null); // null = nothing searched yet
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    const q = query.trim();
    if (!q) {
      setResults(null);
      setLoading(false);
      setError(null);
      return undefined;
    }
    const controller = new AbortController();
    setLoading(true);
    const t = setTimeout(() => {
      searchUsers(q, { signal: controller.signal })
        .then((items) => {
          setResults(items);
          setError(null);
        })
        .catch((e) => {
          if (e?.name === 'AbortError') return;
          setError(friendlyError(e));
          setResults([]);
        })
        .finally(() => !controller.signal.aborted && setLoading(false));
    }, DEBOUNCE_MS);
    return () => {
      clearTimeout(t);
      controller.abort();
    };
  }, [query]);

  const me = user?.username?.toLowerCase();
  const visible = (results || []).filter(
    (u) => u.username && u.username.toLowerCase() !== me && !isBlockedAuthor(u.username),
  );

  return (
    <ActionSheet title="New message" onClose={onClose}>
      <div
        style={{
          height: 40,
          borderRadius: 9999,
          background: 'rgba(140,136,128,0.15)',
          display: 'flex',
          alignItems: 'center',
          padding: '0 14px',
          gap: 8,
          margin: '8px 0 12px',
        }}
      >
        <Search size={16} color="var(--cream-text-secondary)" />
        <input
          autoFocus
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search people"
          style={{ flex: 1, background: 'transparent', outline: 'none', fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text)' }}
        />
      </div>
      <div style={{ minHeight: 120 }}>
        {loading ? (
          <p style={hintStyle}>Searching…</p>
        ) : error ? (
          <p style={hintStyle}>{error}</p>
        ) : results === null ? (
          <p style={hintStyle}>Search by name or username.</p>
        ) : visible.length === 0 ? (
          <p style={hintStyle}>No people found.</p>
        ) : (
          visible.map((u) => (
            <button
              key={u.username}
              onClick={() => onPick(u.username)}
              style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 12, padding: '8px 0', textAlign: 'left' }}
            >
              {u.profilePhotoUrl ? (
                <img src={u.profilePhotoUrl} alt="" width={40} height={40} style={{ width: 40, height: 40, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }} />
              ) : (
                <span style={{ width: 40, height: 40, borderRadius: '50%', background: 'var(--cream-cta-fill)', flexShrink: 0 }} />
              )}
              <span style={{ minWidth: 0 }}>
                <div style={{ fontFamily: 'var(--font-inter)', fontSize: 14, fontWeight: 600, color: 'var(--slate-900)' }}>
                  {u.name || u.username}
                </div>
                <div style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--slate-500)' }}>@{u.username}</div>
              </span>
            </button>
          ))
        )}
      </div>
    </ActionSheet>
  );
}

const hintStyle = {
  fontFamily: 'var(--font-inter)',
  fontSize: 13,
  color: 'var(--cream-text-secondary)',
  textAlign: 'center',
  padding: '24px 0',
};
