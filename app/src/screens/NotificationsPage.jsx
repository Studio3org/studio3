import React from 'react';
import { GlassCard } from '../components/design/GlassCard';
import { SafeArea } from '../components/layout/SafeArea';

const rowStyle = {
  display: 'flex',
  alignItems: 'center',
  gap: 12,
  padding: 12,
  marginBottom: 8,
  boxShadow: 'var(--shadow-card)',
};

const mockActivity = [
  { id: 1, type: 'save', name: 'Alex Chen', text: "saved your piece **'Coastal Forms #3'**", time: '2h', thumb: true },
  { id: 2, type: 'follow', name: 'Riley W.', text: 'started following you', time: '5h', thumb: false },
  { id: 3, type: 'inquiry', name: 'Jordan Lee', text: 'sent an inquiry about **Untitled #12**', time: '1d', thumb: true },
  { id: 4, type: 'purchase', name: 'Sam Rivera', text: 'purchased **Coastal Forms #3**', time: '2d', thumb: true, sale: true },
];

export function NotificationsPage() {
  const today = mockActivity.filter((a) => a.time.includes('h'));
  const week = mockActivity.filter((a) => a.time.includes('d'));

  return (
    <SafeArea style={{ paddingTop: 0 }}>
      <header style={{ paddingBottom: 16 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700, color: 'var(--slate-900)' }}>Activity</h1>
      </header>

      {mockActivity.length === 0 ? (
        <p style={{ textAlign: 'center', color: 'var(--slate-400)', padding: 48 }}>No activity yet</p>
      ) : (
        <>
          {today.length > 0 && (
            <section style={{ marginBottom: 24 }}>
              <h2 style={{ fontSize: 12, fontWeight: 500, color: 'var(--slate-400)', marginBottom: 8 }}>Today</h2>
              {today.map((a) => (
                <ActivityRow key={a.id} item={a} />
              ))}
            </section>
          )}
          {week.length > 0 && (
            <section>
              <h2 style={{ fontSize: 12, fontWeight: 500, color: 'var(--slate-400)', marginBottom: 8 }}>This Week</h2>
              {week.map((a) => (
                <ActivityRow key={a.id} item={a} />
              ))}
            </section>
          )}
        </>
      )}
    </SafeArea>
  );
}

function ActivityRow({ item }) {
  return (
    <GlassCard style={rowStyle}>
      <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'var(--slate-200)', flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0, fontSize: 14, color: 'var(--slate-700)' }}>
        <span style={{ fontWeight: 600, color: 'var(--slate-900)' }}>{item.name}</span>
        {' '}
        <span dangerouslySetInnerHTML={{ __html: item.text.replace(/\*\*(.*?)\*\*/g, '<strong style="color:var(--slate-900)">$1</strong>') }} />
        {item.type === 'inquiry' && (
          <span style={{ marginLeft: 6, padding: '2px 8px', borderRadius: 9999, background: 'var(--slate-100)', fontSize: 11, color: 'var(--slate-600)' }}>Inquiry</span>
        )}
        {item.sale && (
          <span style={{ marginLeft: 6, padding: '2px 8px', borderRadius: 9999, background: 'var(--slate-900)', color: 'var(--white)', fontSize: 11, fontWeight: 600 }}>Sale</span>
        )}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
        <span style={{ fontSize: 11, color: 'var(--slate-400)' }}>{item.time}</span>
        {item.thumb && (
          <div style={{ width: 36, height: 36, borderRadius: 8, background: 'var(--slate-100)' }} />
        )}
      </div>
    </GlassCard>
  );
}
