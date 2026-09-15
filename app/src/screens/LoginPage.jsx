import React, { useState } from 'react';
import { Lock, User as UserIcon } from 'lucide-react';
import {
  AuthLinkFooter,
  AuthPageTitle,
  AuthPasswordInput,
  AuthPillInput,
  AuthPrimaryButton,
  AuthScaffold,
} from '../components/auth/AuthUI';

export function LoginPage() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [remember, setRemember] = useState(true);

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
        />

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
          <AuthPrimaryButton>Login</AuthPrimaryButton>
        </div>
      </div>

      <div style={{ marginTop: 24 }}>
        <AuthLinkFooter prompt="Don't have an account?" linkLabel="Sign Up" to="/signup" />
      </div>
    </AuthScaffold>
  );
}
