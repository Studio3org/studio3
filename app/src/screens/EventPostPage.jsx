import React from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft, Pencil } from 'lucide-react';
import { useEventForm } from './post/useEventForm';
import { MediaGalleryStep } from './post/MediaGalleryStep';
import { MediaEditStep } from './post/MediaEditStep';
import { EventStepper, EventDetailsStep, EventTicketsStep, EventLineupStep, EventReviewStep, EventPublishFooter } from './post/EventFormFields';
import { filterStringFor } from './post/mediaRenderer';

/** Mobile/full-page entry for Event creation — mirrors PostPage.jsx's
 * shape (gallery → edit → wizard, one shared banner) but for the
 * single-flow Event wizard (lib/screens/event_post_page.dart +
 * event_create_page.dart) instead of the Piece/Scene type picker. */
export function EventPostPage() {
  const navigate = useNavigate();
  const form = useEventForm(() => navigate(-1));

  // Matches event_create_page.dart's PopScope: inside the wizard, back only
  // steps between Details/Tickets/Lineup/Review — at step 0 it exits the
  // whole flow (the crop step is only reachable again via the cover's edit
  // pencil, not the back button).
  const back = () => {
    if (form.step === 'gallery') return navigate(-1);
    if (form.step === 'edit') return form.goToGallery();
    if (form.wizardStep > 0) return form.goWizardStep(form.wizardStep - 1);
    return navigate(-1);
  };

  return (
    <div style={{ background: 'var(--cream-bg)', minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <div style={{ height: 53, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', padding: '0 16px', flexShrink: 0 }}>
        <button onClick={back} aria-label="Back" style={{ position: 'absolute', left: 12, color: 'var(--cream-text)' }}>
          <ChevronLeft size={18} strokeWidth={2} />
        </button>
        <span style={{ fontFamily: 'var(--font-geist)', fontSize: 16, fontWeight: 500, color: 'var(--cream-text)' }}>Event</span>
      </div>

      <div style={{ flex: 1, overflowY: 'auto' }}>
        {form.step === 'gallery' && (
          <div style={{ padding: '20px 16px' }}>
            <MediaGalleryStep type="event" form={form} />
          </div>
        )}
        {form.step === 'edit' && (
          <div style={{ padding: '20px 16px' }}>
            <MediaEditStep type="event" form={form} />
          </div>
        )}
        {form.step === 'tabs' && (
          <>
            <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 11 }}>
              <EventCoverPreview form={form} />
            </div>
            <EventStepper form={form} />
            <div style={{ height: 0.5, background: 'var(--cream-title-hairline)', margin: '24px 0 0' }} />
            {form.wizardStep === 0 && <EventDetailsStep form={form} />}
            {form.wizardStep === 1 && <EventTicketsStep form={form} />}
            {form.wizardStep === 2 && <EventLineupStep form={form} />}
            {form.wizardStep === 3 && <EventReviewStep form={form} />}
          </>
        )}
      </div>

      {form.step === 'tabs' && (
        <div style={{ padding: '16px 10px 24px', flexShrink: 0 }}>
          <EventPublishFooter form={form} />
        </div>
      )}
    </div>
  );
}

function EventCoverPreview({ form }) {
  const cover = form.media.items[0];
  if (!cover) return null;
  return (
    <div style={{ position: 'relative', width: 156, height: 197 }}>
      <img
        src={cover.previewUrl}
        alt=""
        style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: 8, filter: filterStringFor(cover.transform) }}
      />
      <button
        onClick={form.goToEdit}
        aria-label="Edit cover"
        style={{
          position: 'absolute',
          top: 7,
          right: 11,
          width: 26,
          height: 26,
          borderRadius: '50%',
          background: 'rgba(35,31,27,0.55)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: '#fff',
        }}
      >
        <Pencil size={13} strokeWidth={2} />
      </button>
      <span
        style={{
          position: 'absolute',
          left: 5,
          bottom: 8,
          padding: '4px 8px',
          borderRadius: 22,
          background: 'rgba(35,31,27,0.3)',
          color: 'var(--cream-text-inverse)',
          fontFamily: 'var(--font-geist)',
          fontSize: 11,
        }}
      >
        Event
      </span>
    </div>
  );
}
