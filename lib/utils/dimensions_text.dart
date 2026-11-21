/// An artwork's size as the app shows it, "24x36x1.5 in", from what the API sends.
///
/// The server stores `dimensions` as given: the app sends text ("24x36x1.5 in"), but the API
/// also accepts an object (`{"width": 40, "height": 60, "depth": 2, "unit": "cm"}`), and other
/// clients and older data use it. Both read the same here, so one piece in the other shape
/// can't break a whole feed. Anything unreadable is null (no size shown).
String? dimensionsText(Object? raw) {
  if (raw == null) return null;
  if (raw is String) return raw.trim().isEmpty ? null : raw;
  if (raw is Map) {
    String? part(Object? v) {
      if (v is num) return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
      if (v is String && v.trim().isNotEmpty) return v.trim();
      return null;
    }

    final sides = [part(raw['width']), part(raw['height']), part(raw['depth'])].whereType<String>().toList();
    if (sides.isEmpty) return null;
    final unit = part(raw['unit']);
    return unit == null ? sides.join('x') : '${sides.join('x')} $unit';
  }
  return null;
}
