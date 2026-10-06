import React, { useRef, useState } from 'react';
import { Play, Upload } from 'lucide-react';

/** Web equivalent of the app's device-gallery grid (PostGalleryPicker) — a
 * native multi-file picker (dropzone + click-to-browse) since there's no
 * browser equivalent of in-app device gallery access, followed by a grid of
 * already-selected thumbnails. Tapping a thumbnail deselects it (no separate
 * delete button, same as the app). Piece posts allow multiple images, so
 * each thumbnail gets a numbered badge showing its order; Scene posts cap
 * at a single image (see useMediaEditor's `maxItems`), so there's nothing
 * to number there. */
export function MediaGalleryStep({ type, form }) {
  const { media } = form;
  const fileInput = useRef(null);
  const [dragOver, setDragOver] = useState(false);
  const atCap = media.items.length >= media.maxItems;

  const pick = (fileList) => {
    media.addFiles(fileList);
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <input
        ref={fileInput}
        type="file"
        accept={type === 'scene' ? 'image/*,video/*' : 'image/*'}
        multiple={type === 'piece'}
        hidden
        onChange={(e) => {
          pick(e.target.files);
          e.target.value = '';
        }}
      />

      <div
        onClick={() => !atCap && fileInput.current?.click()}
        onDragOver={(e) => {
          e.preventDefault();
          if (!atCap) setDragOver(true);
        }}
        onDragLeave={() => setDragOver(false)}
        onDrop={(e) => {
          e.preventDefault();
          setDragOver(false);
          if (!atCap) pick(e.dataTransfer.files);
        }}
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          border: `2px dashed ${dragOver ? 'var(--cream-cta-fill)' : 'var(--cream-hairline)'}`,
          borderRadius: 14,
          padding: '36px 20px',
          textAlign: 'center',
          cursor: atCap ? 'default' : 'pointer',
          opacity: atCap ? 0.5 : 1,
          background: dragOver ? 'rgba(35,31,27,0.04)' : 'transparent',
          transition: 'all 0.15s ease',
        }}
      >
        <Upload size={28} color="var(--cream-text-secondary)" strokeWidth={1.5} style={{ marginBottom: 12 }} />
        <p style={{ fontFamily: 'var(--font-inter)', fontSize: 14, fontWeight: 500, color: 'var(--cream-text)', margin: '0 0 4px 0', textAlign: 'center' }}>
          {type === 'piece'
            ? 'Drag images here, or click to browse'
            : type === 'event'
              ? 'Drag a cover photo here, or click to browse'
              : 'Drag a photo or video here, or click to browse'}
        </p>
        <p style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)', margin: 0, textAlign: 'center' }}>
          {type === 'piece' ? `Up to ${media.maxItems} images` : type === 'event' ? 'One photo' : 'One photo or video'}
        </p>
      </div>

      {media.items.length > 0 && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(84px, 1fr))', gap: 8 }}>
          {media.items.map((item, index) => (
            <button
              key={item.id}
              onClick={() => media.removeItem(item.id)}
              aria-label="Remove"
              style={{
                position: 'relative',
                aspectRatio: '1 / 1',
                borderRadius: 8,
                overflow: 'hidden',
                background: 'var(--cream-skeleton)',
              }}
            >
              {item.mediaType === 'video' ? (
                <>
                  <video src={item.previewUrl} style={{ width: '100%', height: '100%', objectFit: 'cover' }} muted />
                  <span
                    style={{
                      position: 'absolute',
                      inset: 0,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      background: 'rgba(35,31,27,0.25)',
                    }}
                  >
                    <Play size={20} color="#fff" fill="#fff" />
                  </span>
                </>
              ) : (
                <img src={item.previewUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
              )}
              {type === 'piece' && (
                <span
                  style={{
                    position: 'absolute',
                    top: 4,
                    left: 4,
                    width: 18,
                    height: 18,
                    borderRadius: '50%',
                    background: 'var(--cream-cta-fill)',
                    color: 'var(--cream-text-inverse)',
                    fontSize: 10,
                    fontWeight: 600,
                    fontFamily: 'var(--font-inter)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  {index + 1}
                </span>
              )}
            </button>
          ))}
        </div>
      )}

      <button
        onClick={form.goToEditOrTabs}
        disabled={media.items.length === 0}
        style={{
          width: '100%',
          height: 40,
          borderRadius: 8,
          background: 'var(--cream-cta-fill)',
          color: 'var(--cream-text-inverse)',
          fontFamily: 'var(--font-geist)',
          fontSize: 16,
          opacity: media.items.length === 0 ? 0.5 : 1,
        }}
      >
        Next
      </button>
    </div>
  );
}
