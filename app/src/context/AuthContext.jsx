import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { apiFetch, setAccessToken } from '../services/apiClient';

const AuthContext = createContext(null);

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

  useEffect(() => {
    (async () => {
      try {
        const me = await apiFetch('/api/user/me', { auth: true });
        setUser(me);
        setStatus('authenticated');
      } catch {
        // Access token missing/expired. Try the refresh cookie — only works if the
        // browser actually sent it (same-site only, see apiClient.js's note).
        try {
          const session = await apiFetch('/api/auth/refresh', { method: 'POST' });
          applySession(session);
        } catch {
          clearSession();
        }
      }
    })();
  }, [applySession, clearSession]);

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
