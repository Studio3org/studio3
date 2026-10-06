import { apiFetch } from './apiClient';

/** Admin console API (`/api/admin`).
 *
 * Every call is `auth: true` — the backend gates each route on the `is_admin`
 * flag, checked against the database on every request rather than trusted from
 * the token, so a revoked admin loses access immediately.
 *
 * The screens never decide what an admin may do; they only decide what to draw.
 * A client that lied about `isAdmin` would see the nav and get 403s.
 */

/** Counts for the nav, plus the enumerations the filters are built from
 * (order statuses, audit actions, couriers, shipment statuses) — sent by the
 * server so the console cannot drift from what the backend accepts. */
export function getSummary() {
  return apiFetch('/api/admin/summary', { auth: true });
}

export function listOrders({ status, page = 1 } = {}) {
  const params = new URLSearchParams();
  if (status) params.set('status', status);
  if (page > 1) params.set('page', String(page));
  const query = params.toString();
  return apiFetch(`/api/admin/orders${query ? `?${query}` : ''}`, { auth: true });
}

export function getOrder(orderId) {
  return apiFetch(`/api/admin/orders/${orderId}`, { auth: true });
}

/** Record a booked courier pickup. `actualShippingCost` is in dollars —
 * the server converts to cents, the same as the HTML console's form. */
export function createShipment(orderId, { courier, trackingNumber, actualShippingCost }) {
  return apiFetch(`/api/admin/orders/${orderId}/shipment`, {
    method: 'POST',
    auth: true,
    body: { courier, trackingNumber, actualShippingCost },
  });
}

/** Blank fields mean "leave unchanged", so correcting a tracking number cannot
 * accidentally clear the courier or re-post the shipping cost. */
export function updateShipment(orderId, { status, courier, trackingNumber, actualShippingCost }) {
  return apiFetch(`/api/admin/orders/${orderId}/shipment/update`, {
    method: 'POST',
    auth: true,
    body: { status, courier, trackingNumber, actualShippingCost },
  });
}

/** Resolve a dispute by refunding the collector or releasing to the artist.
 * `reason` is required and is what the audit row records — it is the only
 * answer to "why did this money move" a month later. */
export function resolveDispute(orderId, { action, reason }) {
  return apiFetch(`/api/admin/orders/${orderId}/resolve`, {
    method: 'POST',
    auth: true,
    body: { action, reason },
  });
}

export function retryPayout(orderId) {
  return apiFetch(`/api/admin/orders/${orderId}/retry-payout`, { method: 'POST', auth: true });
}

export function listDisputes() {
  return apiFetch('/api/admin/disputes', { auth: true });
}

export function listAuctions() {
  return apiFetch('/api/admin/auctions', { auth: true });
}

export function listEvents() {
  return apiFetch('/api/admin/events', { auth: true });
}

export function listAudit({ action, page = 1 } = {}) {
  const params = new URLSearchParams();
  if (action) params.set('action', action);
  if (page > 1) params.set('page', String(page));
  const query = params.toString();
  return apiFetch(`/api/admin/audit${query ? `?${query}` : ''}`, { auth: true });
}

export function listReports({ status = 'open' } = {}) {
  return apiFetch(`/api/admin/reports?status=${encodeURIComponent(status)}`, { auth: true });
}

export function resolveReport(reportId, { action, note }) {
  return apiFetch(`/api/admin/reports/${reportId}/resolve`, {
    method: 'POST',
    auth: true,
    body: { action, note },
  });
}
