const DEPLOYED_API_URL = 'https://api.studio-3.co';
const DEPLOYED_APP_URL = 'https://studio-3.co';
const LOCAL_APP_URL = 'http://localhost:5173';

/// Backend origin — `app/.env` `NEXT_PUBLIC_API_URL` (local or deployed).
export const API_BASE_URL =
  import.meta.env.NEXT_PUBLIC_API_URL ||
  import.meta.env.VITE_API_URL ||
  DEPLOYED_API_URL;

/// Web app origin — `app/.env` `NEXT_PUBLIC_APP_URL` (local or deployed).
export const APP_BASE_URL =
  import.meta.env.NEXT_PUBLIC_APP_URL ||
  import.meta.env.VITE_APP_URL ||
  (import.meta.env.DEV ? LOCAL_APP_URL : DEPLOYED_APP_URL);

export const OAUTH_CALLBACK_PATH =
  import.meta.env.NEXT_PUBLIC_OAUTH_CALLBACK_PATH || '/auth/callback';

const ACCESS_TOKEN_KEY = 'studio3.accessToken';

export function getAccessToken() {
  try {
    return localStorage.getItem(ACCESS_TOKEN_KEY);
  } catch {
    return null;
  }
}

export function setAccessToken(token) {
  try {
    if (token) localStorage.setItem(ACCESS_TOKEN_KEY, token);
    else localStorage.removeItem(ACCESS_TOKEN_KEY);
  } catch {
    /* localStorage unavailable (private mode etc.) — session just won't persist */
  }
}

export class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

/** Called once, terminally, when a 401 survives a refresh attempt — lets
 * AuthContext clear its session/redirect instead of every caller having to
 * guess whether a 401 means "this call needs auth" or "you're logged out". */
let onAuthFailure = null;
export function setAuthFailureHandler(fn) {
  onAuthFailure = fn;
}

// The access token is short-lived (15 min server-side) and the refresh token
// only exists as an httpOnly cookie (never in a JSON body — see auth_controller
// .py's _issue_session_and_tokens), so refreshing is the only way to stay
// signed in past that window. Refresh tokens rotate (single-use), so two
// concurrent refreshes would have the second one fail after the first
// revokes it — this single-flight promise makes every caller during a
// refresh share the same in-flight request instead of racing.
let refreshInFlight = null;

async function doRefresh() {
  const res = await fetch(`${API_BASE_URL}/api/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
  });
  let json = null;
  try {
    json = await res.json();
  } catch {
    /* empty body */
  }
  if (!res.ok) {
    throw new ApiError(json?.message || `Request failed (${res.status})`, res.status);
  }
  const data = json?.data ?? json;
  setAccessToken(data.accessToken);
  return data;
}

/** Silently exchanges the refresh cookie for a fresh access token. Exported so
 * AuthContext can also call it proactively on a timer, well before the 15-
 * minute expiry, so an idle-but-open tab never actually reaches an expired
 * token in the first place. */
export function refreshAccessToken() {
  if (!refreshInFlight) {
    refreshInFlight = doRefresh().finally(() => {
      refreshInFlight = null;
    });
  }
  return refreshInFlight;
}

/**
 * Thin fetch wrapper matching the backend's `{success, message, data}` envelope
 * (src/shared/utils/api_response.py) and bearer-token auth
 * (src/middlewares/auth_middleware.py). `credentials: 'include'` is set so the
 * httpOnly refreshToken cookie round-trips — the backend sets it with
 * SameSite=None; Secure for cross-origin requests (see
 * src/shared/config/cors.py's refresh_cookie_flags), so this works whether
 * the web app is same-site with the API or not.
 *
 * An authenticated call (`auth: true`) that comes back 401 gets one silent
 * refresh-and-retry before giving up — this is what keeps a long-idle tab
 * from suddenly failing every request the moment the 15-minute access token
 * expires. Only a 401 that survives that retry (refresh token itself is
 * gone/expired/revoked) is a real "you're logged out", which is reported via
 * `onAuthFailure` so AuthContext can clear its session once, instead of
 * every screen improvising its own "am I logged out?" logic.
 */
export async function apiFetch(path, { method = 'GET', body, auth = false, signal, _retried = false } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (auth) {
    const token = getAccessToken();
    if (token) headers.Authorization = `Bearer ${token}`;
  }

  const res = await fetch(`${API_BASE_URL}${path}`, {
    method,
    headers,
    credentials: 'include',
    body: body !== undefined ? JSON.stringify(body) : undefined,
    signal,
  });

  let json = null;
  try {
    json = await res.json();
  } catch {
    /* empty body */
  }

  if (!res.ok) {
    if (auth && res.status === 401 && !_retried && path !== '/api/auth/refresh') {
      try {
        await refreshAccessToken();
        return apiFetch(path, { method, body, auth, signal, _retried: true });
      } catch {
        onAuthFailure?.();
      }
    }
    throw new ApiError(json?.message || `Request failed (${res.status})`, res.status);
  }
  return json?.data ?? json;
}
