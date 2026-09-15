import React, { useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronRight, ImageIcon, User } from 'lucide-react';

const ROLES = [
  { id: 'artist', title: 'Artist', subtitle: 'I make and share my own work.' },
  { id: 'collector', title: 'Collector', subtitle: 'I collect and support artists.' },
  { id: 'enthusiast', title: 'Enthusiast', subtitle: 'I love discovering new art.' },
];

const MEDIUMS = ['Oil', 'Watercolor', 'Digital', 'Photography', 'Sculpture', 'Mixed Media', 'Ceramics', 'Printmaking'];
const STYLES = ['Abstract', 'Figurative', 'Landscape', 'Portrait', 'Contemporary', 'Minimalist'];
const THEMES = ['Nature', 'Urban', 'Identity', 'Surreal', 'Geometric'];

/** Post-signup profile setup — ported from lib/screens/onboarding/onboarding_page.dart.
 * Light cream palette, unlike the dark auth flow it follows. */
export function OnboardingPage() {
  const navigate = useNavigate();
  const [step, setStep] = useState(0);
  const [role, setRole] = useState(null);
  const [mediums, setMediums] = useState([]);
  const [styles, setStyles] = useState([]);
  const [themes, setThemes] = useState([]);
  const [avatarUrl, setAvatarUrl] = useState(null);
  const [coverUrl, setCoverUrl] = useState(null);
  const avatarInput = useRef(null);
  const coverInput = useRef(null);

  const toggle = (list, setList, id) => {
    setList(list.includes(id) ? list.filter((x) => x !== id) : [...list, id]);
  };

  const canContinue =
    step === 0 ? Boolean(role) : step === 1 ? mediums.length >= 3 && styles.length >= 3 && themes.length >= 3 : true;

  const onFile = (setUrl) => (e) => {
    const file = e.target.files?.[0];
    if (file) setUrl(URL.createObjectURL(file));
  };

  return (
    <div style={{ background: 'var(--cream-bg)', minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <header style={{ padding: '16px 16px 12px', textAlign: 'center' }}>
        <h1 style={{ fontFamily: 'var(--font-inter)', fontSize: 17, fontWeight: 600, color: 'var(--cream-text)' }}>
          Set up your profile
        </h1>
      </header>
      <div style={{ display: 'flex', gap: 6, padding: '0 20px 20px' }}>
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            style={{
              flex: 1,
              height: 3,
              borderRadius: 2,
              background: i <= step ? 'var(--cream-text)' : 'rgba(35,31,27,0.15)',
            }}
          />
        ))}
      </div>

      <div style={{ flex: 1, padding: '0 20px', overflowY: 'auto' }}>
        {step === 0 && (
          <>
            <h2 style={{ fontFamily: 'var(--font-inter)', fontSize: 22, fontWeight: 700, color: 'var(--cream-text)', marginBottom: 16 }}>
              What brings you to Studio 3?
            </h2>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {ROLES.map((r) => {
                const selected = role === r.id;
                return (
                  <button
                    key={r.id}
                    onClick={() => setRole(r.id)}
                    style={{
                      textAlign: 'left',
                      padding: 16,
                      borderRadius: 12,
                      border: `1px solid ${selected ? 'var(--cream-text)' : 'rgba(35,31,27,0.2)'}`,
                      background: selected ? 'rgba(35,31,27,0.08)' : 'transparent',
                    }}
                  >
                    <div style={{ fontFamily: 'var(--font-inter)', fontSize: 16, fontWeight: 600, color: 'var(--cream-text)' }}>
                      {r.title}
                    </div>
                    <div style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'rgba(35,31,27,0.55)', marginTop: 2 }}>
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
            <h2 style={{ fontFamily: 'var(--font-inter)', fontSize: 22, fontWeight: 700, color: 'var(--cream-text)', marginBottom: 4 }}>
              Your taste
            </h2>
            <p style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text-secondary)', marginBottom: 20 }}>
              Pick at least 3 mediums, styles, and themes.
            </p>
            <ChipSection label="Mediums" count={mediums.length} options={MEDIUMS} selected={mediums} onToggle={(id) => toggle(mediums, setMediums, id)} />
            <ChipSection label="Styles" count={styles.length} options={STYLES} selected={styles} onToggle={(id) => toggle(styles, setStyles, id)} />
            <ChipSection label="Themes" count={themes.length} options={THEMES} selected={themes} onToggle={(id) => toggle(themes, setThemes, id)} />
          </>
        )}

        {step === 2 && (
          <>
            <h2 style={{ fontFamily: 'var(--font-inter)', fontSize: 22, fontWeight: 700, color: 'var(--cream-text)', marginBottom: 4 }}>
              Profile photos
            </h2>
            <p style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text-secondary)', marginBottom: 20 }}>
              Add a face and a cover to your profile.
            </p>
            <input ref={avatarInput} type="file" accept="image/*" hidden onChange={onFile(setAvatarUrl)} />
            <input ref={coverInput} type="file" accept="image/*" hidden onChange={onFile(setCoverUrl)} />
            <PickerRow
              onClick={() => avatarInput.current?.click()}
              icon={
                avatarUrl ? (
                  <img src={avatarUrl} alt="" style={{ width: 72, height: 72, borderRadius: '50%', objectFit: 'cover' }} />
                ) : (
                  <span style={{ width: 72, height: 72, borderRadius: '50%', background: 'rgba(35,31,27,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <User size={28} color="var(--cream-text-secondary)" />
                  </span>
                )
              }
              label={avatarUrl ? 'Profile photo added' : 'Add profile photo'}
            />
            <div style={{ height: 12 }} />
            {coverUrl ? (
              <img
                src={coverUrl}
                alt=""
                onClick={() => coverInput.current?.click()}
                style={{ width: '100%', height: 120, borderRadius: 12, objectFit: 'cover', marginBottom: 12, cursor: 'pointer' }}
              />
            ) : null}
            <PickerRow
              onClick={() => coverInput.current?.click()}
              icon={<ImageIcon size={22} color="var(--cream-text-secondary)" />}
              label={coverUrl ? 'Cover photo added' : 'Add cover photo'}
            />
          </>
        )}
      </div>

      <div style={{ padding: 20 }}>
        <button
          disabled={!canContinue}
          onClick={() => {
            if (step < 2) setStep(step + 1);
            else navigate('/home');
          }}
          style={{
            width: '100%',
            height: 52,
            borderRadius: 14,
            background: canContinue ? 'var(--cream-cta-fill)' : 'rgba(53,47,42,0.4)',
            color: 'var(--cream-text-inverse)',
            fontFamily: 'var(--font-inter)',
            fontSize: 15,
            fontWeight: 600,
          }}
        >
          {step < 2 ? 'Continue' : 'Finish'}
        </button>
      </div>
    </div>
  );
}

function ChipSection({ label, count, options, selected, onToggle }) {
  return (
    <div style={{ marginBottom: 20 }}>
      <p style={{ fontFamily: 'var(--font-inter)', fontSize: 15, fontWeight: 600, color: 'var(--cream-text)', marginBottom: 10 }}>
        {label} ({count}/3+)
      </p>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {options.map((opt) => {
          const active = selected.includes(opt);
          return (
            <button
              key={opt}
              onClick={() => onToggle(opt)}
              style={{
                padding: '8px 16px',
                borderRadius: 9999,
                border: `1px solid ${active ? 'var(--cream-text)' : 'rgba(35,31,27,0.2)'}`,
                background: active ? 'rgba(35,31,27,0.15)' : 'transparent',
                color: 'var(--cream-text)',
                fontFamily: 'var(--font-inter)',
                fontSize: 13,
              }}
            >
              {opt}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function PickerRow({ onClick, icon, label }) {
  return (
    <button
      onClick={onClick}
      style={{
        width: '100%',
        display: 'flex',
        alignItems: 'center',
        gap: 14,
        padding: '4px 0',
      }}
    >
      {icon}
      <span style={{ flex: 1, textAlign: 'left', fontFamily: 'var(--font-inter)', fontSize: 15, fontWeight: 500, color: 'var(--cream-text)' }}>
        {label}
      </span>
      <ChevronRight size={18} color="rgba(35,31,27,0.35)" />
    </button>
  );
}
