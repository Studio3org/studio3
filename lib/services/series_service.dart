import '../models/series_summary.dart';
import 'api_client.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

class SeriesService {
  SeriesService._();
  static final SeriesService instance = SeriesService._();

  final _api = ApiClient.instance;

  Future<List<SeriesSummary>> getUserSeries(String username) async {
    final json = await _api.get('/api/users/$username/series');
    return _api.extractList(json).map(SeriesSummary.fromJson).toList();
  }

  /// Cache-first user series (Profile "Series" tab) — see
  /// [PieceService.getUserPiecesCached] for the rationale.
  Future<List<SeriesSummary>> getUserSeriesCached(
    String username, {
    bool forceRefresh = false,
    void Function(List<SeriesSummary> fresh)? onBackgroundUpdate,
  }) {
    final key = 'profile.series.$username';
    return CacheService.instance.fetchWithCache<List<SeriesSummary>>(
      key: key,
      ttl: const Duration(minutes: 3),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw CacheMiss(key);
        }
        return _api.get('/api/users/$username/series');
      },
      parse: (json) => _api.extractList(json).map(SeriesSummary.fromJson).toList(),
      onBackgroundUpdate: onBackgroundUpdate,
    );
  }

  List<SeriesSummary>? peekUserSeriesCached(String username) {
    return CacheService.instance.peekCache<List<SeriesSummary>>(
      key: 'profile.series.$username',
      parse: (json) => _api.extractList(json).map(SeriesSummary.fromJson).toList(),
    );
  }

  static const _mySeriesKey = 'series.me';

  /// All series owned by the current user (management UI).
  Future<List<SeriesSummary>> getMySeries() async {
    final json = await _api.get('/api/user/me/series', auth: true);
    return _api.extractList(json).map(SeriesSummary.fromJson).toList();
  }

  /// Cache-first variant of [getMySeries], so re-opening "Manage series"
  /// shows the list straight away instead of a placeholder.
  Future<List<SeriesSummary>> getMySeriesCached({
    bool forceRefresh = false,
    void Function(List<SeriesSummary> fresh)? onBackgroundUpdate,
  }) {
    return CacheService.instance.fetchWithCache<List<SeriesSummary>>(
      key: _mySeriesKey,
      ttl: const Duration(minutes: 3),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw const CacheMiss(_mySeriesKey);
        }
        return _api.get('/api/user/me/series', auth: true);
      },
      parse: (json) =>
          _api.extractList(json).map(SeriesSummary.fromJson).toList(),
      onBackgroundUpdate: onBackgroundUpdate,
    );
  }

  List<SeriesSummary>? peekMySeriesCached() {
    return CacheService.instance.peekCache<List<SeriesSummary>>(
      key: _mySeriesKey,
      parse: (json) =>
          _api.extractList(json).map(SeriesSummary.fromJson).toList(),
    );
  }

  /// Dropped after any mutation so the next read can't serve a list that
  /// no longer matches what the user just did.
  Future<void> invalidateMySeries() =>
      CacheService.instance.invalidate(_mySeriesKey);

  Future<SeriesSummary> getById(String id) async {
    final json = await _api.get('/api/series/$id');
    final data = _api.extractData(json) as Map<String, dynamic>;
    return SeriesSummary.fromJson(data);
  }

  Future<SeriesSummary> create({
    required String name,
    List<String>? pieceIds,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (pieceIds != null && pieceIds.isNotEmpty) {
      body['pieceIds'] = pieceIds;
    }
    final json = await _api.post('/api/series', body: body, auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    await invalidateMySeries();
    return SeriesSummary.fromJson(data);
  }

  Future<SeriesSummary> update(
    String id, {
    String? name,
    String? description,
    List<String>? pieceOrder,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (pieceOrder != null) body['pieceOrder'] = pieceOrder;
    final json = await _api.patch('/api/series/$id', body: body);
    final data = _api.extractData(json) as Map<String, dynamic>;
    await invalidateMySeries();
    return SeriesSummary.fromJson(data);
  }

  Future<SeriesSummary> addPiece(String seriesId, String pieceId) async {
    final json = await _api.post(
      '/api/series/$seriesId/pieces',
      body: {'pieceId': pieceId},
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    await invalidateMySeries();
    return SeriesSummary.fromJson(data);
  }

  Future<SeriesSummary> removePiece(String seriesId, String pieceId) async {
    final json = await _api.delete('/api/series/$seriesId/pieces/$pieceId');
    final data = _api.extractData(json) as Map<String, dynamic>;
    await invalidateMySeries();
    return SeriesSummary.fromJson(data);
  }
}
