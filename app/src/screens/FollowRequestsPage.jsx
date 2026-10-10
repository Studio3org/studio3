import React, { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ChevronLeft } from 'lucide-react';
import { GlassCard } from '../components/design/GlassCard';
import { SafeArea } from '../components/layout/SafeArea';
import { Avatar } from '../components/common/Avatar';
import { GuestPrompt, StateMessage } from '../components/common/StateMessage';
import { apiFetch, isBlockedAuthor, onAuthorBlocked } from '../lib/api';
import { useSession } from '../lib/session';
import { timeAgo } from '../lib/content';
import { friendlyError } from '../lib/social';

const rowStyle = {
  display: 'flex',
  alignItems: 'center',
  gap: 12,
  padding: 12,
  marginBottom: 8,
  boxShadow: 'var(--shadow-card)',
};

const pill = (dark) => ({
  height: 32,
  padding: '0 14px',
  borderRadius: 9999,
  fontSize: 13,
  fontWeight: 600,
  border: dark ? 'none' : '1.5px solid var(--slate-200)',
  background: dark ? 'var(--slate-900)' : 'var(--white)',
  color: dark ? 'var(--white)' : 'var(--slate-700)',
  cursor: 'pointer',
});

/// Back to wherever we came from; straight to Activity on a fresh tab.
function useBack(fallback) {
  const navigate = useNavigate();
  return () => (window.history.state?.idx > 0 ? navigate(-1) : navigate(fallback, { replace: true }));
}

export function FollowRequestsPage() {
  const { loggedIn } = useSession();
  const back = useBack('/notifications');

  return (
    <SafeArea noBottom style={{ paddingTop: 0 }}>
      <header style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '12px 0 16px' }}>
        <button
          type="button"
          aria-label="Back"
          onClick={back}
          style={{ width: 36, height: 36, marginLeft: -8, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--slate-900)' }}
        >
          <ChevronLeft size={24} />
        </button>
        <h1 style={{ fontSize: 22, fontWeight: 700, color: 'var(--slate-900)' }}>Follow requests</h1>
      </header>
      {loggedIn ? (
        <RequestList />
      ) : (
        <GuestPrompt title="Follow requests" message="Log in to review who wants to follow you." next="/follow-requests" />
      )}
    </SafeArea>
  );
}

function RequestList() {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState({}); // username → true while acting
  const [rowError, setRowError] = useState(null);
  const [, setBlockTick] = useState(0);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const list = await apiFetch('/api/users/follow-requests', { auth: true });
      setRequests(Array.isArray(list) ? list : []);
    } catch (e) {
      setError(e);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);
  useEffect(() => onAuthorBlocked(() => setBlockTick((t) => t + 1)), []);

  const respond = async (username, action) => {
    if (busy[username]) return;
    setBusy((b) => ({ ...b, [username]: true }));
    setRowError(null);
    try {
      await apiFetch(`/api/users/follow-requests/${encodeURIComponent(username)}/${action}`, {
        method: 'POST',
        auth: true,
      });
      setRequests((prev) => prev.filter((r) => r.username !== username));
    } catch (e) {
      setRowError(friendlyError(e));
    } finally {
      setBusy((b) => ({ ...b, [username]: false }));
    }
  };

  if (loading) return <StateMessage>Loading…</StateMessage>;
  if (error) return <StateMessage action="Try again" onAction={load}>{friendlyError(error)}</StateMessage>;

  const visible = requests.filter((r) => !isBlockedAuthor(r.username));
  if (visible.length === 0) return <StateMessage>No pending follow requests.</StateMessage>;

  return (
    <>
      {rowError && <p style={{ color: '#E05252', fontSize: 13, marginBottom: 12 }}>{rowError}</p>}
      {visible.map((r) => (
        <GlassCard key={r.username} style={rowStyle}>
          <Link to={`/u/${r.username}`} style={{ display: 'flex', alignItems: 'center', gap: 12, flex: 1, minWidth: 0 }}>
            <Avatar src={r.profilePhotoUrl} name={r.name} size={40} />
            <div style={{ minWidth: 0 }}>
              <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--slate-900)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {r.name || r.username}
              </div>
              <div style={{ fontSize: 12, color: 'var(--slate-500)' }}>
                @{r.username}
                {r.requestedAt ? ` · ${timeAgo(r.requestedAt)}` : ''}
              </div>
            </div>
          </Link>
          <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
            <button type="button" style={pill(true)} disabled={busy[r.username]} onClick={() => respond(r.username, 'accept')}>
              Accept
            </button>
            <button type="button" style={pill(false)} disabled={busy[r.username]} onClick={() => respond(r.username, 'decline')}>
              Decline
            </button>
          </div>
        </GlassCard>
      ))}
    </>
  );
}
