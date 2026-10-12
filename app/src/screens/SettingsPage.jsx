import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ChevronLeft, ChevronRight, ExternalLink } from 'lucide-react';
import { TERMS_URL, logout, updateSessionUser } from '../lib/api';
import { useSession } from '../lib/session';
import { updateMe } from '../lib/profileApi';
import { friendlyError } from '../lib/social';
import { GuestPrompt } from '../components/common/StateMessage';

export const DANGER = '#E05252';

/// Shared chrome for the settings screens: back button, title, padded column.
export function SettingsScreen({ title, back = '/settings', children }) {
  const navigate = useNavigate();
  return (
    <div style={{ minHeight: '100vh', background: 'var(--white)', padding: '0 16px 48px' }}>
      <header style={{ display: 'flex', alignItems: 'center', gap: 8, height: 56 }}>
        <button
          type="button"
          aria-label="Back"
          onClick={() => navigate(back)}
          style={{ width: 36, height: 36, marginLeft: -8, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--slate-900)' }}
        >
          <ChevronLeft size={24} />
        </button>
        <h1 style={{ fontSize: 18, fontWeight: 600, color: 'var(--slate-900)' }}>{title}</h1>
      </header>
      {children}
    </div>
  );
}

export const sectionLabel = {
  fontSize: 12,
  fontWeight: 600,
  letterSpacing: 0.4,
  textTransform: 'uppercase',
  color: 'var(--slate-500)',
  margin: '20px 4px 8px',
};

export const fieldLabel = {
  display: 'block',
  fontSize: 13,
  fontWeight: 500,
  color: 'var(--slate-700)',
  margin: '14px 4px 6px',
};

const rowStyle = {
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  width: '100%',
  padding: '14px 4px',
  borderBottom: '1px solid var(--slate-100)',
  fontSize: 15,
  color: 'var(--slate-900)',
  textAlign: 'left',
  background: 'none',
};

function Row({ to, href, onClick, danger, children }) {
  const style = { ...rowStyle, color: danger ? DANGER : rowStyle.color };
  const chevron = href ? <ExternalLink size={16} color="var(--slate-400)" /> : <ChevronRight size={18} color="var(--slate-400)" />;
  if (to) return <Link to={to} style={style}>{children}{chevron}</Link>;
  if (href) return <a href={href} target="_blank" rel="noopener noreferrer" style={style}>{children}{chevron}</a>;
  return <button type="button" onClick={onClick} style={style}>{children}</button>;
}

/// Segmented choice for one privacy field; saves on tap.
function Choice({ label, value, options, onChange, disabled }) {
  return (
    <div style={{ padding: '12px 4px', borderBottom: '1px solid var(--slate-100)' }}>
      <div style={{ fontSize: 15, color: 'var(--slate-900)', marginBottom: 10 }}>{label}</div>
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
        {options.map(([v, text]) => {
          const active = v === value;
          return (
            <button
              key={v}
              type="button"
              disabled={disabled}
              onClick={() => !active && onChange(v)}
              aria-pressed={active}
              style={{
                padding: '7px 14px',
                borderRadius: 9999,
                border: `1.5px solid ${active ? 'var(--slate-900)' : 'var(--slate-200)'}`,
                background: active ? 'var(--slate-900)' : 'var(--white)',
                color: active ? 'var(--white)' : 'var(--slate-700)',
                fontSize: 13,
                fontWeight: 500,
                opacity: disabled ? 0.6 : 1,
              }}
            >
              {text}
            </button>
          );
        })}
      </div>
    </div>
  );
}

export function SettingsPage() {
  const navigate = useNavigate();
  const { loggedIn, user } = useSession();
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  if (!loggedIn) {
    return (
      <SettingsScreen title="Settings" back="/profile">
        <GuestPrompt title="Settings" message="Log in to manage your account." next="/settings" />
      </SettingsScreen>
    );
  }

  const savePrivacy = async (fields) => {
    setSaving(true);
    setError(null);
    try {
      const updated = await updateMe(fields);
      updateSessionUser(updated ?? fields);
    } catch (e) {
      setError(friendlyError(e));
    } finally {
      setSaving(false);
    }
  };

  const handleLogout = async () => {
    await logout();
    navigate('/home');
  };

  return (
    <SettingsScreen title="Settings" back="/profile">
      <div style={sectionLabel}>Account</div>
      <Row to="/settings/profile">Edit profile</Row>
      <Row to="/follow-requests">Follow requests</Row>
      <Row to="/settings/blocked">Blocked accounts</Row>
      <Row to="/settings/password">Change password</Row>

      <div style={sectionLabel}>Privacy</div>
      <Choice
        label="Profile visibility"
        value={user?.profileVisibility ?? 'public'}
        options={[['public', 'Public'], ['private', 'Private']]}
        disabled={saving}
        onChange={(v) => savePrivacy({ profileVisibility: v })}
      />
      <Choice
        label="Who can message you"
        value={user?.messagePermission ?? 'everyone'}
        options={[['everyone', 'Everyone'], ['following', 'People you follow'], ['no_one', 'No one']]}
        disabled={saving}
        onChange={(v) => savePrivacy({ messagePermission: v })}
      />
      {error && <p style={{ color: DANGER, fontSize: 13, margin: '8px 4px 0' }}>{error}</p>}

      <div style={sectionLabel}>About</div>
      <Row href={TERMS_URL}>Terms of Use</Row>

      <div style={sectionLabel}>Danger zone</div>
      <Row to="/settings/delete-account" danger>Delete account</Row>
      <Row onClick={handleLogout} danger>Log out</Row>
    </SettingsScreen>
  );
}
