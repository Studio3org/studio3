import 'piece_summary.dart';
import 'post_summary.dart';

/// Unified feed row from following/explore/for-you endpoints.
class FeedItem {
  const FeedItem.piece(this.piece) : post = null, type = FeedItemType.piece;

  const FeedItem.post(this.post) : piece = null, type = FeedItemType.post;

  final FeedItemType type;
  final PieceSummary? piece;
  final PostSummary? post;

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final kind = json['type'] as String?;
    if (kind == 'post') {
      return FeedItem.post(PostSummary.fromJson(json));
    }
    if (kind == 'piece') {
      return FeedItem.piece(PieceSummary.fromJson(json));
    }
    if (json.containsKey('linkedPieceId') ||
        (json['title'] == null && json['caption'] != null)) {
      return FeedItem.post(PostSummary.fromJson(json));
    }
    return FeedItem.piece(PieceSummary.fromJson(json));
  }

  String get id => type == FeedItemType.piece ? piece!.id : post!.id;

  String? get mediaUrl =>
      type == FeedItemType.piece ? piece!.mediaUrl : post!.mediaUrl;

  String? get title =>
      type == FeedItemType.piece ? piece!.title : post!.caption;

  String? get authorName =>
      type == FeedItemType.piece ? piece!.authorName : post!.authorName;

  String? get authorUsername =>
      type == FeedItemType.piece ? piece!.authorUsername : post!.authorUsername;

  String? get authorAvatarUrl => type == FeedItemType.piece
      ? piece!.authorAvatarUrl
      : post!.authorAvatarUrl;

  bool get authorIsFollowing => type == FeedItemType.piece
      ? piece!.authorIsFollowing
      : post!.authorIsFollowing;

  bool get isForSale =>
      type == FeedItemType.piece ? (piece?.isForSale ?? false) : false;

  String? get priceDisplay =>
      type == FeedItemType.piece ? piece?.priceDisplay : null;

  String? get mediaType =>
      type == FeedItemType.piece ? piece?.mediaType : post?.mediaType;

  String? get mediaAspectRatio => type == FeedItemType.piece
      ? piece?.mediaAspectRatio
      : post?.mediaAspectRatio;

  /// Video poster frame — pieces are never video, so this is post-only.
  String? get thumbnailUrl =>
      type == FeedItemType.piece ? null : post?.thumbnailUrl;

  bool get isVideo {
    final t = mediaType?.toLowerCase();
    return t == 'video' || t == 'reel' || t == 'reels';
  }

  Map<String, dynamic> toJson() =>
      type == FeedItemType.piece ? piece!.toJson() : post!.toJson();
}

enum FeedItemType { piece, post }

class CommentSummary {
  const CommentSummary({
    required this.id,
    required this.body,
    this.authorUsername,
    this.authorName,
    this.authorAvatarUrl,
    this.createdAt,
  });

  final String id;
  final String body;
  final String? authorUsername;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? createdAt;

  factory CommentSummary.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    final user = json['user'] as Map<String, dynamic>?;
    return CommentSummary(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      authorUsername:
          author?['username'] as String? ?? user?['username'] as String?,
      authorName: author?['name'] as String? ?? user?['name'] as String?,
      authorAvatarUrl:
          author?['profilePhotoUrl'] as String? ??
          user?['profilePhotoUrl'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}
