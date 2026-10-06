import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { GlassCard } from '../components/design/GlassCard';
import { PillInput, PillInputWithToggle } from '../components/inputs/PillInput';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { SafeArea } from '../components/layout/SafeArea';

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
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

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
            type="email"
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
          <PillInputWithToggle
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
          <PrimaryButton>Sign In</PrimaryButton>

          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 8 }}>
            <div style={{ flex: 1, height: 1, background: 'var(--slate-200)' }} />
            <span style={{ fontSize: 12, color: 'var(--slate-400)' }}>or</span>
            <div style={{ flex: 1, height: 1, background: 'var(--slate-200)' }} />
          </div>

          <button
            style={{
              height: 52,
              borderRadius: 9999,
              border: '1.5px solid var(--slate-200)',
              background: 'var(--white)',
              color: 'var(--slate-700)',
              fontSize: 15,
              fontWeight: 500,
            }}
          >
            Continue with Google
          </button>
          <button
            style={{
              height: 52,
              borderRadius: 9999,
              background: 'var(--slate-900)',
              color: 'var(--white)',
              fontSize: 15,
              fontWeight: 500,
            }}
          >
            Continue with Apple
          </button>

          <div style={{ textAlign: 'right' }}>
            <Link to="/login" style={{ fontSize: 12, color: 'var(--slate-500)' }}>
              Forgot password?
            </Link>
          </div>
        </div>
      </GlassCard>

      <p style={{ marginTop: 24, fontSize: 14, color: 'var(--slate-600)' }}>
        Don't have an account? <Link to="/signup" style={{ fontWeight: 600, color: 'var(--slate-900)' }}>Sign Up</Link>
      </p>
    </div>
  );
}
