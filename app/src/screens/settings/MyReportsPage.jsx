import React, { useEffect, useState } from 'react';
import { Flag } from 'lucide-react';
import { REPORT_REASONS, friendlyError, listMyReports } from '../../services/socialApi';
import { SettingsLayout, SettingsSpinner } from './SettingsLayout';

const REASON_LABELS = Object.fromEntries(REPORT_REASONS);
const TYPE_LABELS = { piece: 'Piece', post: 'Scene', comment: 'Comment', user: 'Account' };

function formatDate(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  return Number.isNaN(d.getTime())
    ? ''
    : d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
}

/** Backend statuses: open | resolved | dismissed. */
const STATUS_LABELS = { open: 'In review', resolved: 'Resolved', dismissed: 'Reviewed' };

function statusClass(status) {
  if (status === 'open') return ' settings-status--open';
  if (status === 'resolved') return ' settings-status--resolved';
  return '';
}

/// Reports this account has filed and where each one stands (GET /api/reports/mine).
export function MyReportsPage() {
  const [list, setList] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    listMyReports()
      .then((data) => !cancelled && setList(Array.isArray(data) ? data : data?.items ?? []))
      .catch((e) => !cancelled && setError(friendlyError(e)));
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <SettingsLayout
      title="My reports"
      subtitle="Reports you've sent. Our team reviews every report within 24 hours; reports are anonymous."
    >
      {list === null && !error && <SettingsSpinner />}
      {error && (
        <div className="settings-empty">
          <p className="settings-empty-title">Couldn't load your reports</p>
          <p className="settings-empty-sub">{error}</p>
        </div>
      )}
      {list && list.length === 0 && (
        <div className="settings-empty">
          <p className="settings-empty-title">No reports</p>
          <p className="settings-empty-sub">Content you report will appear here.</p>
        </div>
      )}
      {list?.map((r) => (
        <div key={r.id} className="settings-card is-static">
          <div className="settings-card-left" style={{ minWidth: 0 }}>
            <span className="settings-card-icon">
              <Flag size={18} />
            </span>
            <div className="settings-card-text">
              <span className="settings-card-label">
                {r.targetLabel || TYPE_LABELS[r.targetType] || 'Content'}
              </span>
              <span className="settings-card-sub">
                {[TYPE_LABELS[r.targetType], REASON_LABELS[r.reason] || r.reason, formatDate(r.createdAt)]
                  .filter(Boolean)
                  .join(' · ')}
              </span>
            </div>
          </div>
          {r.status && <span className={`settings-status${statusClass(r.status)}`}>{STATUS_LABELS[r.status] || String(r.status).replace(/_/g, ' ')}</span>}
        </div>
      ))}
    </SettingsLayout>
  );
}
