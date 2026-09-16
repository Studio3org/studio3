import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchConversations, fetchNotifications } from '../../services/inboxApi';
import { isChatLikeNotification, notificationDisplayText } from '../../utils/notificationText';

export const RIGHT_RAIL_WIDTH = 320;

/** Sticky Notifications/Messages rail — originally HomeFeedPage's
 * `HomeRightRail`, now shared so Discover/Events/Saved/Profile can show it
 * in the same fixed spot (>=1264px, alongside SideNav's labeled rail) that
 * Home does, instead of only appearing on the feed. */
export function InboxRail() {
  const navigate = useNavigate();
  const [notifications, setNotifications] = useState(null);
  const [conversations, setConversations] = useState(null);

  useEffect(() => {
    let cancelled = false;
    fetchNotifications({ limit: 8 })
      .then((data) => !cancelled && setNotifications((data.items || []).filter((n) => !isChatLikeNotification(n)).slice(0, 4)))
      .catch(() => !cancelled && setNotifications([]));
    fetchConversations({ limit: 4 })
      .then((data) => !cancelled && setConversations(data.items || []))
      .catch(() => !cancelled && setConversations([]));
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <aside
      style={{
        flex: `0 0 ${RIGHT_RAIL_WIDTH}px`,
        position: 'sticky',
        top: 14,
        height: 'calc(100vh - 28px)',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <RailSection
        title="Notifications"
        onSeeAll={() => navigate('/inbox?tab=notifications')}
        style={{ borderBottom: '1px solid var(--cream-divider)' }}
      >
        {notifications === null ? (
          <RailSectionSkeleton count={4} />
        ) : notifications.length === 0 ? (
          <RailEmpty text="No notifications yet." />
        ) : (
          notifications.map((item) => (
            <RailRow
              key={item.id}
              avatarSrc={item.actor?.profilePhotoUrl}
              name={item.actor?.name || 'Someone'}
              username={item.actor?.username}
              text={notificationDisplayText(item)}
            />
          ))
        )}
      </RailSection>
      <RailSection title="Messages" onSeeAll={() => navigate('/inbox?tab=chats')}>
        {conversations === null ? (
          <RailSectionSkeleton count={3} />
        ) : conversations.length === 0 ? (
          <RailEmpty text="No messages yet." />
        ) : (
          conversations.map((item) => (
            <RailRow
              key={item.id}
              avatarSrc={item.otherParty?.profilePhotoUrl}
              name={item.otherParty?.name || 'Someone'}
              username={item.otherParty?.username}
              text={item.preview}
            />
          ))
        )}
      </RailSection>
    </aside>
  );
}

function RailEmpty({ text }) {
  return (
    <p style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)', padding: '4px 10px' }}>
      {text}
    </p>
  );
}

function RailSection({ title, onSeeAll, style, children }) {
  return (
    <div style={{ flex: '1 1 50%', minHeight: 0, display: 'flex', flexDirection: 'column', paddingTop: 14, ...style }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
        <span style={{ fontFamily: 'var(--font-inter)', fontSize: 14, fontWeight: 600, color: 'var(--cream-text)' }}>
          {title}
        </span>
        <button
          onClick={onSeeAll}
          style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)' }}
        >
          See all
        </button>
      </div>
      <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 4, paddingBottom: 14 }}>
        {children}
      </div>
    </div>
  );
}

function RailSectionSkeleton({ count = 3 }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 10px' }}>
          <div className="feed-skeleton-block" style={{ width: 32, height: 32, borderRadius: '50%', flexShrink: 0 }} />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6, flex: 1 }}>
            <div className="feed-skeleton-block" style={{ width: '60%', height: 12, borderRadius: 4 }} />
            <div className="feed-skeleton-block" style={{ width: '85%', height: 10, borderRadius: 4 }} />
          </div>
        </div>
      ))}
    </div>
  );
}

function RailRow({ avatarSrc, name, username, text }) {
  const navigate = useNavigate();
  const handleClick = () => {
    if (username) {
      navigate(`/profile?username=${username}`);
    }
  };

  return (
    <div
      style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 10px', borderRadius: 10, cursor: username ? 'pointer' : 'default' }}
      onClick={handleClick}
    >
      {avatarSrc ? (
        <img
          src={avatarSrc}
          alt=""
          width={32}
          height={32}
          style={{ width: 32, height: 32, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }}
        />
      ) : (
        <span style={{ width: 32, height: 32, borderRadius: '50%', background: 'var(--cream-cta-fill)', flexShrink: 0 }} />
      )}
      <span style={{ minWidth: 0, fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text)', overflow: 'hidden' }}>
        <strong style={{ fontWeight: 600 }}>{name}</strong>{' '}
        <span
          style={{
            color: 'var(--cream-text-secondary)',
            display: '-webkit-box',
            WebkitLineClamp: 1,
            WebkitBoxOrient: 'vertical',
            overflow: 'hidden',
          }}
        >
          {text}
        </span>
      </span>
    </div>
  );
}
