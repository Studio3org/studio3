import 'post_summary.dart';
import 'series_summary.dart';

class PieceSummary {
  const PieceSummary({
    required this.id,
    required this.title,
    this.mediaUrl,
    this.mediaType,
    this.caption,
    this.medium,
    this.isForSale = false,
    this.priceCents,
    this.dimensions,
    this.shippingRegion,
    this.location,
    this.mediaAspectRatio,
    this.yearCreated,
    this.framingMounting,
    this.provenance,
    this.handlingNotes,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.authorUsername,
    this.authorName,
    this.authorAvatarUrl,
    this.authorIsFollowing = false,
    this.series,
    this.status,
    this.materials = const [],
    this.styleTags = const [],
    this.aiDisclosed = false,
    this.altText,
    this.relatedPosts,
  });

  final String id;
  final String title;
  final String? mediaUrl;
  final String? mediaType;
  final String? caption;
  final String? medium;
  final bool isForSale;
  final int? priceCents;
  final String? dimensions;
  final String? shippingRegion;
  final String? location;
  final String? mediaAspectRatio;
  final int? yearCreated;
  final String? framingMounting;
  final String? provenance;
  final String? handlingNotes;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isSaved;
  final String? authorUsername;
  final String? authorName;
  final String? authorAvatarUrl;
  final bool authorIsFollowing;
  final PieceSeriesInfo? series;
  final String? status;
  final List<String> materials;
  final List<String> styleTags;
  final bool aiDisclosed;
  final String? altText;
  final List<PostSummary>? relatedPosts;

  bool get isLive => status == null || status == 'live';

  factory PieceSummary.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    final user = json['user'] as Map<String, dynamic>?;
    final seriesJson = json['series'];
    final relatedPostsJson = json['relatedPosts'];
    return PieceSummary(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      mediaUrl: json['mediaUrl'] as String?,
      mediaType: json['mediaType'] as String?,
      caption: json['caption'] as String?,
      medium: json['medium'] as String?,
      isForSale: json['isForSale'] as bool? ?? false,
      priceCents: json['priceCents'] as int?,
      dimensions: json['dimensions'] as String?,
      shippingRegion: json['shippingRegion'] as String?,
      location: json['location'] as String?,
      mediaAspectRatio: json['mediaAspectRatio'] as String?,
      yearCreated: _intFrom(json['yearCreated']),
      framingMounting: json['framingMounting'] as String?,
      provenance: json['provenance'] as String?,
      handlingNotes: json['handlingNotes'] as String?,
      likeCount: _intFrom(json['likeCount'] ?? json['likes']) ?? 0,
      commentCount: _intFrom(json['commentCount'] ?? json['comments']) ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      isSaved: json['isSaved'] as bool? ?? false,
      authorUsername: author?['username'] as String? ??
          user?['username'] as String? ??
          json['authorUsername'] as String?,
      authorName: author?['name'] as String? ??
          user?['name'] as String? ??
          json['authorName'] as String?,
      authorAvatarUrl: author?['profilePhotoUrl'] as String? ??
          user?['profilePhotoUrl'] as String? ??
          json['authorAvatarUrl'] as String?,
      authorIsFollowing: author?['isFollowing'] as bool? ??
          user?['isFollowing'] as bool? ??
          false,
      series: seriesJson is Map<String, dynamic>
          ? PieceSeriesInfo.fromJson(seriesJson)
          : null,
      status: json['status'] as String?,
      materials: (json['materials'] as List?)?.whereType<String>().toList() ??
          const [],
      styleTags: (json['styleTags'] as List?)?.whereType<String>().toList() ??
          const [],
      aiDisclosed: json['aiDisclosed'] as bool? ?? false,
      altText: json['altText'] as String?,
      relatedPosts: relatedPostsJson is List
          ? relatedPostsJson
              .whereType<Map<String, dynamic>>()
              .map(PostSummary.fromJson)
              .toList()
          : null,
    );
  }

  static int? _intFrom(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  Map<String, dynamic> toJson() => {
        'type': 'piece',
        'id': id,
        'title': title,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (mediaType != null) 'mediaType': mediaType,
        if (caption != null) 'caption': caption,
        if (medium != null) 'medium': medium,
        'isForSale': isForSale,
        if (priceCents != null) 'priceCents': priceCents,
        if (dimensions != null) 'dimensions': dimensions,
        if (shippingRegion != null) 'shippingRegion': shippingRegion,
        if (location != null) 'location': location,
        if (mediaAspectRatio != null) 'mediaAspectRatio': mediaAspectRatio,
        if (yearCreated != null) 'yearCreated': yearCreated,
        if (framingMounting != null) 'framingMounting': framingMounting,
        if (provenance != null) 'provenance': provenance,
        if (handlingNotes != null) 'handlingNotes': handlingNotes,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'isLiked': isLiked,
        'isSaved': isSaved,
        if (authorUsername != null) 'authorUsername': authorUsername,
        if (authorName != null) 'authorName': authorName,
        if (authorAvatarUrl != null) 'authorAvatarUrl': authorAvatarUrl,
        'authorIsFollowing': authorIsFollowing,
        if (series != null) 'series': series!.toJson(),
        if (status != null) 'status': status,
        'materials': materials,
        'styleTags': styleTags,
        'aiDisclosed': aiDisclosed,
        if (altText != null) 'altText': altText,
        if (relatedPosts != null)
          'relatedPosts': relatedPosts!.map((p) => p.toJson()).toList(),
      };

  String? get priceDisplay {
    if (priceCents == null) return null;
    return '\$${(priceCents! / 100).toStringAsFixed(0)}';
  }
}
