import React from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Calendar, Plus } from 'lucide-react';
import { useBreakpoint } from '../hooks/useBreakpoint';
import { InboxRail } from '../components/layout/InboxRail';

const MAIN_COLUMN_WIDTH = 630;
const RIGHT_RAIL_WIDTH = 320;

/** Events tab. The browse/feed experience (lib/screens/event_page.dart /
 * event_detail_page.dart) still needs its own design pass — this only wires
 * up the "+" entry into event creation (lib/screens/event_post_page.dart +
 * event_create_page.dart), ported in full at EventPostPage/EventPostModal. */
export function EventPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { showRail, railLabeled } = useBreakpoint();

  const openCreate = () => {
    // Desktop gets the dialog treatment (background-location modal, like
    // SideNav does for /post); mobile gets the full-page flow.
    navigate('/event-create', showRail ? { state: { backgroundLocation: location } } : undefined);
  };

  return (
    <div style={{ background: 'var(--cream-bg)', minHeight: '100vh' }}>
      <div
        style={{
          maxWidth: railLabeled ? MAIN_COLUMN_WIDTH + RIGHT_RAIL_WIDTH + 48 : MAIN_COLUMN_WIDTH,
          margin: '0 auto',
          display: 'flex',
          gap: 48,
        }}
      >
        <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
          <div
            style={{
              height: 53,
              flexShrink: 0,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              padding: '0 16px',
              borderBottom: '1px solid var(--cream-divider)',
            }}
          >
            <span style={{ fontFamily: 'var(--font-geist)', fontSize: 17, fontWeight: 500, color: 'var(--cream-text)' }}>Events</span>
            <button
              onClick={openCreate}
              aria-label="Create event"
              style={{
                width: 32,
                height: 32,
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'var(--cream-text)',
                background: 'rgba(35,31,27,0.06)',
              }}
            >
              <Plus size={18} strokeWidth={2} />
            </button>
          </div>

          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 12, padding: 24, textAlign: 'center' }}>
            <Calendar size={40} color="var(--cream-text-secondary)" strokeWidth={1.5} />
            <p style={{ fontFamily: 'var(--font-inter)', fontSize: 14, color: 'var(--cream-text-secondary)' }}>
              No events yet — tap + to post one.
            </p>
          </div>
        </div>
        {railLabeled && <InboxRail />}
      </div>
    </div>
  );
}
