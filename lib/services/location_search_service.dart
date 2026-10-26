import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../data/post_location_options.dart';

/// Free OpenStreetMap Nominatim-backed location search — no API key needed.
/// Usage policy (nominatim.org): identify with a real User-Agent, keep
/// request volume light (this is search-as-you-type for one user, not bulk).
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

  static Future<List<PostLocationOption>> search(String query) async {
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
        },
      );
      return (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PostLocationOption.fromNominatim)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<PostLocationOption?> reverseGeocode(
    double lat,
    double lng,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reverse',
        queryParameters: {'lat': lat, 'lon': lng, 'format': 'jsonv2'},
      );
      final data = response.data;
      if (data == null || data['display_name'] == null) return null;
      return PostLocationOption.fromNominatim(data);
    } catch (_) {
      return null;
    }
  }
}
