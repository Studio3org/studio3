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
