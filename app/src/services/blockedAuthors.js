/// Accounts blocked in this tab, so lists already on screen can drop their content the
/// moment the block lands — the backend leaves it out of every later fetch.

const EVENT = 'studio3:author-blocked';
const blocked = new Set();

export function markBlocked(username) {
  if (!username) return;
  blocked.add(username.toLowerCase());
  window.dispatchEvent(new Event(EVENT));
}

export function markUnblocked(username) {
  if (username) blocked.delete(username.toLowerCase());
}

export function isBlockedAuthor(username) {
  return Boolean(username) && blocked.has(String(username).toLowerCase());
}

export function onAuthorBlocked(listener) {
  window.addEventListener(EVENT, listener);
  return () => window.removeEventListener(EVENT, listener);
}
