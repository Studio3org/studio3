import React, { useEffect, useRef, useState } from 'react';
import Cropper from 'react-easy-crop';
import { FlipHorizontal2, FlipVertical2, RotateCw } from 'lucide-react';
import { buildWorkingImageUrl, filterStringFor } from './mediaRenderer';

const SCENE_ASPECT_OPTIONS = [
  { label: '9:16', value: 9 / 16 },
  { label: '16:9', value: 16 / 9 },
  { label: '1:1', value: 1 },
  { label: '3:4', value: 3 / 4 },
];

/** Pan/zoom crop (react-easy-crop) + 90°-step rotate/flip + brightness/
 * contrast/exposure for one selected image — mirrors the app's
 * PieceSceneStyleEditor. Rotation/flip are baked into a "working image"
 * (mediaRenderer.buildWorkingImageUrl) that the cropper reads from, so crop
 * coordinates never have to reason about rotation; crop/zoom reset whenever
 * that working image's dimensions change. */
export function ImageCropEditor({ type, item, onChange, cropperOnly = false, controlsOnly = false }) {
  const { transform } = item;
  const [aspect, setAspect] = useState(type === 'piece' || type === 'event' ? 3 / 4 : 9 / 16);
  const [workingUrl, setWorkingUrl] = useState(item.previewUrl);
  const revokeRef = useRef(null);

  useEffect(() => {
    let cancelled = false;
    buildWorkingImageUrl(item.previewUrl, transform.rotationDegrees, transform.flipHorizontal, transform.flipVertical).then(
      (url) => {
        if (cancelled) return;
        if (revokeRef.current && revokeRef.current !== url) URL.revokeObjectURL(revokeRef.current);
        revokeRef.current = url === item.previewUrl ? null : url;
        setWorkingUrl(url);
        onChange({ crop: { x: 0, y: 0 }, zoom: 1, croppedAreaPixels: null });
      },
    );
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [item.previewUrl, transform.rotationDegrees, transform.flipHorizontal, transform.flipVertical]);

  useEffect(
    () => () => {
      if (revokeRef.current) URL.revokeObjectURL(revokeRef.current);
    },
    [],
  );

  const cropperView = (
    <div
      style={{
        position: 'relative',
        width: '100%',
        height: 'min(420px, 50vh)',
        borderRadius: 14,
        overflow: 'hidden',
        background: '#000',
      }}
    >
      <Cropper
        image={workingUrl}
        crop={transform.crop}
        zoom={transform.zoom}
        aspect={aspect}
        onCropChange={(crop) => onChange({ crop })}
        onZoomChange={(zoom) => onChange({ zoom })}
        onCropComplete={(_, croppedAreaPixels) => onChange({ croppedAreaPixels })}
        style={{ containerStyle: { filter: filterStringFor(transform) } }}
      />
    </div>
  );

  const controlsView = (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      {type === 'scene' && (
        <div style={{ display: 'flex', gap: 8 }}>
          {SCENE_ASPECT_OPTIONS.map((opt) => (
            <button
              key={opt.label}
              onClick={() => setAspect(opt.value)}
              style={{
                flex: 1,
                padding: '8px 0',
                borderRadius: 8,
                border: `1px solid ${aspect === opt.value ? 'var(--cream-text)' : 'var(--cream-hairline)'}`,
                background: aspect === opt.value ? 'rgba(35,31,27,0.06)' : 'transparent',
                fontFamily: 'var(--font-inter)',
                fontSize: 12,
                fontWeight: 500,
                color: 'var(--cream-text)',
              }}
            >
              {opt.label}
            </button>
          ))}
        </div>
      )}

      <div style={{ display: 'flex', gap: 12, justifyContent: 'center' }}>
        <IconButton
          label="Rotate"
          onClick={() => onChange({ rotationDegrees: (transform.rotationDegrees + 90) % 360 })}
        >
          <RotateCw size={18} strokeWidth={1.75} />
        </IconButton>
        <IconButton
          label="Flip horizontal"
          active={transform.flipHorizontal}
          onClick={() => onChange({ flipHorizontal: !transform.flipHorizontal })}
        >
          <FlipHorizontal2 size={18} strokeWidth={1.75} />
        </IconButton>
        <IconButton
          label="Flip vertical"
          active={transform.flipVertical}
          onClick={() => onChange({ flipVertical: !transform.flipVertical })}
        >
          <FlipVertical2 size={18} strokeWidth={1.75} />
        </IconButton>
      </div>

      <AdjustSlider label="Brightness" value={transform.brightness} onChange={(v) => onChange({ brightness: v })} />
      <AdjustSlider label="Contrast" value={transform.contrast} onChange={(v) => onChange({ contrast: v })} />
      <AdjustSlider label="Exposure" value={transform.exposure} onChange={(v) => onChange({ exposure: v })} />
    </div>
  );

  if (cropperOnly) return cropperView;
  if (controlsOnly) return controlsView;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      {cropperView}
      {controlsView}
    </div>
  );
}

function IconButton({ label, active, onClick, children }) {
  return (
    <button
      onClick={onClick}
      aria-label={label}
      style={{
        width: 40,
        height: 40,
        borderRadius: '50%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        color: 'var(--cream-text)',
        background: active ? 'rgba(35,31,27,0.1)' : 'transparent',
        border: '1px solid var(--cream-hairline)',
      }}
    >
      {children}
    </button>
  );
}

function AdjustSlider({ label, value, onChange }) {
  return (
    <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      <span style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)' }}>{label}</span>
      <input
        type="range"
        min={0}
        max={100}
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        style={{ width: '100%', accentColor: 'var(--cream-cta-fill)' }}
      />
    </label>
  );
}
