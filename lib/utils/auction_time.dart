/// Formats the time left until [endsAt] the way the auction bar/sheet show it
/// ("2d 4h", "4h 12m", "Ending soon"), or `null` once it's passed (the detail
/// page falls back to an "Auction ended" state at that point).
String? formatTimeRemaining(DateTime? endsAt) {
  if (endsAt == null) return null;
  final remaining = endsAt.difference(DateTime.now());
  if (remaining.isNegative) return null;
  final days = remaining.inDays;
  final hours = remaining.inHours % 24;
  if (days > 0) return '${days}d ${hours}h';
  final minutes = remaining.inMinutes % 60;
  if (remaining.inHours > 0) return '${remaining.inHours}h ${minutes}m';
  if (remaining.inMinutes > 0) return '${remaining.inMinutes}m';
  return 'Ending soon';
}

bool isAuctionEnded(DateTime? endsAt) {
  if (endsAt == null) return false;
  return !endsAt.isAfter(DateTime.now());
}

/// A precise countdown for a deadline someone is actively racing.
///
/// Deliberately finer-grained than [formatTimeRemaining]: an event auction gives a winner
/// whose card was declined **ten minutes** to fix it, and "Ending soon" is useless to
/// somebody standing in a gallery trying to find another card. Seconds are shown under an
/// hour; beyond that the coarse form is enough.
///
/// Returns null once the deadline has passed.
String? formatDeadlineCountdown(DateTime? deadline) {
  if (deadline == null) return null;
  final remaining = deadline.difference(DateTime.now());
  if (remaining.isNegative) return null;
  if (remaining.inHours >= 1) {
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours >= 24) {
      final days = remaining.inDays;
      return '${days}d ${hours % 24}h';
    }
    return '${hours}h ${minutes}m';
  }
  final minutes = remaining.inMinutes;
  final seconds = remaining.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
