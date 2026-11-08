import '../utils/media_type_utils.dart';
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
    this.linkedPieceIds = const [],
    this.isProcess = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.saveCount,
    this.isLiked = false,
    this.isSaved = false,
    this.authorUsername,
    this.authorName,
    this.authorAvatarUrl,
    this.authorIsFollowing = false,
    this.linkedPiece,
    this.status,
    this.mediaUrls = const [],
    this.commentsOff = false,
    this.linkedPieces,
    this.createdAt,
    this.updatedAt,
    this.draftStep,
    this.publishFailed = false,
  });

  final String id;
  final String? caption;
  final String? mediaUrl;
  final String? mediaType;
  final String? location;
  final String? mediaAspectRatio;
  final String? thumbnailUrl;
  final String? pieceId;

  /// Every piece the Scene shows on (the first is [pieceId]).
  final List<String> linkedPieceIds;
  final bool isProcess;
  final int likeCount;
  final int commentCount;

  /// How many people saved the Scene; null from a server that doesn't send it (BACKEND_CHANGES
  /// B33).
  final int? saveCount;
  final bool isLiked;
  final bool isSaved;
  final String? authorUsername;
  final String? authorName;
  final String? authorAvatarUrl;
  final bool authorIsFollowing;
  final PieceSummary? linkedPiece;
  final String? status;

  /// Every photo of a photo Scene, in order (B33); the first is [mediaUrl]. Empty from a
  /// server that sends one photo only.
  final List<String> mediaUrls;

  /// The artist turned comments off (B33).
  final bool commentsOff;

  /// The pieces the Scene shows on, with title, picture, artist and price (B33). Null from a
  /// server that sends only [linkedPieceIds]; then they are fetched one by one.
  final List<PieceSummary>? linkedPieces;

  final DateTime? createdAt;

  /// When it was last edited (B33): Drafts' time line.
  final DateTime? updatedAt;

  /// A draft: the posting step it stopped on (B33).
  final String? draftStep;

  /// A draft that saved but failed to go live, on any device (B33).
  final bool publishFailed;

  factory PostSummary.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    final user = json['user'] as Map<String, dynamic>?;
    final pieceJson = json['piece'];
    final linkedJson = json['linkedPieces'];
    return PostSummary(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      caption: json['caption'] as String? ?? json['body'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      mediaType: json['mediaType'] as String?,
      location: json['location'] as String?,
      mediaAspectRatio: json['mediaAspectRatio'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      pieceId: json['linkedPieceId'] as String? ?? json['pieceId'] as String?,
      linkedPieceIds: [
        for (final id in (json['linkedPieceIds'] as List?) ?? const [])
          if (id is String) id,
      ],
      isProcess: json['isProcess'] as bool? ?? false,
      likeCount: _intFrom(json['likeCount'] ?? json['likes']) ?? 0,
      commentCount: _intFrom(json['commentCount'] ?? json['comments']) ?? 0,
      saveCount: _intFrom(json['saveCount']),
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
      mediaUrls: [
        for (final url in (json['mediaUrls'] as List?) ?? const [])
          if (url is String && url.isNotEmpty) url,
      ],
      commentsOff: json['commentsOff'] as bool? ?? false,
      linkedPieces: linkedJson is List
          ? [for (final p in linkedJson.whereType<Map<String, dynamic>>()) PieceSummary.fromJson(p)]
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toLocal(),
      draftStep: json['draftStep'] as String?,
      publishFailed: json['publishFailed'] as bool? ?? false,
    );
  }

  /// The same Scene with comments turned on or off.
  PostSummary withCommentsOff(bool off) => PostSummary.fromJson({...toJson(), 'commentsOff': off});

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
    if (linkedPieceIds.isNotEmpty) 'linkedPieceIds': linkedPieceIds,
    'isProcess': isProcess,
    'likeCount': likeCount,
    'commentCount': commentCount,
    if (saveCount != null) 'saveCount': saveCount,
    'isLiked': isLiked,
    'isSaved': isSaved,
    if (authorUsername != null) 'authorUsername': authorUsername,
    if (authorName != null) 'authorName': authorName,
    if (authorAvatarUrl != null) 'authorAvatarUrl': authorAvatarUrl,
    'authorIsFollowing': authorIsFollowing,
    if (linkedPiece != null) 'piece': linkedPiece!.toJson(),
    if (status != null) 'status': status,
    if (mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
    if (commentsOff) 'commentsOff': true,
    if (linkedPieces != null) 'linkedPieces': [for (final p in linkedPieces!) p.toJson()],
    if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    if (draftStep != null) 'draftStep': draftStep,
    if (publishFailed) 'publishFailed': true,
  };

  bool get isVideo => isVideoMediaType(mediaType, mediaUrl);
}
