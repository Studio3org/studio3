import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { LoginPage } from './screens/LoginPage';
import { SignUpPage } from './screens/SignUpPage';
import { HomeFeedPage } from './screens/HomeFeedPage';
import { DiscoverPage } from './screens/DiscoverPage';
import { ChatPage } from './screens/ChatPage';
import { ProfilePage } from './screens/ProfilePage';
import { PostPage } from './screens/PostPage';
import { NotificationsPage } from './screens/NotificationsPage';
import { PieceDetailPage } from './screens/PieceDetailPage';
import { BottomNav } from './components/layout/BottomNav';

const routesWithNav = ['/home', '/discover', '/chat', '/profile'];

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
      <Route path="/home" element={<AppLayout showNav><HomeFeedPage /></AppLayout>} />
      <Route path="/discover" element={<AppLayout showNav><DiscoverPage /></AppLayout>} />
      <Route path="/chat" element={<AppLayout showNav><ChatPage /></AppLayout>} />
      <Route path="/profile" element={<AppLayout showNav><ProfilePage /></AppLayout>} />
      <Route path="/post" element={<PostPage />} />
      <Route path="/piece/:id" element={<PieceDetailPage />} />
      <Route
        path="/notifications"
        element={
          <AppLayout showNav>
            <NotificationsPage />
          </AppLayout>
        }
      />
      <Route path="/" element={<Navigate to="/home" replace />} />
      <Route path="*" element={<Navigate to="/home" replace />} />
    </Routes>
  );
}
