import React, { useEffect, useState } from 'react';
import { X } from 'lucide-react';
import { PillInput } from '../inputs/PillInput';
import { PillChip } from '../inputs/PillChip';
import { MATERIAL_OPTIONS, listMyPieces, listMySeries } from '../../lib/postApi';
import { friendlyError } from '../../lib/social';
import { selectStyle } from './FormBits';

/// Materials: catalogue chips by category (like the app's add-materials sheet)
/// plus free-text entries. `value` is a list of material names.
export function MaterialsPicker({ value, onChange }) {
  const [category, setCategory] = useState(null);
  const [draft, setDraft] = useState('');
  const toggle = (name) =>
    onChange(value.includes(name) ? value.filter((m) => m !== name) : [...value, name]);
  const addCustom = () => {
    const name = draft.trim();
    if (name && !value.includes(name)) onChange([...value, name]);
    setDraft('');
  };

  return (
    <div>
      {value.length > 0 && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 10 }}>
          {value.map((m) => (
            <PillChip key={m} selected onClick={() => toggle(m)} style={{ gap: 6 }}>
              {m} <X size={12} />
            </PillChip>
          ))}
        </div>
      )}
      <div style={{ display: 'flex', gap: 8, marginBottom: 10 }}>
        <PillInput
          placeholder="Add a material…"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault();
              addCustom();
            }
          }}
          maxLength={120}
        />
        <button
          type="button"
          onClick={addCustom}
          disabled={!draft.trim()}
          style={{
            flexShrink: 0,
            padding: '0 18px',
            borderRadius: 9999,
            background: draft.trim() ? 'var(--slate-900)' : 'var(--slate-200)',
            color: draft.trim() ? 'var(--white)' : 'var(--slate-500)',
            fontSize: 14,
            fontWeight: 600,
          }}
        >
          Add
        </button>
      </div>
      <div style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 4 }}>
        {Object.keys(MATERIAL_OPTIONS).map((c) => (
          <PillChip
            key={c}
            selected={category === c}
            onClick={() => setCategory(category === c ? null : c)}
            style={{ flexShrink: 0, background: category === c ? undefined : 'var(--white)' }}
          >
            {c}
          </PillChip>
        ))}
      </div>
      {category && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 10 }}>
          {MATERIAL_OPTIONS[category].map((name) => (
            <PillChip key={name} selected={value.includes(name)} onClick={() => toggle(name)}>
              {name}
            </PillChip>
          ))}
        </div>
      )}
    </div>
  );
}

const NEW_SERIES = '__new__';

/// Optional series assignment: none, one of the user's series, or a new one.
export function SeriesPicker({ seriesId, newName, onChange }) {
  const [series, setSeries] = useState(null);
  const [error, setError] = useState(null);
  const creating = newName !== null;

  useEffect(() => {
    let alive = true;
    listMySeries()
      .then((list) => alive && setSeries(list))
      .catch((e) => alive && setError(friendlyError(e)));
    return () => {
      alive = false;
    };
  }, []);

  const selectValue = creating ? NEW_SERIES : seriesId || '';
  return (
    <div>
      <select
        value={selectValue}
        onChange={(e) => {
          const v = e.target.value;
          if (v === NEW_SERIES) onChange({ seriesId: null, newName: '' });
          else onChange({ seriesId: v || null, newName: null });
        }}
        style={selectStyle}
      >
        <option value="">No series</option>
        {(series ?? []).map((s) => (
          <option key={s.id} value={s.id}>
            {s.name}{s.pieceCount != null ? ` (${s.pieceCount})` : ''}
          </option>
        ))}
        <option value={NEW_SERIES}>+ New series…</option>
      </select>
      {series === null && !error && (
        <p style={{ fontSize: 12, color: 'var(--slate-400)', margin: '6px 4px 0' }}>Loading your series…</p>
      )}
      {error && <p style={{ fontSize: 12, color: '#E05252', margin: '6px 4px 0' }}>{error}</p>}
      {creating && (
        <div style={{ marginTop: 10 }}>
          <PillInput
            placeholder="Series name"
            value={newName}
            maxLength={120}
            onChange={(e) => onChange({ seriesId: null, newName: e.target.value })}
          />
        </div>
      )}
    </div>
  );
}

/// "Link to a piece" for scenes: a grid of the user's own pieces.
export function LinkPiecePicker({ username, value, onChange }) {
  const [open, setOpen] = useState(false);
  const [pieces, setPieces] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!open || pieces || !username) return undefined;
    let alive = true;
    setError(null);
    listMyPieces(username)
      .then((list) => alive && setPieces(list))
      .catch((e) => alive && setError(friendlyError(e)));
    return () => {
      alive = false;
    };
  }, [open, pieces, username]);

  const selected = pieces?.find((p) => p.id === value) ?? null;
  const coverOf = (p) => p.images?.[0]?.mediaUrl ?? p.mediaUrl;

  return (
    <div>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        style={{
          width: '100%',
          padding: 14,
          borderRadius: 12,
          border: '1.5px solid var(--slate-200)',
          background: 'var(--white)',
          fontSize: 14,
          color: value ? 'var(--slate-800)' : 'var(--slate-500)',
          textAlign: 'left',
          display: 'flex',
          alignItems: 'center',
          gap: 10,
        }}
      >
        {selected && (
          <img src={coverOf(selected)} alt="" style={{ width: 32, height: 40, borderRadius: 6, objectFit: 'cover' }} />
        )}
        <span style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {selected ? `Linked: ${selected.title || 'Untitled'}` : 'Link to a Piece (optional)'}
        </span>
        <span style={{ color: 'var(--slate-400)' }}>{open ? '▴' : '▾'}</span>
      </button>

      {open && (
        <div style={{ marginTop: 10 }}>
          {error && <p style={{ fontSize: 13, color: '#E05252', margin: '0 4px 8px' }}>{error}</p>}
          {!error && pieces === null && (
            <p style={{ fontSize: 13, color: 'var(--slate-400)', margin: '0 4px' }}>Loading your pieces…</p>
          )}
          {pieces?.length === 0 && (
            <p style={{ fontSize: 13, color: 'var(--slate-500)', margin: '0 4px' }}>
              You haven't posted any pieces yet.
            </p>
          )}
          {pieces?.length > 0 && (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
              {pieces.map((p) => {
                const isSel = p.id === value;
                return (
                  <button
                    key={p.id}
                    type="button"
                    onClick={() => {
                      onChange(isSel ? null : p.id);
                      setOpen(false);
                    }}
                    style={{ padding: 0, textAlign: 'left' }}
                  >
                    <div
                      style={{
                        aspectRatio: '3 / 4',
                        borderRadius: 10,
                        overflow: 'hidden',
                        background: 'var(--slate-100)',
                        border: isSel ? '2px solid var(--slate-900)' : '1.5px solid transparent',
                      }}
                    >
                      {coverOf(p) && (
                        <img src={coverOf(p)} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                      )}
                    </div>
                    <div
                      style={{
                        fontSize: 12,
                        color: 'var(--slate-700)',
                        marginTop: 4,
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        whiteSpace: 'nowrap',
                      }}
                    >
                      {p.title || 'Untitled'}
                      {p.status === 'draft' ? ' · Draft' : ''}
                    </div>
                  </button>
                );
              })}
            </div>
          )}
          {value && (
            <button
              type="button"
              onClick={() => onChange(null)}
              style={{ marginTop: 10, fontSize: 13, color: 'var(--slate-500)', textDecoration: 'underline' }}
            >
              Remove link
            </button>
          )}
        </div>
      )}
    </div>
  );
}
