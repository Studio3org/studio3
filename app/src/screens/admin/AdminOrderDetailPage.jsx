import React, { useCallback, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import {
  createShipment, getOrder, resolveDispute, retryPayout, updateShipment,
} from '../../services/adminApi';
import { Pill, formatMoney, formatWhen, useAdminSummary } from './AdminLayout';

function Row({ label, children }) {
  return (
    <div>
      <dt>{label}</dt>
      <dd>{children ?? '—'}</dd>
    </div>
  );
}

export function AdminOrderDetailPage() {
  const { orderId } = useParams();
  const { summary, refresh: refreshCounts } = useAdminSummary();

  const [detail, setDetail] = useState(null);
  const [error, setError] = useState(null);
  const [notice, setNotice] = useState(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      setDetail(await getOrder(orderId));
    } catch (e) {
      setError(e.message);
    }
  }, [orderId]);

  useEffect(() => { load(); }, [load]);

  /** Every action funnels through here so none of them can forget to clear the
   * previous message, re-read the order, or leave the buttons disabled. */
  const run = async (fn) => {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      const result = await fn();
      if (result?.order) setDetail(result);
      else await load();
      if (result?.notice) setNotice(result.notice);
      refreshCounts();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  if (!detail) {
    return <div className="admin-empty">{error || 'Loading…'}</div>;
  }

  const { order, buyer, seller, pieces, shipment, payout, dispute, ledger, shippingAddress } = detail;

  return (
    <>
      <p className="admin-sub"><Link to="/admin">← Orders</Link></p>
      <h1 className="admin-h1">{formatMoney(order.totalCents)} · <Pill>{order.status}</Pill></h1>
      <p className="admin-sub">Placed {formatWhen(order.createdAt)}</p>

      {notice && <div className="admin-note">{notice}</div>}
      {error && <div className="admin-error">{error}</div>}

      <div className="admin-grid">
        <div>
          <div className="admin-card">
            <div className="admin-card__head">Money</div>
            <dl className="admin-dl">
              <Row label="Artwork">{formatMoney(order.artworkCents)}</Row>
              <Row label="Shipping">{formatMoney(order.shippingCents)}</Row>
              <Row label="Tax">{formatMoney(order.taxCents)}</Row>
              {order.prepaidCents > 0 && (
                <Row label="Already paid (hammer)">{formatMoney(order.prepaidCents)}</Row>
              )}
              <Row label="Total">{formatMoney(order.totalCents)}</Row>
              <Row label="Charge"><span className="admin-mono">{order.stripeChargeId || '—'}</span></Row>
              <Row label="Intent"><span className="admin-mono">{order.paymentReference || '—'}</span></Row>
            </dl>
          </div>

          <div className="admin-card">
            <div className="admin-card__head">Parties</div>
            <dl className="admin-dl">
              <Row label="Collector">{buyer ? `${buyer.name || ''} @${buyer.username}` : '—'}</Row>
              <Row label="Artist">{seller ? `${seller.name || ''} @${seller.username}` : '—'}</Row>
              <Row label="Work">{pieces.map((p) => p.title).join(', ') || '—'}</Row>
            </dl>
          </div>

          <div className="admin-card">
            <div className="admin-card__head">Where the money went</div>
            <table className="admin-table">
              <thead>
                <tr><th>When</th><th>Entry</th><th>Account</th><th className="admin-num">Amount</th></tr>
              </thead>
              <tbody>
                {ledger.map((l, i) => (
                  <tr key={i}>
                    <td>{formatWhen(l.createdAt)}</td>
                    <td>{l.transactionType}</td>
                    <td>{l.account} <span className="admin-muted">({l.direction})</span></td>
                    <td className="admin-num">{formatMoney(l.amountCents)}</td>
                  </tr>
                ))}
                {ledger.length === 0 && (
                  <tr><td colSpan={4} className="admin-empty">No ledger entries — nothing has been booked.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>

        <div>
          <div className="admin-card">
            <div className="admin-card__head">Shipment</div>
            {shipment ? (
              <>
                <dl className="admin-dl">
                  <Row label="Courier">{shipment.courier}</Row>
                  <Row label="Tracking"><span className="admin-mono">{shipment.trackingNumber}</span></Row>
                  <Row label="Status"><Pill>{shipment.status}</Pill></Row>
                  <Row label="Actual cost">{formatMoney(shipment.actualCostCents)}</Row>
                </dl>
                <ShipmentUpdateForm
                  busy={busy}
                  statuses={summary?.shipmentStatuses || []}
                  couriers={summary?.couriers || []}
                  shipment={shipment}
                  onSubmit={(body) => run(() => updateShipment(orderId, body))}
                />
              </>
            ) : (
              <ShipmentCreateForm
                busy={busy}
                couriers={summary?.couriers || []}
                onSubmit={(body) => run(() => createShipment(orderId, body))}
              />
            )}
          </div>

          <div className="admin-card">
            <div className="admin-card__head">Payout</div>
            {payout ? (
              <>
                <dl className="admin-dl">
                  <Row label="Status"><Pill>{payout.status}</Pill></Row>
                  <Row label="Amount">{formatMoney(payout.amountCents)}</Row>
                  <Row label="Transfer"><span className="admin-mono">{payout.stripeTransferId || '—'}</span></Row>
                  <Row label="Why it failed">{payout.failureReason}</Row>
                </dl>
                <div className="admin-form">
                  <button
                    className="admin-btn"
                    disabled={busy}
                    onClick={() => run(() => retryPayout(orderId))}
                  >
                    Retry payout
                  </button>
                </div>
              </>
            ) : (
              <div className="admin-empty">No payout row yet.</div>
            )}
          </div>

          <div className="admin-card">
            <div className="admin-card__head">
              Resolve {dispute && <Pill>{dispute.status}</Pill>}
            </div>
            {dispute && (
              <dl className="admin-dl">
                <Row label="Raised">{formatWhen(dispute.createdAt)}</Row>
                <Row label="Reason">{dispute.reason}</Row>
                <Row label="At risk">{formatMoney(dispute.amountCents)}</Row>
              </dl>
            )}
            <ResolveForm busy={busy} onSubmit={(body) => run(() => resolveDispute(orderId, body))} />
          </div>

          {shippingAddress && (
            <div className="admin-card">
              <div className="admin-card__head">Deliver to</div>
              <dl className="admin-dl">
                {Object.entries(shippingAddress).map(([k, v]) => (
                  <Row key={k} label={k}>{String(v)}</Row>
                ))}
              </dl>
            </div>
          )}
        </div>
      </div>
    </>
  );
}

function ShipmentCreateForm({ couriers, busy, onSubmit }) {
  const [courier, setCourier] = useState('');
  const [trackingNumber, setTracking] = useState('');
  const [actualShippingCost, setCost] = useState('');
  return (
    <div className="admin-form">
      <label>
        Courier
        <select value={courier} onChange={(e) => setCourier(e.target.value)}>
          <option value="">Choose…</option>
          {couriers.map((c) => <option key={c} value={c}>{c}</option>)}
        </select>
      </label>
      <label>
        Tracking number
        <input value={trackingNumber} onChange={(e) => setTracking(e.target.value)} />
      </label>
      <label>
        Actual shipping cost (dollars)
        <input value={actualShippingCost} onChange={(e) => setCost(e.target.value)} placeholder="optional" />
      </label>
      <button
        className="admin-btn"
        disabled={busy || !courier || !trackingNumber}
        onClick={() => onSubmit({ courier, trackingNumber, actualShippingCost })}
      >
        Record shipment
      </button>
    </div>
  );
}

/** Every field is blank-means-unchanged, so a correction to one thing cannot
 *  silently overwrite another. Courier and tracking are editable because they are
 *  typed by hand off a courier label — a typo would otherwise have the collector
 *  following somebody else's parcel with no way to fix it. */
function ShipmentUpdateForm({ statuses, couriers, shipment, busy, onSubmit }) {
  const [status, setStatus] = useState('');
  const [courier, setCourier] = useState('');
  const [trackingNumber, setTracking] = useState('');
  const [actualShippingCost, setCost] = useState('');
  const nothingToDo = !status && !courier && !trackingNumber && !actualShippingCost;
  return (
    <div className="admin-form">
      <label>
        Move to
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">Leave unchanged</option>
          {statuses.map((s) => <option key={s} value={s}>{s.replace(/_/g, ' ')}</option>)}
        </select>
      </label>
      <label>
        Courier
        <select value={courier} onChange={(e) => setCourier(e.target.value)}>
          <option value="">Leave as {shipment?.courier || 'is'}</option>
          {couriers.map((c) => <option key={c} value={c}>{c}</option>)}
        </select>
      </label>
      <label>
        Tracking number
        <input
          value={trackingNumber}
          onChange={(e) => setTracking(e.target.value)}
          placeholder={shipment?.trackingNumber || 'unchanged'}
        />
      </label>
      <label>
        Actual shipping cost (dollars)
        <input
          value={actualShippingCost}
          onChange={(e) => setCost(e.target.value)}
          placeholder="unchanged"
        />
      </label>
      <button
        className="admin-btn admin-btn--ghost"
        disabled={busy || nothingToDo}
        onClick={() => onSubmit({ status, courier, trackingNumber, actualShippingCost })}
      >
        Update shipment
      </button>
    </div>
  );
}

/** Refund the collector, or release and pay the artist.
 *
 * The reason is required by the server and is what the audit row records — it is
 * the only answer to "why did this money move" a month from now. The buttons stay
 * disabled without one rather than letting the request fail. */
function ResolveForm({ busy, onSubmit }) {
  const [reason, setReason] = useState('');
  const ready = !busy && reason.trim().length > 0;
  return (
    <div className="admin-form">
      <label>
        Reason — recorded against your name in the audit log
        <textarea value={reason} onChange={(e) => setReason(e.target.value)} />
      </label>
      <div className="admin-actions">
        <button
          className="admin-btn admin-btn--danger"
          disabled={!ready}
          onClick={() => onSubmit({ action: 'refund', reason })}
        >
          Refund collector
        </button>
        <button
          className="admin-btn"
          disabled={!ready}
          onClick={() => onSubmit({ action: 'release', reason })}
        >
          Release to artist
        </button>
      </div>
    </div>
  );
}
