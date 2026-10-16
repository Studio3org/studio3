import React, { useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { setAccessToken } from '../../services/apiClient';
import { friendlyError } from '../../services/socialApi';
import { changePassword } from '../../services/profileApi';
import { SettingsLayout } from './SettingsLayout';

/** Same rule as the app's sign-up / change-password forms. */
function passwordProblem(pw) {
  if (pw.length < 8) return 'Use at least 8 characters.';
  if (!/[A-Z]/.test(pw)) return 'Include at least one uppercase letter.';
  if (!/[0-9]/.test(pw)) return 'Include at least one number.';
  return null;
}

/// Change password. The backend revokes every other session and hands back a fresh access
/// token for this one, which must replace the stored token or the next call would 401.
export function PasswordSettingsPage() {
  const { refreshUser } = useAuth();
  const [current, setCurrent] = useState('');
  const [next, setNext] = useState('');
  const [confirm, setConfirm] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [done, setDone] = useState(false);

  const ruleError = next ? passwordProblem(next) : null;
  const mismatch = Boolean(confirm) && next !== confirm;
  const canSubmit = Boolean(current && next && confirm) && !ruleError && !mismatch && !busy;

  const submit = async (e) => {
    e.preventDefault();
    if (!canSubmit) return;
    if (next === current) {
      setError('Choose a password different from your current one.');
      return;
    }
    setBusy(true);
    setError(null);
    setDone(false);
    try {
      const res = await changePassword(current, next);
      if (res?.accessToken) setAccessToken(res.accessToken);
      await refreshUser().catch(() => {});
      setCurrent('');
      setNext('');
      setConfirm('');
      setDone(true);
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <SettingsLayout
      title="Password & security"
      subtitle="Changing your password signs you out on every other device."
    >
      <form className="settings-form" onSubmit={submit}>
        <label className="settings-modal-label" htmlFor="pw-current">Current password</label>
        <input
          id="pw-current"
          type="password"
          className="settings-modal-input"
          autoComplete="current-password"
          value={current}
          disabled={busy}
          onChange={(e) => setCurrent(e.target.value)}
        />

        <label className="settings-modal-label" htmlFor="pw-new">New password</label>
        <input
          id="pw-new"
          type="password"
          className="settings-modal-input"
          autoComplete="new-password"
          value={next}
          disabled={busy}
          onChange={(e) => setNext(e.target.value)}
        />
        <p className={ruleError ? 'settings-error' : 'settings-hint'} style={{ marginTop: -6, marginBottom: 12 }}>
          {ruleError || 'At least 8 characters, with an uppercase letter and a number.'}
        </p>

        <label className="settings-modal-label" htmlFor="pw-confirm">Confirm new password</label>
        <input
          id="pw-confirm"
          type="password"
          className="settings-modal-input"
          autoComplete="new-password"
          value={confirm}
          disabled={busy}
          onChange={(e) => setConfirm(e.target.value)}
        />
        {mismatch && <p className="settings-error">Passwords don&apos;t match.</p>}
        {error && <p className="settings-error">{error}</p>}
        {done && <p className="settings-success">Password changed. Other devices have been signed out.</p>}

        <div className="settings-form-actions">
          <button type="submit" className="settings-primary-btn" disabled={!canSubmit}>
            {busy ? 'Saving…' : 'Change password'}
          </button>
        </div>
      </form>
    </SettingsLayout>
  );
}
