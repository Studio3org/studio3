import React, { useRef } from 'react';
import { ImageIcon, Send } from 'lucide-react';

const IMAGE_TYPES = 'image/jpeg,image/png,image/webp';

/**
 * The thread's bottom bar: attach-image button, text field, send. Sticky so it
 * stays in reach whichever ancestor (window or the inbox pane) scrolls. When
 * `disabledNote` is set the bar is replaced by that note (closed threads).
 *
 * @param {object} props
 * @param {string} props.value
 * @param {(v: string) => void} props.onChange
 * @param {() => void} props.onSend
 * @param {(file: File) => void} [props.onPickImage]
 * @param {boolean} [props.busy] Disables send/attach while an upload or send is in flight.
 * @param {string|null} [props.disabledNote]
 */
export function ChatComposer({ value, onChange, onSend, onPickImage, busy = false, disabledNote = null }) {
  const fileRef = useRef(null);

  if (disabledNote) {
    return (
      <div
        style={{
          position: 'sticky',
          bottom: 0,
          background: 'var(--chat-header-bg)',
          padding: '14px 16px',
          textAlign: 'center',
          fontFamily: 'var(--font-inter)',
          fontSize: 13,
          color: 'var(--chat-timestamp)',
        }}
      >
        {disabledNote}
      </div>
    );
  }

  return (
    <div style={{ position: 'sticky', bottom: 0, background: 'var(--chat-header-bg)', padding: '12px', display: 'flex', alignItems: 'center', gap: 10 }}>
      <input
        ref={fileRef}
        type="file"
        accept={IMAGE_TYPES}
        style={{ display: 'none' }}
        onChange={(e) => {
          const file = e.target.files?.[0];
          e.target.value = '';
          if (file) onPickImage?.(file);
        }}
      />
      <button
        aria-label="Attach image"
        disabled={busy || !onPickImage}
        onClick={() => fileRef.current?.click()}
        style={{ color: 'var(--cream-text)', opacity: busy ? 0.4 : 1 }}
      >
        <ImageIcon size={22} strokeWidth={1.75} />
      </button>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={(e) => e.key === 'Enter' && !e.nativeEvent.isComposing && onSend()}
        placeholder="Message..."
        style={{
          flex: 1,
          minWidth: 0,
          height: 40,
          borderRadius: 9999,
          border: '1px solid var(--slate-200)',
          background: '#fff',
          padding: '0 16px',
          fontFamily: 'var(--font-inter)',
          fontSize: 14,
          outline: 'none',
        }}
      />
      <button onClick={onSend} disabled={busy} aria-label="Send" style={{ color: 'var(--slate-900)', opacity: busy ? 0.4 : 1 }}>
        <Send size={20} strokeWidth={1.75} />
      </button>
    </div>
  );
}

/** Same check the composer's file picker applies, for files that reach us another way. */
export function isSendableImage(file) {
  return Boolean(file) && IMAGE_TYPES.split(',').includes(file.type);
}
