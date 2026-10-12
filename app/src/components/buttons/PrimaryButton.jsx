import React from 'react';

const styles = {
  height: 52,
  borderRadius: 9999,
  background: 'var(--slate-900)',
  color: 'var(--white)',
  fontSize: 15,
  fontWeight: 600,
  width: '100%',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  transition: 'opacity 0.15s, transform 0.1s',
};
const disabledStyles = {
  background: 'var(--slate-300)',
  color: 'var(--slate-500)',
  cursor: 'not-allowed',
};

export function PrimaryButton({ children, disabled, onClick, style = {}, ...rest }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      style={{
        ...styles,
        ...(disabled ? disabledStyles : {}),
        ...style,
      }}
      onMouseDown={(e) => !disabled && (e.currentTarget.style.transform = 'scale(0.98)')}
      onMouseUp={(e) => (e.currentTarget.style.transform = '')}
      onMouseLeave={(e) => (e.currentTarget.style.transform = '')}
      {...rest}
    >
      {children}
    </button>
  );
}
