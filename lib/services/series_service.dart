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

  /// All series owned by the current user (management UI).
  Future<List<SeriesSummary>> getMySeries() async {
    final json = await _api.get('/api/user/me/series', auth: true);
    return _api.extractList(json).map(SeriesSummary.fromJson).toList();
  }

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
    return SeriesSummary.fromJson(data);
  }

  Future<SeriesSummary> update(
    String id, {
    String? name,
    List<String>? pieceOrder,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (pieceOrder != null) body['pieceOrder'] = pieceOrder;
    final json = await _api.patch('/api/series/$id', body: body);
    final data = _api.extractData(json) as Map<String, dynamic>;
    return SeriesSummary.fromJson(data);
  }

  Future<SeriesSummary> addPiece(String seriesId, String pieceId) async {
    final json = await _api.post(
      '/api/series/$seriesId/pieces',
      body: {'pieceId': pieceId},
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    return SeriesSummary.fromJson(data);
  }

  Future<SeriesSummary> removePiece(String seriesId, String pieceId) async {
    final json = await _api.delete('/api/series/$seriesId/pieces/$pieceId');
    final data = _api.extractData(json) as Map<String, dynamic>;
    return SeriesSummary.fromJson(data);
  }
}
