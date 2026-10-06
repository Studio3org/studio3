import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft, X } from 'lucide-react';
import { SharePieceIcon, ShareSceneIcon } from '../icons/PostIcons';
import { usePostForm } from '../../screens/post/usePostForm';
import { AvailabilityTab, DetailsTab, PublishFooter, ReviewTab, TabBar } from '../../screens/post/PostFormFields';
import { MediaGalleryStep } from '../../screens/post/MediaGalleryStep';
import { MediaEditStep } from '../../screens/post/MediaEditStep';

/**
 * Desktop treatment for `/post`: a proper dialog over the still-mounted
 * background route (React Router "background location" pattern — see
 * App.jsx). Step 1 is a small type-picker dialog; picking Piece/Scene swaps
 * in the same posting flow mobile uses (usePostForm/PostFormFields), just in
 * modal chrome instead of a full page. Mobile never renders this — PostPage
 * keeps its own bottom sheet + full-page flow.
 */
export function PostModal() {
  const navigate = useNavigate();
  const [type, setType] = useState(null);
  const close = () => navigate(-1);

  return (
    <div style={{ position: 'fixed', inset: 0, zIndex: 300, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div
        onClick={close}
        style={{ position: 'absolute', inset: 0, background: 'rgba(35,31,27,0.5)', backdropFilter: 'blur(4px)' }}
      />
      {type ? (
        <PostFormDialog type={type} onBack={() => setType(null)} onClose={close} />
      ) : (
        <TypePickerDialog onChoose={setType} onClose={close} />
      )}
    </div>
  );
}

function DialogCloseButton({ onClick }) {
  return (
    <button
      onClick={onClick}
      aria-label="Close"
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        width: 32,
        height: 32,
        borderRadius: '50%',
        color: 'var(--cream-text)',
      }}
    >
      <X size={18} strokeWidth={2} />
    </button>
  );
}

function TypePickerDialog({ onChoose, onClose }) {
  return (
    <div
      style={{
        position: 'relative',
        width: 'min(440px, 92vw)',
        borderRadius: 'var(--radius-lg)',
        boxShadow: 'var(--shadow-modal)',
        background: 'var(--cream-bg)',
        padding: 24,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
        <h2 style={{ fontFamily: 'var(--font-inter)', fontSize: 18, fontWeight: 500, color: 'var(--cream-text)' }}>
          What are you sharing?
        </h2>
        <DialogCloseButton onClick={onClose} />
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        <TypeOptionCard
          icon={<SharePieceIcon size={36} />}
          title="Piece"
          subtitle="A finished work, up to 5 angles"
          onClick={() => onChoose('piece')}
        />
        <TypeOptionCard
          icon={<ShareSceneIcon size={36} />}
          title="Scene"
          subtitle="One photo or video"
          onClick={() => onChoose('scene')}
        />
      </div>
    </div>
  );
}

function TypeOptionCard({ icon, title, subtitle, onClick }) {
  return (
    <button
      onClick={onClick}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 16,
        width: '100%',
        textAlign: 'left',
        padding: 16,
        borderRadius: 14,
        border: '1px solid var(--cream-divider)',
        background: 'transparent',
        transition: 'background 0.15s',
      }}
    >
      <span
        style={{
          width: 44,
          height: 44,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        {icon}
      </span>
      <span>
        <div style={{ fontFamily: 'var(--font-inter)', fontSize: 16, fontWeight: 500, color: 'var(--cream-text)' }}>{title}</div>
        <div style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)', marginTop: 2 }}>{subtitle}</div>
      </span>
    </button>
  );
}

function PostFormDialog({ type, onBack, onClose }) {
  const form = usePostForm(type, onClose);

  const back = () => {
    if (form.step === 'gallery') return onBack();
    if (form.step === 'edit') return form.goToGallery();
    if (form.tab === form.TABS[0]) {
      return form.media.hasVideo ? form.goToGallery() : form.goToEdit();
    }
    return onBack();
  };

  const coverItem = form.media.items[0];

  return (
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
      {/* Header Bar */}
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
        <span style={{ fontFamily: 'var(--font-inter)', fontSize: 17, fontWeight: 500, color: 'var(--cream-text)' }}>
          {type === 'piece' ? 'Piece' : 'Scene'}
        </span>
        <DialogCloseButton onClick={onClose} />
      </div>

      {/* Main Content Area */}
      <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', overflowX: 'hidden', padding: '20px 24px' }}>
        {form.step === 'gallery' && <MediaGalleryStep type={type} form={form} />}
        {form.step === 'edit' && <MediaEditStep type={type} form={form} />}
        {form.step === 'tabs' && (
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
              gap: 24,
              alignItems: 'start',
            }}
          >
            {/* Left Column: Media Preview */}
            {coverItem && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div
                  style={{
                    position: 'relative',
                    width: '100%',
                    aspectRatio: type === 'piece' ? '3/4' : '9/16',
                    maxHeight: 380,
                    borderRadius: 14,
                    overflow: 'hidden',
                    background: '#000',
                  }}
                >
                  {coverItem.mediaType === 'video' ? (
                    <video src={coverItem.previewUrl} style={{ width: '100%', height: '100%', objectFit: 'cover' }} controls muted />
                  ) : (
                    <img src={coverItem.previewUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  )}
                </div>

                {/* Thumbnails strip for Piece */}
                {form.media.items.length > 1 && (
                  <div style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 4 }}>
                    {form.media.items.map((item) => (
                      <div
                        key={item.id}
                        style={{
                          width: 48,
                          height: 48,
                          borderRadius: 8,
                          overflow: 'hidden',
                          flexShrink: 0,
                          border: '1px solid var(--cream-divider)',
                        }}
                      >
                        <img src={item.previewUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* Right Column: Form Tabs & Fields */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 16, minWidth: 0 }}>
              <TabBar form={form} />
              {form.tab === 'Availability' && <AvailabilityTab form={form} />}
              {form.tab === 'Details' && <DetailsTab type={type} form={form} />}
              {form.tab === 'Review' && <ReviewTab type={type} form={form} />}
              <div style={{ marginTop: 12 }}>
                <PublishFooter form={form} />
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

