import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { setSession } from '../lib/api';
import { useSession } from '../lib/session';
import { changePassword } from '../lib/profileApi';
import { friendlyError } from '../lib/social';
import { passwordProblem } from '../lib/validators';
import { PillInputWithToggle } from '../components/inputs/PillInput';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { GuestPrompt } from '../components/common/StateMessage';
import { DANGER, SettingsScreen, fieldLabel } from './SettingsPage';

export function ChangePasswordPage() {
  const navigate = useNavigate();
  const { loggedIn } = useSession();
  const [current, setCurrent] = useState('');
  const [next, setNext] = useState('');
  const [confirm, setConfirm] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [done, setDone] = useState(false);

  if (!loggedIn && !done) {
    return (
      <SettingsScreen title="Change password">
        <GuestPrompt title="Change password" message="Log in to change your password." next="/settings/password" />
      </SettingsScreen>
    );
  }

  const mismatch = confirm.length > 0 && next !== confirm;
  const passwordError = next.length > 0 ? passwordProblem(next) : null;
  const canSubmit = Boolean(current) && !passwordProblem(next) && next === confirm && !busy;

  const submit = async (e) => {
    e.preventDefault();
    if (!canSubmit) return;
    setBusy(true);
    setError(null);
    try {
      const data = await changePassword(current, next);
      // The backend rotates the session on a password change — keep the new token.
      if (data?.accessToken) setSession(data.accessToken, data.user ?? undefined);
      setDone(true);
    } catch (err) {
      setError(err.status === 401 ? 'Your current password is incorrect.' : friendlyError(err));
    } finally {
      setBusy(false);
    }
  };

  if (done) {
    return (
      <SettingsScreen title="Change password">
        <p style={{ fontSize: 15, color: 'var(--slate-700)', lineHeight: 1.5, margin: '16px 4px 24px' }}>
          Your password has been changed.
        </p>
        <PrimaryButton onClick={() => navigate('/settings')}>Back to settings</PrimaryButton>
      </SettingsScreen>
    );
  }

  return (
    <SettingsScreen title="Change password">
      <form onSubmit={submit}>
        <label style={fieldLabel} htmlFor="cp-current">Current password</label>
        <PillInputWithToggle id="cp-current" value={current} onChange={(e) => setCurrent(e.target.value)} autoComplete="current-password" />
        <label style={fieldLabel} htmlFor="cp-new">New password</label>
        <PillInputWithToggle id="cp-new" value={next} onChange={(e) => setNext(e.target.value)} autoComplete="new-password" placeholder="8+ characters, A–Z and 0–9" />
        <label style={fieldLabel} htmlFor="cp-confirm">Confirm new password</label>
        <PillInputWithToggle id="cp-confirm" value={confirm} onChange={(e) => setConfirm(e.target.value)} autoComplete="new-password" />
        {passwordError && <p style={{ color: DANGER, fontSize: 13, margin: '8px 4px 0' }}>{passwordError}</p>}
        {mismatch && <p style={{ color: DANGER, fontSize: 13, margin: '8px 4px 0' }}>Passwords don't match.</p>}
        {error && <p style={{ color: DANGER, fontSize: 13, margin: '8px 4px 0' }}>{error}</p>}
        <PrimaryButton type="submit" disabled={!canSubmit} style={{ marginTop: 24 }}>
          {busy ? 'Saving…' : 'Change password'}
        </PrimaryButton>
      </form>
    </SettingsScreen>
  );
}
