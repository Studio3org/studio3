import '../utils/media_type_utils.dart';
import 'feed_item.dart';
import 'piece_summary.dart';
import 'post_summary.dart';
import 'series_summary.dart';

enum FeedAspectRatio { portrait3x4, landscape16x9 }

enum FeedAvailabilityFilter { all, available }

/// Home feed type filter (All / Piece / Scene).
enum HomeFeedContentFilter { all, piece, scene }

class RelatedScene {
  const RelatedScene({
    this.id,
    this.mediaUrl,
    this.mediaType,
    this.duration,
  });

  final String? id;
  final String? mediaUrl;
  final String? mediaType;
  final String? duration;

  bool get isVideo => isVideoMediaType(mediaType, mediaUrl);

  factory RelatedScene.fromPost(PostSummary post) {
    return RelatedScene(
      id: post.id,
      mediaUrl: post.mediaUrl,
      mediaType: post.mediaType,
    );
  }

  factory RelatedScene.fromJson(Map<String, dynamic> json) => RelatedScene(
        id: json['id'] as String?,
        mediaUrl: json['mediaUrl'] as String?,
        mediaType: json['mediaType'] as String?,
        duration: json['duration'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (mediaType != null) 'mediaType': mediaType,
        if (duration != null) 'duration': duration,
      };
}

/// Real API-backed Piece/Scene view model shared by the feed, detail, and
/// profile screens.
class FeedPreviewItem {
  const FeedPreviewItem({
    required this.id,
    required this.imageSeeds,
    required this.title,
    required this.medium,
    required this.year,
    required this.dimensions,
    required this.story,
    required this.handle,
    required this.isAvailable,
    required this.aspectRatio,
    this.isProcess = false,
    this.seriesName = '',
    this.seriesId,
    this.seriesThumbs = const [],
    this.seriesThumbUrls = const [],
    this.relatedScenes = const [],
    this.priceCents,
    this.listingType,
    this.auctionEndsAt,
    this.highestBidCents,
    this.startingBidCents,
    this.bidIncrementCents,
    this.bidCount = 0,
    this.minNextBidCents,
    this.isHighestBidder = false,
    this.shippingRegion,
    this.location,
    this.framingNote,
    this.provenanceNote,
    this.handlingNotes,
    this.heroImageUrl,
    this.galleryImageUrls = const [],
    this.isLiked = false,
    this.isSaved = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.authorName,
    this.authorUsername,
    this.authorAvatarUrl,
    this.authorIsFollowing = false,
    this.status,
    this.materials = const [],
    this.styleTags = const [],
  });

  final String id;
  final List<int> imageSeeds;
  final String title;
  final String medium;
  final int year;
  final String dimensions;
  final String story;
  final String handle;
  final bool isAvailable;
  final FeedAspectRatio aspectRatio;
  final bool isProcess;
  final String seriesName;
  final String? seriesId;
  final List<int> seriesThumbs;
  final List<String> seriesThumbUrls;
  final List<RelatedScene> relatedScenes;
  final int? priceCents;
  /// `fixed` | `auction`; null when not for sale or not auction-listed.
  final String? listingType;
  final DateTime? auctionEndsAt;
  final int? highestBidCents;

  /// The artist's stated minimum. The first bid may land exactly on it.
  final int? startingBidCents;

  /// Banded step above the current high bid, computed server-side.
  final int? bidIncrementCents;
  final int bidCount;
  final int? minNextBidCents;
  /// Only meaningful once `status == 'auction_won'` — whether the viewer is the winner.
  final bool isHighestBidder;
  final String? shippingRegion;
  final String? location;
  final String? framingNote;
  final String? provenanceNote;
  final String? handlingNotes;
  final String? heroImageUrl;
  /// A piece's full ordered gallery (Figma 2716:5774 cover/reorder posting
  /// flow) — index 0 matches [heroImageUrl]. Empty for scenes/posts (still
  /// single-image) and for pieces created before the gallery existed.
  final List<String> galleryImageUrls;
  final bool isLiked;
  final bool isSaved;
  final int likeCount;
  final int commentCount;
  final String? authorName;

  /// The artist's handle without the '@'. [handle] is the display form; this is
  /// the value APIs key on — messaging an artist needs the username, not a label.
  final String? authorUsername;
  final String? authorAvatarUrl;
  final bool authorIsFollowing;
  final String? status;
  final List<String> materials;
  final List<String> styleTags;

  bool get isLive => status == null || status == 'live';

  bool get isAuction => listingType == 'auction';

  /// The auction closed with a winning bid and is awaiting the winner's checkout.
  bool get isAuctionWon => status == 'auction_won';

  int get imageCount =>
      galleryImageUrls.isNotEmpty ? galleryImageUrls.length : imageSeeds.length;

  /// All feed items are real/API-backed now that no dummy generator exists.
  bool get isApiBacked => true;

  /// Real poster name when available, otherwise a neutral placeholder —
  /// never a fabricated name.
  String get displayName =>
      (authorName != null && authorName!.isNotEmpty) ? authorName! : 'Artist';

  /// Real poster avatar URL, or null — callers should show an initials
  /// placeholder rather than falling back to a fake photo.
  String? get displayAvatarUrl => authorAvatarUrl;

  double get aspectRatioValue =>
      aspectRatio == FeedAspectRatio.portrait3x4 ? 3 / 4 : 16 / 9;

  String? get priceDisplay {
    if (priceCents == null) return null;
    return '\$${(priceCents! / 100).toStringAsFixed(0)}';
  }

  bool get isScene => medium == 'Scene' || medium == 'Video';

  bool get isPiece => !isScene;

  FeedPreviewItem copyWith({
    String? id,
    List<int>? imageSeeds,
    String? title,
    String? medium,
    int? year,
    String? dimensions,
    String? story,
    String? handle,
    bool? isAvailable,
    FeedAspectRatio? aspectRatio,
    bool? isProcess,
    String? seriesName,
    String? seriesId,
    List<int>? seriesThumbs,
    List<String>? seriesThumbUrls,
    List<RelatedScene>? relatedScenes,
    int? priceCents,
    String? listingType,
    DateTime? auctionEndsAt,
    int? highestBidCents,
    int? startingBidCents,
    int? bidIncrementCents,
    int? bidCount,
    int? minNextBidCents,
    bool? isHighestBidder,
    String? shippingRegion,
    String? location,
    String? framingNote,
    String? provenanceNote,
    String? handlingNotes,
    String? heroImageUrl,
    List<String>? galleryImageUrls,
    bool? isLiked,
    bool? isSaved,
    int? likeCount,
    int? commentCount,
    String? authorName,
    String? authorUsername,
    String? authorAvatarUrl,
    bool? authorIsFollowing,
    String? status,
    List<String>? materials,
    List<String>? styleTags,
  }) {
    return FeedPreviewItem(
      id: id ?? this.id,
      imageSeeds: imageSeeds ?? this.imageSeeds,
      title: title ?? this.title,
      medium: medium ?? this.medium,
      year: year ?? this.year,
      dimensions: dimensions ?? this.dimensions,
      story: story ?? this.story,
      handle: handle ?? this.handle,
      isAvailable: isAvailable ?? this.isAvailable,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      isProcess: isProcess ?? this.isProcess,
      seriesName: seriesName ?? this.seriesName,
      seriesId: seriesId ?? this.seriesId,
      seriesThumbs: seriesThumbs ?? this.seriesThumbs,
      seriesThumbUrls: seriesThumbUrls ?? this.seriesThumbUrls,
      relatedScenes: relatedScenes ?? this.relatedScenes,
      priceCents: priceCents ?? this.priceCents,
      listingType: listingType ?? this.listingType,
      auctionEndsAt: auctionEndsAt ?? this.auctionEndsAt,
      highestBidCents: highestBidCents ?? this.highestBidCents,
      startingBidCents: startingBidCents ?? this.startingBidCents,
      bidIncrementCents: bidIncrementCents ?? this.bidIncrementCents,
      bidCount: bidCount ?? this.bidCount,
      minNextBidCents: minNextBidCents ?? this.minNextBidCents,
      isHighestBidder: isHighestBidder ?? this.isHighestBidder,
      shippingRegion: shippingRegion ?? this.shippingRegion,
      location: location ?? this.location,
      framingNote: framingNote ?? this.framingNote,
      provenanceNote: provenanceNote ?? this.provenanceNote,
      handlingNotes: handlingNotes ?? this.handlingNotes,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      galleryImageUrls: galleryImageUrls ?? this.galleryImageUrls,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      authorName: authorName ?? this.authorName,
      authorUsername: authorUsername ?? this.authorUsername,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      authorIsFollowing: authorIsFollowing ?? this.authorIsFollowing,
      status: status ?? this.status,
      materials: materials ?? this.materials,
      styleTags: styleTags ?? this.styleTags,
    );
  }

  /// Builds a preview-shaped item from an API [PieceSummary] for collect detail.
  factory FeedPreviewItem.fromPieceSummary(PieceSummary piece) {
    final username = piece.authorUsername ?? 'artist';
    final series = piece.series;
    final seriesThumbs = series?.previewPieces
            .map((preview) => preview.id.hashCode.abs())
            .toList(growable: false) ??
        const <int>[];
    final seriesThumbUrls = series?.previewPieces
            .map((preview) => preview.mediaUrl)
            .whereType<String>()
            .where((url) => url.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    return FeedPreviewItem(
      id: piece.id,
      imageSeeds: [piece.id.hashCode.abs()],
      title: piece.title,
      medium: piece.medium ?? 'Mixed media',
      year: piece.yearCreated ?? DateTime.now().year,
      dimensions: piece.dimensions ?? '',
      story: piece.caption ?? '',
      handle: username.startsWith('@') ? username : '@$username',
      authorUsername: username,
      isAvailable: piece.isForSale,
      aspectRatio: aspectRatioFromDimensions(piece.dimensions),
      priceCents: piece.priceCents,
      listingType: piece.listingType,
      auctionEndsAt: piece.auctionEndsAt,
      highestBidCents: piece.highestBidCents,
      startingBidCents: piece.startingBidCents,
      bidIncrementCents: piece.bidIncrementCents,
      bidCount: piece.bidCount,
      minNextBidCents: piece.minNextBidCents,
      isHighestBidder: piece.isHighestBidder,
      shippingRegion: piece.shippingRegion,
      location: piece.location,
      framingNote: piece.framingMounting,
      provenanceNote: piece.provenance,
      handlingNotes: piece.handlingNotes,
      heroImageUrl: piece.mediaUrl,
      galleryImageUrls: ([...piece.images]
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
          .map((image) => image.mediaUrl)
          .where((url) => url.isNotEmpty)
          .toList(growable: false),
      seriesName: series?.name ?? '',
      seriesId: series?.id,
      seriesThumbs: seriesThumbs,
      seriesThumbUrls: seriesThumbUrls,
      isLiked: piece.isLiked,
      isSaved: piece.isSaved,
      likeCount: piece.likeCount,
      commentCount: piece.commentCount,
      authorName: piece.authorName,
      authorAvatarUrl: piece.authorAvatarUrl,
      authorIsFollowing: piece.authorIsFollowing,
      status: piece.status,
      materials: piece.materials,
      styleTags: piece.styleTags,
    );
  }

  /// Builds a preview item from an explore/home API [FeedItem].
  factory FeedPreviewItem.fromFeedItem(FeedItem item) {
    if (item.type == FeedItemType.piece && item.piece != null) {
      return FeedPreviewItem.fromPieceSummary(item.piece!);
    }

    final post = item.post!;
    final username = post.authorUsername ?? 'artist';
    final isVideo = item.isVideo;
    return FeedPreviewItem(
      id: post.id,
      imageSeeds: [post.id.hashCode.abs()],
      title: post.caption ?? 'Scene',
      medium: isVideo ? 'Video' : 'Scene',
      year: DateTime.now().year,
      dimensions: '',
      story: post.caption ?? '',
      handle: username.startsWith('@') ? username : '@$username',
      authorUsername: username,
      isAvailable: false,
      aspectRatio: isVideo
          ? FeedAspectRatio.landscape16x9
          : FeedAspectRatio.portrait3x4,
      heroImageUrl: post.mediaUrl,
      location: post.location,
      isProcess: post.isProcess,
      isLiked: post.isLiked,
      isSaved: post.isSaved,
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      authorName: post.authorName,
      authorAvatarUrl: post.authorAvatarUrl,
      authorIsFollowing: post.authorIsFollowing,
    );
  }

  static List<RelatedScene> relatedScenesFromPosts(List<PostSummary> posts) {
    return posts.map(RelatedScene.fromPost).toList(growable: false);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'imageSeeds': imageSeeds,
        'title': title,
        'medium': medium,
        'year': year,
        'dimensions': dimensions,
        'story': story,
        'handle': handle,
        'isAvailable': isAvailable,
        'aspectRatio': aspectRatio.name,
        'isProcess': isProcess,
        'seriesName': seriesName,
        if (seriesId != null) 'seriesId': seriesId,
        'seriesThumbs': seriesThumbs,
        'seriesThumbUrls': seriesThumbUrls,
        'relatedScenes': relatedScenes.map((s) => s.toJson()).toList(),
        if (priceCents != null) 'priceCents': priceCents,
        if (listingType != null) 'listingType': listingType,
        if (auctionEndsAt != null) 'auctionEndsAt': auctionEndsAt!.toIso8601String(),
        if (highestBidCents != null) 'highestBidCents': highestBidCents,
        if (startingBidCents != null) 'startingBidCents': startingBidCents,
        if (bidIncrementCents != null) 'bidIncrementCents': bidIncrementCents,
        'bidCount': bidCount,
        if (minNextBidCents != null) 'minNextBidCents': minNextBidCents,
        'isHighestBidder': isHighestBidder,
        if (shippingRegion != null) 'shippingRegion': shippingRegion,
        if (location != null) 'location': location,
        if (framingNote != null) 'framingNote': framingNote,
        if (provenanceNote != null) 'provenanceNote': provenanceNote,
        if (handlingNotes != null) 'handlingNotes': handlingNotes,
        if (heroImageUrl != null) 'heroImageUrl': heroImageUrl,
        if (galleryImageUrls.isNotEmpty) 'galleryImageUrls': galleryImageUrls,
        'isLiked': isLiked,
        'isSaved': isSaved,
        'likeCount': likeCount,
        'commentCount': commentCount,
        if (authorName != null) 'authorName': authorName,
        if (authorUsername != null) 'authorUsername': authorUsername,
        if (authorAvatarUrl != null) 'authorAvatarUrl': authorAvatarUrl,
        'authorIsFollowing': authorIsFollowing,
        if (status != null) 'status': status,
        'materials': materials,
        'styleTags': styleTags,
      };

  factory FeedPreviewItem.fromCacheJson(Map<String, dynamic> json) {
    return FeedPreviewItem(
      id: json['id'] as String? ?? '',
      imageSeeds: (json['imageSeeds'] as List?)?.cast<int>() ?? const [],
      title: json['title'] as String? ?? '',
      medium: json['medium'] as String? ?? '',
      year: json['year'] as int? ?? DateTime.now().year,
      dimensions: json['dimensions'] as String? ?? '',
      story: json['story'] as String? ?? '',
      handle: json['handle'] as String? ?? '',
      isAvailable: json['isAvailable'] as bool? ?? false,
      aspectRatio: (json['aspectRatio'] as String?) == 'landscape16x9'
          ? FeedAspectRatio.landscape16x9
          : FeedAspectRatio.portrait3x4,
      isProcess: json['isProcess'] as bool? ?? false,
      seriesName: json['seriesName'] as String? ?? '',
      seriesId: json['seriesId'] as String?,
      seriesThumbs: (json['seriesThumbs'] as List?)?.cast<int>() ?? const [],
      seriesThumbUrls:
          (json['seriesThumbUrls'] as List?)?.cast<String>() ?? const [],
      relatedScenes: (json['relatedScenes'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(RelatedScene.fromJson)
              .toList() ??
          const [],
      priceCents: json['priceCents'] as int?,
      listingType: json['listingType'] as String?,
      auctionEndsAt: DateTime.tryParse(json['auctionEndsAt'] as String? ?? ''),
      highestBidCents: json['highestBidCents'] as int?,
      startingBidCents: json['startingBidCents'] as int?,
      bidIncrementCents: json['bidIncrementCents'] as int?,
      bidCount: json['bidCount'] as int? ?? 0,
      minNextBidCents: json['minNextBidCents'] as int?,
      isHighestBidder: json['isHighestBidder'] as bool? ?? false,
      shippingRegion: json['shippingRegion'] as String?,
      location: json['location'] as String?,
      framingNote: json['framingNote'] as String?,
      provenanceNote: json['provenanceNote'] as String?,
      handlingNotes: json['handlingNotes'] as String?,
      heroImageUrl: json['heroImageUrl'] as String?,
      galleryImageUrls:
          (json['galleryImageUrls'] as List?)?.whereType<String>().toList() ??
              const [],
      isLiked: json['isLiked'] as bool? ?? false,
      isSaved: json['isSaved'] as bool? ?? false,
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      authorName: json['authorName'] as String?,
      authorUsername: json['authorUsername'] as String?,
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      authorIsFollowing: json['authorIsFollowing'] as bool? ?? false,
      status: json['status'] as String?,
      materials:
          (json['materials'] as List?)?.whereType<String>().toList() ??
              const [],
      styleTags:
          (json['styleTags'] as List?)?.whereType<String>().toList() ??
              const [],
    );
  }

  static List<String> seriesThumbUrlsFrom(PieceSeriesInfo? series) {
    if (series == null) return const [];
    return series.previewPieces
        .map((preview) => preview.mediaUrl)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
  }
}

FeedAspectRatio aspectRatioFromDimensions(String? dimensions) {
  if (dimensions == null || dimensions.isEmpty) {
    return FeedAspectRatio.portrait3x4;
  }
  final match = RegExp(r'(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)')
      .firstMatch(dimensions);
  if (match == null) return FeedAspectRatio.portrait3x4;
  final w = double.tryParse(match.group(1)!);
  final h = double.tryParse(match.group(2)!);
  if (w == null || h == null || h == 0) return FeedAspectRatio.portrait3x4;
  return w / h > 1.2
      ? FeedAspectRatio.landscape16x9
      : FeedAspectRatio.portrait3x4;
}

/// The real media URL for [item], or an empty string when genuinely
/// missing — callers already show a neutral broken-image placeholder for
/// an unloadable URL, so there is no fake stand-in photo here.
String feedPreviewImageUrl(FeedPreviewItem item, {int imageIndex = 0}) {
  if (item.galleryImageUrls.isNotEmpty) {
    final index = imageIndex.clamp(0, item.galleryImageUrls.length - 1);
    return item.galleryImageUrls[index];
  }
  return item.heroImageUrl ?? '';
}
