import React, { useState } from 'react';
import { ChevronRightIcon } from '../../components/icons/PostIcons';
import { OptionPickerOverlay } from './PostOptionPickers';
import { LOCATION_OPTIONS, EVENT_CATEGORY_OPTIONS } from './PostPickerOptions';
import { EventDatePicker } from './EventDatePicker';
import { EventTicketEditor } from './EventTicketEditor';
import { TICKET_ACCENT, ticketDescriptionLine, ticketPriceLine, ticketPriceLineIsHint, ticketPerOrderLine, newTicketTier } from './eventTicketUtils';

/** Horizontal step row — ports event_create_page.dart's `_stepper()`: a
 * step label is only tappable when `i <= wizardStep` (jumping back re-locks
 * everything ahead of it). */
export function EventStepper({ form }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '24px 24px 0' }}>
      {form.STEPS.map((label, i) => {
        const active = i === form.wizardStep;
        return (
          <button
            key={label}
            onClick={() => form.goWizardStep(i)}
            style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 6 }}
          >
            <span
              style={{
                fontFamily: 'var(--font-geist)',
                fontSize: 13,
                fontWeight: active ? 500 : 400,
                color: active ? 'var(--cream-text)' : 'var(--cream-text-secondary)',
              }}
            >
              {label}
            </span>
            <span style={{ width: 47, height: 2, borderRadius: 6, background: active ? 'var(--cream-text)' : 'transparent' }} />
          </button>
        );
      })}
    </div>
  );
}

export function EventDetailsStep({ form }) {
  const [activePicker, setActivePicker] = useState(null);

  const categoryName = EVENT_CATEGORY_OPTIONS.find((c) => c.id === form.categoryId)?.name;
  const locationName = LOCATION_OPTIONS.find((l) => l.id === form.location)?.name || form.location || null;

  return (
    <div>
      <LabeledOutlineField
        label="Title"
        value={form.title}
        onChange={form.setTitle}
        placeholder="Give this event a name"
        section
      />
      <LabeledOutlineField
        label="Description"
        value={form.description}
        onChange={form.setDescription}
        placeholder="Tell us what was happening in the studio. The more you share, the further it travels."
        multiline
        section
      />

      <div style={{ padding: '24px 24px 8px', display: 'flex', flexDirection: 'column', gap: 24 }}>
        <NavRow label="Location" trailing={locationName} onClick={() => setActivePicker('location')} />
        <NavRow label="Date" trailing={form.eventDateSummary} onClick={() => setActivePicker('date')} />
        <NavRow label="Category" trailing={categoryName} onClick={() => setActivePicker('category')} />

        <div style={{ display: 'flex', alignItems: 'center' }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: 'var(--font-geist)', fontSize: 13, fontWeight: 500, color: 'var(--cream-text)' }}>Public</div>
            <div style={{ fontFamily: 'var(--font-geist)', fontSize: 12, color: 'var(--cream-text-secondary)', marginTop: 4 }}>
              Off shows this only to people you share it with
            </div>
          </div>
          <Toggle checked={form.isPublic} onChange={form.setIsPublic} />
        </div>
      </div>

      {activePicker === 'location' && (
        <OptionPickerOverlay
          title="Add location"
          subtitle="Choose one"
          searchHint="Search locations"
          options={LOCATION_OPTIONS}
          selectedIds={form.location ? [form.location] : []}
          onClose={() => setActivePicker(null)}
          onSave={(ids) => form.setLocation(ids[0] || '')}
        />
      )}

      {activePicker === 'category' && (
        <OptionPickerOverlay
          title="Add Category"
          subtitle="Choose one"
          searchHint="Search category"
          options={EVENT_CATEGORY_OPTIONS}
          selectedIds={form.categoryId ? [form.categoryId] : []}
          onClose={() => setActivePicker(null)}
          onSave={(ids) => form.setCategoryId(ids[0] || '')}
        />
      )}

      {activePicker === 'date' && (
        <EventDatePicker
          initial={form.eventDate}
          onClose={() => setActivePicker(null)}
          onSave={form.setEventDate}
        />
      )}
    </div>
  );
}

export function EventTicketsStep({ form }) {
  const [editingIndex, setEditingIndex] = useState(null); // number = editing existing, 'new' = adding
  const editorInitial = editingIndex === 'new' ? newTicketTier(form.tickets.length === 0 ? 'General Admission' : '') : editingIndex != null ? form.tickets[editingIndex] : null;

  return (
    <div>
      <Section>
        <SectionLabel>Is this a paid event?</SectionLabel>
        <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
          <ChoiceButton label="Yes" selected={form.paid === true} onClick={() => form.choosePaid(true)} />
          <ChoiceButton label="Free/RSVP" selected={form.paid === false} onClick={() => form.choosePaid(false)} />
        </div>
      </Section>

      {form.paid === true && (
        <Section>
          <SectionLabel>Ticket Tiers</SectionLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginTop: 16 }}>
            {form.tickets.map((ticket, i) => (
              <TicketTierCard key={i} ticket={ticket} onEdit={() => setEditingIndex(i)} />
            ))}
          </div>
          <button
            onClick={() => setEditingIndex('new')}
            style={{ marginTop: 16, fontFamily: 'var(--font-geist)', fontSize: 13, fontWeight: 500, color: TICKET_ACCENT }}
          >
            + Add ticket type
          </button>
        </Section>
      )}

      {editorInitial && (
        <EventTicketEditor
          initial={editorInitial}
          onClose={() => setEditingIndex(null)}
          onSave={(ticket) => (editingIndex === 'new' ? form.addTicket(ticket) : form.updateTicket(editingIndex, ticket))}
        />
      )}
    </div>
  );
}

function TicketTierCard({ ticket, onEdit }) {
  const description = ticketDescriptionLine(ticket);
  const perOrder = ticketPerOrderLine(ticket);
  const priceIsHint = ticketPriceLineIsHint(ticket);
  return (
    <div style={{ border: '1px solid var(--cream-text)', borderRadius: 8, padding: 12 }}>
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
        <span style={{ flex: 1, fontFamily: 'var(--font-geist)', fontSize: 13, fontWeight: 500, color: 'var(--cream-text)' }}>
          {ticket.name.trim() || 'Untitled ticket'}
        </span>
        <button onClick={onEdit} style={{ fontFamily: 'var(--font-geist)', fontSize: 12, fontWeight: 500, color: TICKET_ACCENT }}>
          Edit
        </button>
      </div>
      <div style={{ fontFamily: 'var(--font-geist)', fontSize: 12, color: 'var(--cream-text-secondary)', marginTop: 4 }}>
        {description || 'No description yet'}
      </div>
      <div style={{ fontFamily: 'var(--font-geist)', fontSize: 12, color: priceIsHint ? TICKET_ACCENT : 'var(--cream-text)', marginTop: 2 }}>
        {ticketPriceLine(ticket)}
      </div>
      {perOrder && (
        <div style={{ fontFamily: 'var(--font-geist)', fontSize: 12, color: 'var(--cream-text-secondary)', marginTop: 2 }}>{perOrder}</div>
      )}
    </div>
  );
}

export function EventLineupStep({ form }) {
  return (
    <div style={{ padding: '16px 24px 0' }}>
      <div style={{ fontFamily: 'var(--font-geist)', fontSize: 13, fontWeight: 500, color: 'var(--cream-text-secondary)', marginBottom: 8 }}>
        Featured artists
      </div>
      <input
        type="text"
        value={form.lineup}
        onChange={(e) => form.setLineup(e.target.value)}
        placeholder="Amara, Cedric, Daisy"
        style={{
          width: '100%',
          height: 32,
          border: 'none',
          borderBottom: '1px solid var(--cream-title-hairline)',
          fontFamily: 'var(--font-geist)',
          fontSize: 16,
          color: 'var(--cream-text)',
          background: 'transparent',
          outline: 'none',
        }}
      />
    </div>
  );
}

export function EventReviewStep({ form }) {
  const categoryName = EVENT_CATEGORY_OPTIONS.find((c) => c.id === form.categoryId)?.name;
  const locationName = LOCATION_OPTIONS.find((l) => l.id === form.location)?.name || form.location || null;

  return (
    <div style={{ padding: '24px 24px 16px', display: 'flex', flexDirection: 'column', gap: 4 }}>
      <div style={{ fontFamily: 'var(--font-geist)', fontSize: 16, fontWeight: 500, color: 'var(--cream-text)', marginBottom: 4 }}>
        {form.title.trim() || 'Untitled event'}
      </div>
      <ReviewLine>{form.paid === true ? 'Paid event' : 'Free / RSVP'}</ReviewLine>
      {form.paid === true &&
        form.tickets
          .filter((t) => t.name.trim() && (t.isFree || (t.buyerPays != null && t.buyerPays > 0)))
          .map((t, i) => <ReviewLine key={i}>{`${t.name} · ${ticketPriceLine(t)}`}</ReviewLine>)}
      {locationName && <ReviewLine>{locationName}</ReviewLine>}
      {form.eventDateSummary && <ReviewLine>{form.eventDateSummary}</ReviewLine>}
      {categoryName && <ReviewLine>{categoryName}</ReviewLine>}
      {form.lineup.trim() && <ReviewLine>{form.lineup.trim()}</ReviewLine>}
      <ReviewLine>{form.isPublic ? 'Public' : 'Not public'}</ReviewLine>
      {form.error && <div style={{ fontFamily: 'var(--font-geist)', fontSize: 13, color: 'var(--cream-status-error)', marginTop: 8 }}>{form.error}</div>}
    </div>
  );
}

function ReviewLine({ children }) {
  return <div style={{ fontFamily: 'var(--font-geist)', fontSize: 13, color: 'var(--cream-text)' }}>{children}</div>;
}

export function EventPublishFooter({ form }) {
  return (
    <button
      onClick={form.advance}
      disabled={!form.canAdvance || form.publishing}
      style={{
        width: '100%',
        height: 40,
        borderRadius: 8,
        background: 'var(--cream-cta-fill)',
        color: 'var(--cream-text-inverse)',
        fontFamily: 'var(--font-geist)',
        fontSize: 16,
        opacity: !form.canAdvance || form.publishing ? 0.5 : 1,
      }}
    >
      {form.publishing ? 'Publishing…' : form.wizardStep === form.STEPS.length - 1 ? 'Publish event' : 'Save and continue'}
    </button>
  );
}

function Section({ children }) {
  return <div style={{ padding: '24px 24px 16px', borderBottom: '0.5px solid var(--cream-title-hairline)' }}>{children}</div>;
}

function SectionLabel({ children }) {
  return <div style={{ fontFamily: 'var(--font-geist)', fontSize: 13, fontWeight: 500, color: 'var(--cream-text-secondary)' }}>{children}</div>;
}

function ChoiceButton({ label, selected, onClick }) {
  return (
    <button
      onClick={onClick}
      style={{
        flex: 1,
        height: 40,
        borderRadius: 8,
        background: selected ? 'var(--cream-cta-fill)' : 'transparent',
        border: selected ? 'none' : '1px solid var(--cream-text)',
        color: selected ? 'var(--cream-text-inverse)' : 'var(--cream-text)',
        fontFamily: 'var(--font-geist)',
        fontSize: 16,
      }}
    >
      {label}
    </button>
  );
}

function NavRow({ label, trailing, onClick }) {
  return (
    <button onClick={onClick} style={{ display: 'flex', alignItems: 'center', height: 28, width: '100%', textAlign: 'left' }}>
      <span style={{ fontFamily: 'var(--font-geist)', fontSize: 13, fontWeight: 500, color: 'var(--cream-text)' }}>{label}</span>
      {trailing ? (
        <span
          style={{
            flex: 1,
            marginLeft: 12,
            textAlign: 'right',
            fontFamily: 'var(--font-geist)',
            fontSize: 12,
            color: 'var(--cream-text-secondary)',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {trailing}
        </span>
      ) : (
        <span style={{ flex: 1 }} />
      )}
      <ChevronRightIcon width={5} height={8} color="var(--cream-text-secondary)" style={{ marginLeft: 8 }} />
    </button>
  );
}

function LabeledOutlineField({ label, value, onChange, placeholder, multiline, section }) {
  const field = multiline ? (
    <textarea
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      rows={4}
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
  ) : (
    <input
      type="text"
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      style={{
        height: 40,
        width: '100%',
        borderRadius: 8,
        border: '1px solid var(--cream-text)',
        padding: '0 12px',
        fontFamily: 'var(--font-geist)',
        fontSize: 13,
        color: 'var(--cream-text)',
        outline: 'none',
        background: 'transparent',
      }}
    />
  );

  const content = (
    <div>
      <div style={{ fontFamily: 'var(--font-geist)', fontSize: 13, fontWeight: 500, color: 'var(--cream-text-secondary)', marginBottom: multiline ? 16 : 8 }}>
        {label}
      </div>
      {field}
    </div>
  );

  return section ? <div style={{ padding: '10px 24px', borderBottom: '0.5px solid var(--cream-title-hairline)' }}>{content}</div> : content;
}

function Toggle({ checked, onChange }) {
  return (
    <button
      onClick={() => onChange(!checked)}
      style={{
        width: 44,
        height: 26,
        borderRadius: 13,
        background: checked ? 'var(--cream-cta-fill)' : 'var(--cream-title-hairline)',
        position: 'relative',
        flexShrink: 0,
      }}
    >
      <span
        style={{
          position: 'absolute',
          top: 2,
          left: checked ? 20 : 2,
          width: 22,
          height: 22,
          borderRadius: '50%',
          background: '#fff',
          transition: 'left 0.15s',
        }}
      />
    </button>
  );
}
