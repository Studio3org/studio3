import { useCallback, useEffect, useRef, useState } from 'react';
import { useRequireLogin } from '../../hooks/useRequireLogin';
import { friendlyError, setLiked, setSaved } from '../../services/socialApi';
import { onAuthorBlocked } from '../../services/blockedAuthors';

const keyOf = (item) => `${item.type}:${item.id}`;

/**
 * Optimistic like / save for feed cards. Overrides live beside the fetched items (keyed by
 * type:id) so a page append never clobbers a tap, and a failed write rolls back with the
 * backend's message. Guests are sent to log in first.
 *
 * @param {(message: string) => void} [onError] toast callback
 */
export function useFeedEngagement(onError) {
  const requireLogin = useRequireLogin();
  const [overrides, setOverrides] = useState({});
  const pending = useRef(new Set());

  const stateFor = useCallback(
    (item) => ({
      isLiked: Boolean(item.isLiked),
      likeCount: item.likeCount ?? 0,
      isSaved: Boolean(item.isSaved),
      ...overrides[keyOf(item)],
    }),
    [overrides],
  );

  const patch = (key, next) => setOverrides((prev) => ({ ...prev, [key]: { ...prev[key], ...next } }));

  const toggleLike = useCallback(
    async (item) => {
      if (!requireLogin()) return;
      const key = keyOf(item);
      if (pending.current.has(`like:${key}`)) return;
      const before = stateFor(item);
      const liked = !before.isLiked;
      pending.current.add(`like:${key}`);
      patch(key, { isLiked: liked, likeCount: Math.max(0, before.likeCount + (liked ? 1 : -1)) });
      try {
        const res = await setLiked(item.type, item.id, liked);
        patch(key, { isLiked: Boolean(res?.liked ?? liked), likeCount: res?.likeCount ?? before.likeCount });
      } catch (e) {
        patch(key, { isLiked: before.isLiked, likeCount: before.likeCount });
        onError?.(friendlyError(e));
      } finally {
        pending.current.delete(`like:${key}`);
      }
    },
    [requireLogin, stateFor, onError],
  );

  const toggleSave = useCallback(
    async (item) => {
      if (!requireLogin()) return;
      const key = keyOf(item);
      if (pending.current.has(`save:${key}`)) return;
      const before = stateFor(item);
      const saved = !before.isSaved;
      pending.current.add(`save:${key}`);
      patch(key, { isSaved: saved });
      try {
        const res = await setSaved(item.type, item.id, saved);
        patch(key, { isSaved: Boolean(res?.saved ?? saved) });
      } catch (e) {
        patch(key, { isSaved: before.isSaved });
        onError?.(friendlyError(e));
      } finally {
        pending.current.delete(`save:${key}`);
      }
    },
    [requireLogin, stateFor, onError],
  );

  return { stateFor, toggleLike, toggleSave };
}

/// Re-renders the caller whenever an author is blocked in this tab, so lists filtered with
/// isBlockedAuthor() drop that account's content immediately.
export function useBlockedAuthorsTick() {
  const [tick, setTick] = useState(0);
  useEffect(() => onAuthorBlocked(() => setTick((t) => t + 1)), []);
  return tick;
}
