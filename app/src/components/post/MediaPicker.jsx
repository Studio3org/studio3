import React, { useRef } from 'react';
import { X } from 'lucide-react';

/// File picker + previews. `items` are `{file, url, isVideo}` with object URLs
/// owned by the parent. Pieces take several images (first = cover); scenes
/// take one image or video.
export function MediaPicker({ items, multiple, max, accept, aspect, onAdd, onRemove, onMakeCover, disabled }) {
  const inputRef = useRef(null);
  const cover = items[0];
  const canAddMore = multiple ? items.length < max : items.length === 0;
  const open = () => !disabled && inputRef.current?.click();
  const ratio = cover?.isVideo ? '9 / 16' : aspect === '16:9' ? '16 / 9' : '3 / 4';

  return (
    <div style={{ marginBottom: 20 }}>
      <input
        ref={inputRef}
        type="file"
        accept={accept}
        multiple={multiple}
        style={{ display: 'none' }}
        onChange={(e) => {
          const files = Array.from(e.target.files ?? []);
          e.target.value = ''; // allow re-picking the same file after removal
          if (files.length) onAdd(files);
        }}
      />

      {cover ? (
        <div
          style={{
            position: 'relative',
            width: '100%',
            maxWidth: cover.isVideo ? 220 : aspect === '16:9' ? 343 : 260,
            aspectRatio: ratio,
            margin: '0 auto',
            borderRadius: 16,
            overflow: 'hidden',
            background: 'var(--slate-200)',
          }}
        >
          {cover.isVideo ? (
            <video src={cover.url} muted playsInline controls style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          ) : (
            <img src={cover.url} alt="Selected cover" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          )}
          {!disabled && (
            <button
              type="button"
              onClick={() => (multiple ? onRemove(0) : open())}
              style={{
                position: 'absolute',
                bottom: 12,
                left: '50%',
                transform: 'translateX(-50%)',
                padding: '6px 14px',
                borderRadius: 9999,
                background: 'rgba(255,255,255,0.9)',
                fontSize: 12,
                fontWeight: 500,
                color: 'var(--slate-700)',
              }}
            >
              {multiple ? 'Remove' : 'Change'}
            </button>
          )}
        </div>
      ) : (
        <button
          type="button"
          onClick={open}
          disabled={disabled}
          style={{
            width: '100%',
            maxWidth: 320,
            height: 280,
            margin: '0 auto',
            borderRadius: 16,
            border: '2px dashed var(--slate-300)',
            background: 'var(--slate-100)',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 6,
            color: 'var(--slate-400)',
            fontSize: 14,
          }}
        >
          <span>{accept.includes('video') ? 'Tap to add photo or video' : multiple ? 'Tap to add photos' : 'Tap to add a photo'}</span>
          <span style={{ fontSize: 12 }}>
            {accept.includes('video') ? 'JPEG, PNG, WebP up to 20 MB · MP4 up to 100 MB' : `JPEG, PNG or WebP · up to 20 MB${multiple ? ` · up to ${max}` : ''}`}
          </span>
        </button>
      )}

      {multiple && items.length > 0 && (
        <div style={{ display: 'flex', gap: 8, overflowX: 'auto', padding: '12px 0 4px' }}>
          {items.map((item, i) => (
            <div key={item.url} style={{ position: 'relative', flexShrink: 0 }}>
              <button
                type="button"
                onClick={() => i > 0 && !disabled && onMakeCover(i)}
                title={i === 0 ? 'Cover' : 'Make cover'}
                style={{
                  width: 60,
                  height: 72,
                  borderRadius: 10,
                  overflow: 'hidden',
                  border: i === 0 ? '2px solid var(--slate-900)' : '1.5px solid var(--slate-200)',
                  padding: 0,
                  display: 'block',
                }}
              >
                <img src={item.url} alt={`Image ${i + 1}`} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
              </button>
              {i === 0 && (
                <span
                  style={{
                    position: 'absolute',
                    left: 4,
                    bottom: 4,
                    padding: '1px 6px',
                    borderRadius: 9999,
                    background: 'var(--slate-900)',
                    color: 'var(--white)',
                    fontSize: 10,
                    fontWeight: 600,
                  }}
                >
                  Cover
                </span>
              )}
              {!disabled && (
                <button
                  type="button"
                  aria-label={`Remove image ${i + 1}`}
                  onClick={() => onRemove(i)}
                  style={{
                    position: 'absolute',
                    top: -6,
                    right: -6,
                    width: 20,
                    height: 20,
                    borderRadius: '50%',
                    background: 'var(--slate-900)',
                    color: 'var(--white)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <X size={12} />
                </button>
              )}
            </div>
          ))}
          {canAddMore && !disabled && (
            <button
              type="button"
              onClick={open}
              aria-label="Add more images"
              style={{
                width: 60,
                height: 72,
                flexShrink: 0,
                borderRadius: 10,
                border: '1.5px dashed var(--slate-300)',
                background: 'var(--slate-50)',
                color: 'var(--slate-400)',
                fontSize: 22,
              }}
            >
              +
            </button>
          )}
        </div>
      )}
      {multiple && items.length > 1 && (
        <p style={{ fontSize: 12, color: 'var(--slate-400)', margin: '4px 4px 0' }}>
          {items.length}/{max} · tap a thumbnail to make it the cover
        </p>
      )}
    </div>
  );
}
