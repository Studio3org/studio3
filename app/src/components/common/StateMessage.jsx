import React from 'react';
import { Link } from 'react-router-dom';

/// Centered loading / empty / error text, with an optional action button.
export function StateMessage({ children, action, onAction, style }) {
  return (
    <div
      style={{
        padding: '48px 24px',
        textAlign: 'center',
        color: 'var(--slate-500)',
        fontSize: 14,
        lineHeight: 1.5,
        ...style,
      }}
    >
      <div>{children}</div>
      {action && (
        <button
          type="button"
          onClick={onAction}
          style={{
            marginTop: 16,
            padding: '10px 20px',
            borderRadius: 9999,
            background: 'var(--slate-900)',
            color: 'var(--white)',
            fontSize: 14,
            fontWeight: 600,
          }}
        >
          {action}
        </button>
      )}
    </div>
  );
}

/// Full-page prompt for account-only screens (Saved, Notifications, Chat, own
/// profile, Post) while browsing as a guest.
export function GuestPrompt({ title, message, next }) {
  const href = `/login${next ? `?next=${encodeURIComponent(next)}` : ''}`;
  return (
    <div style={{ padding: '96px 32px', textAlign: 'center' }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, color: 'var(--slate-900)', marginBottom: 8 }}>{title}</h2>
      <p style={{ fontSize: 14, color: 'var(--slate-500)', lineHeight: 1.5, marginBottom: 20 }}>{message}</p>
      <Link
        to={href}
        style={{
          display: 'inline-block',
          padding: '12px 24px',
          borderRadius: 9999,
          background: 'var(--slate-900)',
          color: 'var(--white)',
          fontSize: 14,
          fontWeight: 600,
        }}
      >
        Log in or sign up
      </Link>
    </div>
  );
}
