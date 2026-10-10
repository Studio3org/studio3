// Same deployed backend used by the Flutter app's ApiConfig fallback
// (lib/config/api_config.dart) — this web app has no env-driven config yet.
export const API_BASE_URL = 'https://studio3-backend.onrender.com';

// Terms of Use (EULA), served by the backend so the app, the website, and the
// App Store listing all point at one copy of the text.
export const TERMS_URL = `${API_BASE_URL}/terms`;

const TOKEN_KEY = 'studio3.accessToken';
const USER_KEY = 'studio3.user';

function readStorage(key) {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeStorage(key, value) {
  try {
    if (value == null) window.localStorage.removeItem(key);
    else window.localStorage.setItem(key, value);
  } catch {
    // Private mode / blocked storage — the session just won't persist.
  }
}

export function getAccessToken() {
  return readStorage(TOKEN_KEY);
}

export function getSessionUser() {
  const raw = readStorage(USER_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export function isLoggedIn() {
  return Boolean(getAccessToken());
}

const SESSION_EVENT = 'studio3:session';

function emitSessionChange() {
  window.dispatchEvent(new Event(SESSION_EVENT));
}

/// Subscribe to login/logout/profile changes (this tab and other tabs).
export function onSessionChange(listener) {
  const onStorage = (e) => {
    if (e.key === TOKEN_KEY || e.key === USER_KEY) listener();
  };
  window.addEventListener(SESSION_EVENT, listener);
  window.addEventListener('storage', onStorage);
  return () => {
    window.removeEventListener(SESSION_EVENT, listener);
    window.removeEventListener('storage', onStorage);
  };
}

export function setSession(accessToken, user) {
  if (accessToken !== undefined) writeStorage(TOKEN_KEY, accessToken);
  writeStorage(USER_KEY, user == null ? null : JSON.stringify(user));
  emitSessionChange();
}

/// Merge fresh profile fields (e.g. from GET /api/user/me) into the stored user.
export function updateSessionUser(fields) {
  if (!getAccessToken()) return;
  setSession(undefined, { ...(getSessionUser() ?? {}), ...fields });
}

export function clearSession() {
  writeStorage(TOKEN_KEY, null);
  writeStorage(USER_KEY, null);
  emitSessionChange();
}

export class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

async function rawFetch(path, { method, body, token }) {
  const headers = { Accept: 'application/json' };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  if (token) headers.Authorization = `Bearer ${token}`;
  let res;
  try {
    res = await fetch(`${API_BASE_URL}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      // The httpOnly refresh-token cookie rides along on every call.
      credentials: 'include',
    });
  } catch {
    throw new ApiError("Can't reach Studio3 right now. Check your connection.", 0);
  }
  let json = null;
  try {
    json = await res.json();
  } catch {
    // Non-JSON error page.
  }
  return { res, json };
}

let refreshInFlight = null;

/// Trades the refresh cookie for a new access token. Concurrent 401s share one
/// refresh. Resolves true on success; a rejected refresh ends the session.
function refreshAccessToken() {
  refreshInFlight ??= (async () => {
    try {
      const { res, json } = await rawFetch('/api/auth/refresh', { method: 'POST' });
      if (res.ok && json?.data?.accessToken) {
        setSession(json.data.accessToken, json.data.user ?? getSessionUser());
        return true;
      }
      if (res.status === 401) clearSession();
      return false;
    } catch {
      return false; // network hiccup — keep the session for a later retry
    } finally {
      refreshInFlight = null;
    }
  })();
  return refreshInFlight;
}

/// JSON request against the backend; resolves to the envelope's `data`.
/// `auth` attaches the stored access token when there is one (endpoints with
/// optional auth personalise the response; guests simply send none). An
/// expired token is refreshed once and the request retried, like the app.
export async function apiFetch(path, { method = 'GET', body, auth = false } = {}) {
  const token = auth ? getAccessToken() : null;
  let { res, json } = await rawFetch(path, { method, body, token });
  if (res.status === 401 && token && (await refreshAccessToken())) {
    ({ res, json } = await rawFetch(path, { method, body, token: getAccessToken() }));
  }
  if (!res.ok) {
    throw new ApiError(
      json?.message || json?.error || `Request failed (${res.status})`,
      res.status,
    );
  }
  return json?.data ?? json;
}

export async function logout() {
  try {
    await rawFetch('/api/auth/logout', { method: 'POST' });
  } finally {
    clearSession();
  }
}

export async function login(identifier, password) {
  const data = await apiFetch('/api/auth/login', {
    method: 'POST',
    // The login form won't submit until the Terms of Use box is ticked.
    body: { username: identifier.trim(), password, acceptedTerms: true },
  });
  setSession(data.accessToken, data.user ?? null);
  return data.user;
}

/// Report targets mirror the backend's: piece | post | comment | user (by username).
export function reportContent(target, reason, details) {
  const paths = {
    piece: `/api/pieces/${target.id}/report`,
    post: `/api/posts/${target.id}/report`,
    comment: `/api/comments/${target.id}/report`,
    user: `/api/users/${encodeURIComponent(target.id)}/report`,
  };
  const trimmed = details?.trim();
  return apiFetch(paths[target.type], {
    method: 'POST',
    auth: true,
    body: { reason, ...(trimmed ? { details: trimmed } : {}) },
  });
}

const BLOCK_EVENT = 'studio3:blocked';
const blockedThisSession = new Set();

/// True if `username` was blocked in this tab — feeds already on screen use
/// this to drop that account's content immediately; the backend filters it
/// out of every later fetch.
export function isBlockedAuthor(username) {
  return Boolean(username) && blockedThisSession.has(username.toLowerCase());
}

export function onAuthorBlocked(listener) {
  window.addEventListener(BLOCK_EVENT, listener);
  return () => window.removeEventListener(BLOCK_EVENT, listener);
}

export async function blockUser(username) {
  const data = await apiFetch(`/api/users/${encodeURIComponent(username)}/block`, {
    method: 'POST',
    auth: true,
  });
  blockedThisSession.add(username.toLowerCase());
  window.dispatchEvent(new Event(BLOCK_EVENT));
  return data;
}

export async function unblockUser(username) {
  const data = await apiFetch(`/api/users/${encodeURIComponent(username)}/block`, {
    method: 'DELETE',
    auth: true,
  });
  blockedThisSession.delete(username.toLowerCase());
  return data;
}
