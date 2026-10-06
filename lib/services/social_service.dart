import 'dart:async';

import '../models/blocked_user.dart';
import '../models/comment_page.dart';
import '../models/feed_item.dart';
import '../models/follow_request.dart';
import '../models/follow_user_summary.dart';
import 'api_client.dart';
import 'auth_session.dart';
import 'cache_service.dart';

/// Result of like/unlike or save/unsave toggles (counts when the API returns them).
class EngagementToggleResult {
  const EngagementToggleResult({
    this.liked,
    this.saved,
    this.likeCount,
    this.saveCount,
  });

  final bool? liked;
  final bool? saved;
  final int? likeCount;
  final int? saveCount;
}

/// Result of `POST`/`DELETE /api/users/:username/follow`. Private accounts
/// return `requested: true` instead of following immediately.
class FollowResult {
  const FollowResult({required this.following, required this.requested});

  final bool following;
  final bool requested;

  factory FollowResult.fromJson(Map<String, dynamic> json) {
    return FollowResult(
      following: json['following'] as bool? ?? false,
      requested: json['requested'] as bool? ?? false,
    );
  }
}

class SocialService {
  SocialService._();
  static final SocialService instance = SocialService._();

  final _api = ApiClient.instance;

  Future<FollowResult> follow(String username) async {
    final json = await _api.post('/api/users/$username/follow', auth: true);
    return _parseFollowResult(json);
  }

  Future<FollowResult> unfollow(String username) async {
    final json = await _api.delete('/api/users/$username/follow');
    return _parseFollowResult(json);
  }

  FollowResult _parseFollowResult(Map<String, dynamic> json) {
    final data = _api.extractData(json);
    if (data is Map<String, dynamic>) return FollowResult.fromJson(data);
    return const FollowResult(following: false, requested: false);
  }

  Future<List<FollowRequest>> listFollowRequests() async {
    final json = await _api.get('/api/users/follow-requests', auth: true);
    return _api.extractList(json).map(FollowRequest.fromJson).toList();
  }

  Future<void> acceptFollowRequest(String username) async {
    await _api.post('/api/users/follow-requests/$username/accept', auth: true);
  }

  Future<void> declineFollowRequest(String username) async {
    await _api.post('/api/users/follow-requests/$username/decline', auth: true);
  }

  Future<List<BlockedUser>> listBlocked() async {
    final json = await _api.get('/api/users/blocked', auth: true);
    return _api.extractList(json).map(BlockedUser.fromJson).toList();
  }

  Future<FollowUserPage> listFollowers(
    String username, {
    String? cursor,
    int? limit,
  }) {
    return _getFollowUserPage(
      '/api/users/$username/followers',
      cursor: cursor,
      limit: limit,
    );
  }

  Future<FollowUserPage> listFollowing(
    String username, {
    String? cursor,
    int? limit,
  }) {
    return _getFollowUserPage(
      '/api/users/$username/following',
      cursor: cursor,
      limit: limit,
    );
  }

  Future<FollowUserPage> _getFollowUserPage(
    String path, {
    String? cursor,
    int? limit,
  }) async {
    final query = <String, String>{};
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    if (limit != null) query['limit'] = limit.toString();

    final json = await _api.get(
      path,
      query: query.isEmpty ? null : query,
      auth: AuthSession.instance.isLoggedIn,
    );
    final data = _api.extractData(json);
    final items = _api
        .extractList(json)
        .map(FollowUserSummary.fromJson)
        .toList(growable: false);
    final nextCursor = data is Map<String, dynamic>
        ? data['nextCursor'] as String?
        : null;
    return FollowUserPage(items: items, nextCursor: nextCursor);
  }

  Future<void> blockUser(String username) async {
    await _api.post('/api/users/$username/block', auth: true);
  }

  Future<void> unblockUser(String username) async {
    await _api.delete('/api/users/$username/block');
  }

  Future<EngagementToggleResult> likePiece(String id) async {
    final json = await _api.post('/api/pieces/$id/like', auth: true);
    return _parseEngagementToggle(json, likedKey: 'liked');
  }

  Future<EngagementToggleResult> unlikePiece(String id) async {
    final json = await _api.delete('/api/pieces/$id/like');
    return _parseEngagementToggle(json, likedKey: 'liked');
  }

  Future<EngagementToggleResult> likePost(String id) async {
    final json = await _api.post('/api/posts/$id/like', auth: true);
    return _parseEngagementToggle(json, likedKey: 'liked');
  }

  Future<EngagementToggleResult> unlikePost(String id) async {
    final json = await _api.delete('/api/posts/$id/like');
    return _parseEngagementToggle(json, likedKey: 'liked');
  }

  Future<EngagementToggleResult> savePiece(String id) async {
    final json = await _api.post('/api/pieces/$id/save', auth: true);
    unawaited(_invalidateSavedLists(pieces: true));
    return _parseEngagementToggle(json, savedKey: 'saved');
  }

  Future<EngagementToggleResult> unsavePiece(String id) async {
    final json = await _api.delete('/api/pieces/$id/save');
    unawaited(_invalidateSavedLists(pieces: true));
    return _parseEngagementToggle(json, savedKey: 'saved');
  }

  Future<EngagementToggleResult> savePost(String id) async {
    final json = await _api.post('/api/posts/$id/save', auth: true);
    unawaited(_invalidateSavedLists(posts: true));
    return _parseEngagementToggle(json, savedKey: 'saved');
  }

  Future<EngagementToggleResult> unsavePost(String id) async {
    final json = await _api.delete('/api/posts/$id/save');
    unawaited(_invalidateSavedLists(posts: true));
    return _parseEngagementToggle(json, savedKey: 'saved');
  }

  EngagementToggleResult _parseEngagementToggle(
    Map<String, dynamic> json, {
    String? likedKey,
    String? savedKey,
  }) {
    final data = _api.extractData(json);
    if (data is! Map<String, dynamic>) {
      return const EngagementToggleResult();
    }
    return EngagementToggleResult(
      liked: likedKey != null ? data[likedKey] as bool? : null,
      saved: savedKey != null ? data[savedKey] as bool? : null,
      likeCount: data['likeCount'] as int?,
      saveCount: data['saveCount'] as int?,
    );
  }

  Future<void> _invalidateSavedLists({
    bool pieces = false,
    bool posts = false,
  }) async {
    if (pieces) await CacheService.instance.invalidate('saved.pieces');
    if (posts) await CacheService.instance.invalidate('saved.posts');
  }

  Future<List<Map<String, dynamic>>> listCollections() async {
    final json = await _api.get('/api/collections', auth: true);
    return _api.extractList(json);
  }

  Future<Map<String, dynamic>> createCollection(String name) async {
    final json = await _api.post(
      '/api/collections',
      body: {'name': name},
      auth: true,
    );
    return _api.extractData(json) as Map<String, dynamic>;
  }

  Future<void> renameCollection(String collectionId, String name) async {
    await _api.patch('/api/collections/$collectionId', body: {'name': name});
  }

  Future<void> deleteCollection(String collectionId) async {
    await _api.delete('/api/collections/$collectionId');
  }

  Future<Map<String, dynamic>> getCollectionDetail(String collectionId) async {
    final json = await _api.get('/api/collections/$collectionId', auth: true);
    return _api.extractData(json) as Map<String, dynamic>;
  }

  Future<void> addToCollection({
    required String collectionId,
    required String targetType,
    required String targetId,
  }) async {
    await _api.post(
      '/api/collections/$collectionId/items',
      body: {'targetType': targetType, 'targetId': targetId},
      auth: true,
    );
  }

  Future<void> removeFromCollection({
    required String collectionId,
    required String targetType,
    required String targetId,
  }) async {
    await _api.delete(
      '/api/collections/$collectionId/items/$targetType/$targetId',
    );
  }

  Future<CommentSummary> commentOnPiece(String id, String body) async {
    final json = await _api.post(
      '/api/pieces/$id/comments',
      body: {'body': body},
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    return _withCurrentAuthor(CommentSummary.fromJson(data));
  }

  Future<CommentSummary> commentOnPost(String id, String body) async {
    final json = await _api.post(
      '/api/posts/$id/comments',
      body: {'body': body},
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    return _withCurrentAuthor(CommentSummary.fromJson(data));
  }

  /// The create-comment endpoints don't return an enriched `author`/`user`
  /// object the way the comment-list endpoint does — the author is always
  /// the caller, so fill it in from the session instead of showing a blank
  /// name for a comment that was just successfully posted.
  CommentSummary _withCurrentAuthor(CommentSummary comment) {
    if (comment.authorUsername != null || comment.authorName != null) {
      return comment;
    }
    final user = AuthSession.instance.user;
    if (user == null) return comment;
    return CommentSummary(
      id: comment.id,
      body: comment.body,
      authorUsername: user.username,
      authorName: user.name,
      authorAvatarUrl: user.profilePhotoUrl,
      createdAt: comment.createdAt,
    );
  }

  Future<CommentPage> getPieceComments(
    String id, {
    String? cursor,
    int? limit,
  }) async {
    final json = await _api.get(
      '/api/pieces/$id/comments',
      query: _commentQuery(cursor: cursor, limit: limit),
    );
    return _parseCommentPage(json);
  }

  Future<CommentPage> getPostComments(
    String id, {
    String? cursor,
    int? limit,
  }) async {
    final json = await _api.get(
      '/api/posts/$id/comments',
      query: _commentQuery(cursor: cursor, limit: limit),
    );
    return _parseCommentPage(json);
  }

  Map<String, String> _commentQuery({String? cursor, int? limit}) {
    final query = <String, String>{};
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    if (limit != null) query['limit'] = limit.toString();
    return query;
  }

  CommentPage _parseCommentPage(Map<String, dynamic> json) {
    final data = _api.extractData(json);
    final nextCursor = data is Map<String, dynamic>
        ? data['nextCursor'] as String?
        : null;
    final items = _api
        .extractList(json)
        .map(CommentSummary.fromJson)
        .toList(growable: false);
    return CommentPage(items: items, nextCursor: nextCursor);
  }
}
