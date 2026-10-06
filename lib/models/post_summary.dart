import 'piece_summary.dart';

class PostSummary {
  const PostSummary({
    required this.id,
    this.caption,
    this.mediaUrl,
    this.mediaType,
    this.location,
    this.mediaAspectRatio,
    this.thumbnailUrl,
    this.pieceId,
    this.isProcess = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.authorUsername,
    this.authorName,
    this.authorAvatarUrl,
    this.authorIsFollowing = false,
    this.linkedPiece,
    this.status,
  });

  final String id;
  final String? caption;
  final String? mediaUrl;
  final String? mediaType;
  final String? location;
  final String? mediaAspectRatio;
  final String? thumbnailUrl;
  final String? pieceId;
  final bool isProcess;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isSaved;
  final String? authorUsername;
  final String? authorName;
  final String? authorAvatarUrl;
  final bool authorIsFollowing;
  final PieceSummary? linkedPiece;
  final String? status;

  factory PostSummary.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    final user = json['user'] as Map<String, dynamic>?;
    final pieceJson = json['piece'];
    return PostSummary(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      caption: json['caption'] as String? ?? json['body'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      mediaType: json['mediaType'] as String?,
      location: json['location'] as String?,
      mediaAspectRatio: json['mediaAspectRatio'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      pieceId: json['linkedPieceId'] as String? ?? json['pieceId'] as String?,
      isProcess: json['isProcess'] as bool? ?? false,
      likeCount: _intFrom(json['likeCount'] ?? json['likes']) ?? 0,
      commentCount: _intFrom(json['commentCount'] ?? json['comments']) ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      isSaved: json['isSaved'] as bool? ?? false,
      authorUsername:
          author?['username'] as String? ??
          user?['username'] as String? ??
          json['authorUsername'] as String?,
      authorName:
          author?['name'] as String? ??
          user?['name'] as String? ??
          json['authorName'] as String?,
      authorAvatarUrl:
          author?['profilePhotoUrl'] as String? ??
          user?['profilePhotoUrl'] as String? ??
          json['authorAvatarUrl'] as String?,
      authorIsFollowing:
          author?['isFollowing'] as bool? ??
          user?['isFollowing'] as bool? ??
          false,
      linkedPiece: pieceJson is Map<String, dynamic>
          ? PieceSummary.fromJson(pieceJson)
          : null,
      status: json['status'] as String?,
    );
  }

  static int? _intFrom(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  Map<String, dynamic> toJson() => {
    'type': 'post',
    'id': id,
    if (caption != null) 'caption': caption,
    if (mediaUrl != null) 'mediaUrl': mediaUrl,
    if (mediaType != null) 'mediaType': mediaType,
    if (location != null) 'location': location,
    if (mediaAspectRatio != null) 'mediaAspectRatio': mediaAspectRatio,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (pieceId != null) 'linkedPieceId': pieceId,
    'isProcess': isProcess,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'isLiked': isLiked,
    'isSaved': isSaved,
    if (authorUsername != null) 'authorUsername': authorUsername,
    if (authorName != null) 'authorName': authorName,
    if (authorAvatarUrl != null) 'authorAvatarUrl': authorAvatarUrl,
    'authorIsFollowing': authorIsFollowing,
    if (linkedPiece != null) 'piece': linkedPiece!.toJson(),
    if (status != null) 'status': status,
  };

  bool get isVideo {
    final t = mediaType?.toLowerCase();
    return t == 'video' || t == 'reel' || t == 'reels';
  }
}
