import React from 'react';

/**
 * Light glass card — for forms, overlays on light bg
 */
export function GlassCard({ children, className = '', style = {} }) {
  return (
    <div className={`glass-light ${className}`} style={style}>
      {children}
    </div>
  );
}

/**
 * Dark glass strip — overlays on images (artist strip, badges)
 */
export function GlassDark({ children, className = '', style = {} }) {
  return (
    <div className={`glass-dark ${className}`} style={style}>
      {children}
    </div>
  );
}
