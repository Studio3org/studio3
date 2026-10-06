import React, { useState } from 'react';
import { Play } from 'lucide-react';

/** Horizontal drag-to-reorder thumbnail strip — index 0 is always "the
 * cover" (derived from array position, not a stored field), matching
 * lib/screens/post_edit_page.dart's `_CoverReorderStrip`. */
export function ReorderStrip({ items, activeId, onSelect, onReorder }) {
  const [dragIndex, setDragIndex] = useState(null);
  const [overIndex, setOverIndex] = useState(null);

  return (
    <div style={{ display: 'flex', gap: 8, overflowX: 'auto', padding: '2px 2px 8px' }}>
      {items.map((item, index) => (
        <div
          key={item.id}
          draggable
          onDragStart={() => setDragIndex(index)}
          onDragOver={(e) => {
            e.preventDefault();
            setOverIndex(index);
          }}
          onDrop={(e) => {
            e.preventDefault();
            if (dragIndex !== null && dragIndex !== index) onReorder(dragIndex, index);
            setDragIndex(null);
            setOverIndex(null);
          }}
          onDragEnd={() => {
            setDragIndex(null);
            setOverIndex(null);
          }}
          onClick={() => onSelect(item.id)}
          style={{
            position: 'relative',
            flexShrink: 0,
            width: 56,
            height: 56,
            borderRadius: 8,
            overflow: 'hidden',
            cursor: 'grab',
            outline: activeId === item.id ? '2px solid var(--cream-cta-fill)' : 'none',
            outlineOffset: 2,
            opacity: overIndex === index && dragIndex !== index ? 0.6 : 1,
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
                  background: 'rgba(35,31,27,0.3)',
                }}
              >
                <Play size={16} color="#fff" fill="#fff" />
              </span>
            </>
          ) : (
            <img src={item.previewUrl} alt="" draggable={false} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          )}
          {index === 0 && (
            <span
              style={{
                position: 'absolute',
                left: 2,
                bottom: 2,
                padding: '1px 5px',
                borderRadius: 6,
                background: 'rgba(35,31,27,0.7)',
                color: '#fff',
                fontSize: 9,
                fontWeight: 600,
                fontFamily: 'var(--font-inter)',
              }}
            >
              Cover
            </span>
          )}
        </div>
      ))}
    </div>
  );
}
