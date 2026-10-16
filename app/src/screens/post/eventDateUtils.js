/** Date/time formatting for the Event flow — ports
 * lib/widgets/create_flow/event_date_sheet.dart's free functions.
 * Dates are plain `YYYY-MM-DD` strings (native `<input type="date">` value)
 * and times are plain `HH:MM` 24h strings (native `<input type="time">`
 * value), parsed here only for display formatting. */

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

function parseDateStr(dateStr) {
  const [y, m, d] = dateStr.split('-').map(Number);
  return new Date(y, m - 1, d);
}

export function formatEventDate(dateStr, { includeWeekday = true } = {}) {
  const date = parseDateStr(dateStr);
  const month = MONTHS[date.getMonth()];
  return includeWeekday ? `${WEEKDAYS[date.getDay()]}, ${month} ${date.getDate()}` : `${month} ${date.getDate()}`;
}

export function formatEventDateShort(dateStr) {
  const date = parseDateStr(dateStr);
  return `${MONTHS[date.getMonth()]} ${date.getDate()}`;
}

export function formatEventTime(timeStr) {
  const [h, m] = timeStr.split(':').map(Number);
  const hour = h % 12 === 0 ? 12 : h % 12;
  const period = h < 12 ? 'AM' : 'PM';
  return `${hour}:${String(m).padStart(2, '0')} ${period}`;
}

/** Mirrors `EventDateSelection.summary`. */
export function eventDateSummary(selection) {
  if (!selection?.startDate) return '';
  const { multiDay, startDate, endDate, startTime, endTime } = selection;
  const dateText =
    multiDay && endDate
      ? `${formatEventDate(startDate, { includeWeekday: false })} – ${formatEventDate(endDate, { includeWeekday: false })}`
      : formatEventDate(startDate);
  const start = startTime ? formatEventTime(startTime) : null;
  const end = endTime ? formatEventTime(endTime) : null;
  if (start && end) return `${dateText} · ${start}–${end}`;
  if (start) return `${dateText} · ${start}`;
  return dateText;
}
