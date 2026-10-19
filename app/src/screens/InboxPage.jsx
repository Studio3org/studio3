import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { ChevronLeft, Search, SquarePen } from 'lucide-react';
import {
  acceptConversationRequest,
  declineConversationRequest,
  fetchConversationRequests,
  fetchConversations,
  fetchNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} from '../services/inboxApi';
import { friendlyError, listFollowRequests, respondToFollowRequest } from '../services/socialApi';
import { isBlockedAuthor } from '../services/blockedAuthors';
import { useToast } from '../components/common/ActionSheet';
import { LoadMore } from '../components/inbox/LoadMore';
import { NewMessageSheet } from '../components/inbox/NewMessageSheet';
import { usePagedList } from '../components/inbox/usePagedList';
import { useBlockedAuthorsTick } from '../components/inbox/useBlockedAuthorsTick';
import { profileHref } from '../utils/contentLinks';
import { formatRelativeTime, isWithinLastDay } from '../utils/time';
import { isChatLikeNotification, notificationDisplayText, notificationHref } from '../utils/notificationText';

const TAB_IDS = ['notifications', 'chats', 'requests'];

/// `?tab=` → tab id, or null when the URL doesn't say. "Requests" holds both follow
/// requests and message requests, so `follow-requests` (and Settings' `requests`) land
/// there; `?user=` is a compose, so Chats.
function tabFromParams(params) {
  const raw = params.get('tab');
  if (raw === 'follow-requests') return 'requests';
  if (TAB_IDS.includes(raw)) return raw;
  if (params.get('user')) return 'chats';
  return null;
}

const fetchNotificationPage = (cursor) =>
  fetchNotifications({ cursor }).then((data) => ({
    ...data,
    items: (data?.items || []).filter((n) => !isChatLikeNotification(n)),
  }));
const fetchConversationPage = (cursor) => fetchConversations({ cursor });
const fetchRequestPage = (cursor) => fetchConversationRequests({ cursor });

export function InboxPage() {
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const urlTab = tabFromParams(params);
  // Local state, synced from the URL when it names a tab: on the desktop two-pane layout
  // this list stays mounted while /inbox/thread/:id (no ?tab=) opens beside it, and the
  // Chats tab must stay selected.
  const [tab, setTabState] = useState(urlTab || 'notifications');
  useEffect(() => {
    if (urlTab) setTabState(urlTab);
  }, [urlTab]);
  const [toast, showToast] = useToast();
  const [composing, setComposing] = useState(false);
  useBlockedAuthorsTick();

  const setTab = (id) => {
    setTabState(id);
    const next = new URLSearchParams(params);
    next.set('tab', id);
    setParams(next, { replace: true });
  };

  const notifications = usePagedList(fetchNotificationPage, tab === 'notifications');
  const conversations = usePagedList(fetchConversationPage, tab === 'chats');
  const messageRequests = usePagedList(fetchRequestPage, tab === 'requests');

  /// Follow requests are a plain (unpaginated) array.
  const [followRequests, setFollowRequests] = useState(null);
  const [followError, setFollowError] = useState(null);
  const followStarted = useRef(false);
  useEffect(() => {
    if (tab !== 'requests' || followStarted.current) return;
    followStarted.current = true;
    listFollowRequests()
      .then((data) => setFollowRequests(Array.isArray(data) ? data : data?.items || []))
      .catch((e) => {
        setFollowError(friendlyError(e));
        setFollowRequests([]);
      });
  }, [tab]);

  const visibleNotifications = notifications.items?.filter((n) => !isBlockedAuthor(n.actor?.username)) ?? null;
  const visibleConversations = conversations.items?.filter((c) => !isBlockedAuthor(c.otherParty?.username)) ?? null;
  const visibleMessageRequests = messageRequests.items?.filter((r) => !isBlockedAuthor(r.otherParty?.username)) ?? null;
  const visibleFollowRequests = followRequests?.filter((r) => !isBlockedAuthor(r.username)) ?? null;

  const tabs = [
    { id: 'notifications', label: 'Notifications', count: (visibleNotifications || []).filter((n) => !n.read).length },
    { id: 'chats', label: 'Chats', count: (visibleConversations || []).filter((c) => c.unread).length },
    { id: 'requests', label: 'Requests', count: (visibleMessageRequests || []).length + (visibleFollowRequests || []).length },
  ];

  const setNotificationItems = notifications.setItems;
  const handleNotificationOpen = useCallback((item) => {
    if (!item.read) {
      setNotificationItems((list) => (list || []).map((n) => (n.id === item.id ? { ...n, read: true } : n)));
      markNotificationRead(item.id).catch(() => {});
    }
    const href = notificationHref(item);
    if (href) navigate(href);
  }, [navigate, setNotificationItems]);

  const handleMarkAllRead = useCallback(async () => {
    let previous = null;
    setNotificationItems((list) => {
      previous = list;
      return (list || []).map((n) => ({ ...n, read: true }));
    });
    try {
      await markAllNotificationsRead();
    } catch (e) {
      if (previous) setNotificationItems(previous);
      showToast(friendlyError(e));
    }
  }, [setNotificationItems, showToast]);

  const setRequestItems = messageRequests.setItems;
  const setConversationItems = conversations.setItems;
  const handleMessageRequest = useCallback(async (request, accept) => {
    setRequestItems((list) => (list || []).filter((r) => r.id !== request.id));
    try {
      if (accept) {
        await acceptConversationRequest(request.id);
        // Now an ordinary chat — show it at the top of Chats if that list is loaded.
        setConversationItems((list) =>
          list ? [{ ...request, status: 'open' }, ...list.filter((c) => c.id !== request.id)] : list,
        );
      } else {
        await declineConversationRequest(request.id);
      }
    } catch (e) {
      setRequestItems((list) => [request, ...(list || [])]);
      showToast(friendlyError(e));
    }
  }, [setRequestItems, setConversationItems, showToast]);

  const handleFollowRequest = useCallback(async (request, accept) => {
    setFollowRequests((list) => (list || []).filter((r) => r.username !== request.username));
    try {
      await respondToFollowRequest(request.username, accept);
      showToast(accept ? `@${request.username} now follows you` : 'Request declined');
    } catch (e) {
      setFollowRequests((list) => [request, ...(list || [])]);
      showToast(friendlyError(e));
    }
  }, [showToast]);

  const startMessageWith = (username) => {
    setComposing(false);
    navigate(`/inbox?tab=chats&user=${encodeURIComponent(username)}`);
  };

  const followSectionRef = useRef(null);
  const wantsFollowSection = params.get('tab') === 'follow-requests';
  useEffect(() => {
    if (wantsFollowSection && visibleFollowRequests?.length) {
      followSectionRef.current?.scrollIntoView({ block: 'start' });
    }
  }, [wantsFollowSection, visibleFollowRequests?.length]);

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
        (visibleNotifications === null ? (
          <LoadingRow />
        ) : notifications.error ? (
          <ErrorRow text={notifications.error} onRetry={notifications.reload} />
        ) : (
          <>
            <NotificationsBody items={visibleNotifications} onOpen={handleNotificationOpen} onMarkAllRead={handleMarkAllRead} />
            <LoadMore
              hasMore={notifications.hasMore}
              loading={notifications.loadingMore}
              error={notifications.moreError}
              onLoad={notifications.loadMore}
            />
          </>
        ))}
      {tab === 'chats' &&
        (visibleConversations === null ? (
          <LoadingRow />
        ) : conversations.error ? (
          <ErrorRow text={conversations.error} onRetry={conversations.reload} />
        ) : (
          <>
            <ChatsBody
              items={visibleConversations}
              onOpen={(id) => navigate(`/inbox/thread/${id}`)}
              onNewMessage={() => setComposing(true)}
            />
            <LoadMore
              hasMore={conversations.hasMore}
              loading={conversations.loadingMore}
              error={conversations.moreError}
              onLoad={conversations.loadMore}
            />
          </>
        ))}
      {tab === 'requests' &&
        (visibleMessageRequests === null || visibleFollowRequests === null ? (
          <LoadingRow />
        ) : (
          <>
            <RequestsBody
              followRequests={visibleFollowRequests}
              followError={followError}
              messageRequests={visibleMessageRequests}
              messageError={messageRequests.error}
              followSectionRef={followSectionRef}
              onOpenProfile={(username) => navigate(profileHref(username))}
              onOpenThread={(id) => navigate(`/inbox/thread/${id}`)}
              onFollowRequest={handleFollowRequest}
              onMessageRequest={handleMessageRequest}
            />
            <LoadMore
              hasMore={messageRequests.hasMore}
              loading={messageRequests.loadingMore}
              error={messageRequests.moreError}
              onLoad={messageRequests.loadMore}
            />
          </>
        ))}

      {composing && <NewMessageSheet onPick={startMessageWith} onClose={() => setComposing(false)} />}
      {toast}
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

function ErrorRow({ text, onRetry }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12, padding: 48 }}>
      <p style={{ textAlign: 'center', fontFamily: 'var(--font-inter)', fontSize: 14, color: 'var(--cream-text-secondary)' }}>{text}</p>
      <button
        onClick={onRetry}
        style={{ padding: '6px 14px', borderRadius: 9999, background: 'var(--slate-900)', color: '#fff', fontSize: 12, fontWeight: 600 }}
      >
        Try again
      </button>
    </div>
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

function SectionLabel({ children, action }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '4px 4px 8px' }}>
      <p style={{ fontFamily: 'var(--font-inter)', fontSize: 12, fontWeight: 500, color: 'var(--slate-400)' }}>{children}</p>
      {action}
    </div>
  );
}

function NotificationsBody({ items, onOpen, onMarkAllRead }) {
  if (items.length === 0) return <EmptyRow text="No notifications yet." />;

  const hasUnread = items.some((n) => !n.read);
  const today = items.filter((n) => isWithinLastDay(n.createdAt));
  const earlier = items.filter((n) => !isWithinLastDay(n.createdAt));
  const sections = [
    ['Today', today],
    ['Earlier', earlier],
  ].filter(([, list]) => list.length > 0);

  return (
    <div style={{ padding: '16px 16px 0' }}>
      {sections.map(([section, list], index) => (
        <section key={section} style={{ marginBottom: 16 }}>
          <SectionLabel
            action={
              index === 0 && hasUnread ? (
                <button
                  onClick={onMarkAllRead}
                  style={{ fontFamily: 'var(--font-inter)', fontSize: 12, fontWeight: 500, color: 'var(--slate-600)' }}
                >
                  Mark all read
                </button>
              ) : null
            }
          >
            {section}
          </SectionLabel>
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

function ChatsBody({ items, onOpen, onNewMessage }) {
  const [query, setQuery] = useState('');
  const q = query.trim().toLowerCase();
  const filtered = q
    ? items.filter(
        (c) =>
          (c.otherParty?.name || '').toLowerCase().includes(q) ||
          (c.otherParty?.username || '').toLowerCase().includes(q),
      )
    : items;

  return (
    <div style={{ padding: '12px 16px 0' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16 }}>
        <div
          style={{
            flex: 1,
            height: 40,
            borderRadius: 9999,
            background: 'rgba(140,136,128,0.15)',
            display: 'flex',
            alignItems: 'center',
            padding: '0 14px',
            gap: 8,
          }}
        >
          <Search size={16} color="var(--cream-text-secondary)" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search your connections"
            style={{ flex: 1, minWidth: 0, background: 'transparent', outline: 'none', fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text)' }}
          />
        </div>
        <button
          onClick={onNewMessage}
          aria-label="New message"
          title="New message"
          style={{
            width: 40,
            height: 40,
            borderRadius: '50%',
            background: 'rgba(140,136,128,0.15)',
            color: 'var(--cream-text)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          <SquarePen size={17} strokeWidth={1.75} />
        </button>
      </div>
      {filtered.length === 0 ? (
        <EmptyRow text={q ? 'No matching conversations.' : 'No conversations yet.'} />
      ) : (
        filtered.map((c) => (
          <GlassRow key={c.id} onClick={() => onOpen(c.id)}>
            <Avatar src={c.otherParty?.profilePhotoUrl} size={48} />
            <span style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: 'var(--font-inter)', fontSize: 14, fontWeight: 600, color: 'var(--slate-900)' }}>
                {c.otherParty?.name || 'Someone'}
              </div>
              <div style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--slate-500)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {c.status === 'pending' ? 'Request sent' : c.preview || ''}
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

function RequestButtons({ onAccept, onDecline }) {
  return (
    <span style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
      <button
        onClick={onAccept}
        style={{ padding: '6px 14px', borderRadius: 9999, background: 'var(--slate-900)', color: '#fff', fontSize: 12, fontWeight: 600 }}
      >
        Accept
      </button>
      <button
        onClick={onDecline}
        style={{ padding: '6px 14px', borderRadius: 9999, background: 'var(--slate-100)', color: 'var(--slate-700)', fontSize: 12, fontWeight: 500 }}
      >
        Decline
      </button>
    </span>
  );
}

/// One requester: avatar + name open `onOpen` (their profile, or the request thread).
function RequestRow({ avatarSrc, name, subtitle, onOpen, onAccept, onDecline }) {
  return (
    <GlassRow>
      <button
        onClick={onOpen}
        style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 12, textAlign: 'left' }}
      >
        <Avatar src={avatarSrc} size={48} />
        <span style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontFamily: 'var(--font-inter)', fontSize: 14, fontWeight: 600, color: 'var(--slate-900)' }}>{name}</div>
          <div style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--slate-500)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
            {subtitle}
          </div>
        </span>
      </button>
      <RequestButtons onAccept={onAccept} onDecline={onDecline} />
    </GlassRow>
  );
}

function RequestsBody({
  followRequests,
  followError,
  messageRequests,
  messageError,
  followSectionRef,
  onOpenProfile,
  onOpenThread,
  onFollowRequest,
  onMessageRequest,
}) {
  if (followRequests.length === 0 && messageRequests.length === 0) {
    return <EmptyRow text={followError || messageError || 'No pending requests.'} />;
  }
  return (
    <div style={{ padding: '16px 16px 0' }}>
      {(followRequests.length > 0 || followError) && (
        <section ref={followSectionRef} style={{ marginBottom: 16 }}>
          <SectionLabel>Follow requests</SectionLabel>
          {followError && <EmptyRow text={followError} />}
          {followRequests.map((r) => (
            <RequestRow
              key={r.username}
              avatarSrc={r.profilePhotoUrl}
              name={r.name || r.username}
              subtitle={`@${r.username}${r.requestedAt ? ` · ${formatRelativeTime(r.requestedAt)}` : ''}`}
              onOpen={() => onOpenProfile(r.username)}
              onAccept={() => onFollowRequest(r, true)}
              onDecline={() => onFollowRequest(r, false)}
            />
          ))}
        </section>
      )}
      {(messageRequests.length > 0 || messageError) && (
        <section style={{ marginBottom: 16 }}>
          <SectionLabel>Message requests</SectionLabel>
          {messageError && <EmptyRow text={messageError} />}
          {messageRequests.map((r) => (
            <RequestRow
              key={r.id}
              avatarSrc={r.otherParty?.profilePhotoUrl}
              name={r.otherParty?.name || 'Someone'}
              subtitle={r.preview || `@${r.otherParty?.username || 'unknown'}`}
              onOpen={() => onOpenThread(r.id)}
              onAccept={() => onMessageRequest(r, true)}
              onDecline={() => onMessageRequest(r, false)}
            />
          ))}
        </section>
      )}
    </div>
  );
}
