import React from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft } from 'lucide-react';
import '../ProfileSettingsPage.css';
import './settings.css';

/// Shell for every /settings/* screen: same canvas, width and cards as Profile Settings,
/// plus a back button. Back returns to wherever the user came from, or to Profile Settings
/// when the screen was opened directly.
export function SettingsLayout({ title, subtitle, children }) {
  const navigate = useNavigate();
  const goBack = () => {
    if ((window.history.state?.idx ?? 0) > 0) navigate(-1);
    else navigate('/profile-settings');
  };

  return (
    <div className="settings-page">
      <div className="settings-inner">
        <div className="settings-header settings-header--sub">
          <button type="button" className="settings-back" onClick={goBack} aria-label="Back">
            <ChevronLeft size={22} />
          </button>
          <h1 className="settings-title">{title}</h1>
        </div>
        {subtitle && <p className="settings-intro">{subtitle}</p>}
        {children}
      </div>
    </div>
  );
}

/// Centered spinner in the profile page's style.
export function SettingsSpinner() {
  return (
    <div className="settings-loading">
      <span className="settings-spinner" />
    </div>
  );
}

/// Photo or neutral initial — never a stock image.
export function SettingsAvatar({ src, name }) {
  if (src) return <img className="settings-avatar" src={src} alt="" />;
  return <span className="settings-avatar settings-avatar--empty">{(name || '?').trim().charAt(0).toUpperCase()}</span>;
}
