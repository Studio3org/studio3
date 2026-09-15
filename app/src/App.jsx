import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
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

function AppLayout({ children, showNav }) {
  return (
    <>
      {children}
      {showNav && <BottomNav />}
    </>
  );
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/signup" element={<SignUpPage />} />
      <Route path="/welcome" element={<WelcomePage />} />
      <Route path="/onboarding" element={<OnboardingPage />} />

      <Route path="/home" element={<AppLayout showNav><HomeFeedPage /></AppLayout>} />
      <Route path="/discover" element={<AppLayout showNav><DiscoverPage /></AppLayout>} />
      <Route path="/event" element={<AppLayout showNav><EventPage /></AppLayout>} />
      <Route path="/profile" element={<AppLayout showNav><ProfilePage /></AppLayout>} />
      <Route path="/post" element={<PostPage />} />

      {/* Reached from the home header's inbox icon, not a bottom-nav slot. */}
      <Route path="/inbox" element={<InboxPage />} />
      <Route path="/inbox/thread/:id" element={<ChatThreadPage />} />
      {/* Old direct links to the pre-merge chat/notifications pages. */}
      <Route path="/chat" element={<Navigate to="/inbox?tab=chats" replace />} />
      <Route path="/notifications" element={<Navigate to="/inbox?tab=notifications" replace />} />

      <Route path="/piece/:id" element={<PieceDetailPage />} />
      <Route path="/series/:id" element={<SeriesDetailPage />} />

      <Route path="/" element={<Navigate to="/home" replace />} />
      <Route path="*" element={<Navigate to="/home" replace />} />
    </Routes>
  );
}
