import React, { useEffect, useState } from 'react';
import { X, Check, Plus } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { listMyPieces, listMySeries } from '../../services/postingApi';
import { friendlyError } from '../../services/socialApi';

/** Pickers whose options come from the backend (the user's own series / pieces), in the
 * same dialog chrome as OptionPickerOverlay. */

function PickerShell({ title, subtitle, onClose, onApply, applyDisabled, children }) {
  return (
    <div style={{ position: 'fixed', inset: 0, zIndex: 400, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(35,31,27,0.5)', backdropFilter: 'blur(4px)' }} />
      <div
        style={{
          position: 'relative',
          width: 'min(440px, 92vw)',
          maxHeight: 'min(600px, 85vh)',
          borderRadius: 'var(--radius-lg)',
          boxShadow: 'var(--shadow-modal)',
          background: 'var(--cream-bg)',
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
          padding: 20,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
          <div>
            <h3 style={{ fontFamily: 'var(--font-inter)', fontSize: 17, fontWeight: 500, color: 'var(--cream-text)' }}>{title}</h3>
            {subtitle && <p style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)' }}>{subtitle}</p>}
          </div>
          <button onClick={onClose} aria-label="Close" style={{ padding: 6, color: 'var(--cream-text)' }}>
            <X size={18} strokeWidth={2} />
          </button>
        </div>

        <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 6, paddingRight: 4 }}>{children}</div>

        <div style={{ marginTop: 16, paddingTop: 12, borderTop: '1px solid var(--cream-divider)' }}>
          <button
            onClick={onApply}
            disabled={applyDisabled}
            style={{
              width: '100%',
              height: 42,
              borderRadius: 8,
              background: 'var(--cream-cta-fill)',
              color: 'var(--cream-text-inverse)',
              fontFamily: 'var(--font-geist)',
              fontSize: 15,
              fontWeight: 500,
              opacity: applyDisabled ? 0.5 : 1,
            }}
          >
            Apply Selection
          </button>
        </div>
      </div>
    </div>
  );
}

function OptionRow({ selected, onClick, leading, label, detail }) {
  return (
    <button
      onClick={onClick}
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 10,
        padding: '10px 14px',
        borderRadius: 10,
        background: selected ? 'rgba(35,31,27,0.06)' : 'transparent',
        border: '1px solid',
        borderColor: selected ? 'var(--cream-text)' : 'transparent',
        textAlign: 'left',
      }}
    >
      <span style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
        {leading}
        <span style={{ minWidth: 0 }}>
          <span
            style={{
              display: 'block',
              fontFamily: 'var(--font-inter)',
              fontSize: 14,
              fontWeight: selected ? 500 : 400,
              color: 'var(--cream-text)',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
          >
            {label}
          </span>
          {detail && (
            <span style={{ display: 'block', fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)' }}>{detail}</span>
          )}
        </span>
      </span>
      {selected && <Check size={16} color="var(--cream-text)" strokeWidth={2.5} style={{ flexShrink: 0 }} />}
    </button>
  );
}

function StatusText({ children, color = 'var(--cream-text-secondary)' }) {
  return (
    <div style={{ padding: 24, textAlign: 'center', fontFamily: 'var(--font-inter)', fontSize: 13, color }}>{children}</div>
  );
}

/** Loads a list once on mount; `{ items, loading, error }`. */
function useRemoteList(load) {
  const [state, setState] = useState({ items: [], loading: true, error: '' });
  useEffect(() => {
    let cancelled = false;
    load()
      .then((items) => !cancelled && setState({ items, loading: false, error: '' }))
      .catch((e) => !cancelled && setState({ items: [], loading: false, error: friendlyError(e) }));
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return state;
}

/** Existing series or "Create new series". `value`/`onSave` use the form's shape:
 * `null | {id, name} | {newName}` — a new series is created after the piece is. */
export function SeriesPickerOverlay({ value, onClose, onSave }) {
  const { items, loading, error } = useRemoteList(listMySeries);
  const [selectedId, setSelectedId] = useState(value?.newName ? '__new__' : value?.id || null);
  const [newName, setNewName] = useState(value?.newName || '');

  const creating = selectedId === '__new__';
  const apply = () => {
    if (creating) onSave(newName.trim() ? { newName: newName.trim() } : null);
    else if (selectedId) onSave({ id: selectedId, name: items.find((s) => s.id === selectedId)?.name || value?.name || '' });
    else onSave(null);
    onClose();
  };

  return (
    <PickerShell
      title="Series"
      subtitle="Group this piece with related work"
      onClose={onClose}
      onApply={apply}
      applyDisabled={creating && !newName.trim()}
    >
      <OptionRow
        selected={creating}
        onClick={() => setSelectedId(creating ? null : '__new__')}
        leading={<Plus size={16} color="var(--cream-text)" />}
        label="Create new series"
      />
      {creating && (
        <input
          autoFocus
          type="text"
          maxLength={200}
          placeholder="Series name"
          value={newName}
          onChange={(e) => setNewName(e.target.value)}
          style={{
            height: 42,
            margin: '2px 0 6px',
            borderRadius: 10,
            background: 'var(--cream-bg-detail)',
            border: '1px solid rgba(35,31,27,0.15)',
            padding: '0 14px',
            fontFamily: 'var(--font-inter)',
            fontSize: 14,
            color: 'var(--cream-text)',
            outline: 'none',
          }}
        />
      )}
      {loading && <StatusText>Loading your series…</StatusText>}
      {error && <StatusText color="var(--cream-status-error)">{error}</StatusText>}
      {!loading && !error && items.length === 0 && <StatusText>You don’t have any series yet</StatusText>}
      {items.map((s) => (
        <OptionRow
          key={s.id}
          selected={selectedId === s.id}
          onClick={() => setSelectedId(selectedId === s.id ? null : s.id)}
          label={s.name}
          detail={`${s.pieceCount ?? 0} ${s.pieceCount === 1 ? 'piece' : 'pieces'}`}
        />
      ))}
    </PickerShell>
  );
}

/** One of the signed-in user's own pieces (the backend rejects anyone else's). */
export function LinkedPiecePickerOverlay({ value, onClose, onSave }) {
  const { user } = useAuth();
  const { items, loading, error } = useRemoteList(() =>
    user?.username ? listMyPieces(user.username) : Promise.resolve([]),
  );
  const [selectedId, setSelectedId] = useState(value?.id || null);

  const apply = () => {
    const piece = items.find((p) => p.id === selectedId);
    onSave(selectedId ? { id: selectedId, title: piece?.title || value?.title || 'Untitled' } : null);
    onClose();
  };

  return (
    <PickerShell title="Link to a Piece" subtitle="Connect this scene to one of your pieces" onClose={onClose} onApply={apply}>
      {loading && <StatusText>Loading your pieces…</StatusText>}
      {error && <StatusText color="var(--cream-status-error)">{error}</StatusText>}
      {!loading && !error && items.length === 0 && <StatusText>Post a piece first to link it here</StatusText>}
      {items.map((p) => {
        const cover = p.images?.[0]?.mediaUrl || p.mediaUrl;
        return (
          <OptionRow
            key={p.id}
            selected={selectedId === p.id}
            onClick={() => setSelectedId(selectedId === p.id ? null : p.id)}
            leading={
              <span style={{ width: 40, height: 40, borderRadius: 6, overflow: 'hidden', flexShrink: 0, background: '#ded9d1' }}>
                {cover && <img src={cover} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />}
              </span>
            }
            label={p.title || 'Untitled'}
            detail={p.status === 'draft' ? 'Draft' : null}
          />
        );
      })}
    </PickerShell>
  );
}
