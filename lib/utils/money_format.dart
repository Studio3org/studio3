/// Dollar amounts from cents: `$3,500`, `$950.50`; `US$ 3,500` for collect prices. Moved
/// out of the old `collect_detail_tokens.dart` so screens don't import a token file for it.
String formatCollectPrice(int? priceCents) {
  if (priceCents == null) return '—';
  return 'US\$ ${formatMoneyAmount(priceCents)}';
}

String formatMoney(int cents) => '\$${formatMoneyAmount(cents)}';

String formatMoneyAmount(int cents) {
  final dollars = cents / 100;
  final whole = dollars.truncate();
  final frac = (cents.abs() % 100);
  final wholeStr = _withCommas(whole.abs());
  final signed = whole < 0 ? '-' : '';
  if (frac == 0 && dollars == dollars.roundToDouble()) {
    return '$signed$wholeStr';
  }
  return '$signed$wholeStr.${frac.toString().padLeft(2, '0')}';
}

String _withCommas(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final fromEnd = s.length - i;
    if (i > 0 && fromEnd % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
