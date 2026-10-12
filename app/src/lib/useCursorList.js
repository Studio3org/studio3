import { useCallback, useEffect, useRef, useState } from 'react';

/// Cursor-paginated list state. `fetchPage(cursor)` resolves `{ items, nextCursor }`.
/// Re-fetches from the top whenever `deps` change.
export function useCursorList(fetchPage, deps = []) {
  const [items, setItems] = useState([]);
  const [nextCursor, setNextCursor] = useState(null);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState(null);
  const generation = useRef(0);

  const reload = useCallback(async () => {
    const gen = ++generation.current;
    setLoading(true);
    setError(null);
    try {
      const page = await fetchPage(null);
      if (gen !== generation.current) return;
      setItems(page.items ?? []);
      setNextCursor(page.nextCursor ?? null);
    } catch (e) {
      if (gen !== generation.current) return;
      setItems([]);
      setNextCursor(null);
      setError(e);
    } finally {
      if (gen === generation.current) setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  useEffect(() => {
    reload();
  }, [reload]);

  const loadMore = useCallback(async () => {
    if (!nextCursor || loadingMore || loading) return;
    const gen = generation.current;
    setLoadingMore(true);
    try {
      const page = await fetchPage(nextCursor);
      if (gen !== generation.current) return;
      setItems((prev) => [...prev, ...(page.items ?? [])]);
      setNextCursor(page.nextCursor ?? null);
    } catch {
      // Keep what's shown; the sentinel retries on the next scroll.
    } finally {
      if (gen === generation.current) setLoadingMore(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [nextCursor, loadingMore, loading, ...deps]);

  return { items, setItems, nextCursor, loading, loadingMore, error, reload, loadMore };
}

/// Calls `onVisible` when the returned ref's element scrolls into view.
export function useInfiniteScroll(onVisible, enabled) {
  const ref = useRef(null);
  useEffect(() => {
    const node = ref.current;
    if (!node || !enabled) return undefined;
    const observer = new IntersectionObserver(
      (entries) => entries.some((e) => e.isIntersecting) && onVisible(),
      { rootMargin: '400px' },
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, [onVisible, enabled]);
  return ref;
}
