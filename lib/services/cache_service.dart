import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Thrown by a `fetchRaw` callback when the caller has decided not to
/// attempt a network call (e.g. currently offline) — signals
/// [CacheService.fetchWithCache] to fall back to cache instead of treating
/// it as a real network error.
class CacheMiss implements Exception {
  const CacheMiss(this.key);
  final String key;
  @override
  String toString() => 'CacheMiss($key)';
}

/// Generic Hive-backed read-through cache used by the domain services
/// (feed, addresses, notifications, orders, etc.) to serve cached data
/// immediately and refresh from the network in the background.
///
/// Values are stored as JSON strings wrapped in a `{savedAt, data}`
/// envelope so callers never need a typed Hive adapter — every entry is
/// just the raw decoded API response (a `Map<String, dynamic>`), and each
/// service supplies its own `parse` function to turn that back into a
/// model, reusing the same parsing logic it already uses for live
/// responses.
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  static const _boxName = 'api_cache';
  Box<String>? _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
  }

  /// Cache-first-then-refresh helper.
  ///
  /// - [key]: stable cache key, e.g. `feed.forYou`, `addresses.me`.
  /// - [fetchRaw]: the real network call, returning the raw decoded API
  ///   envelope (before `extractData`/`extractList` unwrapping) — throw
  ///   [CacheMiss] instead of calling the network when offline.
  /// - [parse]: turns a raw envelope (cached or fresh) into `T`, reusing
  ///   the service's existing response-parsing logic.
  /// - [ttl]: how long cached data is considered fresh enough to skip a
  ///   background refresh entirely.
  /// - [onBackgroundUpdate]: called with the freshly-parsed result once a
  ///   background refresh (triggered by returning stale cache) completes,
  ///   so callers can silently merge it into their UI with no flicker and
  ///   no spinner. The refreshed value is written to cache either way.
  ///
  /// True stale-while-revalidate: any cached value (fresh or stale) is
  /// returned immediately when `forceRefresh` isn't set — a stale cache
  /// triggers a non-blocking background refresh instead of making the
  /// caller wait on the network. The network is only awaited when there's
  /// no cached value at all (a genuine first load) or `forceRefresh` is
  /// explicitly requested (e.g. pull-to-refresh).
  Future<T> fetchWithCache<T>({
    required String key,
    required Future<Map<String, dynamic>> Function() fetchRaw,
    required T Function(Map<String, dynamic> raw) parse,
    Duration ttl = const Duration(minutes: 5),
    bool forceRefresh = false,
    void Function(T fresh)? onBackgroundUpdate,
  }) async {
    final cachedRaw = _readEnvelopeData(key);

    if (cachedRaw != null && !forceRefresh) {
      if (_isStale(key, ttl)) {
        unawaited(_refreshInBackground(
          key: key,
          fetchRaw: fetchRaw,
          parse: parse,
          onUpdate: onBackgroundUpdate,
        ));
      }
      return parse(cachedRaw);
    }

    try {
      final fresh = await fetchRaw();
      await _write(key, fresh);
      return parse(fresh);
    } catch (_) {
      if (cachedRaw != null) return parse(cachedRaw);
      rethrow;
    }
  }

  Future<void> _refreshInBackground<T>({
    required String key,
    required Future<Map<String, dynamic>> Function() fetchRaw,
    required T Function(Map<String, dynamic> raw) parse,
    required void Function(T fresh)? onUpdate,
  }) async {
    try {
      final fresh = await fetchRaw();
      await _write(key, fresh);
      onUpdate?.call(parse(fresh));
    } catch (_) {
      // Silent — the next foreground read still serves the same stale
      // cache and will retry the background refresh again.
    }
  }

  /// Synchronous cache read — for seeding a screen's initial state (e.g. in
  /// `initState`) before the first frame, so cached content paints instantly
  /// instead of an empty/loading state while [fetchWithCache]'s (necessarily
  /// `Future`-wrapped) read resolves. Returns `null` on a cache miss;
  /// staleness is ignored here on purpose — showing slightly-stale content
  /// immediately and refreshing silently is the whole point.
  T? peekCache<T>({
    required String key,
    required T Function(Map<String, dynamic> raw) parse,
  }) {
    final raw = _readEnvelopeData(key);
    if (raw == null) return null;
    return parse(raw);
  }

  /// Whether [key] has any cached value at all, regardless of staleness —
  /// lets a screen decide between "show stale cache" and "show offline
  /// empty state" when there's truly nothing to display.
  bool hasCache(String key) => _box?.containsKey(key) ?? false;

  DateTime? savedAt(String key) {
    final raw = _box?.get(key);
    if (raw == null) return null;
    return DateTime.parse((jsonDecode(raw) as Map)['savedAt'] as String);
  }

  /// TTL-less passthrough for data with no staleness concept (e.g. the
  /// user's own saved-items list) — persisted forever until overwritten.
  String? readRaw(String key) => _box?.get(key);

  Future<void> writeRaw(String key, String value) async {
    await _box?.put(key, value);
  }

  Map<String, dynamic>? _readEnvelopeData(String key) {
    final raw = _box?.get(key);
    if (raw == null) return null;
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    return envelope['data'] as Map<String, dynamic>;
  }

  bool _isStale(String key, Duration ttl) {
    final raw = _box?.get(key);
    if (raw == null) return true;
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    final savedAt = DateTime.parse(envelope['savedAt'] as String);
    return DateTime.now().difference(savedAt) > ttl;
  }

  Future<void> _write(String key, Map<String, dynamic> data) async {
    final envelope = {
      'savedAt': DateTime.now().toIso8601String(),
      'data': data,
    };
    await _box?.put(key, jsonEncode(envelope));
  }

  Future<void> invalidate(String key) async => _box?.delete(key);

  Future<void> clearAll() async => _box?.clear();
}
