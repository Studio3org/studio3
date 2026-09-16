/** Compact relative-time label ("2h", "1d") matching the app's inbox chrome. */
export function formatRelativeTime(iso) {
  if (!iso) return '';
  const diff = Date.now() - new Date(iso).getTime();
  if (diff < 60000) return 'now';
  const minutes = Math.floor(diff / 60000);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  return `${days}d`;
}

/** Today/Earlier notification sectioning is client-side only — see
 * lib/widgets/inbox/notifications_body.dart: items newer than 24h go under
 * "Today", everything else under "Earlier". */
export function isWithinLastDay(iso) {
  if (!iso) return false;
  return Date.now() - new Date(iso).getTime() < 24 * 60 * 60 * 1000;
}

function isSameDay(a, b) {
  return a.toDateString() === b.toDateString();
}

/** Day-divider label for a chat thread: "Today" / "Yesterday" / "Mar 4". */
export function formatDayLabel(iso) {
  const d = new Date(iso);
  const now = new Date();
  if (isSameDay(d, now)) return 'Today';
  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  if (isSameDay(d, yesterday)) return 'Yesterday';
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

/** Clock time for a message bubble ("10:02 AM"). */
export function formatClockTime(iso) {
  if (!iso) return '';
  return new Date(iso).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
}
