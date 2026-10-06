import React from 'react';
import { useAuth } from '../../context/AuthContext';
import { useBreakpoint } from '../../hooks/useBreakpoint';
import { BottomNav } from './BottomNav';
import { SideNav } from './SideNav';

/**
 * Chrome shell for every non-auth route: a left rail replacing the bottom
 * pill nav at >=768px. The rail only ever appears for signed-in users, since
 * `/piece/:id` and `/series/:id` are public share links reachable while
 * logged out and shouldn't show navigation into gated routes.
 *
 * @param {object} props
 * @param {React.ReactNode} props.children
 * @param {boolean} props.showNav Whether the bottom pill nav is allowed on this route (mirrors today's NAV_PREFIXES gating).
 */
export function AppShell({ children, showNav }) {
  const { status, user } = useAuth();
  const { showRail, railLabeled } = useBreakpoint();
  const authenticated = status === 'authenticated';
  const renderRail = authenticated && showRail;

  return (
    <div className="app-shell">
      {renderRail && (
        <SideNav railLabeled={railLabeled} avatarSrc={user?.profilePhotoUrl} avatarAlt={user?.name} />
      )}
      <main
        className="app-shell-main"
        style={renderRail ? { marginLeft: railLabeled ? 244 : 72 } : undefined}
      >
        {children}
      </main>
      {authenticated && !showRail && showNav && <BottomNav />}
    </div>
  );
}
