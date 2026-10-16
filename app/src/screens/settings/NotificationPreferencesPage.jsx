import React, { useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { friendlyError } from '../../services/socialApi';
import { updateNotificationPreferences } from '../../services/profileApi';
import { SettingsLayout } from './SettingsLayout';

/** Mirrors the backend's DEFAULT_NOTIFICATION_PREFERENCES (used when the user has none stored). */
const DEFAULTS = {
  push: { follow: true, like: true, save: true, comment: true, inquiry: true, message: true, purchase: true },
  dailyDigest: { enabled: false, time: '09:00' },
};

const PUSH_ROWS = [
  ['follow', 'New followers', 'When someone follows you or requests to.'],
  ['like', 'Likes', 'When someone likes your piece or scene.'],
  ['save', 'Saves', 'When someone saves your work.'],
  ['comment', 'Comments', 'When someone comments on your work.'],
  ['inquiry', 'Inquiries', 'When a collector asks about a piece.'],
  ['message', 'Messages', 'New chat messages and message requests.'],
  ['purchase', 'Purchases', 'When one of your pieces sells.'],
];

function merge(stored) {
  return {
    push: { ...DEFAULTS.push, ...(stored?.push || {}) },
    dailyDigest: { ...DEFAULTS.dailyDigest, ...(stored?.dailyDigest || {}) },
  };
}

function Toggle({ checked, disabled, onChange, label }) {
  return (
    <label className="settings-switch" onClick={(e) => e.stopPropagation()}>
      <input
        type="checkbox"
        aria-label={label}
        checked={checked}
        disabled={disabled}
        onChange={(e) => onChange(e.target.checked)}
      />
      <span className="settings-slider" />
    </label>
  );
}

/// Which push notifications the app sends, plus the daily digest. Each change is saved on its
/// own (the backend deep-merges partial updates).
export function NotificationPreferencesPage() {
  const { user, setUser } = useAuth();
  const [prefs, setPrefs] = useState(() => merge(user?.notificationPreferences));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  const save = async (patch, nextPrefs) => {
    const previous = prefs;
    setPrefs(nextPrefs);
    setSaving(true);
    setError(null);
    try {
      const res = await updateNotificationPreferences(patch);
      const stored = res?.notificationPreferences;
      if (stored) {
        setPrefs(merge(stored));
        if (user) setUser({ ...user, notificationPreferences: stored });
      }
    } catch (e) {
      setPrefs(previous);
      setError(friendlyError(e));
    } finally {
      setSaving(false);
    }
  };

  const setPush = (key, value) =>
    save({ push: { [key]: value } }, { ...prefs, push: { ...prefs.push, [key]: value } });

  const setDigest = (patch) =>
    save({ dailyDigest: patch }, { ...prefs, dailyDigest: { ...prefs.dailyDigest, ...patch } });

  return (
    <SettingsLayout
      title="Notification preferences"
      subtitle="Push notifications are delivered to the Studio3 app on your phone. Your inbox on the web always shows everything."
    >
      <div className="settings-section">
        <h2 className="settings-section-title">Push notifications</h2>
        {PUSH_ROWS.map(([key, label, sub]) => (
          <div key={key} className="settings-card is-static">
            <div className="settings-card-text">
              <span className="settings-card-label">{label}</span>
              <span className="settings-card-sub">{sub}</span>
            </div>
            <Toggle
              label={label}
              checked={Boolean(prefs.push[key])}
              disabled={saving}
              onChange={(v) => setPush(key, v)}
            />
          </div>
        ))}
      </div>

      <div className="settings-section">
        <h2 className="settings-section-title">Daily digest</h2>
        <div className="settings-card is-static">
          <div className="settings-card-text">
            <span className="settings-card-label">Daily digest</span>
            <span className="settings-card-sub">One summary of your day&apos;s activity.</span>
          </div>
          <Toggle
            label="Daily digest"
            checked={Boolean(prefs.dailyDigest.enabled)}
            disabled={saving}
            onChange={(v) => setDigest({ enabled: v })}
          />
        </div>
        {prefs.dailyDigest.enabled && (
          <div className="settings-card is-static">
            <div className="settings-card-text">
              <span className="settings-card-label">Delivery time</span>
            </div>
            <input
              type="time"
              className="settings-modal-input settings-time-input"
              value={prefs.dailyDigest.time || '09:00'}
              disabled={saving}
              onChange={(e) => e.target.value && setDigest({ time: e.target.value })}
            />
          </div>
        )}
      </div>

      {error && <p className="settings-error">{error}</p>}
    </SettingsLayout>
  );
}
