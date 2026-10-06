import React, { useCallback, useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import {
  listAudit, listAuctions, listDisputes, listEvents, listReports, resolveReport,
} from '../../services/adminApi';
import { Pill, formatMoney, formatWhen, useAdminSummary } from './AdminLayout';

/** One loader for every read-only queue: fetch, show the error if it fails,
 * show "Loading…" until it doesn't. */
function useQueue(fetcher, deps = []) {
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const reload = useCallback(() => {
    setError(null);
    fetcher()
      .then(setData)
      .catch((e) => setError(e.message));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
  useEffect(() => { reload(); }, [reload]);
  return { data, error, reload };
}

function Card({ title, children, colSpan = 4, data, error, empty }) {
  return (
    <div className="admin-card">
      <div className="admin-card__head">{title}</div>
      {error && <div className="admin-empty">{error}</div>}
      {!data && !error && <div className="admin-empty">Loading…</div>}
      {data && (data.length === 0
        ? <div className="admin-empty">{empty}</div>
        : children)}
      {colSpan && null}
    </div>
  );
}

// --- disputes and stuck payouts ------------------------------------------------------------

export function AdminDisputesPage() {
  const { data, error } = useQueue(listDisputes);
  return (
    <>
      <h1 className="admin-h1">Disputes &amp; stuck payouts</h1>
      <p className="admin-sub">
        A failed transfer means an artist is unpaid on a delivered order — the queue that must
        not go unwatched.
      </p>

      <Card title="Open disputes" data={data?.disputes} error={error} empty="No open disputes.">
        <table className="admin-table">
          <thead>
            <tr><th>Raised</th><th>Reason</th><th className="admin-num">At risk</th><th /></tr>
          </thead>
          <tbody>
            {(data?.disputes || []).map((row) => (
              <tr key={row.dispute.id}>
                <td>{formatWhen(row.dispute.createdAt)}</td>
                <td>{row.dispute.reason || '—'}</td>
                <td className="admin-num">{formatMoney(row.dispute.amountCents ?? row.order.totalCents)}</td>
                <td className="admin-num"><Link to={`/admin/orders/${row.order.id}`}>Resolve</Link></td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>

      <Card title="Payouts needing attention" data={data?.failedPayouts} error={error}
            empty="Every artist has been paid.">
        <table className="admin-table">
          <thead>
            <tr><th>Artist</th><th>Status</th><th>Why</th><th className="admin-num">Amount</th><th /></tr>
          </thead>
          <tbody>
            {(data?.failedPayouts || []).map((row) => (
              <tr key={row.payout.id}>
                <td>@{row.seller?.username}</td>
                <td><Pill>{row.payout.status}</Pill></td>
                <td className="admin-muted">{row.payout.failureReason || '—'}</td>
                <td className="admin-num">{formatMoney(row.payout.amountCents)}</td>
                <td className="admin-num"><Link to={`/admin/orders/${row.order.id}`}>Open</Link></td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </>
  );
}

// --- auctions --------------------------------------------------------------------------------

export function AdminAuctionsPage() {
  const { data, error } = useQueue(listAuctions);
  return (
    <>
      <h1 className="admin-h1">Auctions</h1>
      <p className="admin-sub">Read-only. Auctions resolve on their own schedule; this is the window in.</p>

      <Card title="Needing attention" data={data?.needingAttention} error={error}
            empty="No auction is waiting on anyone.">
        <table className="admin-table">
          <thead>
            <tr><th>Work</th><th>Artist</th><th>Status</th><th>Winner deadline</th></tr>
          </thead>
          <tbody>
            {(data?.needingAttention || []).map((row) => (
              <tr key={row.auction.id}>
                <td>{row.piece?.title}</td>
                <td>@{row.seller?.username}</td>
                <td><Pill>{row.auction.status}</Pill></td>
                <td>{formatWhen(row.auction.winnerDeadlineAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>

      <Card title="Live now" data={data?.live} error={error} empty="Nothing is running.">
        <table className="admin-table">
          <thead>
            <tr><th>Work</th><th>Artist</th><th>Closes</th><th className="admin-num">Bids</th><th className="admin-num">High bid</th></tr>
          </thead>
          <tbody>
            {(data?.live || []).map((row) => (
              <tr key={row.auction.id}>
                <td>{row.piece?.title}</td>
                <td>@{row.seller?.username}</td>
                <td>{formatWhen(row.auction.auctionEndsAt)}</td>
                <td className="admin-num">{row.bidCount ?? 0}</td>
                <td className="admin-num">{formatMoney(row.highBidCents ?? row.auction.startingBidCents)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </>
  );
}

// --- events ----------------------------------------------------------------------------------

export function AdminEventsPage() {
  const { data, error } = useQueue(listEvents);
  return (
    <>
      <h1 className="admin-h1">Events</h1>
      <p className="admin-sub">Read-only. An event matters here as a container for money.</p>
      <Card title="All events" data={data?.events} error={error} empty="No events yet.">
        <table className="admin-table">
          <thead>
            <tr><th>Event</th><th>Host</th><th>Status</th><th>Starts</th>
              <th className="admin-num">For sale</th><th className="admin-num">Going</th></tr>
          </thead>
          <tbody>
            {(data?.events || []).map((row) => (
              <tr key={row.event.id}>
                <td>{row.event.title}</td>
                <td>@{row.host?.username}</td>
                <td><Pill>{row.event.status}</Pill></td>
                <td>{formatWhen(row.event.startsAt)}</td>
                <td className="admin-num">{row.sellingCount ?? 0}</td>
                <td className="admin-num">{row.goingCount ?? 0}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </>
  );
}

// --- audit -----------------------------------------------------------------------------------

export function AdminAuditPage() {
  const [params, setParams] = useSearchParams();
  const action = params.get('action') || '';
  const { summary } = useAdminSummary();
  const { data, error } = useQueue(() => listAudit({ action: action || undefined }), [action]);

  return (
    <>
      <h1 className="admin-h1">Audit</h1>
      <p className="admin-sub">
        Who did what. Read when something has gone wrong and the question is who changed it.
      </p>

      <div className="admin-filters">
        <button className={`admin-chip${action ? '' : ' admin-chip--on'}`} onClick={() => setParams({})}>
          Everything
        </button>
        {(summary?.auditActions || []).map((a) => (
          <button
            key={a}
            className={`admin-chip${action === a ? ' admin-chip--on' : ''}`}
            onClick={() => setParams({ action: a })}
          >
            {a.replace(/_/g, ' ')}
          </button>
        ))}
      </div>

      <Card title="Recent" data={data?.entries} error={error} empty="Nothing recorded here yet.">
        <table className="admin-table">
          <thead>
            <tr><th>When</th><th>Action</th><th>Who</th><th>Subject</th><th>Note</th></tr>
          </thead>
          <tbody>
            {(data?.entries || []).map((e) => (
              <tr key={e.id}>
                <td>{formatWhen(e.createdAt)}</td>
                <td>{e.action.replace(/_/g, ' ')}</td>
                <td>
                  {e.actorLabel || '—'}
                  {e.actorType === 'system' && <span className="admin-muted"> (scheduled)</span>}
                </td>
                <td>
                  {e.subjectType === 'order' && e.subjectId
                    ? <Link to={`/admin/orders/${e.subjectId}`}>{e.subjectType}</Link>
                    : <span className="admin-muted">{e.subjectType || '—'}</span>}
                </td>
                <td className="admin-muted">
                  {e.note || (e.detail ? JSON.stringify(e.detail) : '—')}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </>
  );
}

// --- reports ---------------------------------------------------------------------------------

export function AdminReportsPage() {
  const [params, setParams] = useSearchParams();
  const status = params.get('status') || 'open';
  const { data, error, reload } = useQueue(() => listReports({ status }), [status]);
  const { refresh: refreshCounts } = useAdminSummary();
  const [busy, setBusy] = useState(null);
  const [note, setNote] = useState({});
  const [failed, setFailed] = useState(null);

  const act = async (id, action) => {
    setBusy(id);
    setFailed(null);
    try {
      await resolveReport(id, { action, note: note[id] || '' });
      reload();
      refreshCounts();
    } catch (e) {
      setFailed(e.message);
    } finally {
      setBusy(null);
    }
  };

  return (
    <>
      <h1 className="admin-h1">Reports</h1>
      <p className="admin-sub">Content flagged by members.</p>

      <div className="admin-filters">
        {['open', 'resolved', 'dismissed'].map((s) => (
          <button
            key={s}
            className={`admin-chip${status === s ? ' admin-chip--on' : ''}`}
            onClick={() => setParams({ status: s })}
          >
            {s}
          </button>
        ))}
      </div>

      {failed && <div className="admin-error">{failed}</div>}

      <Card title={`${status} reports`} data={data?.reports} error={error} empty="Nothing to review.">
        <table className="admin-table">
          <thead>
            <tr><th>Reported</th><th>Target</th><th>Reason</th><th>By</th><th>Note &amp; action</th></tr>
          </thead>
          <tbody>
            {(data?.reports || []).map((r) => (
              <tr key={r.id}>
                <td>{formatWhen(r.createdAt)}</td>
                <td>{r.targetLabel} <span className="admin-muted">({r.targetType})</span></td>
                <td>{r.reason || '—'}</td>
                <td>{r.reporter ? `@${r.reporter.username}` : '—'}</td>
                <td>
                  {status === 'open' ? (
                    <div className="admin-form" style={{ padding: 0 }}>
                      <input
                        placeholder="Note (optional)"
                        value={note[r.id] || ''}
                        onChange={(e) => setNote({ ...note, [r.id]: e.target.value })}
                      />
                      <div className="admin-actions">
                        <button className="admin-btn" disabled={busy === r.id}
                                onClick={() => act(r.id, 'resolve')}>
                          Resolve
                        </button>
                        <button className="admin-btn admin-btn--ghost" disabled={busy === r.id}
                                onClick={() => act(r.id, 'dismiss')}>
                          Dismiss
                        </button>
                      </div>
                    </div>
                  ) : (
                    <Pill>{r.status}</Pill>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </>
  );
}
