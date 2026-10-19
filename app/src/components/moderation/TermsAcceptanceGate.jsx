import React, { useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { API_BASE_URL, apiFetch } from '../../services/apiClient';
import { ActionSheet } from '../common/ActionSheet';

const TERMS_URL = `${API_BASE_URL}/terms`;

/// Blocking prompt for a signed-in account that hasn't agreed to the current Terms of Use
/// (EULA) — accounts created before the terms existed, or after they change. Same rule as
/// the app (App Store guideline 1.2): agree, or log out.
export function TermsAcceptanceGate() {
  const { user, setUser, logout } = useAuth();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  const needsTerms = user?.currentTermsVersion && user.termsVersion !== user.currentTermsVersion;
  if (!needsTerms) return null;

  const agree = async () => {
    setBusy(true);
    setError(null);
    try {
      const me = await apiFetch('/api/user/me/accept-terms', { method: 'POST', auth: true });
      setUser((prev) => ({ ...(prev ?? {}), ...(me ?? {}) }));
    } catch (e) {
      setError(e?.message || 'Could not save that — please try again.');
      setBusy(false);
    }
  };

  return (
    <ActionSheet title="Terms of Use" onClose={() => {}}>
      <p className="s3-sheet-subtitle" style={{ fontSize: 14 }}>
        To keep using your Studio3 account, please review and agree to our{' '}
        <a href={TERMS_URL} target="_blank" rel="noreferrer" style={{ fontWeight: 600, textDecoration: 'underline' }}>
          Terms of Use (EULA)
        </a>
        . Studio3 has zero tolerance for objectionable content or abusive users — violating
        content is removed and the accounts behind it are ejected.
      </p>
      {error && <p className="s3-sheet-error">{error}</p>}
      <div className="s3-sheet-actions">
        <button type="button" className="s3-sheet-btn s3-sheet-btn--primary" disabled={busy} onClick={agree}>
          {busy ? 'Saving…' : 'I agree'}
        </button>
        <button type="button" className="s3-sheet-btn s3-sheet-btn--ghost" disabled={busy} onClick={() => logout()}>
          Log out
        </button>
      </div>
    </ActionSheet>
  );
}
