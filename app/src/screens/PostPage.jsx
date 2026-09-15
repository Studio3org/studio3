import React, { useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft, Image as ImageIcon, Video } from 'lucide-react';

const TABS = ['Availability', 'Details', 'Review'];

/** Entry: Piece-vs-Scene share-type sheet (lib/widgets/post_share_type_sheet.dart), then a
 * details-form screen matching PostCreatePage's shape. Static/local-state only — this web
 * prototype has no real create-piece API to publish to. */
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
    <div style={{ position: 'fixed', inset: 0, zIndex: 200 }}>
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
            icon={<ImageIcon size={30} color="var(--cream-cta-fill)" strokeWidth={1.5} />}
            title="Piece"
            subtitle="A finished work, up to 5 angles"
            onClick={() => onChoose('piece')}
          />
          <ShareTypeRow
            icon={<Video size={30} color="var(--cream-cta-fill)" strokeWidth={1.5} />}
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
        <div style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)' }}>{subtitle}</div>
      </span>
    </button>
  );
}

function PostDetailsForm({ type, onClose }) {
  const [tab, setTab] = useState('Availability');
  const [unlocked, setUnlocked] = useState(1);
  const [forSale, setForSale] = useState(false);
  const [listingType, setListingType] = useState('fixed');
  const [price, setPrice] = useState('');
  const [title, setTitle] = useState('');
  const [caption, setCaption] = useState('');
  const fileInput = useRef(null);
  const [coverUrl, setCoverUrl] = useState(null);

  const goTab = (i) => {
    if (i <= unlocked) setTab(TABS[i]);
  };
  const advance = () => {
    const i = TABS.indexOf(tab);
    if (i < TABS.length - 1) {
      setUnlocked(Math.max(unlocked, i + 1));
      setTab(TABS[i + 1]);
    } else {
      onClose();
    }
  };

  return (
    <div style={{ background: 'var(--cream-bg)', minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <div style={{ height: 53, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', padding: '0 16px' }}>
        <button onClick={onClose} aria-label="Back" style={{ position: 'absolute', left: 12, color: 'var(--cream-text)' }}>
          <ChevronLeft size={18} strokeWidth={2} />
        </button>
        <span style={{ fontFamily: 'var(--font-inter)', fontSize: 16, fontWeight: 500, color: 'var(--cream-text)' }}>
          {type === 'piece' ? 'Piece' : 'Scene'}
        </span>
      </div>

      <div style={{ padding: '12px 16px 0', display: 'flex', justifyContent: 'center' }}>
        <input ref={fileInput} type="file" accept="image/*" hidden onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) setCoverUrl(URL.createObjectURL(f));
        }} />
        <button
          onClick={() => fileInput.current?.click()}
          style={{
            position: 'relative',
            width: 156,
            height: 197,
            borderRadius: 8,
            overflow: 'hidden',
            background: coverUrl ? undefined : 'var(--cream-skeleton)',
          }}
        >
          {coverUrl && <img src={coverUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}
          {!coverUrl && (
            <span style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)' }}>
              Tap to add cover
            </span>
          )}
        </button>
      </div>

      <div style={{ display: 'flex', justifyContent: 'center', gap: 24, marginTop: 20, borderBottom: '1px solid var(--cream-title-hairline)', paddingBottom: 10 }}>
        {TABS.map((t, i) => (
          <button
            key={t}
            onClick={() => goTab(i)}
            style={{
              fontFamily: 'var(--font-inter)',
              fontSize: 13,
              fontWeight: tab === t ? 500 : 400,
              color: i > unlocked ? 'var(--cream-text-secondary)' : tab === t ? 'var(--cream-text)' : 'var(--cream-text-secondary)',
              opacity: i > unlocked ? 0.4 : 1,
            }}
          >
            {t}
          </button>
        ))}
      </div>

      <div style={{ flex: 1, padding: '20px 16px', overflowY: 'auto' }}>
        {tab === 'Availability' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <span style={{ fontFamily: 'var(--font-inter)', fontSize: 15, color: 'var(--cream-text)' }}>List for sale</span>
              <Toggle checked={forSale} onChange={setForSale} />
            </div>
            {forSale && (
              <>
                <div style={{ display: 'flex', gap: 8 }}>
                  {['fixed', 'auction'].map((lt) => (
                    <button
                      key={lt}
                      onClick={() => setListingType(lt)}
                      style={{
                        flex: 1,
                        padding: '12px',
                        borderRadius: 8,
                        border: `1px solid ${listingType === lt ? 'var(--cream-text)' : 'var(--cream-hairline)'}`,
                        background: listingType === lt ? 'rgba(35,31,27,0.06)' : 'transparent',
                        fontFamily: 'var(--font-inter)',
                        fontSize: 13,
                        fontWeight: 500,
                        color: 'var(--cream-text)',
                        textTransform: 'capitalize',
                      }}
                    >
                      {lt}
                    </button>
                  ))}
                </div>
                <PillField placeholder={listingType === 'auction' ? 'Starting bid ($)' : 'Price ($)'} value={price} onChange={setPrice} />
              </>
            )}
          </div>
        )}

        {tab === 'Details' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <PillField placeholder="Title" value={title} onChange={setTitle} />
            <textarea
              placeholder="Story / caption"
              value={caption}
              onChange={(e) => setCaption(e.target.value)}
              style={{
                minHeight: 96,
                borderRadius: 14,
                background: 'var(--cream-bg-detail)',
                border: '1px solid rgba(35,31,27,0.15)',
                padding: 14,
                fontFamily: 'var(--font-inter)',
                fontSize: 14,
                color: 'var(--cream-text)',
                resize: 'vertical',
              }}
            />
            <MetaRow label="Medium" value="Choose" />
            <MetaRow label="Location" value="Choose" />
            <MetaRow label="Materials" value="Add" />
            <MetaRow label="Series" value="None" />
          </div>
        )}

        {tab === 'Review' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <ReviewRow label="Title" value={title || '—'} />
            <ReviewRow label="For sale" value={forSale ? `Yes (${listingType})` : 'No'} />
            {forSale && <ReviewRow label="Price" value={price ? `$${price}` : '—'} />}
            <ReviewRow label="Story" value={caption || '—'} />
          </div>
        )}
      </div>

      <div style={{ padding: 16 }}>
        <button
          onClick={advance}
          style={{
            width: '100%',
            height: 40,
            borderRadius: 8,
            background: 'var(--cream-cta-fill)',
            color: 'var(--cream-text-inverse)',
            fontFamily: 'var(--font-geist)',
            fontSize: 16,
          }}
        >
          {tab === 'Review' ? 'Publish' : 'Save and continue'}
        </button>
      </div>
    </div>
  );
}

function Toggle({ checked, onChange }) {
  return (
    <button
      onClick={() => onChange(!checked)}
      style={{
        width: 44,
        height: 26,
        borderRadius: 13,
        background: checked ? 'var(--cream-cta-fill)' : 'var(--cream-hairline)',
        position: 'relative',
      }}
    >
      <span
        style={{
          position: 'absolute',
          top: 2,
          left: checked ? 20 : 2,
          width: 22,
          height: 22,
          borderRadius: '50%',
          background: '#fff',
          transition: 'left 0.15s',
        }}
      />
    </button>
  );
}

function PillField({ placeholder, value, onChange }) {
  return (
    <input
      placeholder={placeholder}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      style={{
        height: 48,
        borderRadius: 14,
        background: 'var(--cream-bg-detail)',
        border: '1px solid rgba(35,31,27,0.15)',
        padding: '0 16px',
        fontFamily: 'var(--font-inter)',
        fontSize: 14,
        color: 'var(--cream-text)',
        outline: 'none',
      }}
    />
  );
}

function MetaRow({ label, value }) {
  return (
    <button style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 0', borderBottom: '1px solid var(--cream-divider)' }}>
      <span style={{ fontFamily: 'var(--font-inter)', fontSize: 14, color: 'var(--cream-text)' }}>{label}</span>
      <span style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text-secondary)' }}>{value}</span>
    </button>
  );
}

function ReviewRow({ label, value }) {
  return (
    <div style={{ display: 'flex', gap: 12 }}>
      <span style={{ width: 90, flexShrink: 0, fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text-secondary)' }}>{label}</span>
      <span style={{ fontFamily: 'var(--font-inter)', fontSize: 14, color: 'var(--cream-text)' }}>{value}</span>
    </div>
  );
}
