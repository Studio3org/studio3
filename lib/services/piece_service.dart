import '../models/piece_summary.dart';
import '../models/post_summary.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_session.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

class PieceService {
  PieceService._();
  static final PieceService instance = PieceService._();

  final _api = ApiClient.instance;

  Future<PieceSummary> create(Map<String, dynamic> body) async {
    final json = await _api.post('/api/pieces', body: body, auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    return PieceSummary.fromJson(data);
  }

  Future<PieceSummary> getById(String id, {bool? auth}) async {
    final json = await _api.get(
      '/api/pieces/$id',
      auth: auth ?? AuthSession.instance.isLoggedIn,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    return PieceSummary.fromJson(data);
  }

  /// Cache-first piece detail — short TTL since availability/price can
  /// change, but enables offline drill-in from an already-cached feed.
  Future<PieceSummary> getByIdCached(String id, {bool forceRefresh = false}) {
    final key = 'piece.$id';
    return CacheService.instance.fetchWithCache<PieceSummary>(
      key: key,
      ttl: const Duration(minutes: 2),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw CacheMiss(key);
        }
        return _api.get(
          '/api/pieces/$id',
          auth: AuthSession.instance.isLoggedIn,
        );
      },
      parse: (json) =>
          PieceSummary.fromJson(_api.extractData(json) as Map<String, dynamic>),
    );
  }

  Future<PieceSummary> update(String id, Map<String, dynamic> body) async {
    final json = await _api.patch('/api/pieces/$id', body: body);
    final data = _api.extractData(json) as Map<String, dynamic>;
    await CacheService.instance.invalidate('piece.$id');
    return PieceSummary.fromJson(data);
  }

  Future<List<PieceSummary>> getUserPieces(String username) async {
    final json = await _api.get('/api/users/$username/pieces');
    return _api.extractList(json).map(PieceSummary.fromJson).toList();
  }

  /// The pieces [username] bought on Studio 3, newest first: the profile's Collection tab
  /// (BACKEND_CHANGES B37). Empty from a server that doesn't have the list yet (404).
  Future<List<PieceSummary>> getUserCollection(String username) async {
    try {
      final json = await _api.get('/api/users/$username/collection');
      return _api.extractList(json).map(PieceSummary.fromJson).toList();
    } on ApiException catch (e) {
      if (e.statusCode == 404) return const [];
      rethrow;
    }
  }

  /// Cache-first user pieces — lets a cold app start paint the Profile
  /// "Pieces" tab instantly from the last-seen list while silently
  /// refreshing, instead of a spinner on every fresh launch.
  Future<List<PieceSummary>> getUserPiecesCached(
    String username, {
    bool forceRefresh = false,
    void Function(List<PieceSummary> fresh)? onBackgroundUpdate,
  }) {
    final key = 'profile.pieces.$username';
    return CacheService.instance.fetchWithCache<List<PieceSummary>>(
      key: key,
      ttl: const Duration(minutes: 3),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw CacheMiss(key);
        }
        return _api.get('/api/users/$username/pieces');
      },
      parse: (json) => _api.extractList(json).map(PieceSummary.fromJson).toList(),
      onBackgroundUpdate: onBackgroundUpdate,
    );
  }

  /// Synchronous peek at whatever pieces list is already cached for
  /// [username] (if any) — for seeding Profile's initial state instantly.
  List<PieceSummary>? peekUserPiecesCached(String username) {
    return CacheService.instance.peekCache<List<PieceSummary>>(
      key: 'profile.pieces.$username',
      parse: (json) => _api.extractList(json).map(PieceSummary.fromJson).toList(),
    );
  }

  Future<List<PieceSummary>> getUserPiecesForSale(String username) async {
    final json = await _api.get('/api/users/$username/pieces/for-sale');
    return _api.extractList(json).map(PieceSummary.fromJson).toList();
  }

  /// Cache-first for-sale pieces (Profile "Collect" tab).
  Future<List<PieceSummary>> getUserPiecesForSaleCached(
    String username, {
    bool forceRefresh = false,
    void Function(List<PieceSummary> fresh)? onBackgroundUpdate,
  }) {
    final key = 'profile.forSale.$username';
    return CacheService.instance.fetchWithCache<List<PieceSummary>>(
      key: key,
      ttl: const Duration(minutes: 3),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw CacheMiss(key);
        }
        return _api.get('/api/users/$username/pieces/for-sale');
      },
      parse: (json) => _api.extractList(json).map(PieceSummary.fromJson).toList(),
      onBackgroundUpdate: onBackgroundUpdate,
    );
  }

  /// Synchronous peek at whatever for-sale list is already cached.
  List<PieceSummary>? peekUserPiecesForSaleCached(String username) {
    return CacheService.instance.peekCache<List<PieceSummary>>(
      key: 'profile.forSale.$username',
      parse: (json) => _api.extractList(json).map(PieceSummary.fromJson).toList(),
    );
  }

  Future<List<PostSummary>> getRelatedPosts(String pieceId) async {
    final json = await _api.get('/api/pieces/$pieceId/related-posts');
    return _api.extractList(json).map(PostSummary.fromJson).toList();
  }

  Future<void> delete(String id) => _api.delete('/api/pieces/$id');
}
