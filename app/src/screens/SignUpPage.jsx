import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { GlassCard } from '../components/design/GlassCard';
import { PillInput, PillInputWithToggle } from '../components/inputs/PillInput';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { PillChip } from '../components/inputs/PillChip';

const bgStyle = {
  minHeight: '100vh',
  background: 'linear-gradient(180deg, var(--slate-50) 0%, var(--slate-100) 50%, var(--slate-200) 100%)',
  paddingTop: 44,
  paddingBottom: 24,
  paddingLeft: 16,
  paddingRight: 16,
};

const MEDIUMS = ['Oil', 'Watercolor', 'Digital', 'Photography', 'Sculpture', 'Mixed Media', 'Ceramics', 'Printmaking'];
const STYLES = ['Abstract', 'Figurative', 'Landscape', 'Portrait', 'Contemporary', 'Minimalist'];
const THEMES = ['Nature', 'Urban', 'Identity', 'Surreal', 'Geometric'];

export function SignUpPage() {
  const navigate = useNavigate();
  const [step, setStep] = useState(1);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [bio, setBio] = useState('');
  const [location, setLocation] = useState('');
  const [selectedMediums, setSelectedMediums] = useState([]);
  const [selectedStyles, setSelectedStyles] = useState([]);
  const [selectedThemes, setSelectedThemes] = useState([]);

  const toggle = (arr, set, id) => {
    if (arr.includes(id)) set(arr.filter((x) => x !== id));
    else set([...arr, id]);
  };
  const canFinish =
    selectedMediums.length >= 3 && selectedStyles.length >= 3 && selectedThemes.length >= 3;

  return (
    <div style={bgStyle}>
      <div style={{ textAlign: 'center', marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, color: 'var(--slate-900)' }}>Studio 3</h1>
        <p style={{ fontSize: 13, color: 'var(--slate-400)', marginTop: 4 }}>Discover Art. Collect Stories.</p>
      </div>

      <GlassCard style={{ width: '100%', maxWidth: 343, padding: 28 }}>
        <div style={{ display: 'flex', justifyContent: 'center', gap: 8, marginBottom: 24 }}>
          {[1, 2, 3].map((i) => (
            <div
              key={i}
              style={{
                width: 8,
                height: 8,
                borderRadius: '50%',
                background: step === i ? 'var(--slate-900)' : 'var(--slate-300)',
              }}
            />
          ))}
        </div>

        {step === 1 && (
          <>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              <PillInput placeholder="Full Name" value={name} onChange={(e) => setName(e.target.value)} />
              <PillInput type="email" placeholder="Email" value={email} onChange={(e) => setEmail(e.target.value)} />
              <PillInputWithToggle placeholder="Password" value={password} onChange={(e) => setPassword(e.target.value)} />
              <div style={{ height: 4, background: 'var(--slate-200)', borderRadius: 2, overflow: 'hidden' }}>
                <div style={{ width: '60%', height: '100%', background: 'var(--slate-600)', borderRadius: 2 }} />
              </div>
              <PrimaryButton onClick={() => setStep(2)}>Continue</PrimaryButton>
            </div>
          </>
        )}

        {step === 2 && (
          <>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              <div
                style={{
                  width: 72,
                  height: 72,
                  borderRadius: '50%',
                  border: '2px dashed var(--slate-300)',
                  background: 'var(--slate-50)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: 'var(--slate-400)',
                  fontSize: 12,
                  alignSelf: 'center',
                }}
              >
                Avatar
              </div>
              <textarea
                placeholder="Bio"
                value={bio}
                onChange={(e) => setBio(e.target.value)}
                maxLength={300}
                style={{
                  minHeight: 80,
                  borderRadius: 12,
                  border: '1.5px solid var(--slate-200)',
                  padding: 12,
                  fontSize: 14,
                  color: 'var(--slate-700)',
                  resize: 'vertical',
                }}
              />
              <span style={{ fontSize: 11, color: 'var(--slate-400)' }}>{bio.length}/300</span>
              <PillInput placeholder="Location (optional)" value={location} onChange={(e) => setLocation(e.target.value)} />
              <div style={{ display: 'flex', gap: 8 }}>
                <PrimaryButton onClick={() => setStep(3)} style={{ flex: 1 }}>Continue</PrimaryButton>
                <button
                  onClick={() => setStep(3)}
                  style={{
                    flex: 1,
                    height: 52,
                    borderRadius: 9999,
                    border: '1.5px solid var(--slate-300)',
                    background: 'transparent',
                    color: 'var(--slate-600)',
                    fontSize: 15,
                    fontWeight: 500,
                  }}
                >
                  Skip
                </button>
              </div>
            </div>
          </>
        )}

        {step === 3 && (
          <>
            <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 4 }}>What moves you?</h2>
            <p style={{ fontSize: 13, color: 'var(--slate-500)', marginBottom: 20 }}>
              Select at least 3 to personalize your feed
            </p>
            <p style={{ fontSize: 12, fontWeight: 500, color: 'var(--slate-600)', marginBottom: 8 }}>Medium</p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 16 }}>
              {MEDIUMS.map((m) => (
                <PillChip key={m} selected={selectedMediums.includes(m)} onClick={() => toggle(selectedMediums, setSelectedMediums, m)}>
                  {m}
                </PillChip>
              ))}
            </div>
            <p style={{ fontSize: 12, fontWeight: 500, color: 'var(--slate-600)', marginBottom: 8 }}>Style</p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 16 }}>
              {STYLES.map((s) => (
                <PillChip key={s} selected={selectedStyles.includes(s)} onClick={() => toggle(selectedStyles, setSelectedStyles, s)}>
                  {s}
                </PillChip>
              ))}
            </div>
            <p style={{ fontSize: 12, fontWeight: 500, color: 'var(--slate-600)', marginBottom: 8 }}>Theme</p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 24 }}>
              {THEMES.map((t) => (
                <PillChip key={t} selected={selectedThemes.includes(t)} onClick={() => toggle(selectedThemes, setSelectedThemes, t)}>
                  {t}
                </PillChip>
              ))}
            </div>
            <PrimaryButton disabled={!canFinish} onClick={() => canFinish && navigate('/home')}>
              Get Started
            </PrimaryButton>
          </>
        )}
      </GlassCard>

      <p style={{ marginTop: 24, fontSize: 14, color: 'var(--slate-600)', textAlign: 'center' }}>
        Already have an account? <Link to="/login" style={{ fontWeight: 600 }}>Sign In</Link>
      </p>
    </div>
  );
}
