import React, { useEffect } from 'react';
import { Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { LoginPage } from './screens/LoginPage';
import { SignUpPage } from './screens/SignUpPage';
import { OnboardingPage } from './screens/OnboardingPage';
import { ForgotPasswordPage } from './screens/ForgotPasswordPage';
import { ResetPasswordPage } from './screens/ResetPasswordPage';
import { HomeFeedPage } from './screens/HomeFeedPage';
import { DiscoverPage } from './screens/DiscoverPage';
import { ReelsPage } from './screens/ReelsPage';
import { SavedPage } from './screens/SavedPage';
import { ChatPage } from './screens/ChatPage';
import { ConversationPage } from './screens/ConversationPage';
import { ProfilePage } from './screens/ProfilePage';
import { FollowListPage } from './screens/FollowListPage';
import { FollowRequestsPage } from './screens/FollowRequestsPage';
import { PostPage } from './screens/PostPage';
import { NotificationsPage } from './screens/NotificationsPage';
import { PieceDetailPage } from './screens/PieceDetailPage';
import { SceneDetailPage } from './screens/SceneDetailPage';
import { SettingsPage } from './screens/SettingsPage';
import { EditProfilePage } from './screens/EditProfilePage';
import { BlockedUsersPage } from './screens/BlockedUsersPage';
import { ChangePasswordPage } from './screens/ChangePasswordPage';
import { DeleteAccountPage } from './screens/DeleteAccountPage';
import { BottomNav } from './components/layout/BottomNav';
import { TermsAcceptanceGate } from './components/moderation/TermsAcceptanceGate';
import { useSession } from './lib/session';
import { apiFetch, updateSessionUser } from './lib/api';

function WithNav({ children }) {
  return (
    <>
      {children}
      <BottomNav />
    </>
  );
}

// Screens a signed-in account may visit before finishing onboarding.
const PRE_ONBOARDING_PATHS = ['/onboarding', '/login', '/signup', '/forgot-password', '/reset-password'];

/// Mirrors the app's AuthGate: guests browse freely; a signed-in account that
/// hasn't finished onboarding is sent to /onboarding; the stored profile is
/// refreshed once per load so terms/onboarding state is current.
function SessionGate({ children }) {
  const { loggedIn, user } = useSession();
  const location = useLocation();

  useEffect(() => {
    if (!loggedIn) return;
    apiFetch('/api/user/me', { auth: true })
      .then((me) => me && updateSessionUser(me))
      .catch(() => {});
  }, [loggedIn]);

  const needsOnboarding = loggedIn && user && user.onboardingComplete === false;
  if (needsOnboarding && !PRE_ONBOARDING_PATHS.some((p) => location.pathname.startsWith(p))) {
    return <Navigate to="/onboarding" replace />;
  }
  return (
    <>
      {children}
      {loggedIn && user?.onboardingComplete && <TermsAcceptanceGate />}
    </>
  );
}

export default function App() {
  return (
    <SessionGate>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/signup" element={<SignUpPage />} />
        <Route path="/onboarding" element={<OnboardingPage />} />
        <Route path="/forgot-password" element={<ForgotPasswordPage />} />
        <Route path="/reset-password" element={<ResetPasswordPage />} />

        <Route path="/home" element={<WithNav><HomeFeedPage /></WithNav>} />
        <Route path="/discover" element={<WithNav><DiscoverPage /></WithNav>} />
        <Route path="/reels" element={<WithNav><ReelsPage /></WithNav>} />
        <Route path="/saved" element={<WithNav><SavedPage /></WithNav>} />
        <Route path="/notifications" element={<WithNav><NotificationsPage /></WithNav>} />
        <Route path="/follow-requests" element={<FollowRequestsPage />} />
        <Route path="/chat" element={<WithNav><ChatPage /></WithNav>} />
        <Route path="/chat/:conversationId" element={<ConversationPage />} />
        <Route path="/messages/:username" element={<ConversationPage />} />
        <Route path="/profile" element={<WithNav><ProfilePage /></WithNav>} />
        <Route path="/u/:username" element={<WithNav><ProfilePage /></WithNav>} />
        <Route path="/u/:username/followers" element={<FollowListPage />} />
        <Route path="/u/:username/following" element={<FollowListPage />} />
        <Route path="/post" element={<PostPage />} />
        <Route path="/piece/:id" element={<PieceDetailPage />} />
        <Route path="/scene/:id" element={<SceneDetailPage />} />
        <Route path="/settings" element={<SettingsPage />} />
        <Route path="/settings/profile" element={<EditProfilePage />} />
        <Route path="/settings/blocked" element={<BlockedUsersPage />} />
        <Route path="/settings/password" element={<ChangePasswordPage />} />
        <Route path="/settings/delete-account" element={<DeleteAccountPage />} />

        <Route path="/" element={<Navigate to="/home" replace />} />
        <Route path="*" element={<Navigate to="/home" replace />} />
      </Routes>
    </SessionGate>
  );
}
