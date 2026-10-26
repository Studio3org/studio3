import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../data/post_location_options.dart';
import '../models/street_address.dart';

/// Free OpenStreetMap Nominatim-backed location search — no API key needed.
/// Usage policy (nominatim.org): identify with a real User-Agent, keep
/// request volume light (this is search-as-you-type for one user, not bulk).
///
/// Every place it returns is a real, named place: a city ([searchCities], [reverseGeocode]
/// with `cityOnly`), a venue or address ([search]) or a US street address
/// ([searchAddresses], [reverseAddress]). Nothing is guessed from the network (no IP
/// lookup), and the phone's own coordinates are only ever turned into the place they are in.
abstract final class LocationSearchService {
  static const _userAgent = 'Studio3App/1.0 (contact: ankit@studio-3.co)';

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Sends every search through [adapter] instead of the network, for tests.
  @visibleForTesting
  static void debugUseAdapter(HttpClientAdapter adapter) => _dio.httpClientAdapter = adapter;

  static Future<List<Map<String, dynamic>>> _find(String query, Map<String, Object> extra) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];
    try {
      final response = await _dio.get<List<dynamic>>(
        '/search',
        queryParameters: {
          'q': trimmed,
          'format': 'jsonv2',
          'addressdetails': 1,
          'limit': 8,
          ...extra,
        },
      );
      return (response.data ?? const []).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<Map<String, dynamic>?> _reverse(double lat, double lng, {required int zoom}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reverse',
        queryParameters: {'lat': lat, 'lon': lng, 'format': 'jsonv2', 'addressdetails': 1, 'zoom': zoom},
      );
      final data = response.data;
      if (data == null || data['display_name'] == null) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Any place: venues, addresses, cities (an event's location).
  static Future<List<PostLocationOption>> search(String query) async =>
      (await _find(query, const {})).map(PostLocationOption.fromNominatim).toList();

  /// Cities and towns only, named "Dallas, TX" (a piece's, a post's or a profile's place).
  static Future<List<PostLocationOption>> searchCities(String query) async {
    final seen = <String>{};
    return [
      for (final json in await _find(query, const {'featureType': 'settlement'}))
        if (PostLocationOption.cityFromNominatim(json) case final city? when seen.add(city.displayName)) city,
    ];
  }

  /// The place at [lat], [lng]: its city when [cityOnly] (zoomed out to the town), otherwise
  /// the building or street.
  static Future<PostLocationOption?> reverseGeocode(double lat, double lng, {bool cityOnly = false}) async {
    final data = await _reverse(lat, lng, zoom: cityOnly ? 10 : 18);
    if (data == null) return null;
    return cityOnly ? PostLocationOption.cityFromNominatim(data) : PostLocationOption.fromNominatim(data);
  }

  /// US street addresses for the address form.
  static Future<List<StreetAddress>> searchAddresses(String query) async => [
    for (final json in await _find(query, const {'countrycodes': 'us'}))
      ?StreetAddress.fromNominatim(json),
  ];

  /// The street address at [lat], [lng] (where the phone is), split into the form's fields.
  static Future<StreetAddress?> reverseAddress(double lat, double lng) async {
    final data = await _reverse(lat, lng, zoom: 18);
    return data == null ? null : StreetAddress.fromNominatim(data);
  }

  /// Where a typed address is, so a saved address carries its own coordinates.
  static Future<({double lat, double lng})?> geocodeAddress({
    required String line1,
    required String city,
    required String state,
    required String zip,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/search',
        queryParameters: {
          'street': line1,
          'city': city,
          'state': state,
          'postalcode': zip,
          'countrycodes': 'us',
          'format': 'jsonv2',
          'limit': 1,
        },
      );
      final first = (response.data ?? const []).whereType<Map<String, dynamic>>().firstOrNull;
      final lat = double.tryParse(first?['lat']?.toString() ?? '');
      final lng = double.tryParse(first?['lon']?.toString() ?? '');
      return lat == null || lng == null ? null : (lat: lat, lng: lng);
    } catch (_) {
      return null;
    }
  }
}
