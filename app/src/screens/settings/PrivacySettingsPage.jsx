import React, { useEffect, useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { friendlyError } from '../../services/socialApi';
import { getMe, updatePrivacy } from '../../services/profileApi';
import { SettingsLayout, SettingsSpinner } from './SettingsLayout';

const VISIBILITY = [
  ['public', 'Public', 'Anyone can see your pieces, scenes and series.'],
  ['private', 'Private', 'Only approved followers see your content. New followers send a request.'],
];

const MESSAGING = [
  ['everyone', 'Everyone', 'Anyone on Studio3 can message you.'],
  ['following', 'People you follow', 'Only accounts you follow can start a conversation.'],
  ['no_one', 'No one', 'Nobody can start a new conversation with you.'],
];

function OptionGroup({ title, options, value, disabled, onChange }) {
  const pick = (key) => !disabled && value !== key && onChange(key);
  return (
    <div className="settings-section" role="radiogroup" aria-label={title}>
      <h2 className="settings-section-title">{title}</h2>
      {options.map(([key, label, sub]) => (
        <div
          key={key}
          role="radio"
          aria-checked={value === key}
          tabIndex={0}
          className={`settings-card${value === key ? ' is-selected' : ''}`}
          onClick={() => pick(key)}
          onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && pick(key)}
        >
          <div className="settings-card-text">
            <span className="settings-card-label">{label}</span>
            <span className="settings-card-sub">{sub}</span>
          </div>
          <span className="settings-radio" aria-hidden />
        </div>
      ))}
    </div>
  );
}

/// Profile visibility + who can message you — PATCH /api/user/me, saved on tap.
export function PrivacySettingsPage() {
  const { setUser } = useAuth();
  const [prefs, setPrefs] = useState(null);
  const [loadError, setLoadError] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    let cancelled = false;
    getMe()
      .then((me) => {
        if (cancelled) return;
        setPrefs({
          profileVisibility: me?.profileVisibility || 'public',
          messagePermission: me?.messagePermission || 'everyone',
        });
      })
      .catch((e) => !cancelled && setLoadError(friendlyError(e)));
    return () => {
      cancelled = true;
    };
  }, []);

  const save = async (field, value) => {
    const previous = prefs;
    setPrefs({ ...prefs, [field]: value });
    setSaving(true);
    setError(null);
    setSaved(false);
    try {
      const me = await updatePrivacy({ [field]: value });
      if (me?.username) setUser(me);
      setSaved(true);
    } catch (e) {
      setPrefs(previous);
      setError(friendlyError(e));
    } finally {
      setSaving(false);
    }
  };

  return (
    <SettingsLayout title="Profile visibility & messaging">
      {!prefs && !loadError && <SettingsSpinner />}
      {loadError && (
        <div className="settings-empty">
          <p className="settings-empty-title">Couldn&apos;t load your settings</p>
          <p className="settings-empty-sub">{loadError}</p>
        </div>
      )}
      {prefs && (
        <>
          <OptionGroup
            title="Profile visibility"
            options={VISIBILITY}
            value={prefs.profileVisibility}
            disabled={saving}
            onChange={(v) => save('profileVisibility', v)}
          />
          <OptionGroup
            title="Who can message you"
            options={MESSAGING}
            value={prefs.messagePermission}
            disabled={saving}
            onChange={(v) => save('messagePermission', v)}
          />
          {error && <p className="settings-error">{error}</p>}
          {saved && !error && <p className="settings-success">Saved</p>}
        </>
      )}
    </SettingsLayout>
  );
}
