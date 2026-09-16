import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { apiFetch, refreshAccessToken, setAccessToken, setAuthFailureHandler } from '../services/apiClient';

const AuthContext = createContext(null);

// Access tokens expire after 15 minutes server-side (JWT_ACCESS_EXPIRY_MINUTES) —
// refresh well before that so an open-but-idle tab never actually reaches an
// expired token (apiFetch's retry-on-401 is the reactive backstop for calls
// this proactive timer's interval happens to miss, e.g. right after a laptop
// wakes from sleep).
const SILENT_REFRESH_INTERVAL_MS = 10 * 60 * 1000;

/** 'loading' while the initial session check is in flight, then 'authenticated' or 'guest'. */
export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [status, setStatus] = useState('loading');

  const applySession = useCallback((session) => {
    setAccessToken(session.accessToken);
    setUser(session.user);
    setStatus('authenticated');
  }, []);

  const clearSession = useCallback(() => {
    setAccessToken(null);
    setUser(null);
    setStatus('guest');
  }, []);

  // Registered once: a 401 that survives apiFetch's own refresh-and-retry means
  // the refresh token itself is gone (expired/revoked/never existed) — that's
  // the one real "you're logged out" signal, reported from one place instead
  // of every screen guessing at what a 401 means.
  useEffect(() => {
    setAuthFailureHandler(clearSession);
    return () => setAuthFailureHandler(null);
  }, [clearSession]);

  useEffect(() => {
    (async () => {
      try {
        // No manual refresh fallback needed here — apiFetch already retries once
        // via the refresh cookie on a 401 before giving up.
        const me = await apiFetch('/api/user/me', { auth: true });
        setUser(me);
        setStatus('authenticated');
      } catch {
        clearSession();
      }
    })();
  }, [clearSession]);

  // Silent refresh while a session is open — keeps an idle tab's token from
  // ever actually reaching its 15-minute expiry.
  useEffect(() => {
    if (status !== 'authenticated') return;
    const id = setInterval(() => {
      refreshAccessToken().catch(() => {
        /* apiFetch's reactive retry-on-401 is the backstop if this misses */
      });
    }, SILENT_REFRESH_INTERVAL_MS);
    return () => clearInterval(id);
  }, [status]);

  const login = useCallback(
    async (identifier, password) => {
      const session = await apiFetch('/api/auth/login', {
        method: 'POST',
        body: { username: identifier, password },
      });
      applySession(session);
      return session.user;
    },
    [applySession],
  );

  const register = useCallback(
    async (fields) => {
      const session = await apiFetch('/api/auth/register', { method: 'POST', body: fields });
      applySession(session);
      return session.user;
    },
    [applySession],
  );

  const logout = useCallback(async () => {
    try {
      await apiFetch('/api/auth/logout', { method: 'POST' });
    } catch {
      /* best-effort — clear local state regardless */
    }
    clearSession();
  }, [clearSession]);

  const refreshUser = useCallback(async () => {
    const me = await apiFetch('/api/user/me', { auth: true });
    setUser(me);
    return me;
  }, []);

  const value = useMemo(
    () => ({ user, status, login, register, logout, refreshUser, setUser }),
    [user, status, login, register, logout, refreshUser],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
