import '../models/post_summary.dart';
import 'api_client.dart';
import 'auth_session.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

class PostService {
  PostService._();
  static final PostService instance = PostService._();

  final _api = ApiClient.instance;

  Future<PostSummary> create(Map<String, dynamic> body) async {
    final json = await _api.post('/api/posts', body: body, auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    return PostSummary.fromJson(data);
  }

  Future<PostSummary> getById(String id, {bool? auth}) async {
    final json = await _api.get(
      '/api/posts/$id',
      auth: auth ?? AuthSession.instance.isLoggedIn,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    return PostSummary.fromJson(data);
  }

  Future<PostSummary> update(String id, Map<String, dynamic> body) async {
    final json = await _api.patch('/api/posts/$id', body: body);
    final data = _api.extractData(json) as Map<String, dynamic>;
    return PostSummary.fromJson(data);
  }

  /// The artist turns comments off or on for their Scene (BACKEND_CHANGES B33).
  Future<PostSummary> setCommentsOff(String id, bool off) => update(id, {'commentsOff': off});

  Future<List<PostSummary>> getUserPosts(String username) async {
    final json = await _api.get('/api/users/$username/posts');
    return _api.extractList(json).map(PostSummary.fromJson).toList();
  }

  /// Cache-first user posts (Profile "Scenes" tab) — see
  /// [PieceService.getUserPiecesCached] for the rationale.
  Future<List<PostSummary>> getUserPostsCached(
    String username, {
    bool forceRefresh = false,
    void Function(List<PostSummary> fresh)? onBackgroundUpdate,
  }) {
    final key = 'profile.posts.$username';
    return CacheService.instance.fetchWithCache<List<PostSummary>>(
      key: key,
      ttl: const Duration(minutes: 3),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw CacheMiss(key);
        }
        return _api.get('/api/users/$username/posts');
      },
      parse: (json) => _api.extractList(json).map(PostSummary.fromJson).toList(),
      onBackgroundUpdate: onBackgroundUpdate,
    );
  }

  List<PostSummary>? peekUserPostsCached(String username) {
    return CacheService.instance.peekCache<List<PostSummary>>(
      key: 'profile.posts.$username',
      parse: (json) => _api.extractList(json).map(PostSummary.fromJson).toList(),
    );
  }

  Future<List<PostSummary>> getSavedPosts() async {
    final json = await _api.get('/api/user/me/saved/posts', auth: true);
    return _api.extractList(json).map(PostSummary.fromJson).toList();
  }

  /// Cache-first saved posts (Saved page) — cold-start instant paint.
  Future<List<PostSummary>> getSavedPostsCached({
    bool forceRefresh = false,
    void Function(List<PostSummary> fresh)? onBackgroundUpdate,
  }) {
    const key = 'saved.posts';
    return CacheService.instance.fetchWithCache<List<PostSummary>>(
      key: key,
      ttl: const Duration(minutes: 3),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw const CacheMiss(key);
        }
        return _api.get('/api/user/me/saved/posts', auth: true);
      },
      parse: (json) => _api.extractList(json).map(PostSummary.fromJson).toList(),
      onBackgroundUpdate: onBackgroundUpdate,
    );
  }

  List<PostSummary>? peekSavedPostsCached() {
    return CacheService.instance.peekCache<List<PostSummary>>(
      key: 'saved.posts',
      parse: (json) => _api.extractList(json).map(PostSummary.fromJson).toList(),
    );
  }

  Future<void> delete(String id) => _api.delete('/api/posts/$id');
}
