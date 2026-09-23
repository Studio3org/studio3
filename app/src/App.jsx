import React from 'react';
import { Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { useAuth } from './context/AuthContext';
import { AdminLayout } from './screens/admin/AdminLayout';
import { AdminOrdersPage } from './screens/admin/AdminOrdersPage';
import { AdminOrderDetailPage } from './screens/admin/AdminOrderDetailPage';
import {
  AdminAuctionsPage, AdminAuditPage, AdminDisputesPage, AdminEventsPage, AdminReportsPage,
} from './screens/admin/AdminQueues';
import { LoginPage } from './screens/LoginPage';
import { SignUpPage } from './screens/SignUpPage';
import { WelcomePage } from './screens/WelcomePage';
import { OnboardingPage } from './screens/OnboardingPage';
import { HomeFeedPage } from './screens/HomeFeedPage';
import { DiscoverPage } from './screens/DiscoverPage';
import { EventPage } from './screens/EventPage';
import { ProfilePage } from './screens/ProfilePage';
import { EditProfilePage } from './screens/EditProfilePage';
import { ProfileSettingsPage } from './screens/ProfileSettingsPage';
import { SavedPage } from './screens/SavedPage';
import { PostPage } from './screens/PostPage';
import { EventPostPage } from './screens/EventPostPage';
import { InboxLayout } from './screens/InboxLayout';
import { ChatThreadPage } from './screens/ChatThreadPage';
import { PieceDetailPage } from './screens/PieceDetailPage';
import { SeriesDetailPage } from './screens/SeriesDetailPage';
import { DeleteAccountPage } from './screens/DeleteAccountPage';
import { AppShell } from './components/layout/AppShell';
import { StudioLogoLoader } from './components/common/StudioLogoLoader';
import { PostModal } from './components/layout/PostModal';
import { EventPostModal } from './components/layout/EventPostModal';

const NAV_PREFIXES = ['/home', '/discover', '/event', '/saved', '/profile', '/profile-settings'];
// Auth pages are a full-viewport, genuinely responsive experience on every screen size —
// unlike the rest of the app, which renders inside AppShell (bottom nav on phones, a left
// rail on tablet/desktop, see components/layout/AppShell.jsx) — login/signup/welcome/
// onboarding render outside that shell entirely.
const AUTH_PREFIXES = ['/login', '/signup', '/welcome', '/onboarding'];

/** Signed-in users only — everything past login/signup/welcome/onboarding. */
function RequireAuth({ children }) {
  const { status } = useAuth();
  const location = useLocation();
  if (status === 'loading') return <LoadingScreen />;
  if (status === 'guest') return <Navigate to="/login" replace state={{ from: location }} />;
  return children;
}

/** Login/signup only — bounce an already-signed-in user straight to the app.
 *  Show the form while the session check is in flight so /login is never a
 *  loader that then hops to /home. */
function RequireGuest({ children }) {
  const { status } = useAuth();
  if (status === 'authenticated') return <Navigate to="/home" replace />;
  return children;
}

/** `/` and unknown paths: guests go to login, members to home. Never send a
 *  guest through /home first (that was the loader → /login bounce). */
function RootRedirect() {
  const { status } = useAuth();
  if (status === 'loading') return <LoadingScreen />;
  if (status === 'authenticated') return <Navigate to="/home" replace />;
  return <Navigate to="/login" replace />;
}

function LoadingScreen() {
  return <StudioLogoLoader fullScreen />;
}

export default function App() {
  const location = useLocation();
  const backgroundLocation = location.state?.backgroundLocation;
  const isAuthRoute = AUTH_PREFIXES.some((p) => location.pathname.startsWith(p));
  // The ops console brings its own chrome. Wrapping it in AppShell would put the
  // member side rail next to a tool for resolving disputes, and indent every table
  // by the width of navigation that does not apply to it.
  const isAdminRoute = location.pathname.startsWith('/admin');
  const showNav = NAV_PREFIXES.some((p) => location.pathname.startsWith(p));

  const routes = (
    <Routes location={backgroundLocation || location}>
      <Route path="/login" element={<RequireGuest><LoginPage /></RequireGuest>} />
      <Route path="/signup" element={<RequireGuest><SignUpPage /></RequireGuest>} />
      <Route path="/welcome" element={<RequireAuth><WelcomePage /></RequireAuth>} />
      <Route path="/onboarding" element={<RequireAuth><OnboardingPage /></RequireAuth>} />

      <Route path="/home" element={<RequireAuth><HomeFeedPage /></RequireAuth>} />
      <Route path="/discover" element={<RequireAuth><DiscoverPage /></RequireAuth>} />
      <Route path="/event" element={<RequireAuth><EventPage /></RequireAuth>} />
      <Route path="/saved" element={<RequireAuth><SavedPage /></RequireAuth>} />
      <Route path="/profile" element={<RequireAuth><ProfilePage /></RequireAuth>} />
      <Route path="/profile/edit" element={<RequireAuth><EditProfilePage /></RequireAuth>} />
      <Route path="/profile-settings" element={<RequireAuth><ProfileSettingsPage /></RequireAuth>} />
      {/* Full-page fallback: reached directly (refresh/deep-link) or on mobile, where
          Post never uses the backgroundLocation modal treatment below. */}
      <Route path="/post" element={<RequireAuth><PostPage /></RequireAuth>} />
      {/* Event creation — same full-page-fallback/background-location-modal
          split as /post above. Deliberately not under /event so NAV_PREFIXES
          hides the bottom nav during creation, matching /post's treatment. */}
      <Route path="/event-create" element={<RequireAuth><EventPostPage /></RequireAuth>} />

      {/* Reached from the home header's inbox icon, not a bottom-nav slot. */}
      <Route path="/inbox" element={<RequireAuth><InboxLayout /></RequireAuth>}>
        <Route path="thread/:id" element={<ChatThreadPage />} />
      </Route>
      {/* Old direct links to the pre-merge chat/notifications pages. */}
      <Route path="/chat" element={<Navigate to="/inbox?tab=chats" replace />} />
      <Route path="/notifications" element={<Navigate to="/inbox?tab=notifications" replace />} />

      {/* Public share-link fallbacks — no auth required. */}
      {/* Ops console. AdminLayout carries its own is_admin gate, and every route
          behind it is re-checked server-side — this nesting only decides what is
          drawn, never what is permitted. */}
      <Route path="/admin" element={<AdminLayout />}>
        <Route index element={<AdminOrdersPage />} />
        <Route path="orders/:orderId" element={<AdminOrderDetailPage />} />
        <Route path="disputes" element={<AdminDisputesPage />} />
        <Route path="reports" element={<AdminReportsPage />} />
        <Route path="auctions" element={<AdminAuctionsPage />} />
        <Route path="events" element={<AdminEventsPage />} />
        <Route path="audit" element={<AdminAuditPage />} />
      </Route>

      <Route path="/piece/:id" element={<PieceDetailPage />} />
      <Route path="/series/:id" element={<SeriesDetailPage />} />
      {/* Google Play Data Safety requires a URL, reachable without signing in, where
          someone can request their account and data be deleted — see DeleteAccountPage
          for why the wording there has to track auth_controller.delete_account exactly. */}
      <Route path="/delete-account" element={<DeleteAccountPage />} />

      <Route path="/" element={<RootRedirect />} />
      <Route path="*" element={<RootRedirect />} />
    </Routes>
  );

  if (isAuthRoute || isAdminRoute) {
    return routes;
  }

  return (
    <AppShell showNav={showNav}>
      {routes}
      {backgroundLocation && (
        <Routes>
          <Route
            path="/post"
            element={
              <RequireAuth>
                <PostModal />
              </RequireAuth>
            }
          />
          <Route
            path="/event-create"
            element={
              <RequireAuth>
                <EventPostModal />
              </RequireAuth>
            }
          />
        </Routes>
      )}
    </AppShell>
  );
}
