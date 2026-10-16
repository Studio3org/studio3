import React, { useState } from 'react';
import { ChevronLeft } from 'lucide-react';
import { youReceive } from './eventTicketUtils';

/** Full-screen "Edit ticket" overlay — ports
 * lib/widgets/create_flow/event_ticket_edit_page.dart. Opened for both
 * "+ Add ticket type" and tapping "Edit" on an existing tier; returns the
 * saved tier via `onSave`, or nothing on close/cancel. */
export function EventTicketEditor({ initial, onClose, onSave }) {
  const [name, setName] = useState(initial.name);
  const [isFree, setIsFree] = useState(initial.isFree);
  const [buyerPaysStr, setBuyerPaysStr] = useState(initial.buyerPays != null ? String(initial.buyerPays) : '');
  const [limitWindow, setLimitWindow] = useState(initial.limitPurchaseWindow);
  const [startsSelling, setStartsSelling] = useState(initial.startsSelling || '');
  const [stopsSelling, setStopsSelling] = useState(initial.stopsSelling || '');
  const [description, setDescription] = useState(initial.description);
  const [limitQuantity, setLimitQuantity] = useState(initial.limitQuantity);
  const [quantityStr, setQuantityStr] = useState(initial.quantity != null ? String(initial.quantity) : '');
  const [limitPerOrder, setLimitPerOrder] = useState(initial.limitPerOrder);
  const [perOrderStr, setPerOrderStr] = useState(initial.perOrder != null ? String(initial.perOrder) : '');

  const buyerPays = (() => {
    const parsed = Number.parseFloat(buyerPaysStr);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
  })();
  const canSave = name.trim().length > 0 && (isFree || buyerPays != null);

  const handleSave = () => {
    if (!canSave) return;
    onSave({
      name: name.trim(),
      isFree,
      buyerPays: isFree ? null : buyerPays,
      limitPurchaseWindow: limitWindow,
      startsSelling: limitWindow ? startsSelling || null : null,
      stopsSelling: limitWindow ? stopsSelling || null : null,
      description: description.trim(),
      limitQuantity,
      quantity: limitQuantity ? Number.parseInt(quantityStr, 10) || null : null,
      limitPerOrder,
      perOrder: limitPerOrder ? Number.parseInt(perOrderStr, 10) || null : null,
    });
    onClose();
  };

  return (
    <div style={{ position: 'fixed', inset: 0, zIndex: 500, background: 'var(--cream-bg)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ height: 53, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', padding: '0 16px', flexShrink: 0 }}>
        <button onClick={onClose} aria-label="Back" style={{ position: 'absolute', left: 12, color: 'var(--cream-text)' }}>
          <ChevronLeft size={18} strokeWidth={2} />
        </button>
        <span style={{ fontFamily: 'var(--font-geist)', fontSize: 16, fontWeight: 500, color: 'var(--cream-text)' }}>Edit ticket</span>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '8px 24px 24px', display: 'flex', flexDirection: 'column', gap: 24 }}>
        <Field label="Name">
          <OutlineInput value={name} onChange={setName} placeholder="General Admission" />
        </Field>

        <ToggleRow label="Make this ticket type free" checked={isFree} onChange={setIsFree} />

        {!isFree && (
          <div style={{ display: 'flex', gap: 10 }}>
            <Field label="Buyer pays" style={{ flex: 1 }}>
              <PriceInput value={buyerPaysStr} onChange={setBuyerPaysStr} />
            </Field>
            <Field label="You receive" style={{ flex: 1 }}>
              <PriceDisplay value={buyerPays != null ? youReceive(buyerPays).toFixed(2) : ''} />
            </Field>
          </div>
        )}

        <ToggleRow label="Limit when this can be purchased" checked={limitWindow} onChange={setLimitWindow} />

        {limitWindow && (
          <div style={{ display: 'flex', gap: 10 }}>
            <Field label="Starts selling" style={{ flex: 1 }}>
              <DateTapInput value={startsSelling} onChange={setStartsSelling} />
            </Field>
            <Field label="Stops selling" style={{ flex: 1 }}>
              <DateTapInput value={stopsSelling} onChange={setStopsSelling} />
            </Field>
          </div>
        )}

        <Field label="Description">
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="What's included with this ticket?"
            rows={3}
            style={{
              width: '100%',
              borderRadius: 8,
              border: '1px solid var(--cream-text)',
              padding: 12,
              fontFamily: 'var(--font-geist)',
              fontSize: 12,
              color: 'var(--cream-text)',
              resize: 'vertical',
              outline: 'none',
            }}
          />
        </Field>

        <ToggleRow label="Limit quantity" checked={limitQuantity} onChange={setLimitQuantity} />
        {limitQuantity && (
          <div style={{ marginTop: -12 }}>
            <OutlineInput value={quantityStr} onChange={(v) => setQuantityStr(v.replace(/[^0-9]/g, ''))} placeholder="100" inputMode="numeric" />
          </div>
        )}

        <ToggleRow label="Limit purchase per order" checked={limitPerOrder} onChange={setLimitPerOrder} />
        {limitPerOrder && (
          <div style={{ marginTop: -12 }}>
            <OutlineInput value={perOrderStr} onChange={(v) => setPerOrderStr(v.replace(/[^0-9]/g, ''))} placeholder="4" inputMode="numeric" />
          </div>
        )}
      </div>

      <div style={{ padding: '16px 10px', flexShrink: 0 }}>
        <button
          onClick={handleSave}
          disabled={!canSave}
          style={{
            width: '100%',
            height: 40,
            borderRadius: 8,
            background: canSave ? 'var(--cream-cta-fill)' : 'var(--cream-title-hairline)',
            color: canSave ? 'var(--cream-text-inverse)' : 'var(--cream-text)',
            fontFamily: 'var(--font-geist)',
            fontSize: 16,
          }}
        >
          Save and continue
        </button>
      </div>
    </div>
  );
}

function Field({ label, children, style }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8, ...style }}>
      <span style={{ fontFamily: 'var(--font-geist)', fontSize: 13, fontWeight: 500, color: 'var(--cream-text-secondary)' }}>{label}</span>
      {children}
    </div>
  );
}

function OutlineInput({ value, onChange, placeholder, inputMode }) {
  return (
    <input
      type="text"
      inputMode={inputMode}
      value={value}
      placeholder={placeholder}
      onChange={(e) => onChange(e.target.value)}
      style={{
        height: 40,
        width: '100%',
        borderRadius: 8,
        border: '1px solid var(--cream-text)',
        padding: '0 12px',
        fontFamily: 'var(--font-geist)',
        fontSize: 13,
        color: 'var(--cream-text)',
        background: 'transparent',
      }}
    />
  );
}

function PriceInput({ value, onChange }) {
  return (
    <div style={{ height: 40, borderRadius: 8, border: '1px solid var(--cream-text)', display: 'flex', alignItems: 'center', padding: '0 12px' }}>
      <span style={{ fontFamily: 'var(--font-geist)', fontSize: 10, color: 'var(--cream-text-secondary)', marginRight: 4 }}>$</span>
      <input
        type="text"
        inputMode="decimal"
        value={value}
        onChange={(e) => onChange(e.target.value.replace(/[^0-9.]/g, ''))}
        style={{ flex: 1, border: 'none', outline: 'none', background: 'transparent', fontFamily: 'var(--font-geist)', fontSize: 13, color: 'var(--cream-text)' }}
      />
    </div>
  );
}

function PriceDisplay({ value }) {
  return (
    <div
      style={{
        height: 40,
        borderRadius: 8,
        border: '1px solid var(--cream-text)',
        background: 'var(--cream-skeleton)',
        display: 'flex',
        alignItems: 'center',
        padding: '0 12px',
      }}
    >
      <span style={{ fontFamily: 'var(--font-geist)', fontSize: 10, color: 'var(--cream-text-secondary)', marginRight: 4 }}>$</span>
      <span style={{ fontFamily: 'var(--font-geist)', fontSize: 13, color: 'var(--cream-text)' }}>{value}</span>
    </div>
  );
}

function DateTapInput({ value, onChange }) {
  return (
    <input
      type="date"
      value={value || ''}
      onChange={(e) => onChange(e.target.value)}
      style={{
        height: 40,
        width: '100%',
        borderRadius: 8,
        border: '1px solid var(--cream-text)',
        padding: '0 12px',
        fontFamily: 'var(--font-geist)',
        fontSize: 13,
        color: 'var(--cream-text)',
        background: 'transparent',
      }}
    />
  );
}

function ToggleRow({ label, checked, onChange }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center' }}>
      <span style={{ flex: 1, fontFamily: 'var(--font-geist)', fontSize: 13, fontWeight: 500, color: 'var(--cream-text)' }}>{label}</span>
      <button
        onClick={() => onChange(!checked)}
        style={{
          width: 40,
          height: 24,
          borderRadius: 12,
          background: checked ? 'var(--cream-cta-fill)' : 'var(--cream-title-hairline)',
          position: 'relative',
          flexShrink: 0,
        }}
      >
        <span
          style={{
            position: 'absolute',
            top: 2,
            left: checked ? 18 : 2,
            width: 20,
            height: 20,
            borderRadius: '50%',
            background: '#fff',
            transition: 'left 0.15s',
          }}
        />
      </button>
    </div>
  );
}
