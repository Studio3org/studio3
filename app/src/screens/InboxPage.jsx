import React, { useCallback, useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { ChevronLeft, Search } from 'lucide-react';
import {
  acceptConversationRequest,
  declineConversationRequest,
  fetchConversationRequests,
  fetchConversations,
  fetchNotifications,
  markNotificationRead,
} from '../services/inboxApi';
import { formatRelativeTime, isWithinLastDay } from '../utils/time';
import { isChatLikeNotification, notificationDisplayText } from '../utils/notificationText';

export function InboxPage() {
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const [tab, setTab] = useState(params.get('tab') || 'notifications');

  const [notifications, setNotifications] = useState(null);
  const [conversations, setConversations] = useState(null);
  const [requests, setRequests] = useState(null);

  useEffect(() => {
    let cancelled = false;
    if (tab === 'notifications' && notifications === null) {
      fetchNotifications()
        .then((data) => !cancelled && setNotifications((data.items || []).filter((n) => !isChatLikeNotification(n))))
        .catch(() => !cancelled && setNotifications([]));
    }
    if (tab === 'chats' && conversations === null) {
      fetchConversations()
        .then((data) => !cancelled && setConversations(data.items || []))
        .catch(() => !cancelled && setConversations([]));
    }
    if (tab === 'requests' && requests === null) {
      fetchConversationRequests()
        .then((data) => !cancelled && setRequests(data.items || []))
        .catch(() => !cancelled && setRequests([]));
    }
    return () => {
      cancelled = true;
    };
  }, [tab, notifications, conversations, requests]);

  const tabs = [
    { id: 'notifications', label: 'Notifications', count: (notifications || []).filter((n) => !n.read).length },
    { id: 'chats', label: 'Chats', count: (conversations || []).filter((c) => c.unread).length },
    { id: 'requests', label: 'Requests', count: (requests || []).length },
  ];

  const handleNotificationOpen = useCallback((item) => {
    setNotifications((list) => (list || []).map((n) => (n.id === item.id ? { ...n, read: true } : n)));
    markNotificationRead(item.id).catch(() => {});
    if (item.target?.type === 'piece' && item.target?.id) {
      navigate(`/piece/${item.target.id}`);
    }
  }, [navigate]);

  const handleAccept = useCallback((id) => {
    setRequests((list) => (list || []).filter((r) => r.id !== id));
    acceptConversationRequest(id).catch(() => {});
  }, []);

  const handleDecline = useCallback((id) => {
    setRequests((list) => (list || []).filter((r) => r.id !== id));
    declineConversationRequest(id).catch(() => {});
  }, []);

  return (
    <div style={{ background: 'var(--cream-bg)', minHeight: '100vh', paddingBottom: 40 }}>
      <div style={{ display: 'flex', alignItems: 'center', padding: '10px 8px 4px', position: 'relative' }}>
        <button onClick={() => navigate(-1)} aria-label="Back" style={{ color: 'var(--cream-text)', padding: 8 }}>
          <ChevronLeft size={20} strokeWidth={2} />
        </button>
        <div style={{ flex: 1, display: 'flex', justifyContent: 'center', gap: 24 }}>
          {tabs.map((t) => (
            <TabButton key={t.id} tab={t} active={tab === t.id} onClick={() => setTab(t.id)} />
          ))}
        </div>
        <div style={{ width: 36 }} />
      </div>

      {tab === 'notifications' &&
        (notifications === null ? (
          <LoadingRow />
        ) : (
          <NotificationsBody items={notifications} onOpen={handleNotificationOpen} />
        ))}
      {tab === 'chats' &&
        (conversations === null ? (
          <LoadingRow />
        ) : (
          <ChatsBody items={conversations} onOpen={(id) => navigate(`/inbox/thread/${id}`)} />
        ))}
      {tab === 'requests' &&
        (requests === null ? (
          <LoadingRow />
        ) : (
          <RequestsBody items={requests} onAccept={handleAccept} onDecline={handleDecline} />
        ))}
    </div>
  );
}

function LoadingRow() {
  return (
    <div style={{ display: 'flex', justifyContent: 'center', padding: 48 }}>
      <span
        style={{
          width: 20,
          height: 20,
          borderRadius: '50%',
          border: '2px solid var(--cream-divider)',
          borderTopColor: 'var(--cream-cta-fill)',
          animation: 'app-spin 0.7s linear infinite',
        }}
      />
    </div>
  );
}

function EmptyRow({ text }) {
  return (
    <p style={{ textAlign: 'center', fontFamily: 'var(--font-inter)', fontSize: 14, color: 'var(--cream-text-secondary)', padding: 48 }}>
      {text}
    </p>
  );
}

function TabButton({ tab, active, onClick }) {
  return (
    <button onClick={onClick} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, padding: '6px 0' }}>
      <span style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
        <span
          style={{
            fontFamily: 'var(--font-inter)',
            fontSize: 15,
            color: active ? 'var(--cream-text)' : 'var(--cream-text-secondary)',
          }}
        >
          {tab.label}
        </span>
        {tab.count > 0 && (
          <span
            style={{
              minWidth: 16,
              height: 16,
              padding: '0 4px',
              borderRadius: 8,
              background: '#E05252',
              color: '#fff',
              fontSize: 9,
              fontWeight: 600,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            {tab.count}
          </span>
        )}
      </span>
      <span style={{ width: '100%', height: 1.5, background: active ? 'var(--cream-text)' : 'transparent' }} />
    </button>
  );
}

function GlassRow({ children, onClick }) {
  const Tag = onClick ? 'button' : 'div';
  return (
    <Tag
      onClick={onClick}
      className="glass-light"
      style={{
        width: '100%',
        textAlign: 'left',
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        padding: 12,
        marginBottom: 8,
      }}
    >
      {children}
    </Tag>
  );
}

function Avatar({ src, size }) {
  return src ? (
    <img
      src={src}
      alt=""
      width={size}
      height={size}
      style={{ width: size, height: size, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }}
    />
  ) : (
    <span style={{ width: size, height: size, borderRadius: '50%', background: 'var(--cream-cta-fill)', flexShrink: 0 }} />
  );
}

function NotificationsBody({ items, onOpen }) {
  if (items.length === 0) return <EmptyRow text="No notifications yet." />;

  const today = items.filter((n) => isWithinLastDay(n.createdAt));
  const earlier = items.filter((n) => !isWithinLastDay(n.createdAt));
  const sections = [
    ['Today', today],
    ['Earlier', earlier],
  ].filter(([, list]) => list.length > 0);

  return (
    <div style={{ padding: '16px 16px 24px' }}>
      {sections.map(([section, list]) => (
        <section key={section} style={{ marginBottom: 16 }}>
          <p style={{ fontFamily: 'var(--font-inter)', fontSize: 12, fontWeight: 500, color: 'var(--slate-400)', padding: '4px 4px 8px' }}>
            {section}
          </p>
          {list.map((item) => {
            const pill = item.type === 'purchase' ? 'Sale' : null;
            return (
              <GlassRow key={item.id} onClick={() => onOpen(item)}>
                <Avatar src={item.actor?.profilePhotoUrl} size={36} />
                <span style={{ flex: 1, minWidth: 0, fontFamily: 'var(--font-inter)', fontSize: 14, color: 'var(--slate-700)' }}>
                  <strong style={{ color: 'var(--slate-900)', fontWeight: 600 }}>{item.actor?.name || 'Someone'}</strong>{' '}
                  {notificationDisplayText(item)}
                  {pill && (
                    <span
                      style={{
                        marginLeft: 6,
                        padding: '2px 8px',
                        borderRadius: 9999,
                        fontSize: 11,
                        background: pill === 'Sale' ? 'var(--slate-900)' : 'var(--slate-100)',
                        color: pill === 'Sale' ? '#fff' : 'var(--slate-600)',
                        fontWeight: pill === 'Sale' ? 600 : 400,
                      }}
                    >
                      {pill}
                    </span>
                  )}
                  {!item.read && (
                    <span style={{ display: 'inline-block', width: 6, height: 6, borderRadius: '50%', background: 'var(--slate-900)', marginLeft: 6 }} />
                  )}
                </span>
                <span style={{ fontFamily: 'var(--font-inter)', fontSize: 11, color: 'var(--slate-400)', flexShrink: 0 }}>
                  {formatRelativeTime(item.createdAt)}
                </span>
              </GlassRow>
            );
          })}
        </section>
      ))}
    </div>
  );
}

function ChatsBody({ items, onOpen }) {
  const [query, setQuery] = useState('');
  const filtered = query.trim()
    ? items.filter((c) => (c.otherParty?.name || '').toLowerCase().includes(query.trim().toLowerCase()))
    : items;

  return (
    <div style={{ padding: '12px 16px 24px' }}>
      <div
        style={{
          height: 40,
          borderRadius: 9999,
          background: 'rgba(140,136,128,0.15)',
          display: 'flex',
          alignItems: 'center',
          padding: '0 14px',
          gap: 8,
          marginBottom: 16,
        }}
      >
        <Search size={16} color="var(--cream-text-secondary)" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search your connections"
          style={{ flex: 1, background: 'transparent', outline: 'none', fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text)' }}
        />
      </div>
      {filtered.length === 0 ? (
        <EmptyRow text="No conversations yet." />
      ) : (
        filtered.map((c) => (
          <GlassRow key={c.id} onClick={() => onOpen(c.id)}>
            <Avatar src={c.otherParty?.profilePhotoUrl} size={48} />
            <span style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: 'var(--font-inter)', fontSize: 14, fontWeight: 600, color: 'var(--slate-900)' }}>
                {c.otherParty?.name || 'Someone'}
              </div>
              <div style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--slate-500)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {c.preview || ''}
              </div>
            </span>
            <span style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4, flexShrink: 0 }}>
              <span style={{ fontFamily: 'var(--font-inter)', fontSize: 11, color: 'var(--slate-400)' }}>
                {formatRelativeTime(c.updatedAt)}
              </span>
              {c.unread && <span style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--slate-900)' }} />}
            </span>
          </GlassRow>
        ))
      )}
    </div>
  );
}

function RequestsBody({ items, onAccept, onDecline }) {
  if (items.length === 0) return <EmptyRow text="No pending requests." />;
  return (
    <div style={{ padding: '12px 16px 24px' }}>
      {items.map((r) => (
        <GlassRow key={r.id}>
          <Avatar src={r.otherParty?.profilePhotoUrl} size={48} />
          <span style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontFamily: 'var(--font-inter)', fontSize: 14, fontWeight: 600, color: 'var(--slate-900)' }}>
              {r.otherParty?.name || 'Someone'}
            </div>
            <div style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--slate-500)' }}>
              @{r.otherParty?.username || 'unknown'}
            </div>
          </span>
          <span style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
            <button
              onClick={() => onAccept(r.id)}
              style={{ padding: '6px 14px', borderRadius: 9999, background: 'var(--slate-900)', color: '#fff', fontSize: 12, fontWeight: 600 }}
            >
              Accept
            </button>
            <button
              onClick={() => onDecline(r.id)}
              style={{ padding: '6px 14px', borderRadius: 9999, background: 'var(--slate-100)', color: 'var(--slate-700)', fontSize: 12, fontWeight: 500 }}
            >
              Decline
            </button>
          </span>
        </GlassRow>
      ))}
    </div>
  );
}
