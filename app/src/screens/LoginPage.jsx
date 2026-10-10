import React, { useState } from 'react';
import { Link, Navigate, useNavigate, useSearchParams } from 'react-router-dom';
import { login } from '../lib/api';
import { TermsCheckbox } from '../components/moderation/TermsCheckbox';
import { GlassCard } from '../components/design/GlassCard';
import { PillInput, PillInputWithToggle } from '../components/inputs/PillInput';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { useSession } from '../lib/session';

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

export function LoginPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [agreed, setAgreed] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const { loggedIn } = useSession();

  // Only same-site paths — never bounce to an arbitrary URL after login.
  const nextParam = searchParams.get('next');
  const next = nextParam && nextParam.startsWith('/') && !nextParam.startsWith('//')
    ? nextParam
    : '/home';
  const canSubmit = email.trim() && password && agreed && !loading;

  // Already signed in (or just signed in) — go where the user was headed.
  if (loggedIn) return <Navigate to={next} replace />;

  const signIn = async () => {
    if (!canSubmit) return;
    setLoading(true);
    setError(null);
    try {
      await login(email, password);
      navigate(next, { replace: true });
    } catch (e) {
      setError(e.message);
      setLoading(false);
    }
  };

  return (
    <div style={bgStyle}>
      <div style={{ textAlign: 'center', marginBottom: 32 }}>
        <h1 style={{ fontFamily: 'Inter', fontSize: 28, fontWeight: 700, color: 'var(--slate-900)' }}>
          Studio 3
        </h1>
        <p style={{ fontSize: 13, fontWeight: 400, color: 'var(--slate-400)', marginTop: 4 }}>
          Discover Art. Collect Stories.
        </p>
      </div>

      <GlassCard style={{ width: '100%', maxWidth: 343, padding: 28 }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <PillInput
            type="text"
            placeholder="Username or email"
            autoComplete="username"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
          <PillInputWithToggle
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && signIn()}
          />
          <TermsCheckbox checked={agreed} onChange={setAgreed} />
          {error && (
            <div style={{ fontSize: 13, color: '#E05252' }} role="alert">{error}</div>
          )}
          <PrimaryButton disabled={!canSubmit} onClick={signIn}>
            {loading ? 'Signing in…' : 'Sign In'}
          </PrimaryButton>

          <div style={{ textAlign: 'right' }}>
            <Link to="/forgot-password" style={{ fontSize: 12, color: 'var(--slate-500)' }}>
              Forgot password?
            </Link>
          </div>
        </div>
      </GlassCard>

      <p style={{ marginTop: 24, fontSize: 14, color: 'var(--slate-600)' }}>
        Don't have an account? <Link to="/signup" style={{ fontWeight: 600, color: 'var(--slate-900)' }}>Sign Up</Link>
      </p>
      <Link to="/home" style={{ marginTop: 12, fontSize: 14, color: 'var(--slate-500)', textDecoration: 'underline' }}>
        Browse without an account
      </Link>
    </div>
  );
}
