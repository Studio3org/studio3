import React from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import { MessageCircle } from 'lucide-react';
import { useBreakpoint } from '../hooks/useBreakpoint';
import { InboxPage } from './InboxPage';

/**
 * Mobile (<768px): byte-identical to the old flat-route behavior — `InboxPage`
 * at `/inbox`, `ChatThreadPage` (via `<Outlet/>`) at `/inbox/thread/:id`, full
 * push navigation.
 *
 * Desktop (>=768px): both panes render together — the conversation list stays
 * mounted on the left while the thread route renders in the right pane.
 */
export function InboxLayout() {
  const { showRail } = useBreakpoint();
  const location = useLocation();
  const hasThread = location.pathname !== '/inbox';

  if (!showRail) {
    return hasThread ? <Outlet /> : <InboxPage />;
  }

  return (
    <div style={{ display: 'flex', height: '100vh', overflow: 'hidden' }}>
      <div
        style={{
          width: 375,
          flexShrink: 0,
          height: '100%',
          overflowY: 'auto',
          borderRight: '1px solid var(--cream-divider)',
        }}
      >
        <InboxPage />
      </div>
      <div style={{ flex: 1, minWidth: 0, height: '100%', overflowY: 'auto' }}>
        {hasThread ? <Outlet /> : <InboxEmptyState />}
      </div>
    </div>
  );
}

function InboxEmptyState() {
  return (
    <div
      style={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 12,
        background: 'var(--chat-bg)',
        color: 'var(--cream-text-secondary)',
      }}
    >
      <MessageCircle size={40} strokeWidth={1.5} />
      <p style={{ fontFamily: 'var(--font-inter)', fontSize: 14 }}>Select a conversation</p>
    </div>
  );
}
