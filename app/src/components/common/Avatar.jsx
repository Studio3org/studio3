import React from 'react';
import { User } from 'lucide-react';

export function Avatar({ src, name, size = 32, style }) {
  const box = {
    width: size,
    height: size,
    borderRadius: '50%',
    flexShrink: 0,
    background: 'var(--slate-200)',
    objectFit: 'cover',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    color: 'var(--slate-500)',
    overflow: 'hidden',
    ...style,
  };
  if (src) return <img src={src} alt={name ?? ''} style={box} loading="lazy" />;
  return (
    <span style={box} aria-hidden>
      <User size={Math.round(size * 0.55)} strokeWidth={1.75} />
    </span>
  );
}
