import React from 'react';

const base = {
  height: 32,
  borderRadius: 9999,
  padding: '0 16px',
  fontSize: 13,
  fontWeight: 500,
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  transition: 'background 0.2s, color 0.2s, border-color 0.2s',
  border: '1.5px solid transparent',
};

export function PillChip({ children, selected, onClick, style = {} }) {
  return (
    <button
      type="button"
      onClick={onClick}
      style={{
        ...base,
        background: selected ? 'var(--slate-900)' : 'var(--slate-100)',
        color: selected ? 'var(--white)' : 'var(--slate-600)',
        borderColor: selected ? 'var(--slate-900)' : 'var(--slate-200)',
        ...style,
      }}
    >
      {children}
    </button>
  );
}
