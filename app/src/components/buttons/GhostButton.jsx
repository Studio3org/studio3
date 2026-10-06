import React from 'react';

const styles = {
  height: 44,
  borderRadius: 9999,
  border: '1.5px solid var(--slate-300)',
  background: 'transparent',
  color: 'var(--slate-700)',
  fontSize: 14,
  fontWeight: 500,
  padding: '0 20px',
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
};

export function GhostButton({ children, onClick, style = {}, ...rest }) {
  return (
    <button type="button" onClick={onClick} style={{ ...styles, ...style }} {...rest}>
      {children}
    </button>
  );
}
