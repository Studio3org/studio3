import React, { useState } from 'react';

const pillInputStyles = {
  height: 52,
  borderRadius: 9999,
  border: '1.5px solid var(--slate-200)',
  background: 'var(--white)',
  padding: '0 20px',
  fontSize: 15,
  fontWeight: 400,
  color: 'var(--slate-700)',
  width: '100%',
  outline: 'none',
};
const focusRing = '0 0 0 3px rgba(15,23,42,0.06)';

export function PillInput({
  type = 'text',
  placeholder,
  value,
  onChange,
  onBlur,
  name,
  id,
  disabled,
  ...rest
}) {
  const [focused, setFocused] = useState(false);
  return (
    <input
      type={type}
      placeholder={placeholder}
      value={value}
      onChange={onChange}
      onBlur={(e) => { setFocused(false); onBlur?.(e); }}
      onFocus={() => setFocused(true)}
      name={name}
      id={id}
      disabled={disabled}
      style={{
        ...pillInputStyles,
        borderColor: focused ? 'var(--slate-800)' : undefined,
        boxShadow: focused ? focusRing : undefined,
      }}
      {...rest}
    />
  );
}

export function PillInputWithToggle({ type = 'password', ...props }) {
  const [show, setShow] = useState(false);
  return (
    <div style={{ position: 'relative', width: '100%' }}>
      <input
        type={show ? 'text' : type}
        style={{
          ...pillInputStyles,
          paddingRight: 48,
        }}
        {...props}
      />
      <button
        type="button"
        onClick={() => setShow((s) => !s)}
        aria-label={show ? 'Hide password' : 'Show password'}
        style={{
          position: 'absolute',
          right: 16,
          top: '50%',
          transform: 'translateY(-50%)',
          color: 'var(--slate-500)',
          padding: 4,
        }}
      >
        {show ? '🙈' : '👁'}
      </button>
    </div>
  );
}
