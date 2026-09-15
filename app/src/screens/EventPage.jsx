import React from 'react';
import { Calendar } from 'lucide-react';

/** Placeholder — the real Events screen (lib/screens/event_page.dart /
 * event_detail_page.dart) needs its own design pass before being ported here.
 * This exists only so the bottom nav's Event slot has somewhere to go. */
export function EventPage() {
  return (
    <div
      style={{
        background: 'var(--cream-bg)',
        minHeight: '100vh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 12,
        padding: 24,
        textAlign: 'center',
      }}
    >
      <Calendar size={40} color="var(--cream-text-secondary)" strokeWidth={1.5} />
      <p style={{ fontFamily: 'var(--font-inter)', fontSize: 14, color: 'var(--cream-text-secondary)' }}>
        Events are coming soon.
      </p>
    </div>
  );
}
