/** Ticket-tier helpers — ports lib/widgets/create_flow/event_ticket_edit_page.dart's
 * EventTicketTier getters and constants. A ticket tier is a plain object:
 * { name, isFree, buyerPays, limitPurchaseWindow, startsSelling, stopsSelling,
 *   description, limitQuantity, quantity, limitPerOrder, perOrder } */

export const TICKET_ACCENT = '#C45C4A';
const PLATFORM_FEE = 0.13;

export function newTicketTier(name = '') {
  return {
    name,
    isFree: false,
    buyerPays: null,
    limitPurchaseWindow: false,
    startsSelling: null,
    stopsSelling: null,
    description: '',
    limitQuantity: false,
    quantity: null,
    limitPerOrder: false,
    perOrder: null,
  };
}

export function youReceive(buyerPays) {
  return buyerPays == null ? null : buyerPays * (1 - PLATFORM_FEE);
}

export function ticketIsComplete(ticket) {
  if (!ticket.name.trim()) return false;
  if (ticket.isFree) return true;
  return ticket.buyerPays != null && ticket.buyerPays > 0;
}

function formatDollars(value) {
  return Number.isInteger(value) ? `$${value}` : `$${value.toFixed(2)}`;
}

export function ticketDescriptionLine(ticket) {
  const text = ticket.description.trim();
  return text || null;
}

export function ticketPriceLine(ticket) {
  if (ticket.isFree) {
    if (ticket.limitQuantity && ticket.quantity != null) return `Free, ${ticket.quantity} available`;
    return 'Free, unlimited capacity';
  }
  if (ticket.buyerPays == null || ticket.buyerPays <= 0) return 'Set a price, unlimited capacity';
  const price = formatDollars(ticket.buyerPays);
  if (ticket.limitQuantity && ticket.quantity != null) return `${price}, ${ticket.quantity} available`;
  return `${price}, unlimited capacity`;
}

export function ticketPriceLineIsHint(ticket) {
  return !ticket.isFree && (ticket.buyerPays == null || ticket.buyerPays <= 0);
}

export function ticketPerOrderLine(ticket) {
  if (!ticket.limitPerOrder || ticket.perOrder == null) return null;
  return `max ${ticket.perOrder} per order`;
}
