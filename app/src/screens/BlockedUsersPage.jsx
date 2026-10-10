import React, { useCallback, useEffect, useState } from 'react';
import { unblockUser } from '../lib/api';
import { useSession } from '../lib/session';
import { listBlocked } from '../lib/profileApi';
import { friendlyError } from '../lib/social';
import { Avatar } from '../components/common/Avatar';
import { GuestPrompt, StateMessage } from '../components/common/StateMessage';
import { DANGER, SettingsScreen } from './SettingsPage';

export function BlockedUsersPage() {
  const { loggedIn } = useSession();
  const [users, setUsers] = useState(null);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(null);
  const [rowError, setRowError] = useState(null);

  const load = useCallback(() => {
    setUsers(null);
    setError(null);
    listBlocked().then(setUsers).catch((e) => setError(friendlyError(e)));
  }, []);

  useEffect(() => {
    if (loggedIn) load();
  }, [loggedIn, load]);

  if (!loggedIn) {
    return (
      <SettingsScreen title="Blocked accounts">
        <GuestPrompt title="Blocked accounts" message="Log in to manage who you've blocked." next="/settings/blocked" />
      </SettingsScreen>
    );
  }

  const unblock = async (username) => {
    setBusy(username);
    setRowError(null);
    try {
      await unblockUser(username);
      setUsers((list) => list.filter((u) => u.username !== username));
    } catch (e) {
      setRowError(friendlyError(e));
    } finally {
      setBusy(null);
    }
  };

  return (
    <SettingsScreen title="Blocked accounts">
      {error ? (
        <StateMessage action="Try again" onAction={load}>{error}</StateMessage>
      ) : users == null ? (
        <StateMessage>Loading…</StateMessage>
      ) : users.length === 0 ? (
        <StateMessage>You haven't blocked anyone.</StateMessage>
      ) : (
        <>
          {rowError && <p style={{ color: DANGER, fontSize: 13, margin: '0 4px 8px' }}>{rowError}</p>}
          {users.map((u) => (
            <div key={u.username} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 0' }}>
              <Avatar src={u.profilePhotoUrl} name={u.name} size={44} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 15, fontWeight: 600, color: 'var(--slate-900)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {u.name || u.username}
                </div>
                <div style={{ fontSize: 13, color: 'var(--slate-500)' }}>@{u.username}</div>
              </div>
              <button
                type="button"
                disabled={busy === u.username}
                onClick={() => unblock(u.username)}
                style={{ padding: '8px 16px', borderRadius: 9999, border: '1.5px solid var(--slate-300)', fontSize: 13, fontWeight: 600, color: 'var(--slate-800)', opacity: busy === u.username ? 0.6 : 1 }}
              >
                {busy === u.username ? 'Unblocking…' : 'Unblock'}
              </button>
            </div>
          ))}
        </>
      )}
    </SettingsScreen>
  );
}
