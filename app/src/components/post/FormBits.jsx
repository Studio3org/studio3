import React from 'react';
import { PillChip } from '../inputs/PillChip';

/// Small building blocks shared by the piece and scene forms.

export function FieldLabel({ children, hint }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', margin: '0 4px 8px' }}>
      <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--slate-700)' }}>{children}</span>
      {hint && <span style={{ fontSize: 12, color: 'var(--slate-400)' }}>{hint}</span>}
    </div>
  );
}

export function Field({ label, hint, children, style }) {
  return (
    <div style={{ marginBottom: 16, ...style }}>
      {label && <FieldLabel hint={hint}>{label}</FieldLabel>}
      {children}
    </div>
  );
}

export const textAreaStyle = {
  width: '100%',
  minHeight: 88,
  borderRadius: 16,
  background: 'var(--slate-50)',
  border: '1.5px solid var(--slate-200)',
  padding: 14,
  fontSize: 14,
  color: 'var(--slate-700)',
  resize: 'vertical',
  outline: 'none',
  fontFamily: 'inherit',
};

export const selectStyle = {
  height: 52,
  width: '100%',
  borderRadius: 9999,
  border: '1.5px solid var(--slate-200)',
  background: 'var(--white)',
  padding: '0 20px',
  fontSize: 15,
  color: 'var(--slate-700)',
  outline: 'none',
  appearance: 'none',
  fontFamily: 'inherit',
};

export function Toggle({ on, onChange, disabled, label }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!on)}
      style={{
        width: 50,
        height: 28,
        flexShrink: 0,
        borderRadius: 14,
        background: on ? 'var(--slate-900)' : 'var(--slate-300)',
        position: 'relative',
        opacity: disabled ? 0.5 : 1,
      }}
    >
      <span
        style={{
          position: 'absolute',
          top: 2,
          left: on ? 24 : 2,
          width: 24,
          height: 24,
          borderRadius: '50%',
          background: 'var(--white)',
          transition: 'left 0.2s',
        }}
      />
    </button>
  );
}

export function ToggleRow({ title, subtitle, on, onChange, disabled }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginBottom: 16 }}>
      <div>
        <div style={{ fontSize: 15, color: 'var(--slate-700)' }}>{title}</div>
        {subtitle && <div style={{ fontSize: 12, color: 'var(--slate-500)', marginTop: 2, lineHeight: 1.4 }}>{subtitle}</div>}
      </div>
      <Toggle on={on} onChange={onChange} disabled={disabled} label={title} />
    </div>
  );
}

export function ChipGroup({ options, selected, onToggle, style }) {
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, ...style }}>
      {options.map((o) => (
        <PillChip key={o.id} selected={selected.includes(o.id)} onClick={() => onToggle(o.id)}>
          {o.name}
        </PillChip>
      ))}
    </div>
  );
}

export const ASPECT_OPTIONS = [
  { id: '3:4', name: 'Portrait 3:4' },
  { id: '16:9', name: 'Landscape 16:9' },
];

export function AspectPicker({ value, onChange }) {
  return (
    <ChipGroup options={ASPECT_OPTIONS} selected={[value]} onToggle={onChange} />
  );
}

export function ErrorText({ children }) {
  if (!children) return null;
  return (
    <p role="alert" style={{ fontSize: 13, color: '#E05252', lineHeight: 1.4, margin: '0 4px 16px' }}>
      {children}
    </p>
  );
}
