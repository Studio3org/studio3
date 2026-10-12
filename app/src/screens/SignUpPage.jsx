import React, { useEffect, useRef, useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import { ChevronLeft } from 'lucide-react';
import { GlassCard } from '../components/design/GlassCard';
import { PillInput, PillInputWithToggle } from '../components/inputs/PillInput';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { PillChip } from '../components/inputs/PillChip';
import { TermsCheckbox } from '../components/moderation/TermsCheckbox';
import { useSession } from '../lib/session';
import { checkUsername, generateOtp, register, resendOtp, verifyOtp } from '../lib/authApi';
import { passwordProblem } from '../lib/validators';

const bgStyle = {
  minHeight: '100vh',
  background: 'linear-gradient(180deg, var(--slate-50) 0%, var(--slate-100) 50%, var(--slate-200) 100%)',
  paddingTop: 44,
  paddingBottom: 24,
  paddingLeft: 16,
  paddingRight: 16,
};

const STEPS = ['name', 'email', 'otp', 'username', 'phone', 'password'];
const RESEND_COOLDOWN_SECONDS = 120;
const EMAIL_RE = /^[\w.-]+@([\w-]+\.)+[\w-]{2,}$/;
const USERNAME_RE = /^[a-zA-Z0-9_.]+$/;

/// Same client-side rules as the app's AuthValidators; the backend has the final say.
function usernameError(v) {
  const u = v.trim();
  if (!u) return 'Username is required';
  if (u.length < 3) return 'At least 3 characters';
  if (!USERNAME_RE.test(u)) return 'Letters, numbers, _ and . only';
  return null;
}

const errorText = { fontSize: 13, color: '#E05252' };
const hintText = { fontSize: 12, color: 'var(--slate-500)' };

const skipButton = {
  height: 52,
  borderRadius: 9999,
  border: '1.5px solid var(--slate-300)',
  background: 'transparent',
  color: 'var(--slate-600)',
  fontSize: 15,
  fontWeight: 500,
  width: '100%',
};

function StepHeader({ title, subtitle }) {
  return (
    <div style={{ marginBottom: 4 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, color: 'var(--slate-900)', marginBottom: 4 }}>{title}</h2>
      {subtitle && <p style={{ fontSize: 13, color: 'var(--slate-500)', lineHeight: 1.4 }}>{subtitle}</p>}
    </div>
  );
}

export function SignUpPage() {
  const navigate = useNavigate();
  const { loggedIn, user } = useSession();
  const [step, setStep] = useState('name');
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [agreedToTerms, setAgreedToTerms] = useState(false);
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [username, setUsername] = useState('');
  const [usernameCheck, setUsernameCheck] = useState(null); // {available, message, suggestions} | 'checking' | null
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [notice, setNotice] = useState(null);
  const [cooldown, setCooldown] = useState(0);
  const checkSeq = useRef(0);

  // Resend cooldown ticker.
  useEffect(() => {
    if (cooldown <= 0) return undefined;
    const t = setTimeout(() => setCooldown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [cooldown]);

  /// Debounced live availability check. A sequence number drops responses
  /// that arrive after the user has kept typing.
  useEffect(() => {
    if (step !== 'username') return undefined;
    const seq = ++checkSeq.current;
    if (usernameError(username)) {
      setUsernameCheck(null);
      return undefined;
    }
    setUsernameCheck('checking');
    const t = setTimeout(async () => {
      try {
        const result = await checkUsername(username);
        if (seq === checkSeq.current) setUsernameCheck(result);
      } catch {
        if (seq === checkSeq.current) setUsernameCheck(null);
      }
    }, 450);
    return () => clearTimeout(t);
  }, [username, step]);

  // Already signed in (e.g. a stale /signup tab) — nothing to do here.
  if (loggedIn) {
    return <Navigate to={user?.onboardingComplete === false ? '/onboarding' : '/home'} replace />;
  }

  const go = (next) => {
    setError(null);
    setNotice(null);
    setStep(next);
  };

  const goBack = () => {
    const i = STEPS.indexOf(step);
    if (i <= 0) navigate(-1);
    else go(STEPS[i - 1]);
  };

  /// Run an async step action with shared loading/error handling.
  const run = async (fn) => {
    if (loading) return;
    setLoading(true);
    setError(null);
    try {
      await fn();
    } catch (e) {
      setError(e.message || 'Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  const nameValid = firstName.trim() && lastName.trim();
  const emailValid = EMAIL_RE.test(email.trim());
  const usernameValid = !usernameError(username) && usernameCheck !== 'checking'
    && usernameCheck?.available !== false;
  const phoneDigits = phone.replace(/\D/g, '');
  const passwordError = password ? passwordProblem(password) : null;
  const confirmError = confirm && confirm !== password ? 'Passwords do not match' : null;
  const passwordValid = !passwordProblem(password) && confirm === password;

  const sendCode = () => run(async () => {
    await generateOtp(email);
    setOtp('');
    setCooldown(RESEND_COOLDOWN_SECONDS);
    go('otp');
    setNotice('Verification code sent to your email');
  });

  const resend = () => run(async () => {
    await resendOtp(email);
    setOtp('');
    setCooldown(RESEND_COOLDOWN_SECONDS);
    setNotice('Verification code resent');
  });

  const verify = () => run(async () => {
    if (otp.length !== 6) throw new Error('Enter the 6-digit code');
    await verifyOtp(email, otp);
    go('username');
  });

  /// Re-check on submit — the live check may be stale or still in flight.
  const confirmUsername = () => run(async () => {
    const result = await checkUsername(username);
    if (!result.available) {
      setUsernameCheck(result);
      return;
    }
    go('phone');
  });

  const continuePhone = (skip) => {
    if (skip) setPhone('');
    else if (phone.trim() && phoneDigits.length < 10) {
      setError('Enter a valid phone number');
      return;
    }
    go('password');
  };

  const createAccount = () => run(async () => {
    await register({
      username,
      name: `${firstName.trim()} ${lastName.trim()}`,
      email,
      password,
      otp,
      phone,
    });
    navigate('/onboarding', { replace: true });
  });

  const onEnter = (action, enabled) => (e) => {
    if (e.key === 'Enter' && enabled) action();
  };

  const stepIndex = STEPS.indexOf(step);
  const checking = usernameCheck === 'checking';

  return (
    <div style={bgStyle}>
      <div style={{ textAlign: 'center', marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, color: 'var(--slate-900)' }}>Studio 3</h1>
        <p style={{ fontSize: 13, color: 'var(--slate-400)', marginTop: 4 }}>Discover Art. Collect Stories.</p>
      </div>

      <GlassCard style={{ width: '100%', maxWidth: 343, padding: 28, margin: '0 auto' }}>
        <div style={{ position: 'relative', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 8, marginBottom: 24, minHeight: 24 }}>
          <button
            type="button"
            onClick={goBack}
            aria-label="Back"
            style={{ position: 'absolute', left: -8, color: 'var(--slate-600)', padding: 4, display: 'flex' }}
          >
            <ChevronLeft size={22} />
          </button>
          {STEPS.map((s, i) => (
            <div
              key={s}
              style={{
                width: 8,
                height: 8,
                borderRadius: '50%',
                background: i <= stepIndex ? 'var(--slate-900)' : 'var(--slate-300)',
              }}
            />
          ))}
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {step === 'name' && (
            <>
              <StepHeader title="Your name" subtitle="How should we address you?" />
              <PillInput placeholder="First name" autoComplete="given-name" value={firstName} onChange={(e) => setFirstName(e.target.value)} />
              <PillInput placeholder="Last name" autoComplete="family-name" value={lastName} onChange={(e) => setLastName(e.target.value)} />
              <TermsCheckbox checked={agreedToTerms} onChange={setAgreedToTerms} />
              <PrimaryButton disabled={!nameValid || !agreedToTerms} onClick={() => go('email')}>
                Continue
              </PrimaryButton>
            </>
          )}

          {step === 'email' && (
            <>
              <StepHeader title="Your email" subtitle="We'll send a verification code" />
              <PillInput
                type="email"
                placeholder="Email address"
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                onKeyDown={onEnter(sendCode, emailValid && !loading)}
              />
              {error && <div style={errorText} role="alert">{error}</div>}
              <PrimaryButton disabled={!emailValid || loading} onClick={sendCode}>
                {loading ? 'Sending…' : 'Send code'}
              </PrimaryButton>
            </>
          )}

          {step === 'otp' && (
            <>
              <StepHeader title="Verify email" subtitle={`Enter the 6-digit code sent to ${email.trim()}`} />
              <PillInput
                inputMode="numeric"
                autoComplete="one-time-code"
                placeholder="6-digit code"
                maxLength={6}
                value={otp}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                onKeyDown={onEnter(verify, otp.length === 6 && !loading)}
              />
              {notice && !error && <div style={hintText}>{notice}</div>}
              {error && <div style={errorText} role="alert">{error}</div>}
              <PrimaryButton disabled={otp.length !== 6 || loading} onClick={verify}>
                {loading ? 'Verifying…' : 'Verify'}
              </PrimaryButton>
              <div style={{ textAlign: 'center', fontSize: 13 }}>
                <button
                  type="button"
                  onClick={resend}
                  disabled={cooldown > 0 || loading}
                  style={{
                    color: cooldown > 0 ? 'var(--slate-400)' : 'var(--slate-900)',
                    fontWeight: 600,
                    cursor: cooldown > 0 ? 'default' : 'pointer',
                  }}
                >
                  Resend code
                </button>
                {cooldown > 0 && (
                  <span style={{ color: 'var(--slate-400)', marginLeft: 6 }}>
                    ({Math.floor(cooldown / 60)}:{String(cooldown % 60).padStart(2, '0')})
                  </span>
                )}
              </div>
            </>
          )}

          {step === 'username' && (
            <>
              <StepHeader title="Pick a username" subtitle="This is how others will find you" />
              <PillInput
                placeholder="Username"
                autoComplete="username"
                autoCapitalize="none"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                onKeyDown={onEnter(confirmUsername, usernameValid && !loading)}
              />
              {username && usernameError(username) && <div style={errorText}>{usernameError(username)}</div>}
              {checking && <div style={hintText}>Checking availability…</div>}
              {usernameCheck && !checking && (
                <div style={{ fontSize: 13, color: usernameCheck.available ? '#2E9E5B' : '#E05252' }}>
                  {usernameCheck.message || (usernameCheck.available ? 'Username is available' : 'Username is taken')}
                </div>
              )}
              {usernameCheck && !checking && !usernameCheck.available && usernameCheck.suggestions.length > 0 && (
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                  {usernameCheck.suggestions.map((s) => (
                    <PillChip key={s} onClick={() => setUsername(s)}>{s}</PillChip>
                  ))}
                </div>
              )}
              {error && <div style={errorText} role="alert">{error}</div>}
              <PrimaryButton disabled={!usernameValid || loading} onClick={confirmUsername}>
                {loading ? 'Checking…' : 'Continue'}
              </PrimaryButton>
            </>
          )}

          {step === 'phone' && (
            <>
              <StepHeader title="Phone number" subtitle="Optional — for account recovery" />
              <PillInput
                type="tel"
                placeholder="Phone number (optional)"
                autoComplete="tel"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                onKeyDown={onEnter(() => continuePhone(false), true)}
              />
              {error && <div style={errorText} role="alert">{error}</div>}
              <PrimaryButton onClick={() => continuePhone(false)}>Continue</PrimaryButton>
              <button type="button" style={skipButton} onClick={() => continuePhone(true)}>
                Skip for now
              </button>
            </>
          )}

          {step === 'password' && (
            <>
              <StepHeader title="Set password" subtitle="8+ characters, with an uppercase letter and a number" />
              <PillInputWithToggle
                placeholder="Password"
                autoComplete="new-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              {passwordError && <div style={errorText}>{passwordError}</div>}
              <PillInputWithToggle
                placeholder="Confirm password"
                autoComplete="new-password"
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                onKeyDown={onEnter(createAccount, passwordValid && !loading)}
              />
              {confirmError && <div style={errorText}>{confirmError}</div>}
              {error && <div style={errorText} role="alert">{error}</div>}
              <PrimaryButton disabled={!passwordValid || loading} onClick={createAccount}>
                {loading ? 'Creating account…' : 'Create Account'}
              </PrimaryButton>
            </>
          )}
        </div>
      </GlassCard>

      <p style={{ marginTop: 24, fontSize: 14, color: 'var(--slate-600)', textAlign: 'center' }}>
        Already have an account? <Link to="/login" style={{ fontWeight: 600 }}>Sign In</Link>
      </p>
    </div>
  );
}
