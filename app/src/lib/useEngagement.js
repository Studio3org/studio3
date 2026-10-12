import { useEffect, useState } from 'react';
import { setLiked, setSaved, friendlyError } from './social';
import { useRequireLogin } from './session';

/// Optimistic like/save state for one piece or scene. Guests are sent to login.
export function useEngagement(item) {
  const requireLogin = useRequireLogin();
  const [liked, setLikedState] = useState(item?.isLiked ?? false);
  const [likeCount, setLikeCount] = useState(item?.likeCount ?? 0);
  const [saved, setSavedState] = useState(item?.isSaved ?? false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    setLikedState(item?.isLiked ?? false);
    setLikeCount(item?.likeCount ?? 0);
    setSavedState(item?.isSaved ?? false);
  }, [item?.id, item?.isLiked, item?.likeCount, item?.isSaved]);

  const toggleLike = async () => {
    if (!item || busy || !requireLogin()) return;
    const next = !liked;
    setBusy(true);
    setError(null);
    setLikedState(next);
    setLikeCount((c) => Math.max(0, c + (next ? 1 : -1)));
    try {
      const res = await setLiked(item, next);
      if (res?.likeCount != null) setLikeCount(res.likeCount);
    } catch (e) {
      setLikedState(!next);
      setLikeCount((c) => Math.max(0, c + (next ? -1 : 1)));
      setError(friendlyError(e));
    } finally {
      setBusy(false);
    }
  };

  const toggleSave = async () => {
    if (!item || busy || !requireLogin()) return;
    const next = !saved;
    setBusy(true);
    setError(null);
    setSavedState(next);
    try {
      await setSaved(item, next);
    } catch (e) {
      setSavedState(!next);
      setError(friendlyError(e));
    } finally {
      setBusy(false);
    }
  };

  return { liked, likeCount, saved, toggleLike, toggleSave, error };
}
