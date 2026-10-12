import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { clearSession } from '../lib/api';
import { useSession } from '../lib/session';
import { deleteAccount } from '../lib/profileApi';
import { friendlyError } from '../lib/social';
import { PillInputWithToggle } from '../components/inputs/PillInput';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { GuestPrompt } from '../components/common/StateMessage';
import { DANGER, SettingsScreen, fieldLabel } from './SettingsPage';

export function DeleteAccountPage() {
  const navigate = useNavigate();
  const { loggedIn } = useSession();
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  if (!loggedIn) {
    return (
      <SettingsScreen title="Delete account">
        <GuestPrompt title="Delete account" message="Log in to manage your account." next="/settings/delete-account" />
      </SettingsScreen>
    );
  }

  const submit = async (e) => {
    e.preventDefault();
    if (!password || busy) return;
    setBusy(true);
    setError(null);
    try {
      await deleteAccount(password);
      navigate('/home', { replace: true });
      clearSession();
    } catch (err) {
      // 401 here means a wrong password, not an expired session.
      setError(err.status === 401 ? 'That password is incorrect.' : friendlyError(err));
      setBusy(false);
    }
  };

  const enabled = Boolean(password) && !busy;

  return (
    <SettingsScreen title="Delete account">
      <p style={{ fontSize: 15, color: 'var(--slate-700)', lineHeight: 1.5, margin: '8px 4px 12px' }}>
        Deleting your account is permanent and can't be undone.
      </p>
      <ul style={{ fontSize: 14, color: 'var(--slate-600)', lineHeight: 1.6, margin: '0 4px 8px', paddingLeft: 18 }}>
        <li>Your profile, pieces, scenes, and series will be removed.</li>
        <li>Your likes, saves, comments, follows, and messages will be deleted.</li>
        <li>Active listings or open orders must be resolved before you can delete.</li>
      </ul>
      <form onSubmit={submit}>
        <label style={fieldLabel} htmlFor="del-password">Enter your password to confirm</label>
        <PillInputWithToggle id="del-password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" />
        {error && <p style={{ color: DANGER, fontSize: 13, margin: '8px 4px 0' }}>{error}</p>}
        <PrimaryButton type="submit" disabled={!enabled} style={{ marginTop: 24, ...(enabled ? { background: DANGER } : {}) }}>
          {busy ? 'Deleting…' : 'Delete my account'}
        </PrimaryButton>
      </form>
    </SettingsScreen>
  );
}
