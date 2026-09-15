const DEPLOYED_API_URL = 'https://studio3-backend.onrender.com';
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

/**
 * Thin fetch wrapper matching the backend's `{success, message, data}` envelope
 * (src/shared/utils/api_response.py) and bearer-token auth
 * (src/middlewares/auth_middleware.py). `credentials: 'include'` is set so the
 * httpOnly refreshToken cookie round-trips when the web app happens to be
 * same-site with the API — cross-origin browsers will drop it per
 * SameSite=Lax, in which case refresh silently fails and the caller re-logs-in;
 * there's no reliable web workaround for that without a backend cookie-policy
 * change, so callers should treat "session expired, please log in again" as
 * expected behavior, not a bug.
 */
export async function apiFetch(path, { method = 'GET', body, auth = false, signal } = {}) {
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
    throw new ApiError(json?.message || `Request failed (${res.status})`, res.status);
  }
  return json?.data ?? json;
}
