import React, { useEffect, useState } from 'react';
import './ActionSheet.css';

/// Bottom sheet (centered card on wider screens) in the piece page's style. Closes on
/// backdrop click and Escape.
export function ActionSheet({ title, subtitle, onClose, children }) {
  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && onClose?.();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div className="s3-sheet-backdrop" onClick={onClose} role="presentation">
      <div
        className="s3-sheet"
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="s3-sheet-handle" />
        {title && <h2 className="s3-sheet-title">{title}</h2>}
        {subtitle && <p className="s3-sheet-subtitle">{subtitle}</p>}
        {children}
      </div>
    </div>
  );
}

/// One tappable row in an ActionSheet.
export function SheetItem({ icon, danger = false, onClick, children }) {
  return (
    <button
      type="button"
      className={`s3-sheet-item${danger ? ' s3-sheet-item--danger' : ''}`}
      onClick={onClick}
    >
      {icon}
      {children}
    </button>
  );
}

/// `[message, show]` — show(text) displays a toast for ~2.6s.
export function useToast() {
  const [message, setMessage] = useState(null);
  useEffect(() => {
    if (!message) return undefined;
    const t = setTimeout(() => setMessage(null), 2600);
    return () => clearTimeout(t);
  }, [message]);
  const toast = message ? <div className="s3-toast" role="status">{message}</div> : null;
  return [toast, setMessage];
}
