import React from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft, MoreHorizontal } from 'lucide-react';
import { profileHref } from '../../utils/contentLinks';

/** Thread header — back, the other person (taps through to their profile), optional "⋯". */
export function ChatHeader({ onBack, name, username, avatarUrl, onMore }) {
  const navigate = useNavigate();
  return (
    <div
      style={{
        position: 'sticky',
        top: 0,
        zIndex: 2,
        background: 'var(--chat-header-bg)',
        display: 'flex',
        alignItems: 'center',
        padding: '8px 8px 8px 4px',
        gap: 12,
      }}
    >
      <button onClick={onBack} aria-label="Back" style={{ color: 'var(--cream-text)', padding: 8 }}>
        <ChevronLeft size={20} strokeWidth={2} />
      </button>
      <div
        style={{ display: 'flex', alignItems: 'center', gap: 12, cursor: username ? 'pointer' : 'default', flex: 1, minWidth: 0 }}
        onClick={() => username && navigate(profileHref(username))}
      >
        {avatarUrl ? (
          <img
            src={avatarUrl}
            alt=""
            width={36}
            height={36}
            style={{ width: 36, height: 36, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }}
          />
        ) : (
          <span style={{ width: 36, height: 36, borderRadius: '50%', background: 'var(--cream-cta-fill)', flexShrink: 0 }} />
        )}
        <span style={{ minWidth: 0 }}>
          <div style={{ fontFamily: 'var(--font-inter)', fontSize: 16, fontWeight: 700, color: 'var(--cream-text)' }}>
            {name || username || 'Someone'}
          </div>
          <div style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--chat-username)' }}>
            @{username || 'unknown'}
          </div>
        </span>
      </div>
      {onMore && (
        <button onClick={onMore} aria-label="More options" style={{ color: 'var(--cream-text)', padding: 8 }}>
          <MoreHorizontal size={20} strokeWidth={2} />
        </button>
      )}
    </div>
  );
}
