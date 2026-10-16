import React, { useEffect, useState } from 'react';
import { friendlyError, listBlockedUsers, unblockUser } from '../../services/socialApi';
import { markUnblocked } from '../../services/blockedAuthors';
import { SettingsAvatar, SettingsLayout, SettingsSpinner } from './SettingsLayout';

/// Accounts you've blocked (GET /api/users/blocked — a plain array). Unblocking lets their
/// content back into your feeds on the next fetch.
export function BlockedAccountsPage() {
  const [list, setList] = useState(null);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(null); // username being unblocked
  const [reload, setReload] = useState(0);

  useEffect(() => {
    let cancelled = false;
    setError(null);
    listBlockedUsers()
      .then((data) => !cancelled && setList(Array.isArray(data) ? data : data?.items ?? []))
      .catch((e) => !cancelled && setError(friendlyError(e)));
    return () => {
      cancelled = true;
    };
  }, [reload]);

  const handleUnblock = async (username) => {
    if (busy) return;
    setBusy(username);
    setError(null);
    try {
      await unblockUser(username);
      markUnblocked(username);
      setList((prev) => prev.filter((u) => u.username !== username));
    } catch (e) {
      setError(friendlyError(e));
    } finally {
      setBusy(null);
    }
  };

  return (
    <SettingsLayout
      title="Blocked accounts"
      subtitle="Blocked accounts can't message you or see your content, and you won't see theirs. They aren't notified."
    >
      {list === null && !error && <SettingsSpinner />}
      {list === null && error && (
        <div className="settings-empty">
          <p className="settings-empty-title">Couldn't load blocked accounts</p>
          <p className="settings-empty-sub">{error}</p>
          <div className="settings-form-actions" style={{ justifyContent: 'center' }}>
            <button type="button" className="settings-secondary-btn" onClick={() => setReload((n) => n + 1)}>
              Try again
            </button>
          </div>
        </div>
      )}
      {list && list.length === 0 && (
        <div className="settings-empty">
          <p className="settings-empty-title">No blocked accounts</p>
          <p className="settings-empty-sub">Accounts you block will appear here.</p>
        </div>
      )}
      {list && list.length > 0 && (
        <>
          {list.map((u) => (
            <div key={u.username} className="settings-card is-static">
              <div className="settings-card-left" style={{ minWidth: 0 }}>
                <SettingsAvatar src={u.profilePhotoUrl} name={u.name || u.username} />
                <div className="settings-card-text">
                  <span className="settings-card-label">{u.name || u.username}</span>
                  <span className="settings-card-sub">@{u.username}</span>
                </div>
              </div>
              <button
                type="button"
                className="settings-small-btn"
                disabled={busy === u.username}
                onClick={() => handleUnblock(u.username)}
              >
                {busy === u.username ? 'Unblocking…' : 'Unblock'}
              </button>
            </div>
          ))}
          {error && <p className="settings-error">{error}</p>}
        </>
      )}
    </SettingsLayout>
  );
}
