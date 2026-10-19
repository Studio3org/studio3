import React, { useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { friendlyError } from '../../services/socialApi';
import { confirmEmailChange, requestEmailChange } from '../../services/profileApi';
import { SettingsLayout } from './SettingsLayout';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/// Two steps, like the app: send a 6-digit code to the new address, then confirm with it.
/// The account's email only changes once the code is verified.
export function ChangeEmailPage() {
  const { user, refreshUser } = useAuth();
  const [step, setStep] = useState('email'); // email | code | done
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [notice, setNotice] = useState(null);

  const trimmed = email.trim().toLowerCase();
  const validEmail = EMAIL_RE.test(trimmed);
  const sameAsCurrent = Boolean(user?.email) && trimmed === user.email.toLowerCase();

  const sendCode = async (e) => {
    e?.preventDefault();
    if (!validEmail || sameAsCurrent || busy) return;
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      await requestEmailChange(trimmed);
      setStep('code');
      setNotice(`We sent a 6-digit code to ${trimmed}.`);
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setBusy(false);
    }
  };

  const confirm = async (e) => {
    e.preventDefault();
    if (otp.length !== 6 || busy) return;
    setBusy(true);
    setError(null);
    try {
      await confirmEmailChange(trimmed, otp);
      await refreshUser().catch(() => {});
      setStep('done');
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <SettingsLayout
      title="Change email"
      subtitle={user?.email ? `Your current email is ${user.email}.` : undefined}
    >
      {step === 'email' && (
        <form className="settings-form" onSubmit={sendCode}>
          <label className="settings-modal-label" htmlFor="new-email">New email</label>
          <input
            id="new-email"
            type="email"
            className="settings-modal-input"
            autoComplete="email"
            placeholder="you@example.com"
            value={email}
            disabled={busy}
            onChange={(e) => setEmail(e.target.value)}
          />
          {sameAsCurrent && <p className="settings-error">That&apos;s already your email.</p>}
          {error && <p className="settings-error">{error}</p>}
          <div className="settings-form-actions">
            <button type="submit" className="settings-primary-btn" disabled={!validEmail || sameAsCurrent || busy}>
              {busy ? 'Sending…' : 'Send code'}
            </button>
          </div>
        </form>
      )}

      {step === 'code' && (
        <form className="settings-form" onSubmit={confirm}>
          {notice && <p className="settings-hint">{notice}</p>}
          <label className="settings-modal-label" htmlFor="email-otp">Verification code</label>
          <input
            id="email-otp"
            className="settings-modal-input"
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={6}
            placeholder="123456"
            value={otp}
            disabled={busy}
            onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
          />
          {error && <p className="settings-error">{error}</p>}
          <div className="settings-form-actions">
            <button
              type="button"
              className="settings-secondary-btn"
              disabled={busy}
              onClick={() => {
                setStep('email');
                setOtp('');
                setError(null);
              }}
            >
              Change address
            </button>
            <button type="button" className="settings-secondary-btn" disabled={busy} onClick={sendCode}>
              Resend code
            </button>
            <button type="submit" className="settings-primary-btn" disabled={otp.length !== 6 || busy}>
              {busy ? 'Verifying…' : 'Confirm'}
            </button>
          </div>
        </form>
      )}

      {step === 'done' && (
        <div className="settings-form">
          <p className="settings-success" style={{ margin: 0 }}>
            Your email is now {trimmed}. Use it the next time you log in.
          </p>
        </div>
      )}
    </SettingsLayout>
  );
}
