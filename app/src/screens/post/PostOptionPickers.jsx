import React, { useState } from 'react';
import { X, Search, Check } from 'lucide-react';

export function OptionPickerOverlay({ title, subtitle, searchHint, options, selectedIds = [], isMulti = false, maxSelections, onClose, onSave }) {
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState(new Set(selectedIds));

  const filteredOptions = options.filter((opt) => opt.name.toLowerCase().includes(search.toLowerCase().trim()));

  const handleToggle = (id) => {
    if (isMulti) {
      const next = new Set(selected);
      if (next.has(id)) {
        next.delete(id);
      } else {
        if (maxSelections && next.size >= maxSelections) return;
        next.add(id);
      }
      setSelected(next);
    } else {
      setSelected(new Set([id]));
    }
  };

  const handleDone = () => {
    onSave(Array.from(selected));
    onClose();
  };

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
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
          <div>
            <h3 style={{ fontFamily: 'var(--font-inter)', fontSize: 17, fontWeight: 500, color: 'var(--cream-text)' }}>{title}</h3>
            {subtitle && <p style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)' }}>{subtitle}</p>}
          </div>
          <button onClick={onClose} aria-label="Close" style={{ padding: 6, color: 'var(--cream-text)' }}>
            <X size={18} strokeWidth={2} />
          </button>
        </div>

        {/* Search Bar */}
        {searchHint && (
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              padding: '0 12px',
              height: 40,
              borderRadius: 10,
              background: 'var(--cream-bg-detail)',
              border: '1px solid rgba(35,31,27,0.12)',
              marginBottom: 14,
            }}
          >
            <Search size={16} color="var(--cream-text-secondary)" />
            <input
              type="text"
              placeholder={searchHint}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              style={{
                flex: 1,
                background: 'transparent',
                border: 'none',
                outline: 'none',
                fontFamily: 'var(--font-inter)',
                fontSize: 14,
                color: 'var(--cream-text)',
              }}
            />
          </div>
        )}

        {/* Options List */}
        <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 6, paddingRight: 4 }}>
          {filteredOptions.length === 0 ? (
            <div style={{ padding: 24, textAlign: 'center', fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text-secondary)' }}>
              No options found
            </div>
          ) : (
            filteredOptions.map((opt) => {
              const isSelected = selected.has(opt.id);
              return (
                <button
                  key={opt.id}
                  onClick={() => handleToggle(opt.id)}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '12px 14px',
                    borderRadius: 10,
                    background: isSelected ? 'rgba(35,31,27,0.06)' : 'transparent',
                    border: '1px solid',
                    borderColor: isSelected ? 'var(--cream-text)' : 'transparent',
                    textAlign: 'left',
                  }}
                >
                  <span style={{ fontFamily: 'var(--font-inter)', fontSize: 14, fontWeight: isSelected ? 500 : 400, color: 'var(--cream-text)' }}>
                    {opt.name}
                  </span>
                  {isSelected && <Check size={16} color="var(--cream-text)" strokeWidth={2.5} />}
                </button>
              );
            })
          )}
        </div>

        {/* Confirm Button */}
        <div style={{ marginTop: 16, paddingTop: 12, borderTop: '1px solid var(--cream-divider)' }}>
          <button
            onClick={handleDone}
            style={{
              width: '100%',
              height: 42,
              borderRadius: 8,
              background: 'var(--cream-cta-fill)',
              color: 'var(--cream-text-inverse)',
              fontFamily: 'var(--font-geist)',
              fontSize: 15,
              fontWeight: 500,
            }}
          >
            Apply Selection
          </button>
        </div>
      </div>
    </div>
  );
}
