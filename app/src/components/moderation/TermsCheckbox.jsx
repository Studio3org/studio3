import React from 'react';
import { TERMS_URL } from '../../lib/api';

/// Required Terms of Use (EULA) agreement — same wording as the iOS/Android
/// app's login and sign-up forms (App Store guideline 1.2).
export function TermsCheckbox({ checked, onChange }) {
  return (
    <label style={{ display: 'flex', gap: 10, alignItems: 'flex-start', fontSize: 12, lineHeight: 1.45, color: 'var(--slate-600)', cursor: 'pointer' }}>
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        style={{ marginTop: 2 }}
      />
      <span>
        I agree to the{' '}
        <a href={TERMS_URL} target="_blank" rel="noreferrer" style={{ fontWeight: 600, color: 'var(--slate-900)', textDecoration: 'underline' }}>
          Terms of Use (EULA)
        </a>
        . Studio3 has zero tolerance for objectionable content or abusive users.
      </span>
    </label>
  );
}
