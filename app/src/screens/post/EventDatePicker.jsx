import React, { useState } from 'react';
import { formatEventDate, formatEventTime } from './eventDateUtils';

/** Date/time bottom sheet — ports lib/widgets/create_flow/event_date_sheet.dart.
 * Native `<input type="date"/"time">` stand in for Flutter's showDatePicker/
 * showTimePicker (there's no in-browser equivalent of a custom calendar
 * dialog that beats the platform picker here). Returns
 * `{ multiDay, startDate, endDate, startTime, endTime }` via `onSave`. */
export function EventDatePicker({ initial, onClose, onSave }) {
  const [multiDay, setMultiDay] = useState(initial?.multiDay ?? false);
  const [startDate, setStartDate] = useState(initial?.startDate ?? '');
  const [endDate, setEndDate] = useState(initial?.endDate ?? '');
  const [startTime, setStartTime] = useState(initial?.startTime ?? '');
  const [endTime, setEndTime] = useState(initial?.endTime ?? '');

  const canSubmit = Boolean(startDate) && (!multiDay || Boolean(endDate));

  const handleDone = () => {
    if (!canSubmit) return;
    onSave({
      multiDay,
      startDate,
      endDate: multiDay ? endDate : null,
      startTime: startTime || null,
      endTime: endTime || null,
    });
    onClose();
  };

  return (
    <div style={{ position: 'fixed', inset: 0, zIndex: 400, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}>
      <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.5)' }} />
      <div
        style={{
          position: 'relative',
          width: '100%',
          maxWidth: 480,
          background: 'var(--cream-bg)',
          borderRadius: '16px 16px 0 0',
          padding: '10px 16px 24px',
        }}
      >
        <div style={{ width: 36, height: 4, borderRadius: 2, background: 'var(--cream-title-hairline)', margin: '0 auto 20px' }} />
        <h2 style={{ fontFamily: 'var(--font-geist)', fontSize: 20, fontWeight: 600, color: 'var(--cream-text)', marginBottom: 20 }}>Date</h2>

        <div style={{ display: 'flex', alignItems: 'center', marginBottom: 16 }}>
          <span style={{ flex: 1, fontFamily: 'var(--font-geist)', fontSize: 13, fontWeight: 500, color: 'var(--cream-text)' }}>Multi-day event</span>
          <MiniToggle
            checked={multiDay}
            onChange={(v) => {
              setMultiDay(v);
              if (!v) setEndDate('');
            }}
          />
        </div>

        <LabeledDateField label={multiDay ? 'Start date' : 'Date'} value={startDate} onChange={setStartDate} />

        {multiDay && (
          <div style={{ marginTop: 16 }}>
            <LabeledDateField label="End date" value={endDate} onChange={setEndDate} min={startDate || undefined} />
          </div>
        )}

        <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
          <LabeledTimeField label="Start time" value={startTime} onChange={setStartTime} />
          <LabeledTimeField label="End time" value={endTime} onChange={setEndTime} />
        </div>

        <button
          onClick={handleDone}
          disabled={!canSubmit}
          style={{
            width: '100%',
            height: 40,
            marginTop: 24,
            borderRadius: 8,
            background: canSubmit ? 'var(--cream-cta-fill)' : 'var(--cream-title-hairline)',
            color: canSubmit ? 'var(--cream-text-inverse)' : 'var(--cream-text)',
            fontFamily: 'var(--font-geist)',
            fontSize: 16,
          }}
        >
          Done
        </button>
      </div>
    </div>
  );
}

function LabeledDateField({ label, value, onChange, min }) {
  return (
    <label style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <span style={{ fontFamily: 'var(--font-geist)', fontSize: 13, fontWeight: 500, color: 'var(--cream-text-secondary)' }}>{label}</span>
      <input
        type="date"
        value={value}
        min={min}
        onChange={(e) => onChange(e.target.value)}
        style={{
          height: 40,
          borderRadius: 8,
          border: '1px solid var(--cream-text)',
          padding: '0 12px',
          fontFamily: 'var(--font-geist)',
          fontSize: 13,
          color: 'var(--cream-text)',
          background: 'transparent',
        }}
      />
    </label>
  );
}

function LabeledTimeField({ label, value, onChange }) {
  return (
    <label style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
      <span style={{ fontFamily: 'var(--font-geist)', fontSize: 13, fontWeight: 500, color: 'var(--cream-text-secondary)' }}>{label}</span>
      <input
        type="time"
        value={value}
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
    </label>
  );
}

function MiniToggle({ checked, onChange }) {
  return (
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
  );
}

export { formatEventDate, formatEventTime };
