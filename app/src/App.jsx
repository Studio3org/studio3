import React from 'react';
import { Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { useAuth } from './context/AuthContext';
import { LoginPage } from './screens/LoginPage';
import { SignUpPage } from './screens/SignUpPage';
import { WelcomePage } from './screens/WelcomePage';
import { OnboardingPage } from './screens/OnboardingPage';
import { HomeFeedPage } from './screens/HomeFeedPage';
import { DiscoverPage } from './screens/DiscoverPage';
import { EventPage } from './screens/EventPage';
import { ProfilePage } from './screens/ProfilePage';
import { PostPage } from './screens/PostPage';
import { InboxPage } from './screens/InboxPage';
import { ChatThreadPage } from './screens/ChatThreadPage';
import { PieceDetailPage } from './screens/PieceDetailPage';
import { SeriesDetailPage } from './screens/SeriesDetailPage';
import { BottomNav } from './components/layout/BottomNav';

const NAV_PREFIXES = ['/home', '/discover', '/event', '/profile'];
// Auth pages are a full-viewport, genuinely responsive experience on every screen size —
// unlike the rest of the app (a mobile-only design shown inside a phone-in-tablet device
// mockup on desktop, see .device-frame in index.css), login/signup/welcome/onboarding
// render outside that mockup entirely.
const AUTH_PREFIXES = ['/login', '/signup', '/welcome', '/onboarding'];

/** Signed-in users only — everything past login/signup/welcome/onboarding. */
function RequireAuth({ children }) {
  const { status } = useAuth();
  const location = useLocation();
  if (status === 'loading') return <LoadingScreen />;
  if (status === 'guest') return <Navigate to="/login" replace state={{ from: location }} />;
  return children;
}

/** Login/signup only — bounce an already-signed-in user straight to the app. */
function RequireGuest({ children }) {
  const { status } = useAuth();
  if (status === 'loading') return <LoadingScreen />;
  if (status === 'authenticated') return <Navigate to="/home" replace />;
  return children;
}

function LoadingScreen() {
  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'var(--cream-bg)',
      }}
    >
      <span
        style={{
          width: 22,
          height: 22,
          borderRadius: '50%',
          border: '2px solid var(--cream-divider)',
          borderTopColor: 'var(--cream-cta-fill)',
          animation: 'app-spin 0.7s linear infinite',
        }}
      />
    </div>
  );
}

export default function App() {
  const location = useLocation();
  const isAuthRoute = AUTH_PREFIXES.some((p) => location.pathname.startsWith(p));
  const showNav = NAV_PREFIXES.some((p) => location.pathname.startsWith(p));

  const routes = (
    <Routes>
      <Route path="/login" element={<RequireGuest><LoginPage /></RequireGuest>} />
      <Route path="/signup" element={<RequireGuest><SignUpPage /></RequireGuest>} />
      <Route path="/welcome" element={<RequireAuth><WelcomePage /></RequireAuth>} />
      <Route path="/onboarding" element={<RequireAuth><OnboardingPage /></RequireAuth>} />

      <Route path="/home" element={<RequireAuth><HomeFeedPage /></RequireAuth>} />
      <Route path="/discover" element={<RequireAuth><DiscoverPage /></RequireAuth>} />
      <Route path="/event" element={<RequireAuth><EventPage /></RequireAuth>} />
      <Route path="/profile" element={<RequireAuth><ProfilePage /></RequireAuth>} />
      <Route path="/post" element={<RequireAuth><PostPage /></RequireAuth>} />

      {/* Reached from the home header's inbox icon, not a bottom-nav slot. */}
      <Route path="/inbox" element={<RequireAuth><InboxPage /></RequireAuth>} />
      <Route path="/inbox/thread/:id" element={<RequireAuth><ChatThreadPage /></RequireAuth>} />
      {/* Old direct links to the pre-merge chat/notifications pages. */}
      <Route path="/chat" element={<Navigate to="/inbox?tab=chats" replace />} />
      <Route path="/notifications" element={<Navigate to="/inbox?tab=notifications" replace />} />

      {/* Public share-link fallbacks — no auth required. */}
      <Route path="/piece/:id" element={<PieceDetailPage />} />
      <Route path="/series/:id" element={<SeriesDetailPage />} />

      <Route path="/" element={<Navigate to="/home" replace />} />
      <Route path="*" element={<Navigate to="/home" replace />} />
    </Routes>
  );

  if (isAuthRoute) {
    return routes;
  }

  return (
    <div className="device-frame">
      <div className="device-screen">
        <div className="device-scroll">{routes}</div>
        {showNav && <BottomNav />}
      </div>
    </div>
  );
}
