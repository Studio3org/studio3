import React, { useEffect, useRef, useState } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';
import { Camera, ChevronLeft } from 'lucide-react';
import { GlassCard } from '../components/design/GlassCard';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { PillChip } from '../components/inputs/PillChip';
import { useSession } from '../lib/session';
import {
  completeOnboarding,
  setOnboardingPhotos,
  setOnboardingPreferences,
  setRole,
  uploadProfilePhoto,
} from '../lib/authApi';

const bgStyle = {
  minHeight: '100vh',
  background: 'linear-gradient(180deg, var(--slate-50) 0%, var(--slate-100) 50%, var(--slate-200) 100%)',
  paddingTop: 44,
  paddingBottom: 24,
  paddingLeft: 16,
  paddingRight: 16,
};

const ROLES = [
  { id: 'artist', title: 'Artist', subtitle: 'Create and share your work' },
  { id: 'collector', title: 'Collector', subtitle: 'Discover and collect art' },
  { id: 'enthusiast', title: 'Enthusiast', subtitle: 'Explore and engage with art' },
];

/// Mediums and styles are stored by id (same option lists as the app's
/// post_picker_options.dart); themes are stored by label, like the app.
const MEDIUMS = [
  ['acrylic', 'Acrylic'], ['encaustic', 'Encaustic'], ['fresco', 'Fresco'], ['gouache', 'Gouache'],
  ['oil', 'Oil'], ['tempera', 'Tempera'], ['watercolor', 'Watercolor'], ['ink', 'Ink'],
  ['charcoal', 'Charcoal'], ['pastel', 'Pastel'], ['mixed_media', 'Mixed media'], ['digital', 'Digital'],
];
const STYLES = [
  ['abstract', 'Abstract'], ['expressionist', 'Expressionist'], ['figurative', 'Figurative'],
  ['geometric', 'Geometric'], ['landscape', 'Landscape'], ['minimalist', 'Minimalist'],
  ['portrait', 'Portrait'], ['surrealist', 'Surrealist'], ['realist', 'Realist'],
  ['conceptual', 'Conceptual'], ['street', 'Street art'], ['pop', 'Pop art'],
];
const THEMES = ['Nature', 'Urban', 'Portrait', 'Abstract', 'Memory', 'Identity', 'Landscape', 'Still life', 'Figurative', 'Surreal']
  .map((t) => [t, t]);

const errorText = { fontSize: 13, color: '#E05252' };
const sectionLabel = { fontSize: 12, fontWeight: 500, color: 'var(--slate-600)', marginBottom: 8 };

function ChipGroup({ label, options, selected, onToggle }) {
  return (
    <>
      <p style={sectionLabel}>{label} ({selected.length}/3+)</p>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 16 }}>
        {options.map(([id, name]) => (
          <PillChip key={id} selected={selected.includes(id)} onClick={() => onToggle(id)}>
            {name}
          </PillChip>
        ))}
      </div>
    </>
  );
}

/// Pre-fill from preferences already saved (e.g. user left mid-onboarding).
function savedPrefs(user, key) {
  const list = user?.tastePreferences?.[key];
  return Array.isArray(list) ? list : [];
}

export function OnboardingPage() {
  const navigate = useNavigate();
  const { loggedIn, user } = useSession();
  const [step, setStep] = useState(0);
  const [role, setRoleChoice] = useState(user?.role ?? null);
  const [mediums, setMediums] = useState(() => savedPrefs(user, 'mediums'));
  const [styles, setStyles] = useState(() => savedPrefs(user, 'styles'));
  const [themes, setThemes] = useState(() => savedPrefs(user, 'themes'));
  const [photoUrl, setPhotoUrl] = useState(null);
  const [preview, setPreview] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  // Set right before the final navigate so the onboardingComplete redirect
  // below doesn't race it.
  const finishing = useRef(false);
  const fileInput = useRef(null);

  useEffect(() => () => preview && URL.revokeObjectURL(preview), [preview]);

  if (!loggedIn) return <Navigate to="/login?next=%2Fonboarding" replace />;
  if (user?.onboardingComplete && !finishing.current) return <Navigate to="/home" replace />;

  const toggle = (set) => (id) =>
    set((arr) => (arr.includes(id) ? arr.filter((x) => x !== id) : [...arr, id]));

  const run = async (fn) => {
    if (loading || uploading) return;
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

  const prefsValid = mediums.length >= 3 && styles.length >= 3 && themes.length >= 3;

  const next = () => {
    if (step === 0) {
      return run(async () => {
        await setRole(role);
        setStep(1);
      });
    }
    if (step === 1) {
      return run(async () => {
        await setOnboardingPreferences({ mediums, styles, themes });
        setStep(2);
      });
    }
    return run(async () => {
      await setOnboardingPhotos(photoUrl);
      finishing.current = true;
      try {
        await completeOnboarding();
      } catch (e) {
        finishing.current = false;
        throw e;
      }
      navigate('/home', { replace: true });
    });
  };

  const pickPhoto = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    setError(null);
    setUploading(true);
    try {
      const url = await uploadProfilePhoto(file);
      setPhotoUrl(url);
      setPreview(URL.createObjectURL(file));
    } catch (err) {
      setError(err.message || 'Upload failed');
    } finally {
      setUploading(false);
    }
  };

  const canContinue = (step === 0 && role) || (step === 1 && prefsValid) || step === 2;

  return (
    <div style={bgStyle}>
      <div style={{ textAlign: 'center', marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, color: 'var(--slate-900)' }}>Studio 3</h1>
        <p style={{ fontSize: 13, color: 'var(--slate-400)', marginTop: 4 }}>Discover Art. Collect Stories.</p>
      </div>

      <GlassCard style={{ width: '100%', maxWidth: 343, padding: 28, margin: '0 auto' }}>
        <div style={{ position: 'relative', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 8, marginBottom: 24, minHeight: 24 }}>
          {step > 0 && (
            <button
              type="button"
              onClick={() => { setError(null); setStep(step - 1); }}
              aria-label="Back"
              style={{ position: 'absolute', left: -8, color: 'var(--slate-600)', padding: 4, display: 'flex' }}
            >
              <ChevronLeft size={22} />
            </button>
          )}
          {[0, 1, 2].map((i) => (
            <div
              key={i}
              style={{
                width: 8,
                height: 8,
                borderRadius: '50%',
                background: i <= step ? 'var(--slate-900)' : 'var(--slate-300)',
              }}
            />
          ))}
        </div>

        {step === 0 && (
          <>
            <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 16 }}>What brings you to Studio 3?</h2>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 24 }}>
              {ROLES.map((r) => {
                const selected = role === r.id;
                return (
                  <button
                    key={r.id}
                    type="button"
                    onClick={() => setRoleChoice(r.id)}
                    aria-pressed={selected}
                    style={{
                      textAlign: 'left',
                      padding: '14px 18px',
                      borderRadius: 16,
                      border: `1.5px solid ${selected ? 'var(--slate-900)' : 'var(--slate-200)'}`,
                      background: selected ? 'var(--slate-900)' : 'var(--white)',
                      color: selected ? 'var(--white)' : 'var(--slate-900)',
                      transition: 'background 0.2s, color 0.2s, border-color 0.2s',
                    }}
                  >
                    <div style={{ fontSize: 15, fontWeight: 600 }}>{r.title}</div>
                    <div style={{ fontSize: 13, marginTop: 2, color: selected ? 'var(--slate-300)' : 'var(--slate-500)' }}>
                      {r.subtitle}
                    </div>
                  </button>
                );
              })}
            </div>
          </>
        )}

        {step === 1 && (
          <>
            <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 4 }}>What moves you?</h2>
            <p style={{ fontSize: 13, color: 'var(--slate-500)', marginBottom: 20 }}>
              Pick at least 3 mediums, styles, and themes to personalize your feed
            </p>
            <ChipGroup label="Mediums" options={MEDIUMS} selected={mediums} onToggle={toggle(setMediums)} />
            <ChipGroup label="Styles" options={STYLES} selected={styles} onToggle={toggle(setStyles)} />
            <ChipGroup label="Themes" options={THEMES} selected={themes} onToggle={toggle(setThemes)} />
            <div style={{ height: 8 }} />
          </>
        )}

        {step === 2 && (
          <>
            <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 4 }}>Profile photo</h2>
            <p style={{ fontSize: 13, color: 'var(--slate-500)', marginBottom: 20, lineHeight: 1.4 }}>
              Add a profile photo, or tap Finish to skip for now.
            </p>
            <input
              ref={fileInput}
              type="file"
              accept="image/jpeg,image/png,image/webp"
              onChange={pickPhoto}
              style={{ display: 'none' }}
            />
            <button
              type="button"
              onClick={() => fileInput.current?.click()}
              disabled={uploading || loading}
              aria-label="Choose profile photo"
              style={{
                width: 96,
                height: 96,
                borderRadius: '50%',
                border: preview ? 'none' : '2px dashed var(--slate-300)',
                background: 'var(--slate-50)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'var(--slate-400)',
                margin: '0 auto 12px',
                overflow: 'hidden',
                padding: 0,
              }}
            >
              {preview
                ? <img src={preview} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                : <Camera size={26} />}
            </button>
            <p style={{ textAlign: 'center', fontSize: 12, color: 'var(--slate-500)', marginBottom: 24 }}>
              {uploading ? 'Uploading…' : preview ? 'Tap to change' : 'Tap to add a photo'}
            </p>
          </>
        )}

        {error && <div style={{ ...errorText, marginBottom: 12 }} role="alert">{error}</div>}
        <PrimaryButton disabled={!canContinue || loading || uploading} onClick={next}>
          {loading ? 'Saving…' : step === 2 ? 'Finish' : 'Continue'}
        </PrimaryButton>
      </GlassCard>
    </div>
  );
}
