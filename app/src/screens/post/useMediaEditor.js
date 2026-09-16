import { useCallback, useRef, useState } from 'react';

let nextId = 0;
const genId = () => `media-${Date.now()}-${nextId++}`;

function defaultTransform() {
  return {
    croppedAreaPixels: null,
    zoom: 1,
    crop: { x: 0, y: 0 },
    rotationDegrees: 0,
    flipHorizontal: false,
    flipVertical: false,
    brightness: 50,
    contrast: 50,
    exposure: 50,
  };
}

function isVideoFile(file) {
  return file.type.startsWith('video');
}

/**
 * Multi-item media selection + per-item edit transform for the Post flow's
 * Gallery/Edit steps — ports the cap/mutual-exclusivity rules from
 * lib/widgets/post_gallery/post_gallery_picker.dart's `_toggleSelect`:
 * Piece = up to 5 images. Scene = exactly 1 item, image OR video (picking
 * one clears the other).
 */
export function useMediaEditor(type) {
  const maxItems = type === 'piece' ? 5 : 1;
  const [items, setItems] = useState([]);
  const [activeEditId, setActiveEditId] = useState(null);
  const urlsRef = useRef(new Map());

  const previewUrlFor = (file) => {
    if (urlsRef.current.has(file)) return urlsRef.current.get(file);
    const url = URL.createObjectURL(file);
    urlsRef.current.set(file, url);
    return url;
  };

  const addFiles = useCallback(
    (fileList) => {
      const files = Array.from(fileList || []);
      if (files.length === 0) return;

      setItems((current) => {
        let next = current;
        const incomingVideo = files.some(isVideoFile);
        const incomingImages = files.filter((f) => !isVideoFile(f));

        if (type === 'scene') {
          // Scene: single item, image-or-video, mutually exclusive — a new
          // pick of either kind replaces whatever's currently selected.
          const chosen = incomingVideo ? files.find(isVideoFile) : incomingImages[0];
          if (!chosen) return current;
          return [
            {
              id: genId(),
              file: chosen,
              mediaType: isVideoFile(chosen) ? 'video' : 'image',
              previewUrl: previewUrlFor(chosen),
              transform: defaultTransform(),
            },
          ];
        }

        // Piece: images only, cap at maxItems, silently ignore the rest.
        const room = maxItems - next.length;
        if (room <= 0) return next;
        const toAdd = incomingImages.slice(0, room).map((file) => ({
          id: genId(),
          file,
          mediaType: 'image',
          previewUrl: previewUrlFor(file),
          transform: defaultTransform(),
        }));
        return [...next, ...toAdd];
      });
    },
    [type, maxItems],
  );

  const removeItem = useCallback((id) => {
    setItems((current) => current.filter((item) => item.id !== id));
    setActiveEditId((current) => (current === id ? null : current));
  }, []);

  const reorderItems = useCallback((fromIndex, toIndex) => {
    setItems((current) => {
      if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0) return current;
      if (fromIndex >= current.length || toIndex >= current.length) return current;
      const next = [...current];
      const [moved] = next.splice(fromIndex, 1);
      next.splice(toIndex, 0, moved);
      return next;
    });
  }, []);

  const updateTransform = useCallback((id, patch) => {
    setItems((current) =>
      current.map((item) => (item.id === id ? { ...item, transform: { ...item.transform, ...patch } } : item)),
    );
  }, []);

  const resetTransform = useCallback((id) => {
    setItems((current) => current.map((item) => (item.id === id ? { ...item, transform: defaultTransform() } : item)));
  }, []);

  return {
    items,
    maxItems,
    addFiles,
    removeItem,
    reorderItems,
    updateTransform,
    resetTransform,
    activeEditId,
    setActiveEditId,
    hasVideo: items[0]?.mediaType === 'video',
  };
}
