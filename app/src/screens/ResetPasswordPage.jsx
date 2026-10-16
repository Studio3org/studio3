import React, { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { CheckCircle2, Link2Off, Lock } from 'lucide-react';
import { apiFetch, ApiError } from '../services/apiClient';
import {
  AuthMessage,
  AuthPageTitle,
  AuthPasswordInput,
  AuthPrimaryButton,
  AuthScaffold,
  passwordError,
} from '../components/auth/AuthUI';

/** Landing page for the emailed link (`/reset-password?token=...`, built by the backend's
 * password_reset_service). A missing token, or one the backend rejects as invalid/expired,
 * swaps to a "Request a new link" state instead of leaving the user stuck on the form. */
export function ResetPasswordPage() {
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const token = (params.get('token') || '').trim();
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [state, setState] = useState(token ? 'form' : 'invalid'); // 'form' | 'invalid' | 'done'

  const pwError = passwordError(password);
  const mismatch = confirm && confirm !== password;

  const submit = async () => {
    if (pwError || password !== confirm || busy) return;
    setBusy(true);
    setError(null);
    try {
      await apiFetch('/api/auth/reset-password', { method: 'POST', body: { token, newPassword: password } });
      setState('done');
    } catch (e) {
      // The only 400 that isn't about the password itself is the token being bad/expired.
      if (e instanceof ApiError && e.status === 400 && !/password must/i.test(e.message || '')) setState('invalid');
      else setError(e instanceof ApiError ? e.message : 'Could not reset your password. Please try again.');
    } finally {
      setBusy(false);
    }
  };

  if (state === 'done') {
    return (
      <AuthScaffold compact>
        <div style={{ textAlign: 'center' }}>
          <CheckCircle2 size={48} color="#fff" strokeWidth={1.5} style={{ margin: '0 auto 20px' }} />
          <AuthPageTitle align="center" title="Password updated" subtitle="You can now sign in with your new password." />
          <AuthPrimaryButton onClick={() => navigate('/login', { replace: true })}>Sign in</AuthPrimaryButton>
        </div>
      </AuthScaffold>
    );
  }

  if (state === 'invalid') {
    return (
      <AuthScaffold compact>
        <div style={{ textAlign: 'center' }}>
          <Link2Off size={48} color="#fff" strokeWidth={1.5} style={{ margin: '0 auto 20px' }} />
          <AuthPageTitle
            align="center"
            title="Link expired"
            subtitle="This reset link is invalid or has expired. Request a new one to continue."
          />
          <AuthPrimaryButton onClick={() => navigate('/forgot-password', { replace: true })}>Request a new link</AuthPrimaryButton>
        </div>
      </AuthScaffold>
    );
  }

  return (
    <AuthScaffold compact showBackButton onBack={() => navigate('/login')}>
      <AuthPageTitle title="Set a new password" subtitle="Choose a new password for your Studio 3 account." />
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        <AuthPasswordInput
          icon={<Lock size={20} strokeWidth={1.75} />}
          placeholder="New password"
          autoComplete="new-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        <AuthMessage tone={password && !pwError ? 'success' : password ? 'error' : 'dim'}>
          {password ? pwError || 'Strong enough' : 'At least 8 characters, with an uppercase letter and a number.'}
        </AuthMessage>
        <AuthPasswordInput
          icon={<Lock size={20} strokeWidth={1.75} />}
          placeholder="Confirm new password"
          autoComplete="new-password"
          value={confirm}
          onChange={(e) => setConfirm(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && submit()}
          error={mismatch ? 'Passwords do not match' : null}
        />
        {error && <AuthMessage>{error}</AuthMessage>}
        <div style={{ marginTop: 6 }}>
          <AuthPrimaryButton disabled={Boolean(pwError) || password !== confirm} loading={busy} onClick={submit}>
            Reset password
          </AuthPrimaryButton>
        </div>
      </div>
    </AuthScaffold>
  );
}
