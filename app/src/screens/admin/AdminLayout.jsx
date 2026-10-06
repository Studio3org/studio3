import React, { createContext, useCallback, useContext, useEffect, useState } from 'react';
import { NavLink, Outlet, Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { getSummary } from '../../services/adminApi';
import './admin.css';

const SummaryContext = createContext({ summary: null, refresh: () => {} });

/** Order statuses, audit actions, couriers and shipment statuses all come from
 * the server so the console's filters cannot drift from what the API accepts. */
export function useAdminSummary() {
  return useContext(SummaryContext);
}

export function formatMoney(cents) {
  if (cents === null || cents === undefined) return '—';
  return `$${(cents / 100).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

export function formatWhen(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? '—' : d.toLocaleString();
}

/** Status → tone. Anything that means money is stuck reads as a problem. */
export function statusTone(status) {
  if (['paid', 'completed', 'released', 'active', 'resolved'].includes(status)) return 'good';
  if (['disputed', 'failed', 'transfer_failed', 'blocked', 'refunded'].includes(status)) return 'bad';
  if (['pending_payment', 'awaiting_confirmation', 'open', 'pending'].includes(status)) return 'warn';
  return '';
}

export function Pill({ children, tone }) {
  const t = tone ?? statusTone(children);
  return <span className={`admin-pill${t ? ` admin-pill--${t}` : ''}`}>{children ?? '—'}</span>;
}

/** Admin-only gate.
 *
 * `isAdmin` is only ever sent to the account itself, and this decides what to
 * *draw* — never what is permitted. Every route behind it re-checks the flag
 * server-side against the database, so a client that lied would see the nav and
 * then collect 403s.
 */
function RequireAdmin({ children }) {
  const { status, user } = useAuth();
  const location = useLocation();
  if (status === 'loading') return <div className="admin-empty">Loading…</div>;
  if (status === 'guest') return <Navigate to="/login" replace state={{ from: location }} />;
  // Not 403 and not a message: an ordinary member has no reason to learn that a
  // staff console exists at all.
  if (!user?.isAdmin) return <Navigate to="/home" replace />;
  return children;
}

function Tab({ to, label, count }) {
  return (
    <NavLink
      to={to}
      end={to === '/admin'}
      className={({ isActive }) => `admin-bar__link${isActive ? ' admin-bar__link--active' : ''}`}
    >
      {label}
      {count > 0 && <span className="admin-badge">{count}</span>}
    </NavLink>
  );
}

export function AdminLayout() {
  const { user } = useAuth();
  const [summary, setSummary] = useState(null);

  const refresh = useCallback(async () => {
    try {
      setSummary(await getSummary());
    } catch {
      // The console still works without its counts — a failed badge fetch must
      // not blank the page an operator came here to read.
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  return (
    <RequireAdmin>
      <SummaryContext.Provider value={{ summary, refresh }}>
        <div className="admin">
          <header className="admin-bar">
            <span className="admin-bar__brand">Studio 3 · Ops</span>
            <nav className="admin-bar__nav">
              <Tab to="/admin" label="Orders" />
              <Tab to="/admin/disputes" label="Disputes" count={summary?.openDisputes} />
              <Tab to="/admin/reports" label="Reports" count={summary?.openReports} />
              <Tab to="/admin/auctions" label="Auctions" count={summary?.auctionsNeedingAttention} />
              <Tab to="/admin/events" label="Events" />
              <Tab to="/admin/audit" label="Audit" />
            </nav>
            {/* A way back. The console replaces the member chrome entirely, so
                without this the only exit is the browser's back button. */}
            <NavLink to="/home" className="admin-bar__link">Leave ops</NavLink>
            <span className="admin-bar__who">{user?.email}</span>
          </header>
          <main className="admin-main">
            <Outlet />
          </main>
        </div>
      </SummaryContext.Provider>
    </RequireAdmin>
  );
}
