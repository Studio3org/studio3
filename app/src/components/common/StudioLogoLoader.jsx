import React from 'react';
import './StudioLogoLoader.css';

/**
 * Studio 3 loading mark — matches Flutter's `StudioBubbleLoader`
 * (lib/widgets/studio_loading.dart): the three-bubble logo cluster, with
 * bubbles pulsing largest → medium → smallest → repeat, one at a time
 * (not all three at once). No separate wordmark — the bubble cluster is
 * the mark. `message` renders the same way the app's publishing/loading
 * overlays do: small caption centered below the mark.
 */
export function StudioLogoLoader({ fullScreen = true, message = 'Loading…' }) {
  return (
    <div className={`studio-loader-container ${fullScreen ? 'is-fullscreen' : ''}`}>
      <div className="studio-loader-content">
        <div className="studio-loader-bubbles" role="status" aria-label="Loading">
          <span className="studio-bubble bubble-1" />
          <span className="studio-bubble bubble-2" />
          <span className="studio-bubble bubble-3" />
        </div>
        {message && <div className="studio-loader-message">{message}</div>}
      </div>
    </div>
  );
}
