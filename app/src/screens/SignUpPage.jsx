import React, { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { AtSign, Badge, Lock, Mail, Phone } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { apiFetch, ApiError } from '../services/apiClient';
import {
  AuthGhostButton,
  AuthLinkFooter,
  AuthOtpInput,
  AuthPageTitle,
  AuthPasswordInput,
  AuthPillInput,
  AuthPrimaryButton,
  AuthScaffold,
  AuthStepProgress,
} from '../components/auth/AuthUI';

const TOTAL_STEPS = 6;
const RESEND_COOLDOWN = 120;

function passwordStrength(pw) {
  if (!pw) return 0;
  let score = 0;
  if (pw.length >= 8) score += 0.34;
  if (/[A-Z]/.test(pw) && /[a-z]/.test(pw)) score += 0.33;
  if (/\d/.test(pw) || /[^A-Za-z0-9]/.test(pw)) score += 0.33;
  return Math.min(score, 1);
}

export function SignUpPage() {
  const { register } = useAuth();
  const navigate = useNavigate();
  const [step, setStep] = useState(1);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [cooldown, setCooldown] = useState(RESEND_COOLDOWN);
  const [username, setUsername] = useState('');
  const [usernameStatus, setUsernameStatus] = useState(null); // 'checking' | 'available' | 'taken'
  const [usernameMessage, setUsernameMessage] = useState(null);
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const usernameCheckId = useRef(0);

  useEffect(() => {
    if (step !== 3 || cooldown <= 0) return;
    const t = setTimeout(() => setCooldown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [step, cooldown]);

  useEffect(() => {
    if (step !== 4 || !username.trim()) {
      setUsernameStatus(null);
      return;
    }
    const id = ++usernameCheckId.current;
    setUsernameStatus('checking');
    const t = setTimeout(async () => {
      try {
        const result = await apiFetch(`/api/auth/username/check?username=${encodeURIComponent(username.trim())}`);
        if (usernameCheckId.current !== id) return;
        setUsernameStatus(result.available ? 'available' : 'taken');
        setUsernameMessage(result.message || null);
      } catch {
        if (usernameCheckId.current !== id) return;
        setUsernameStatus(null);
      }
    }, 450);
    return () => clearTimeout(t);
  }, [step, username]);

  const goBack = () => {
    setError(null);
    if (step > 1) setStep(step - 1);
    else navigate(-1);
  };

  const withBusy = async (fn) => {
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      await fn();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Something went wrong. Please try again.');
    } finally {
      setBusy(false);
    }
  };

  const sendCode = () =>
    withBusy(async () => {
      await apiFetch('/api/auth/otp/generate', { method: 'POST', body: { email } });
      setCooldown(RESEND_COOLDOWN);
      setStep(3);
    });

  const resendCode = () =>
    withBusy(async () => {
      await apiFetch('/api/auth/otp/resend', { method: 'POST', body: { email } });
      setCooldown(RESEND_COOLDOWN);
    });

  const verifyCode = () =>
    withBusy(async () => {
      await apiFetch('/api/auth/otp/verify', { method: 'POST', body: { email, otp } });
      setStep(4);
    });

  const createAccount = () =>
    withBusy(async () => {
      const user = await register({
        username: username.trim(),
        name: `${firstName.trim()} ${lastName.trim()}`.trim(),
        email,
        password,
        otp,
        phone: phone.trim() || undefined,
      });
      navigate('/welcome', { replace: true, state: { onboardingComplete: user.onboardingComplete } });
    });

  const strength = passwordStrength(password);
  const strengthColor = strength < 0.4 ? '#FF6B6B' : strength < 0.7 ? '#FFB347' : 'var(--auth-success)';

  return (
    <AuthScaffold compact showBackButton onBack={goBack}>
      <div style={{ marginBottom: 24 }}>
        <AuthStepProgress total={TOTAL_STEPS} current={step} />
      </div>

      {error && (
        <p style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--auth-error)', marginBottom: 12 }}>
          {error}
        </p>
      )}

      {step === 1 && (
        <StepBody title="What's your name?">
          <AuthPillInput icon={<Badge size={20} strokeWidth={1.75} />} placeholder="First name" value={firstName} onChange={(e) => setFirstName(e.target.value)} />
          <AuthPillInput icon={<Badge size={20} strokeWidth={1.75} />} placeholder="Last name" value={lastName} onChange={(e) => setLastName(e.target.value)} />
          <AuthPrimaryButton disabled={!firstName || !lastName} onClick={() => setStep(2)}>Continue</AuthPrimaryButton>
        </StepBody>
      )}

      {step === 2 && (
        <StepBody title="What's your email?" subtitle="We'll send you a verification code.">
          <AuthPillInput icon={<Mail size={20} strokeWidth={1.75} />} type="email" placeholder="Email" value={email} onChange={(e) => setEmail(e.target.value)} />
          <AuthPrimaryButton disabled={!email} loading={busy} onClick={sendCode}>Send code</AuthPrimaryButton>
        </StepBody>
      )}

      {step === 3 && (
        <StepBody title="Verify your email" subtitle={`We sent a 6-digit code to ${email || 'your email'}.`}>
          <AuthOtpInput value={otp} onChange={setOtp} />
          <div style={{ textAlign: 'center', fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--auth-text-dim)' }}>
            {cooldown > 0 ? (
              <span>Resend code in {String(Math.floor(cooldown / 60)).padStart(2, '0')}:{String(cooldown % 60).padStart(2, '0')}</span>
            ) : (
              <button onClick={resendCode} style={{ color: '#fff', fontWeight: 500 }}>Resend code</button>
            )}
          </div>
          <AuthPrimaryButton disabled={otp.length !== 6} loading={busy} onClick={verifyCode}>Verify</AuthPrimaryButton>
        </StepBody>
      )}

      {step === 4 && (
        <StepBody title="Choose a username">
          <AuthPillInput
            icon={<AtSign size={20} strokeWidth={1.75} />}
            placeholder="Username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
          />
          {usernameStatus && (
            <p
              style={{
                fontFamily: 'var(--font-inter)',
                fontSize: 12,
                color: usernameStatus === 'available' ? 'var(--auth-success)' : usernameStatus === 'taken' ? 'var(--auth-error)' : 'var(--auth-text-dim)',
                margin: '-6px 2px 0',
              }}
            >
              {usernameStatus === 'checking' && 'Checking availability…'}
              {usernameStatus === 'available' && 'Username is available'}
              {usernameStatus === 'taken' && (usernameMessage || 'That username is taken')}
            </p>
          )}
          <AuthPrimaryButton disabled={usernameStatus !== 'available'} onClick={() => setStep(5)}>Continue</AuthPrimaryButton>
        </StepBody>
      )}

      {step === 5 && (
        <StepBody title="Add your phone" subtitle="Optional — helps secure your account.">
          <AuthPillInput icon={<Phone size={20} strokeWidth={1.75} />} type="tel" placeholder="Phone number" value={phone} onChange={(e) => setPhone(e.target.value)} />
          <AuthPrimaryButton onClick={() => setStep(6)}>Continue</AuthPrimaryButton>
          <AuthGhostButton onClick={() => setStep(6)}>Skip for now</AuthGhostButton>
        </StepBody>
      )}

      {step === 6 && (
        <StepBody title="Create a password">
          <AuthPasswordInput icon={<Lock size={20} strokeWidth={1.75} />} placeholder="Password" value={password} onChange={(e) => setPassword(e.target.value)} />
          {password && (
            <div style={{ height: 3, borderRadius: 2, background: 'var(--auth-border)', overflow: 'hidden' }}>
              <div style={{ width: `${strength * 100}%`, height: '100%', background: strengthColor, transition: 'width 0.2s' }} />
            </div>
          )}
          <AuthPasswordInput icon={<Lock size={20} strokeWidth={1.75} />} placeholder="Confirm password" value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} />
          <AuthPrimaryButton
            disabled={!password || password.length < 8 || password !== confirmPassword}
            loading={busy}
            onClick={createAccount}
          >
            Create Account
          </AuthPrimaryButton>
        </StepBody>
      )}

      {step === 1 && (
        <div style={{ marginTop: 24 }}>
          <AuthLinkFooter prompt="Already have an account?" linkLabel="Sign in" to="/login" />
        </div>
      )}
    </AuthScaffold>
  );
}

function StepBody({ title, subtitle, children }) {
  return (
    <div>
      <AuthPageTitle title={title} subtitle={subtitle} />
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>{children}</div>
    </div>
  );
}
