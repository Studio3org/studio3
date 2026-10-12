import React, { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Camera } from 'lucide-react';
import { updateSessionUser } from '../lib/api';
import { useSession } from '../lib/session';
import { getMe, updateMe } from '../lib/profileApi';
import { uploadImage } from '../lib/uploadImage';
import { friendlyError } from '../lib/social';
import { PillInput } from '../components/inputs/PillInput';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { Avatar } from '../components/common/Avatar';
import { GuestPrompt } from '../components/common/StateMessage';
import { DANGER, SettingsScreen, fieldLabel } from './SettingsPage';

const BIO_MAX = 250;
const TEXT_FIELDS = [
  ['name', 'Name', 'Your name'],
  ['location', 'Location', 'City, country'],
  ['pronouns', 'Pronouns', 'e.g. she/her'],
  ['website', 'Website', 'https://'],
  ['instagram', 'Instagram', 'username'],
  ['twitter', 'X / Twitter', 'username'],
];
const EDITABLE = ['name', 'bio', 'location', 'pronouns', 'website', 'instagram', 'twitter'];

function formFrom(user) {
  return Object.fromEntries(EDITABLE.map((k) => [k, user?.[k] ?? '']));
}

const photoButton = {
  position: 'absolute',
  width: 32,
  height: 32,
  borderRadius: '50%',
  background: 'rgba(15, 23, 42, 0.65)',
  color: 'var(--white)',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
};

export function EditProfilePage() {
  const navigate = useNavigate();
  const { loggedIn, user } = useSession();
  const [base, setBase] = useState(user);
  const [form, setForm] = useState(() => formFrom(user));
  const [photos, setPhotos] = useState({ profilePhotoUrl: user?.profilePhotoUrl ?? null, coverPhotoUrl: user?.coverPhotoUrl ?? null });
  const [uploading, setUploading] = useState(null); // 'profile' | 'cover' | null
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const avatarInput = useRef(null);
  const coverInput = useRef(null);
  const touched = useRef(false);

  // The stored session user can be stale; refresh the form unless they've started typing.
  useEffect(() => {
    if (!loggedIn) return;
    getMe()
      .then((me) => {
        if (!me) return;
        updateSessionUser(me);
        setBase(me);
        if (!touched.current) {
          setForm(formFrom(me));
          setPhotos({ profilePhotoUrl: me.profilePhotoUrl ?? null, coverPhotoUrl: me.coverPhotoUrl ?? null });
        }
      })
      .catch(() => {});
  }, [loggedIn]);

  if (!loggedIn) {
    return (
      <SettingsScreen title="Edit profile">
        <GuestPrompt title="Edit profile" message="Log in to edit your profile." next="/settings/profile" />
      </SettingsScreen>
    );
  }

  const setField = (key) => (e) => {
    touched.current = true;
    setForm((f) => ({ ...f, [key]: e.target.value }));
  };

  const pickPhoto = async (e, purpose) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    touched.current = true;
    setUploading(purpose);
    setError(null);
    try {
      const url = await uploadImage(file, purpose);
      setPhotos((p) => ({ ...p, [purpose === 'profile' ? 'profilePhotoUrl' : 'coverPhotoUrl']: url }));
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setUploading(null);
    }
  };

  const save = async (e) => {
    e.preventDefault();
    if (saving || uploading) return;
    if (!form.name.trim()) {
      setError('Name is required.');
      return;
    }
    // Only send what changed, so untouched optional fields aren't re-validated.
    const changes = {};
    EDITABLE.forEach((k) => {
      const v = form[k].trim();
      if (v !== (base?.[k] ?? '')) changes[k] = v;
    });
    ['profilePhotoUrl', 'coverPhotoUrl'].forEach((k) => {
      if (photos[k] && photos[k] !== base?.[k]) changes[k] = photos[k];
    });
    if (Object.keys(changes).length === 0) {
      navigate('/profile');
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const updated = await updateMe(changes);
      updateSessionUser(updated ?? changes);
      navigate('/profile');
    } catch (err) {
      setError(friendlyError(err));
      setSaving(false);
    }
  };

  return (
    <SettingsScreen title="Edit profile">
      <form onSubmit={save}>
        <div style={{ position: 'relative', marginBottom: 52 }}>
          <div
            style={{
              height: 140,
              borderRadius: 16,
              overflow: 'hidden',
              background: photos.coverPhotoUrl ? 'var(--slate-100)' : 'linear-gradient(160deg, #d9d4cc 0%, #e8e3dc 55%, #f0ece6 100%)',
            }}
          >
            {photos.coverPhotoUrl && (
              <img src={photos.coverPhotoUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
            )}
          </div>
          <button
            type="button"
            aria-label="Change cover photo"
            onClick={() => coverInput.current?.click()}
            disabled={Boolean(uploading)}
            style={{ ...photoButton, right: 10, top: 10 }}
          >
            <Camera size={16} />
          </button>
          {uploading === 'cover' && (
            <span style={{ position: 'absolute', left: 12, top: 14, fontSize: 12, color: 'var(--white)', textShadow: '0 1px 2px rgba(0,0,0,0.5)' }}>
              Uploading…
            </span>
          )}

          <div style={{ position: 'absolute', left: '50%', bottom: -44, transform: 'translateX(-50%)' }}>
            <Avatar src={photos.profilePhotoUrl} name={form.name} size={88} style={{ border: '3px solid var(--white)' }} />
            <button
              type="button"
              aria-label="Change profile photo"
              onClick={() => avatarInput.current?.click()}
              disabled={Boolean(uploading)}
              style={{ ...photoButton, right: -4, bottom: -2 }}
            >
              <Camera size={16} />
            </button>
          </div>
          <input ref={coverInput} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={(e) => pickPhoto(e, 'cover')} />
          <input ref={avatarInput} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={(e) => pickPhoto(e, 'profile')} />
        </div>
        {uploading === 'profile' && (
          <p style={{ textAlign: 'center', fontSize: 12, color: 'var(--slate-500)' }}>Uploading photo…</p>
        )}

        {TEXT_FIELDS.slice(0, 1).map(([key, label, placeholder]) => (
          <div key={key}>
            <label style={fieldLabel} htmlFor={`ep-${key}`}>{label}</label>
            <PillInput id={`ep-${key}`} value={form[key]} onChange={setField(key)} placeholder={placeholder} maxLength={100} />
          </div>
        ))}

        <label style={fieldLabel} htmlFor="ep-bio">Bio</label>
        <textarea
          id="ep-bio"
          value={form.bio}
          onChange={setField('bio')}
          maxLength={BIO_MAX}
          rows={4}
          placeholder="Tell people about your work"
          style={{
            width: '100%',
            boxSizing: 'border-box',
            padding: '14px 20px',
            borderRadius: 20,
            border: '1.5px solid var(--slate-200)',
            fontSize: 15,
            fontFamily: 'inherit',
            color: 'var(--slate-700)',
            resize: 'vertical',
            outline: 'none',
          }}
        />
        <div style={{ textAlign: 'right', fontSize: 12, color: 'var(--slate-400)', margin: '4px 6px 0' }}>
          {form.bio.length}/{BIO_MAX}
        </div>

        {TEXT_FIELDS.slice(1).map(([key, label, placeholder]) => (
          <div key={key}>
            <label style={fieldLabel} htmlFor={`ep-${key}`}>{label}</label>
            <PillInput id={`ep-${key}`} value={form[key]} onChange={setField(key)} placeholder={placeholder} maxLength={200} />
          </div>
        ))}

        {error && <p style={{ color: DANGER, fontSize: 13, margin: '12px 4px 0' }}>{error}</p>}
        <PrimaryButton type="submit" disabled={saving || Boolean(uploading)} style={{ marginTop: 24 }}>
          {saving ? 'Saving…' : 'Save'}
        </PrimaryButton>
      </form>
    </SettingsScreen>
  );
}
