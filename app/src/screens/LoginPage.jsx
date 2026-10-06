import React, { useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Lock, User as UserIcon } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { ApiError } from '../services/apiClient';
import {
  AuthLinkFooter,
  AuthPageTitle,
  AuthPasswordInput,
  AuthPillInput,
  AuthPrimaryButton,
  AuthScaffold,
} from '../components/auth/AuthUI';

export function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [remember, setRemember] = useState(true);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);

  const submit = async () => {
    if (!username || !password || loading) return;
    setLoading(true);
    setError(null);
    try {
      const user = await login(username, password);
      const redirectTo = location.state?.from?.pathname;
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
          value={username}
          onChange={(e) => setUsername(e.target.value)}
        />
        <AuthPasswordInput
          icon={<Lock size={20} strokeWidth={1.75} />}
          placeholder="Password"
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
              onChange={(e) => setRemember(e.target.checked)}
              style={{ width: 16, height: 16, accentColor: '#fff' }}
            />
            Remember me
          </label>
          <button style={{ fontFamily: 'var(--font-inter)', fontSize: 12, fontWeight: 500, color: 'var(--auth-text-muted)' }}>
            Forgot login?
          </button>
        </div>

        <div style={{ marginTop: 6 }}>
          <AuthPrimaryButton disabled={!username || !password} loading={loading} onClick={submit}>
            Login
          </AuthPrimaryButton>
        </div>
      </div>

      <div style={{ marginTop: 24 }}>
        <AuthLinkFooter prompt="Don't have an account?" linkLabel="Sign Up" to="/signup" />
      </div>
    </AuthScaffold>
  );
}
