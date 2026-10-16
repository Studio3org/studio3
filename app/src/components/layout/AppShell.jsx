import React from 'react';
import { useAuth } from '../../context/AuthContext';
import { useBreakpoint } from '../../hooks/useBreakpoint';
import { BottomNav } from './BottomNav';
import { SideNav } from './SideNav';
import { TermsAcceptanceGate } from '../moderation/TermsAcceptanceGate';

/**
 * Chrome shell for every non-auth route: a left rail replacing the bottom
 * pill nav at >=768px. Shown to guests too — they can browse Home, Discover and
 * Reels, and the account tabs (Create, Saved, Profile) send them to log in via
 * RequireAuth. Signed-in accounts also get the Terms of Use prompt when needed.
 *
 * @param {object} props
 * @param {React.ReactNode} props.children
 * @param {boolean} props.showNav Whether the bottom pill nav is allowed on this route (mirrors today's NAV_PREFIXES gating).
 */
export function AppShell({ children, showNav }) {
  const { status, user } = useAuth();
  const { showRail, railLabeled } = useBreakpoint();
  const authenticated = status === 'authenticated';
  const renderRail = status !== 'loading' && showRail;

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
      {status !== 'loading' && !showRail && showNav && <BottomNav />}
      {authenticated && <TermsAcceptanceGate />}
    </div>
  );
}
