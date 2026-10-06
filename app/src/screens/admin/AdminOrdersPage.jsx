import React, { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { listOrders } from '../../services/adminApi';
import { Pill, formatMoney, formatWhen, useAdminSummary } from './AdminLayout';

export function AdminOrdersPage() {
  const [params, setParams] = useSearchParams();
  const status = params.get('status') || '';
  const page = Number(params.get('page') || 1);
  const { summary } = useAdminSummary();

  const [data, setData] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    setError(null);
    listOrders({ status: status || undefined, page })
      .then((res) => !cancelled && setData(res))
      .catch((e) => !cancelled && setError(e.message));
    return () => {
      cancelled = true;
    };
  }, [status, page]);

  const counts = summary?.ordersByStatus || {};
  const statuses = summary?.orderStatuses || [];
  const setFilter = (next) => setParams(next ? { status: next } : {});

  const total = data?.total ?? 0;
  const perPage = data?.perPage ?? 50;
  const lastPage = Math.max(1, Math.ceil(total / perPage));

  return (
    <>
      <h1 className="admin-h1">Orders</h1>
      <p className="admin-sub">{total} order{total === 1 ? '' : 's'}{status ? ` in ${status}` : ''}</p>

      <div className="admin-filters">
        <button className={`admin-chip${status ? '' : ' admin-chip--on'}`} onClick={() => setFilter('')}>
          All
        </button>
        {statuses.map((s) => (
          <button
            key={s}
            className={`admin-chip${status === s ? ' admin-chip--on' : ''}`}
            onClick={() => setFilter(s)}
          >
            {s.replace(/_/g, ' ')}
            {counts[s] ? ` · ${counts[s]}` : ''}
          </button>
        ))}
      </div>

      {error && <div className="admin-error">{error}</div>}

      <div className="admin-card">
        <table className="admin-table">
          <thead>
            <tr>
              <th>Placed</th>
              <th>Status</th>
              <th className="admin-num">Total</th>
              <th>Charge</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {(data?.orders || []).map((o) => (
              <tr key={o.id}>
                <td>{formatWhen(o.createdAt)}</td>
                <td><Pill>{o.status}</Pill></td>
                <td className="admin-num">{formatMoney(o.totalCents)}</td>
                <td className="admin-mono admin-muted">{o.stripeChargeId || '—'}</td>
                <td className="admin-num"><Link to={`/admin/orders/${o.id}`}>Open</Link></td>
              </tr>
            ))}
            {data && data.orders.length === 0 && (
              <tr><td colSpan={5} className="admin-empty">Nothing here.</td></tr>
            )}
            {!data && !error && (
              <tr><td colSpan={5} className="admin-empty">Loading…</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {lastPage > 1 && (
        <div className="admin-actions">
          <button
            className="admin-btn admin-btn--ghost"
            disabled={page <= 1}
            onClick={() => setParams({ ...(status && { status }), page: String(page - 1) })}
          >
            Previous
          </button>
          <span className="admin-sub">Page {page} of {lastPage}</span>
          <button
            className="admin-btn admin-btn--ghost"
            disabled={page >= lastPage}
            onClick={() => setParams({ ...(status && { status }), page: String(page + 1) })}
          >
            Next
          </button>
        </div>
      )}
    </>
  );
}
