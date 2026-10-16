import React from 'react';
import { Outlet, useLocation, useSearchParams } from 'react-router-dom';
import { MessageCircle } from 'lucide-react';
import { useBreakpoint } from '../hooks/useBreakpoint';
import { InboxPage } from './InboxPage';
import { NewConversationPane } from '../components/inbox/NewConversationPane';

/**
 * Mobile (<768px): byte-identical to the old flat-route behavior — `InboxPage`
 * at `/inbox`, `ChatThreadPage` (via `<Outlet/>`) at `/inbox/thread/:id`, full
 * push navigation.
 *
 * Desktop (>=768px): both panes render together — the conversation list stays
 * mounted on the left while the thread route renders in the right pane.
 *
 * `/inbox?user=<username>` (Message from a profile, or the New message picker)
 * takes the thread's place with a compose pane that reuses or starts the thread.
 */
export function InboxLayout() {
  const { showRail } = useBreakpoint();
  const location = useLocation();
  const [params] = useSearchParams();
  const hasThread = location.pathname.replace(/\/+$/, '') !== '/inbox';
  const composeUser = hasThread ? null : params.get('user');
  const compose = composeUser ? <NewConversationPane key={composeUser} username={composeUser} /> : null;

  if (!showRail) {
    return hasThread ? <Outlet /> : compose || <InboxPage />;
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
        {hasThread ? <Outlet /> : compose || <InboxEmptyState />}
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
