import React, { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { GlassCard } from '../components/design/GlassCard';
import { PillInputWithToggle } from '../components/inputs/PillInput';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { resetPassword } from '../lib/authApi';
import { passwordProblem } from '../lib/validators';

const bgStyle = {
  minHeight: '100vh',
  background: 'linear-gradient(180deg, var(--slate-50) 0%, var(--slate-100) 50%, var(--slate-200) 100%)',
  paddingTop: 44,
  paddingBottom: 24,
  paddingLeft: 16,
  paddingRight: 16,
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
};

const errorText = { fontSize: 13, color: '#E05252' };
const linkButton = {
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  height: 52,
  borderRadius: 9999,
  background: 'var(--slate-900)',
  color: 'var(--white)',
  fontSize: 15,
  fontWeight: 600,
};

/// Landing page for the emailed link: {FRONTEND_URL}/reset-password?token=…
export function ResetPasswordPage() {
  const [searchParams] = useSearchParams();
  const token = searchParams.get('token') ?? '';
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [loading, setLoading] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState(null);

  const passwordError = password ? passwordProblem(password) : null;
  const confirmError = confirm && confirm !== password ? 'Passwords do not match' : null;
  const canSubmit = Boolean(token) && !passwordProblem(password) && confirm === password && !loading;

  const submit = async () => {
    if (!canSubmit) return;
    setLoading(true);
    setError(null);
    try {
      await resetPassword(token, password);
      setDone(true);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  let body;
  if (!token) {
    body = (
      <>
        <p style={{ fontSize: 13, color: 'var(--slate-500)', lineHeight: 1.4 }}>
          This reset link is missing its token. Open the link from your email again, or request a new one.
        </p>
        <Link to="/forgot-password" style={linkButton}>Request a new link</Link>
      </>
    );
  } else if (done) {
    body = (
      <>
        <p style={{ fontSize: 13, color: 'var(--slate-500)', lineHeight: 1.4 }}>
          Your password has been reset and you've been signed out on all devices. Sign in with your new password.
        </p>
        <Link to="/login" style={linkButton}>Sign In</Link>
      </>
    );
  } else {
    body = (
      <>
        <PillInputWithToggle
          placeholder="New password"
          autoComplete="new-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        {passwordError && <div style={errorText}>{passwordError}</div>}
        <PillInputWithToggle
          placeholder="Confirm new password"
          autoComplete="new-password"
          value={confirm}
          onChange={(e) => setConfirm(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && submit()}
        />
        {confirmError && <div style={errorText}>{confirmError}</div>}
        {error && (
          <div style={errorText} role="alert">
            {error}{' '}
            <Link to="/forgot-password" style={{ textDecoration: 'underline' }}>Request a new link</Link>
          </div>
        )}
        <PrimaryButton disabled={!canSubmit} onClick={submit}>
          {loading ? 'Saving…' : 'Reset password'}
        </PrimaryButton>
      </>
    );
  }

  return (
    <div style={bgStyle}>
      <div style={{ textAlign: 'center', marginBottom: 32 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, color: 'var(--slate-900)' }}>Studio 3</h1>
        <p style={{ fontSize: 13, color: 'var(--slate-400)', marginTop: 4 }}>Discover Art. Collect Stories.</p>
      </div>

      <GlassCard style={{ width: '100%', maxWidth: 343, padding: 28 }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <h2 style={{ fontSize: 18, fontWeight: 600, color: 'var(--slate-900)' }}>
            {done ? 'Password updated' : 'Set a new password'}
          </h2>
          {body}
        </div>
      </GlassCard>

      <p style={{ marginTop: 24, fontSize: 14, color: 'var(--slate-600)' }}>
        <Link to="/login" style={{ fontWeight: 600, color: 'var(--slate-900)' }}>Back to Sign In</Link>
      </p>
    </div>
  );
}
