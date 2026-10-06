import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft } from 'lucide-react';
import { SharePieceIcon, ShareSceneIcon } from '../components/icons/PostIcons';
import { usePostForm } from './post/usePostForm';
import { AvailabilityTab, DetailsTab, PublishFooter, ReviewTab, TabBar } from './post/PostFormFields';
import { MediaGalleryStep } from './post/MediaGalleryStep';
import { MediaEditStep } from './post/MediaEditStep';

/** Mobile entry: Piece-vs-Scene bottom sheet (lib/widgets/post_share_type_sheet.dart),
 * then a full-page details form matching PostCreatePage's shape. The desktop modal
 * (components/layout/PostModal.jsx) shares the same form via usePostForm/PostFormFields —
 * this is the same posting flow, just full-page mobile chrome instead of a dialog. */
export function PostPage() {
  const navigate = useNavigate();
  const [type, setType] = useState(null);

  if (!type) {
    return <ShareTypeSheet onChoose={setType} onCancel={() => navigate(-1)} />;
  }
  return <PostDetailsForm type={type} onClose={() => navigate(-1)} />;
}

function ShareTypeSheet({ onChoose, onCancel }) {
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 200 }}>
      <div
        onClick={onCancel}
        style={{
          position: 'absolute',
          inset: 0,
          background: 'rgba(35,31,27,0.4)',
          backdropFilter: 'blur(4px)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: 0,
          background: 'var(--cream-bg)',
          borderRadius: '20px 20px 0 0',
          padding: '16px 24px 24px',
        }}
      >
        <div style={{ width: 40, height: 2, borderRadius: 12, background: 'var(--cream-title-hairline)', margin: '0 auto 12px' }} />
        <h2 style={{ fontFamily: 'var(--font-inter)', fontSize: 18, fontWeight: 500, color: 'var(--cream-text)', marginBottom: 23 }}>
          What are you sharing?
        </h2>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 23 }}>
          <ShareTypeRow
            icon={<SharePieceIcon size={36} />}
            title="Piece"
            subtitle="A finished work, up to 5 angles"
            onClick={() => onChoose('piece')}
          />
          <ShareTypeRow
            icon={<ShareSceneIcon size={36} />}
            title="Scene"
            subtitle="One photo or video"
            onClick={() => onChoose('scene')}
          />
        </div>
      </div>
    </div>
  );
}

function ShareTypeRow({ icon, title, subtitle, onClick }) {
  return (
    <button onClick={onClick} style={{ display: 'flex', alignItems: 'center', gap: 16, width: '100%', textAlign: 'left' }}>
      <span style={{ width: 36, height: 36, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>{icon}</span>
      <span>
        <div style={{ fontFamily: 'var(--font-inter)', fontSize: 16, fontWeight: 500, color: 'var(--cream-text)' }}>{title}</div>
        <div style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)', marginTop: 2 }}>{subtitle}</div>
      </span>
    </button>
  );
}

function PostDetailsForm({ type, onClose }) {
  const form = usePostForm(type, onClose);

  const back = () => {
    if (form.step === 'gallery') return onClose();
    if (form.step === 'edit') return form.goToGallery();
    if (form.tab === form.TABS[0]) {
      return form.media.hasVideo ? form.goToGallery() : form.goToEdit();
    }
    return onClose();
  };

  return (
    <div style={{ background: 'var(--cream-bg)', minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <div style={{ height: 53, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', padding: '0 16px' }}>
        <button onClick={back} aria-label="Back" style={{ position: 'absolute', left: 12, color: 'var(--cream-text)' }}>
          <ChevronLeft size={18} strokeWidth={2} />
        </button>
        <span style={{ fontFamily: 'var(--font-inter)', fontSize: 16, fontWeight: 500, color: 'var(--cream-text)' }}>
          {type === 'piece' ? 'Piece' : 'Scene'}
        </span>
      </div>

      <div style={{ flex: 1, padding: '20px 16px', overflowY: 'auto' }}>
        {form.step === 'gallery' && <MediaGalleryStep type={type} form={form} />}
        {form.step === 'edit' && <MediaEditStep type={type} form={form} />}
        {form.step === 'tabs' && (
          <>
            <div style={{ marginBottom: 20 }}>
              <TabBar form={form} />
            </div>
            {form.tab === 'Availability' && <AvailabilityTab form={form} />}
            {form.tab === 'Details' && <DetailsTab type={type} form={form} />}
            {form.tab === 'Review' && <ReviewTab type={type} form={form} />}
          </>
        )}
      </div>

      {form.step === 'tabs' && (
        <div style={{ padding: 16 }}>
          <PublishFooter form={form} />
        </div>
      )}
    </div>
  );
}

