import '../models/street_address.dart';

/// A location result for the create-post flow, sourced from live search
/// (see `LocationSearchService`) rather than a fixed list.
class PostLocationOption {
  const PostLocationOption({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.displayName,
    this.lat,
    this.lng,
  });

  final String id;
  final String name;
  final String subtitle;

  /// Full human-readable place name — what's actually sent to the backend
  /// and shown on the piece/scene detail page.
  final String displayName;
  final double? lat;
  final double? lng;

  /// Parses a Nominatim `/search` or `/reverse` (jsonv2) result.
  factory PostLocationOption.fromNominatim(Map<String, dynamic> json) {
    final displayName = (json['display_name'] as String?)?.trim() ?? '';
    final parts = displayName
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final rawName = json['name'] as String?;
    final name = (rawName != null && rawName.trim().isNotEmpty)
        ? rawName.trim()
        : (parts.isNotEmpty ? parts.first : 'Unknown location');
    final subtitle = parts.length > 1
        ? parts.sublist(1).join(', ')
        : displayName;
    return PostLocationOption(
      id: json['place_id']?.toString() ?? displayName,
      name: name,
      subtitle: subtitle,
      displayName: displayName.isNotEmpty ? displayName : name,
      lat: double.tryParse(json['lat']?.toString() ?? ''),
      lng: double.tryParse(json['lon']?.toString() ?? ''),
    );
  }

  /// The city a Nominatim result (with `addressdetails=1`) is in: "Dallas, TX" in the US,
  /// "Paris, France" elsewhere. Null when it isn't in a city or town.
  static PostLocationOption? cityFromNominatim(Map<String, dynamic> json) {
    final a = json['address'];
    if (a is! Map) return null;
    String part(List<String> keys) {
      for (final k in keys) {
        final v = a[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    final city = part(['city', 'town', 'village', 'hamlet', 'municipality']);
    if (city.isEmpty) return null;
    final country = part(['country']);
    final state = part(['state']);
    final code = StreetAddress.usStateCode(a);
    final displayName = code.isNotEmpty ? '$city, $code' : [city, country].where((s) => s.isNotEmpty).join(', ');
    return PostLocationOption(
      id: json['place_id']?.toString() ?? displayName,
      name: city,
      subtitle: [if (state.isNotEmpty && state != city) state, country].where((s) => s.isNotEmpty).join(', '),
      displayName: displayName,
      lat: double.tryParse(json['lat']?.toString() ?? ''),
      lng: double.tryParse(json['lon']?.toString() ?? ''),
    );
  }
}
