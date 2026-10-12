import { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { getSessionUser, isLoggedIn, onSessionChange } from './api';

/// Current signed-in user (or null for a guest), re-rendering on login/logout.
export function useSession() {
  const read = () => ({ loggedIn: isLoggedIn(), user: getSessionUser() });
  const [session, setSession] = useState(read);
  useEffect(() => onSessionChange(() => setSession(read())), []);
  return session;
}

/// Guests can browse everything public; account actions (like, save, comment,
/// follow, message, post, report, block…) go through this, which sends a guest
/// to /login and brings them back to the current page afterwards — the web
/// counterpart of the app's `requireLogin`.
export function useRequireLogin() {
  const navigate = useNavigate();
  const location = useLocation();
  return () => {
    if (isLoggedIn()) return true;
    const next = `${location.pathname}${location.search}`;
    navigate(`/login?next=${encodeURIComponent(next)}`);
    return false;
  };
}
