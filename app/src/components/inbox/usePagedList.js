import { useCallback, useEffect, useRef, useState } from 'react';
import { friendlyError } from '../../services/socialApi';

/**
 * Cursor-paginated list state for the inbox tabs. Loads the first page the first
 * time `enabled` is true (tabs fetch lazily) and keeps it across tab switches.
 *
 * @param {(cursor: string|null) => Promise<{items: any[], nextCursor?: string|null}>} fetchPage
 * @param {boolean} enabled
 */
export function usePagedList(fetchPage, enabled) {
  const [items, setItems] = useState(null); // null until the first page lands
  const [cursor, setCursor] = useState(null);
  const [error, setError] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [moreError, setMoreError] = useState(null);
  const started = useRef(false);
  const fetchRef = useRef(fetchPage);
  fetchRef.current = fetchPage;

  const loadFirst = useCallback(() => {
    started.current = true;
    setError(null);
    setItems(null);
    fetchRef.current(null)
      .then((data) => {
        setItems(data?.items || []);
        setCursor(data?.nextCursor || null);
      })
      .catch((e) => {
        setError(friendlyError(e));
        setItems([]);
      });
  }, []);

  useEffect(() => {
    if (enabled && !started.current) loadFirst();
  }, [enabled, loadFirst]);

  const loadMore = useCallback(() => {
    if (!cursor || loadingMore) return;
    setLoadingMore(true);
    setMoreError(null);
    fetchRef.current(cursor)
      .then((data) => {
        setItems((list) => {
          const known = new Set((list || []).map((i) => i.id));
          return [...(list || []), ...(data?.items || []).filter((i) => !known.has(i.id))];
        });
        setCursor(data?.nextCursor || null);
      })
      .catch((e) => setMoreError(friendlyError(e)))
      .finally(() => setLoadingMore(false));
  }, [cursor, loadingMore]);

  return { items, setItems, error, hasMore: Boolean(cursor), loadMore, loadingMore, moreError, reload: loadFirst };
}
