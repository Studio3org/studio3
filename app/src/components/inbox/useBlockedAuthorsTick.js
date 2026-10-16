import { useEffect, useState } from 'react';
import { onAuthorBlocked } from '../../services/blockedAuthors';

/// Re-renders the caller when someone is blocked this session, so lists can drop that
/// account's rows via `isBlockedAuthor` at render time without refetching.
export function useBlockedAuthorsTick() {
  const [tick, setTick] = useState(0);
  useEffect(() => onAuthorBlocked(() => setTick((t) => t + 1)), []);
  return tick;
}
