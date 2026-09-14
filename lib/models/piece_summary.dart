import 'post_summary.dart';
import 'series_summary.dart';

/// One image in a piece's gallery (Figma 2716:5774 cover/reorder posting
/// flow) — `sortOrder == 0` is the cover, mirrored onto [PieceSummary.mediaUrl].
class PieceImage {
  const PieceImage({
    required this.mediaUrl,
    this.mediaType,
    this.mediaAspectRatio,
    this.sortOrder = 0,
  });

  final String mediaUrl;
  final String? mediaType;
  final String? mediaAspectRatio;
  final int sortOrder;

  factory PieceImage.fromJson(Map<String, dynamic> json) => PieceImage(
        mediaUrl: json['mediaUrl'] as String? ?? '',
        mediaType: json['mediaType'] as String?,
        mediaAspectRatio: json['mediaAspectRatio'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'mediaUrl': mediaUrl,
        if (mediaType != null) 'mediaType': mediaType,
        if (mediaAspectRatio != null) 'mediaAspectRatio': mediaAspectRatio,
        'sortOrder': sortOrder,
      };
}

class PieceSummary {
  const PieceSummary({
    required this.id,
    required this.title,
    this.mediaUrl,
    this.mediaType,
    this.images = const [],
    this.caption,
    this.medium,
    this.isForSale = false,
    this.priceCents,
    this.listingType,
    this.auctionDurationDays,
    this.auctionEndsAt,
    this.highestBidCents,
    this.bidCount = 0,
    this.minNextBidCents,
    this.isHighestBidder = false,
    this.dimensions,
    this.shippingRegion,
    this.weightKg,
    this.packageLengthCm,
    this.packageWidthCm,
    this.packageHeightCm,
    this.declaredValueCents,
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
    this.listingState,
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
  /// Full ordered gallery — index 0 is the cover and matches [mediaUrl].
  /// Empty on older cached payloads; callers should fall back to [mediaUrl].
  final List<PieceImage> images;
  final String? caption;
  final String? medium;
  final bool isForSale;
  final int? priceCents;
  /// `fixed` | `auction`; null when not for sale.
  final String? listingType;
  final int? auctionDurationDays;
  final DateTime? auctionEndsAt;
  final int? highestBidCents;
  final int bidCount;
  final int? minNextBidCents;
  /// Only meaningful once `status == 'auction_won'` — whether the viewer is the winner.
  final bool isHighestBidder;
  final String? dimensions;
  final String? shippingRegion;
  final double? weightKg;
  final double? packageLengthCm;
  final double? packageWidthCm;
  final double? packageHeightCm;
  final int? declaredValueCents;
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
  /// `available` | `collected` from the API; null on older payloads.
  final String? listingState;
  final List<String> materials;
  final List<String> styleTags;
  final bool aiDisclosed;
  final String? altText;
  final List<PostSummary>? relatedPosts;

  bool get isLive => status == null || status == 'live';

  bool get isAuction => listingType == 'auction';

  /// The auction closed with a winning bid and is awaiting the winner's checkout.
  bool get isAuctionWon => status == 'auction_won';

  /// Listed and currently purchasable.
  bool get isAvailableListing {
    final state = listingState ?? _derivedListingState;
    return state == 'available';
  }

  /// Sold, reserved, or otherwise no longer purchasable.
  bool get isCollectedListing {
    final state = listingState ?? _derivedListingState;
    return state == 'collected';
  }

  String get _derivedListingState {
    if (status == 'sold' || status == 'reserved') return 'collected';
    if (status == 'delisted' && isForSale) return 'collected';
    if (isForSale && isLive) return 'available';
    return 'none';
  }

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
      images: (json['images'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(PieceImage.fromJson)
              .toList() ??
          const [],
      caption: json['caption'] as String?,
      medium: json['medium'] as String?,
      isForSale: json['isForSale'] as bool? ?? false,
      priceCents: json['priceCents'] as int?,
      listingType: json['listingType'] as String?,
      auctionDurationDays: _intFrom(json['auctionDurationDays']),
      auctionEndsAt: DateTime.tryParse(json['auctionEndsAt'] as String? ?? ''),
      highestBidCents: _intFrom(json['highestBidCents']),
      bidCount: _intFrom(json['bidCount']) ?? 0,
      minNextBidCents: _intFrom(json['minNextBidCents']),
      isHighestBidder: json['isHighestBidder'] as bool? ?? false,
      dimensions: json['dimensions'] as String?,
      shippingRegion: json['shippingRegion'] as String?,
      weightKg: _doubleFrom(json['weightKg']),
      packageLengthCm: _doubleFrom(json['packageLengthCm']),
      packageWidthCm: _doubleFrom(json['packageWidthCm']),
      packageHeightCm: _doubleFrom(json['packageHeightCm']),
      declaredValueCents: _intFrom(json['declaredValueCents']),
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
      listingState: json['listingState'] as String?,
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

  static double? _doubleFrom(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }

  Map<String, dynamic> toJson() => {
        'type': 'piece',
        'id': id,
        'title': title,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (mediaType != null) 'mediaType': mediaType,
        if (images.isNotEmpty) 'images': images.map((i) => i.toJson()).toList(),
        if (caption != null) 'caption': caption,
        if (medium != null) 'medium': medium,
        'isForSale': isForSale,
        if (priceCents != null) 'priceCents': priceCents,
        if (listingType != null) 'listingType': listingType,
        if (auctionDurationDays != null) 'auctionDurationDays': auctionDurationDays,
        if (auctionEndsAt != null) 'auctionEndsAt': auctionEndsAt!.toIso8601String(),
        if (highestBidCents != null) 'highestBidCents': highestBidCents,
        'bidCount': bidCount,
        if (minNextBidCents != null) 'minNextBidCents': minNextBidCents,
        'isHighestBidder': isHighestBidder,
        if (dimensions != null) 'dimensions': dimensions,
        if (shippingRegion != null) 'shippingRegion': shippingRegion,
        if (weightKg != null) 'weightKg': weightKg,
        if (packageLengthCm != null) 'packageLengthCm': packageLengthCm,
        if (packageWidthCm != null) 'packageWidthCm': packageWidthCm,
        if (packageHeightCm != null) 'packageHeightCm': packageHeightCm,
        if (declaredValueCents != null) 'declaredValueCents': declaredValueCents,
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
        if (listingState != null) 'listingState': listingState,
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
