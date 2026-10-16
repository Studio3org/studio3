import React from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft, X, Pencil } from 'lucide-react';
import { useEventForm } from '../../screens/post/useEventForm';
import { MediaGalleryStep } from '../../screens/post/MediaGalleryStep';
import { MediaEditStep } from '../../screens/post/MediaEditStep';
import {
  EventStepper,
  EventDetailsStep,
  EventTicketsStep,
  EventLineupStep,
  EventReviewStep,
  EventPublishFooter,
} from '../../screens/post/EventFormFields';

/** Desktop dialog treatment for `/event-create` — same "background location"
 * pattern as PostModal.jsx, sharing useEventForm/EventFormFields with the
 * mobile full-page flow (EventPostPage.jsx). */
export function EventPostModal() {
  const navigate = useNavigate();
  const close = () => navigate(-1);
  const form = useEventForm(close);

  // Matches event_create_page.dart's PopScope: inside the wizard, back only
  // steps between Details/Tickets/Lineup/Review — at step 0 it exits the
  // whole flow (the crop step is only reachable again via the cover's edit
  // pencil, not the back button).
  const back = () => {
    if (form.step === 'gallery') return close();
    if (form.step === 'edit') return form.goToGallery();
    if (form.wizardStep > 0) return form.goWizardStep(form.wizardStep - 1);
    return close();
  };

  const coverItem = form.media.items[0];

  return (
    <div style={{ position: 'fixed', inset: 0, zIndex: 300, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div onClick={close} style={{ position: 'absolute', inset: 0, background: 'rgba(35,31,27,0.5)', backdropFilter: 'blur(4px)' }} />
      <div
        style={{
          position: 'relative',
          width: 'min(880px, 94vw)',
          maxHeight: '90vh',
          height: 'fit-content',
          display: 'flex',
          flexDirection: 'column',
          borderRadius: 'var(--radius-lg)',
          boxShadow: 'var(--shadow-modal)',
          background: 'var(--cream-bg)',
          overflow: 'hidden',
        }}
      >
        <div
          style={{
            flexShrink: 0,
            height: 56,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0 16px 0 12px',
            borderBottom: '1px solid var(--cream-divider)',
          }}
        >
          <button onClick={back} aria-label="Back" style={{ padding: 8, color: 'var(--cream-text)' }}>
            <ChevronLeft size={20} strokeWidth={2} />
          </button>
          <span style={{ fontFamily: 'var(--font-geist)', fontSize: 17, fontWeight: 500, color: 'var(--cream-text)' }}>Event</span>
          <button onClick={close} aria-label="Close" style={{ width: 32, height: 32, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--cream-text)' }}>
            <X size={18} strokeWidth={2} />
          </button>
        </div>

        <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', overflowX: 'hidden', padding: '20px 24px' }}>
          {form.step === 'gallery' && <MediaGalleryStep type="event" form={form} />}
          {form.step === 'edit' && <MediaEditStep type="event" form={form} />}
          {form.step === 'tabs' && (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 24, alignItems: 'start' }}>
              {coverItem && (
                <div style={{ display: 'flex', justifyContent: 'center' }}>
                  <div style={{ position: 'relative', width: 220, aspectRatio: '3/4', borderRadius: 14, overflow: 'hidden', background: '#000' }}>
                    <img src={coverItem.previewUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                    <button
                      onClick={form.goToEdit}
                      aria-label="Edit cover"
                      style={{
                        position: 'absolute',
                        top: 10,
                        right: 10,
                        width: 30,
                        height: 30,
                        borderRadius: '50%',
                        background: 'rgba(35,31,27,0.55)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        color: '#fff',
                      }}
                    >
                      <Pencil size={14} strokeWidth={2} />
                    </button>
                    <span
                      style={{
                        position: 'absolute',
                        left: 8,
                        bottom: 10,
                        padding: '4px 9px',
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
                </div>
              )}

              <div style={{ display: 'flex', flexDirection: 'column', gap: 16, minWidth: 0 }}>
                <EventStepper form={form} />
                {form.wizardStep === 0 && <EventDetailsStep form={form} />}
                {form.wizardStep === 1 && <EventTicketsStep form={form} />}
                {form.wizardStep === 2 && <EventLineupStep form={form} />}
                {form.wizardStep === 3 && <EventReviewStep form={form} />}
                <EventPublishFooter form={form} />
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
