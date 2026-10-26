import 'collect_shipping_address.dart' show kUsStateNames;

/// A US street address found by search or from where the phone is (`BuyAddress` "Search your
/// address"), split into the address form's fields, with the coordinates of the address
/// itself.
class StreetAddress {
  const StreetAddress({
    required this.line1,
    required this.city,
    required this.state,
    required this.zip,
    required this.label,
    this.lat,
    this.lng,
  });

  /// House number and street, e.g. "1414 Dragon St".
  final String line1;
  final String city;

  /// Two-letter code, e.g. "TX"; empty when the place isn't in a US state.
  final String state;
  final String zip;

  /// The whole address on one line, for the results list.
  final String label;
  final double? lat;
  final double? lng;

  /// From a Nominatim result with `addressdetails=1`; null when it isn't a street address in
  /// a US state (a city, a park, somewhere abroad).
  static StreetAddress? fromNominatim(Map<String, dynamic> json) {
    final a = json['address'];
    if (a is! Map) return null;
    String part(List<String> keys) {
      for (final k in keys) {
        final v = a[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    final road = part(['road', 'pedestrian', 'footway', 'residential']);
    if (road.isEmpty) return null;
    final number = part(['house_number']);
    final city = part(['city', 'town', 'village', 'hamlet', 'municipality', 'suburb']);
    final state = usStateCode(a);
    if (state.isEmpty) return null;
    final zip = part(['postcode']).split('-').first;
    final line1 = number.isEmpty ? road : '$number $road';
    return StreetAddress(
      line1: line1,
      city: city,
      state: state,
      zip: zip,
      label: [line1, city, [state, zip].where((s) => s.isNotEmpty).join(' ')].where((s) => s.isNotEmpty).join(', '),
      lat: double.tryParse(json['lat']?.toString() ?? ''),
      lng: double.tryParse(json['lon']?.toString() ?? ''),
    );
  }

  /// "TX" from Nominatim's `ISO3166-2-lvl4` ("US-TX") or the state's name; empty outside the
  /// US states.
  static String usStateCode(Map<dynamic, dynamic> address) {
    if ((address['country_code'] as String?)?.toLowerCase() != 'us') return '';
    final iso = address['ISO3166-2-lvl4'];
    if (iso is String && iso.startsWith('US-')) {
      final code = iso.substring(3);
      if (kUsStateNames.containsKey(code)) return code;
    }
    final name = (address['state'] as String?)?.trim().toLowerCase();
    for (final e in kUsStateNames.entries) {
      if (e.value.toLowerCase() == name) return e.key;
    }
    return '';
  }
}
