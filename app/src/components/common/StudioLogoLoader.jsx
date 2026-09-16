import React from 'react';
import './StudioLogoLoader.css';

/**
 * Studio 3 Logo Loader — matching Flutter's studio_loading.dart
 * Animated Studio 3 logo + pulsing bubble sequence on cream background.
 */
export function StudioLogoLoader({ fullScreen = true, message }) {
  return (
    <div className={`studio-loader-container ${fullScreen ? 'is-fullscreen' : ''}`}>
      <div className="studio-loader-content">
        <div className="studio-loader-bubbles">
          <span className="studio-bubble bubble-1" />
          <span className="studio-bubble bubble-2" />
          <span className="studio-bubble bubble-3" />
        </div>
        <img
          src="/logo/logo_text_black.png"
          alt="Studio 3"
          className="studio-loader-logo"
        />
        {message && <div className="studio-loader-message">{message}</div>}
      </div>
    </div>
  );
}
