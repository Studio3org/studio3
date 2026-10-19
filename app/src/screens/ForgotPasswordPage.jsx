import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Mail, MailCheck } from 'lucide-react';
import { apiFetch, ApiError } from '../services/apiClient';
import {
  AuthGhostButton,
  AuthLinkFooter,
  AuthMessage,
  AuthPageTitle,
  AuthPillInput,
  AuthPrimaryButton,
  AuthScaffold,
} from '../components/auth/AuthUI';

const EMAIL_RE = /^[\w.-]+@([\w-]+\.)+[\w-]{2,}$/;

/** "Forgot login?" — emails a reset link. The backend answers 200 whether or not the
 * address has an account (no account enumeration), so the confirmation copy is the same
 * either way; only genuine failures (rate limit, network) surface as errors. */
export function ForgotPasswordPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [sent, setSent] = useState(false);

  const valid = EMAIL_RE.test(email.trim());

  const submit = async () => {
    if (!valid || busy) return;
    setBusy(true);
    setError(null);
    try {
      await apiFetch('/api/auth/forget-password', { method: 'POST', body: { email: email.trim() } });
      setSent(true);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not send the reset link. Please try again.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <AuthScaffold compact showBackButton onBack={() => navigate('/login')}>
      {sent ? (
        <div style={{ textAlign: 'center' }}>
          <MailCheck size={48} color="#fff" strokeWidth={1.5} style={{ margin: '0 auto 20px' }} />
          <AuthPageTitle
            align="center"
            title="Check your email"
            subtitle="If an account exists for that email, we've emailed a reset link."
          />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <AuthPrimaryButton onClick={() => navigate('/login', { replace: true })}>Back to sign in</AuthPrimaryButton>
            <AuthGhostButton onClick={() => setSent(false)}>Use a different email</AuthGhostButton>
          </div>
        </div>
      ) : (
        <>
          <AuthPageTitle title="Forgot password?" subtitle="Enter your account email and we'll send you a reset link." />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <AuthPillInput
              icon={<Mail size={20} strokeWidth={1.75} />}
              type="email"
              autoComplete="email"
              placeholder="Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && submit()}
            />
            {error && <AuthMessage>{error}</AuthMessage>}
            <div style={{ marginTop: 6 }}>
              <AuthPrimaryButton disabled={!valid} loading={busy} onClick={submit}>
                Send reset link
              </AuthPrimaryButton>
            </div>
          </div>
          <div style={{ marginTop: 24 }}>
            <AuthLinkFooter prompt="Remembered it?" linkLabel="Sign in" to="/login" />
          </div>
        </>
      )}
    </AuthScaffold>
  );
}
