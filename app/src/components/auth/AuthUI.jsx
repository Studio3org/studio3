import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { ChevronLeft, Eye, EyeOff } from 'lucide-react';

/** Dark "premium" auth shell — ported from lib/widgets/auth_ui.dart (AuthColors/AuthScaffold). */
export function AuthScaffold({ children, showBackButton = false, onBack, compact = false }) {
  return (
    <div
      style={{
        minHeight: '100vh',
        background:
          'linear-gradient(135deg, #121212 0%, #0A0A0A 30%, #000000 65%, #1A1A1A 100%)',
        position: 'relative',
        overflow: 'hidden',
      }}
    >
      {/* Soft radial highlight + vignette — approximates the Flutter background's
          painted curves/glow without needing a canvas. */}
      <div
        style={{
          position: 'absolute',
          top: -80,
          right: -80,
          width: 280,
          height: 280,
          borderRadius: '50%',
          background: 'rgba(64,64,64,0.18)',
          filter: 'blur(40px)',
          pointerEvents: 'none',
        }}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: 'radial-gradient(circle at 50% 40%, transparent 45%, rgba(0,0,0,0.55) 100%)',
          pointerEvents: 'none',
        }}
      />

      <div
        style={{
          position: 'relative',
          minHeight: '100vh',
          padding: '24px 24px 32px',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        {showBackButton && (
          <button
            type="button"
            onClick={onBack}
            aria-label="Back"
            style={{
              width: 40,
              height: 40,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: 'var(--auth-text-muted)',
              marginBottom: 8,
              marginLeft: -8,
            }}
          >
            <ChevronLeft size={20} strokeWidth={2} />
          </button>
        )}

        <StudioAuthLogo compact={compact} />

        <div style={{ marginTop: compact ? 28 : 40, flex: 1 }}>{children}</div>
      </div>
    </div>
  );
}

export function StudioAuthLogo({ compact = false }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
      <div
        style={{
          width: compact ? 40 : 64,
          height: compact ? 40 : 64,
          borderRadius: '50%',
          border: '1.5px solid #fff',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <span style={{ color: '#fff', fontFamily: 'var(--font-geist)', fontWeight: 700, fontSize: compact ? 18 : 26 }}>
          3
        </span>
      </div>
      {!compact && (
        <span style={{ color: '#fff', fontFamily: 'var(--font-inter)', fontSize: 15, letterSpacing: 2 }}>
          STUDIO&nbsp;3
        </span>
      )}
    </div>
  );
}

export function AuthPageTitle({ title, subtitle, align = 'start' }) {
  return (
    <div style={{ textAlign: align === 'center' ? 'center' : 'left', marginBottom: 24 }}>
      <h1 style={{ fontFamily: 'var(--font-inter)', fontSize: 28, fontWeight: 600, color: 'var(--auth-text)' }}>
        {title}
      </h1>
      {subtitle && (
        <p style={{ fontFamily: 'var(--font-inter)', fontSize: 14, color: 'var(--auth-text-dim)', marginTop: 6 }}>
          {subtitle}
        </p>
      )}
    </div>
  );
}

export function AuthPillInput({ icon, error, trailing, style, ...inputProps }) {
  const [focused, setFocused] = useState(false);
  const borderColor = error ? 'var(--auth-error)' : focused ? 'var(--auth-border-focus)' : 'var(--auth-border)';
  return (
    <div>
      <div
        style={{
          height: 52,
          borderRadius: 14,
          background: 'rgba(0,0,0,0.35)',
          border: `1px solid ${borderColor}`,
          display: 'flex',
          alignItems: 'center',
          padding: '0 16px',
          gap: 10,
          ...style,
        }}
      >
        {icon && (
          <span style={{ color: 'var(--auth-text-muted)', display: 'flex', flexShrink: 0 }}>{icon}</span>
        )}
        <input
          {...inputProps}
          onFocus={(e) => {
            setFocused(true);
            inputProps.onFocus?.(e);
          }}
          onBlur={(e) => {
            setFocused(false);
            inputProps.onBlur?.(e);
          }}
          style={{
            flex: 1,
            background: 'transparent',
            color: 'var(--auth-text)',
            fontFamily: 'var(--font-inter)',
            fontSize: 15,
            outline: 'none',
            minWidth: 0,
          }}
        />
        {trailing}
      </div>
      {error && (
        <p style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--auth-error)', marginTop: 6 }}>
          {error}
        </p>
      )}
    </div>
  );
}

export function AuthPasswordInput(props) {
  const [show, setShow] = useState(false);
  return (
    <AuthPillInput
      {...props}
      type={show ? 'text' : 'password'}
      trailing={
        <button
          type="button"
          onClick={() => setShow((s) => !s)}
          aria-label={show ? 'Hide password' : 'Show password'}
          style={{ color: 'var(--auth-text-muted)', display: 'flex' }}
        >
          {show ? <EyeOff size={18} /> : <Eye size={18} />}
        </button>
      }
    />
  );
}

export function AuthPrimaryButton({ children, disabled, loading, onClick, style, type = 'button' }) {
  return (
    <button
      type={type}
      disabled={disabled || loading}
      onClick={onClick}
      style={{
        width: '100%',
        height: 52,
        borderRadius: 14,
        background: disabled ? 'var(--auth-surface-elevated)' : 'var(--auth-accent)',
        color: disabled ? 'var(--auth-text-dim)' : 'var(--auth-bg-deep)',
        fontFamily: 'var(--font-inter)',
        fontSize: 15,
        fontWeight: 600,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        ...style,
      }}
    >
      {loading ? (
        <span
          style={{
            width: 18,
            height: 18,
            borderRadius: '50%',
            border: '2px solid rgba(0,0,0,0.25)',
            borderTopColor: '#000',
            animation: 'auth-spin 0.7s linear infinite',
          }}
        />
      ) : (
        children
      )}
      <style>{'@keyframes auth-spin{to{transform:rotate(360deg)}}'}</style>
    </button>
  );
}

export function AuthGhostButton({ children, onClick, style }) {
  return (
    <button
      type="button"
      onClick={onClick}
      style={{
        width: '100%',
        height: 52,
        borderRadius: 14,
        background: 'transparent',
        border: '1px solid rgba(255,255,255,0.2)',
        color: 'var(--auth-text)',
        fontFamily: 'var(--font-inter)',
        fontSize: 15,
        fontWeight: 500,
        ...style,
      }}
    >
      {children}
    </button>
  );
}

export function AuthStepProgress({ total, current }) {
  return (
    <div>
      <div style={{ display: 'flex', gap: 5 }}>
        {Array.from({ length: total }, (_, i) => (
          <div
            key={i}
            style={{
              flex: 1,
              height: 3,
              borderRadius: 2,
              background: i < current ? 'var(--auth-text)' : 'var(--auth-border)',
            }}
          />
        ))}
      </div>
      <p style={{ textAlign: 'center', fontFamily: 'var(--font-inter)', fontSize: 11, color: 'var(--auth-text-dim)', marginTop: 8 }}>
        Step {current} of {total}
      </p>
    </div>
  );
}

export function AuthOtpInput({ length = 6, value, onChange }) {
  return (
    <div style={{ display: 'flex', gap: 8, justifyContent: 'center' }}>
      {Array.from({ length }, (_, i) => (
        <input
          key={i}
          value={value[i] || ''}
          onChange={(e) => {
            const digit = e.target.value.replace(/\D/g, '').slice(-1);
            const next = value.split('');
            next[i] = digit;
            onChange(next.join('').slice(0, length));
            if (digit && e.target.nextElementSibling) {
              e.target.nextElementSibling.focus();
            }
          }}
          maxLength={1}
          inputMode="numeric"
          style={{
            width: 44,
            height: 52,
            borderRadius: 12,
            background: 'rgba(0,0,0,0.35)',
            border: `1px solid ${value[i] ? 'var(--auth-border-focus)' : 'var(--auth-border)'}`,
            color: '#fff',
            textAlign: 'center',
            fontFamily: 'var(--font-inter)',
            fontSize: 20,
            fontWeight: 600,
            outline: 'none',
          }}
        />
      ))}
    </div>
  );
}

export function AuthLinkFooter({ prompt, linkLabel, to }) {
  return (
    <p style={{ textAlign: 'center', fontFamily: 'var(--font-inter)', fontSize: 14, color: 'var(--auth-text-muted)' }}>
      {prompt}{' '}
      <Link to={to} style={{ fontWeight: 600, color: '#fff', textDecoration: 'underline' }}>
        {linkLabel}
      </Link>
    </p>
  );
}
