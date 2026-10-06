import React, { useEffect } from 'react';
import { Plus } from 'lucide-react';
import { ImageCropEditor } from './ImageCropEditor';
import { ReorderStrip } from './ReorderStrip';

/** Drag-to-reorder strip (cover = position 0) + the focused item's crop/
 * rotate/adjust editor — mirrors lib/screens/post_edit_page.dart. */
export function MediaEditStep({ type, form }) {
  const { media } = form;
  const activeItem = media.items.find((item) => item.id === media.activeEditId) || media.items[0];

  useEffect(() => {
    if (!media.activeEditId && media.items[0]) media.setActiveEditId(media.items[0].id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [media.activeEditId, media.items[0]?.id]);

  if (!activeItem) return null;

  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
        gap: 24,
        alignItems: 'start',
      }}
    >
      {/* Left Column: Crop Canvas */}
      <div style={{ width: '100%', minWidth: 0 }}>
        <ImageCropEditor
          key={activeItem.id}
          type={type}
          item={activeItem}
          onChange={(patch) => media.updateTransform(activeItem.id, patch)}
          cropperOnly
        />
      </div>

      {/* Right Column: Reorder Strip & Tool Controls */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16, minWidth: 0 }}>
        {/* Reorder Thumbnails Strip */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, overflowX: 'auto', paddingBottom: 4 }}>
          <ReorderStrip
            items={media.items}
            activeId={activeItem.id}
            onSelect={media.setActiveEditId}
            onReorder={media.reorderItems}
          />
          {media.items.length < media.maxItems && (
            <button
              onClick={form.goToGallery}
              aria-label="Add more"
              style={{
                flexShrink: 0,
                width: 56,
                height: 56,
                borderRadius: 8,
                border: '1px dashed var(--cream-hairline)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'var(--cream-text-secondary)',
              }}
            >
              <Plus size={20} strokeWidth={1.75} />
            </button>
          )}
        </div>

        {/* Controls (Aspect, Rotate, Sliders) */}
        <ImageCropEditor
          key={`controls-${activeItem.id}`}
          type={type}
          item={activeItem}
          onChange={(patch) => media.updateTransform(activeItem.id, patch)}
          controlsOnly
        />

        <button
          onClick={form.goToTabs}
          style={{
            width: '100%',
            height: 44,
            borderRadius: 10,
            background: 'var(--cream-cta-fill)',
            color: 'var(--cream-text-inverse)',
            fontFamily: 'var(--font-geist)',
            fontSize: 16,
            fontWeight: 500,
            marginTop: 8,
          }}
        >
          Next
        </button>
      </div>
    </div>
  );
}
