import React, { useState } from 'react';
import { TERMS_URL, apiFetch, logout, updateSessionUser } from '../../lib/api';
import { useSession } from '../../lib/session';

/// Blocking prompt for a signed-in account that hasn't agreed to the current
/// Terms of Use (EULA) — accounts created before the terms existed, or after
/// they change. Same rule as the app: agree, or log out.
export function TermsAcceptanceGate() {
  const { user } = useSession();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  const needsTerms =
    user?.currentTermsVersion && user.termsVersion !== user.currentTermsVersion;
  if (!needsTerms) return null;

  const agree = async () => {
    setBusy(true);
    setError(null);
    try {
      const me = await apiFetch('/api/user/me/accept-terms', { method: 'POST', auth: true });
      updateSessionUser(me);
    } catch (e) {
      setError(e.message);
      setBusy(false);
    }
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="terms-gate-title"
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 300,
        background: 'rgba(15, 23, 42, 0.55)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 16,
      }}
    >
      <div style={{ width: '100%', maxWidth: 360, background: 'var(--white)', borderRadius: 20, padding: 24 }}>
        <h2 id="terms-gate-title" style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>
          Terms of Use
        </h2>
        <p style={{ fontSize: 14, lineHeight: 1.5, color: 'var(--slate-600)', marginBottom: 16 }}>
          To keep using your Studio3 account, please review and agree to our{' '}
          <a href={TERMS_URL} target="_blank" rel="noreferrer" style={{ fontWeight: 600, textDecoration: 'underline' }}>
            Terms of Use (EULA)
          </a>
          . Studio3 has zero tolerance for objectionable content or abusive users — violating
          content is removed and the accounts behind it are ejected.
        </p>
        {error && <p style={{ fontSize: 13, color: '#E05252', marginBottom: 10 }}>{error}</p>}
        <button
          type="button"
          onClick={agree}
          disabled={busy}
          style={{ width: '100%', height: 48, borderRadius: 14, background: 'var(--slate-900)', color: 'var(--white)', fontSize: 15, fontWeight: 600 }}
        >
          {busy ? 'Saving…' : 'I agree'}
        </button>
        <button
          type="button"
          onClick={() => logout()}
          disabled={busy}
          style={{ width: '100%', height: 44, marginTop: 8, color: 'var(--slate-500)', fontSize: 14 }}
        >
          Log out
        </button>
      </div>
    </div>
  );
}
