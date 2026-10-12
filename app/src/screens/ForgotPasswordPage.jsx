import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { GlassCard } from '../components/design/GlassCard';
import { PillInput } from '../components/inputs/PillInput';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { requestPasswordReset } from '../lib/authApi';

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

const EMAIL_RE = /^[\w.-]+@([\w-]+\.)+[\w-]{2,}$/;

export function ForgotPasswordPage() {
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState(null);

  const canSubmit = EMAIL_RE.test(email.trim()) && !loading;

  const submit = async () => {
    if (!canSubmit) return;
    setLoading(true);
    setError(null);
    try {
      await requestPasswordReset(email);
      setSent(true);
    } catch (e) {
      // The backend answers 200 whether or not the account exists; only
      // network/rate-limit failures land here.
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={bgStyle}>
      <div style={{ textAlign: 'center', marginBottom: 32 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, color: 'var(--slate-900)' }}>Studio 3</h1>
        <p style={{ fontSize: 13, color: 'var(--slate-400)', marginTop: 4 }}>Discover Art. Collect Stories.</p>
      </div>

      <GlassCard style={{ width: '100%', maxWidth: 343, padding: 28 }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div>
            <h2 style={{ fontSize: 18, fontWeight: 600, color: 'var(--slate-900)', marginBottom: 4 }}>Forgot password</h2>
            <p style={{ fontSize: 13, color: 'var(--slate-500)', lineHeight: 1.4 }}>
              {sent
                ? "If an account exists for that email, we've emailed a reset link. It expires in an hour."
                : "Enter your account's email and we'll send you a link to reset your password."}
            </p>
          </div>
          {!sent && (
            <>
              <PillInput
                type="email"
                placeholder="Email address"
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && submit()}
              />
              {error && <div style={{ fontSize: 13, color: '#E05252' }} role="alert">{error}</div>}
              <PrimaryButton disabled={!canSubmit} onClick={submit}>
                {loading ? 'Sending…' : 'Send reset link'}
              </PrimaryButton>
            </>
          )}
          {sent && (
            <button
              type="button"
              onClick={() => setSent(false)}
              style={{ fontSize: 13, color: 'var(--slate-600)', textDecoration: 'underline' }}
            >
              Use a different email
            </button>
          )}
        </div>
      </GlassCard>

      <p style={{ marginTop: 24, fontSize: 14, color: 'var(--slate-600)' }}>
        Remembered it? <Link to="/login" style={{ fontWeight: 600, color: 'var(--slate-900)' }}>Sign In</Link>
      </p>
    </div>
  );
}
