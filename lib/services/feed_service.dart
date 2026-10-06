import '../models/feed_item.dart';
import '../models/feed_page.dart';
import 'api_client.dart';
import 'auth_session.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

class FeedService {
  FeedService._();
  static final FeedService instance = FeedService._();

  final _api = ApiClient.instance;

  Future<FeedPage> getFollowing({String? cursor, int? limit}) async {
    final json = await _api.get(
      '/api/feed/following',
      query: _query(cursor: cursor, limit: limit),
      auth: true,
    );
    return _parseFeedPage(json);
  }

  Future<FeedPage> getExplore({
    String? medium,
    bool videoOnly = false,
    String? cursor,
    int? limit,
  }) async {
    final query = _query(cursor: cursor, limit: limit);
    if (videoOnly) {
      query['medium'] = 'video';
    } else if (medium != null && medium.isNotEmpty && medium != 'All') {
      query['medium'] = medium.toLowerCase();
    }

    final json = await _api.get(
      '/api/feed/explore',
      query: query.isEmpty ? null : query,
      auth: AuthSession.instance.isLoggedIn,
    );
    return _parseFeedPage(
      json,
      videoOnly: videoOnly,
    );
  }

  Future<FeedPage> getForYou({String? cursor, int? limit}) async {
    final json = await _api.get(
      '/api/feed/for-you',
      query: _query(cursor: cursor, limit: limit),
      auth: true,
    );
    return _parseFeedPage(json);
  }

  /// Video scenes for Reels (`type: post` + `mediaType: video`).
  Future<FeedPage> getVideoScenes({String? cursor, int? limit}) {
    return getExplore(videoOnly: true, cursor: cursor, limit: limit);
  }

  /// Cache-first first page of the "For You" feed — pagination past page 1
  /// always stays network-only. Serves cached data immediately when fresh
  /// (or when offline and cache exists), refreshing in the background
  /// otherwise.
  Future<FeedPage> getForYouCached({
    bool forceRefresh = false,
    void Function(FeedPage fresh)? onBackgroundUpdate,
  }) {
    return CacheService.instance.fetchWithCache<FeedPage>(
      key: 'feed.forYou',
      ttl: const Duration(minutes: 5),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw const CacheMiss('feed.forYou');
        }
        return _api.get(
          '/api/feed/for-you',
          query: _query(),
          auth: true,
        );
      },
      parse: _parseFeedPage,
      onBackgroundUpdate: onBackgroundUpdate,
    );
  }

  /// Synchronous peek at whatever "For You" page is already cached (if any)
  /// — for seeding the feed screen's initial state instantly instead of
  /// starting from an empty spinner while the real (possibly-cached)
  /// network round trip resolves.
  FeedPage? peekForYouCached() {
    return CacheService.instance.peekCache<FeedPage>(
      key: 'feed.forYou',
      parse: _parseFeedPage,
    );
  }

  /// Cache-first Explore feed, keyed per medium filter so "All"/"Video"/etc
  /// each cache independently.
  Future<FeedPage> getExploreCached({
    String? medium,
    bool videoOnly = false,
    bool forceRefresh = false,
    void Function(FeedPage fresh)? onBackgroundUpdate,
  }) {
    final key = 'feed.explore.${videoOnly ? 'video' : (medium ?? 'all')}';
    return CacheService.instance.fetchWithCache<FeedPage>(
      key: key,
      ttl: const Duration(minutes: 5),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw CacheMiss(key);
        }
        final query = _query();
        if (videoOnly) {
          query['medium'] = 'video';
        } else if (medium != null && medium.isNotEmpty && medium != 'All') {
          query['medium'] = medium.toLowerCase();
        }
        return _api.get(
          '/api/feed/explore',
          query: query.isEmpty ? null : query,
          auth: AuthSession.instance.isLoggedIn,
        );
      },
      parse: (json) => _parseFeedPage(json, videoOnly: videoOnly),
      onBackgroundUpdate: onBackgroundUpdate,
    );
  }

  Map<String, String> _query({String? cursor, int? limit}) {
    final query = <String, String>{};
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    if (limit != null) query['limit'] = limit.toString();
    return query;
  }

  FeedPage _parseFeedPage(
    Map<String, dynamic> json, {
    bool videoOnly = false,
  }) {
    final data = _api.extractData(json);
    final rawItems = data is Map<String, dynamic> ? data['items'] : data;
    final nextCursor =
        data is Map<String, dynamic> ? data['nextCursor'] as String? : null;
    final stub =
        data is Map<String, dynamic> ? data['stub'] as bool? ?? false : false;

    var items = _api
        .extractList(json)
        .map(FeedItem.fromJson)
        .toList(growable: false);

    if (rawItems is! List && items.isEmpty) {
      items = const [];
    }

    if (videoOnly) {
      items = items
          .where((item) => item.type == FeedItemType.post && item.isVideo)
          .toList(growable: false);
    }

    return FeedPage(items: items, nextCursor: nextCursor, stub: stub);
  }
}
