import React, { useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { Lock, User as UserIcon } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { ApiError } from '../services/apiClient';
import {
  AuthGuestLink,
  AuthLinkFooter,
  AuthPageTitle,
  AuthPasswordInput,
  AuthPillInput,
  AuthPrimaryButton,
  AuthScaffold,
  AuthTermsCheckbox,
  hasAgreedToTerms,
} from '../components/auth/AuthUI';

/// "Remember me" keeps only the username/email on this device (never the password)
/// so the next visit's form is prefilled; unticking it forgets the stored value.
const REMEMBERED_LOGIN_KEY = 'studio3.rememberedLogin';

function readRememberedLogin() {
  try {
    return localStorage.getItem(REMEMBERED_LOGIN_KEY) || '';
  } catch {
    return '';
  }
}

function writeRememberedLogin(identifier) {
  try {
    if (identifier) localStorage.setItem(REMEMBERED_LOGIN_KEY, identifier);
    else localStorage.removeItem(REMEMBERED_LOGIN_KEY);
  } catch {
    /* storage unavailable — nothing to remember */
  }
}

export function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [username, setUsername] = useState(readRememberedLogin);
  const [password, setPassword] = useState('');
  const [remember, setRemember] = useState(true);
  const [agreed, setAgreed] = useState(hasAgreedToTerms);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);

  const canSubmit = Boolean(username.trim() && password && agreed);

  const submit = async () => {
    if (!canSubmit || loading) return;
    setLoading(true);
    setError(null);
    try {
      const identifier = username.trim();
      const user = await login(identifier, password);
      writeRememberedLogin(remember ? identifier : null);
      const from = location.state?.from;
      const redirectTo = from ? `${from.pathname || ''}${from.search || ''}${from.hash || ''}` : null;
      if (!user.onboardingComplete) navigate('/onboarding', { replace: true });
      else navigate(redirectTo || '/home', { replace: true });
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not log in. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthScaffold compact>
      <AuthPageTitle title="Login" />

      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        <AuthPillInput
          icon={<UserIcon size={20} strokeWidth={1.75} />}
          placeholder="Username or email"
          autoComplete="username"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
        />
        <AuthPasswordInput
          icon={<Lock size={20} strokeWidth={1.75} />}
          placeholder="Password"
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && submit()}
        />

        {error && (
          <p style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--auth-error)', margin: '-6px 2px 0' }}>
            {error}
          </p>
        )}

        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', margin: '0 2px' }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, color: 'var(--auth-text-muted)', fontFamily: 'var(--font-inter)', fontSize: 12 }}>
            <input
              type="checkbox"
              checked={remember}
              onChange={(e) => {
                setRemember(e.target.checked);
                if (!e.target.checked) writeRememberedLogin(null);
              }}
              style={{ width: 16, height: 16, accentColor: '#fff' }}
            />
            Remember me
          </label>
          <Link
            to="/forgot-password"
            style={{ fontFamily: 'var(--font-inter)', fontSize: 12, fontWeight: 500, color: 'var(--auth-text-muted)' }}
          >
            Forgot login?
          </Link>
        </div>

        <AuthTermsCheckbox checked={agreed} onChange={setAgreed} />

        <div style={{ marginTop: 6 }}>
          <AuthPrimaryButton disabled={!canSubmit} loading={loading} onClick={submit}>
            Login
          </AuthPrimaryButton>
        </div>
      </div>

      <div style={{ marginTop: 24 }}>
        <AuthLinkFooter prompt="Don't have an account?" linkLabel="Sign Up" to="/signup" />
        <AuthGuestLink />
      </div>
    </AuthScaffold>
  );
}
