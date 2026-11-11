import 'auction.dart';
import 'order.dart' show PieceViewerOrder;
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

/// A show the piece was on (Phase 5.4, "Exhibited"): the event's name, venue and city, and
/// the month in the event's own zone, shown as the server sends it. [eventId] is null once the
/// event is deleted.
class PieceExhibition {
  const PieceExhibition({required this.title, this.eventId, this.venueName, this.city, this.date, this.month});

  final String? eventId;
  final String title;
  final String? venueName;
  final String? city;
  final DateTime? date;

  /// "November 2026".
  final String? month;

  /// "Cedars Union, Austin", dropping what's missing.
  String get place => [venueName ?? '', city ?? ''].where((p) => p.trim().isNotEmpty).join(', ');

  factory PieceExhibition.fromJson(Map<String, dynamic> json) => PieceExhibition(
        eventId: json['eventId'] as String?,
        title: json['title'] as String? ?? '',
        venueName: json['venueName'] as String?,
        city: json['city'] as String?,
        date: DateTime.tryParse(json['date'] as String? ?? ''),
        month: json['month'] as String?,
      );

  static List<PieceExhibition> listFrom(Object? raw) =>
      (raw as List?)
          ?.whereType<Map<String, dynamic>>()
          .map(PieceExhibition.fromJson)
          .where((e) => e.title.isNotEmpty)
          .toList() ??
      const [];

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'title': title,
        if (venueName != null) 'venueName': venueName,
        if (city != null) 'city': city,
        if (date != null) 'date': date!.toIso8601String(),
        if (month != null) 'month': month,
      };
}

/// What the piece's owner still has to add before it can ship through Convelio
/// (`shippingReady`, FRONTEND_HANDOFF 8.1): labels such as "packed length", "weight",
/// "pickup address". Sent to the owner only.
class ShippingReady {
  const ShippingReady({required this.ready, this.missing = const []});

  final bool ready;
  final List<String> missing;

  static ShippingReady? maybeFrom(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return ShippingReady(
      ready: raw['ready'] as bool? ?? false,
      missing: (raw['missing'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }

  /// "To ship, add: packed length, weight." — null when nothing is missing.
  String? get line => ready || missing.isEmpty ? null : 'To ship, add: ${missing.join(', ')}.';

  Map<String, dynamic> toJson() => {'ready': ready, 'missing': missing};
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
    this.startingBidCents,
    this.bidIncrementCents,
    this.bidCount = 0,
    this.minNextBidCents,
    this.isHighestBidder = false,
    this.auction,
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
    this.savesCount,
    this.lastAuction,
    this.myTopBidCents,
    this.myBidStatus,
    this.isLiked = false,
    this.isSaved = false,
    this.authorUsername,
    this.authorName,
    this.authorAvatarUrl,
    this.authorIsFollowing = false,
    this.series,
    this.listingState,
    this.imageUrls = const [],
    this.status,
    this.materials = const [],
    this.styleTags = const [],
    this.aiDisclosed = false,
    this.altText,
    this.relatedPosts,
    this.createdAt,
    this.updatedAt,
    this.draftStep,
    this.publishFailed = false,
    this.hidden = false,
    this.exhibitions = const [],
    this.shippingItemType,
    this.shippingPacking,
    this.shippingMaterials = const [],
    this.shippingReady,
    this.viewerOrder,
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

  /// The artist's stated minimum — the first bid may land exactly on it.
  /// Distinct from [highestBidCents], which is null until someone bids.
  final int? startingBidCents;

  /// Server-computed step above the current high bid. Banded by price, so the
  /// client must never assume a fixed amount. Zero when there are no bids yet.
  final int? bidIncrementCents;
  final int bidCount;
  final int? minNextBidCents;
  /// Whether the viewer currently leads the *live* bidding. Goes false the moment the
  /// auction closes, because there is no longer a highest active bid — use
  /// [AuctionSummary.isWinner] on [auction] to ask who won.
  final bool isHighestBidder;

  /// The full auction state, including everything that only exists after the close: who won,
  /// whether their payment failed, and how long they have to fix it. Null for a fixed-price
  /// piece.
  final AuctionSummary? auction;
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

  /// How many people saved it: sent to its owner only, else null (BACKEND_CHANGES B17).
  final int? savesCount;

  /// The artist's auction that ended, on their own piece only (BACKEND_CHANGES B38).
  final EndedAuction? lastAuction;

  /// The viewer's own bid, from the server (BACKEND_CHANGES B18): the most they bid in this
  /// run, and `leading`, `outbid`, `won`, `lost` or `none`. Null signed out (or from an older
  /// server), when the app falls back on what this phone remembers (`BidStore`).
  final int? myTopBidCents;
  final String? myBidStatus;
  final bool isLiked;
  final bool isSaved;
  final String? authorUsername;
  final String? authorName;
  final String? authorAvatarUrl;
  final bool authorIsFollowing;
  final PieceSeriesInfo? series;

  /// Marketplace badge from the piece payload (`available`, `collected`, …).
  final String? listingState;

  /// Ordered gallery. Empty when the payload only has a cover [mediaUrl].
  final List<String> imageUrls;
  final String? status;
  final List<String> materials;

  /// Shows it was on the bill of, newest first (Phase 5.4); empty for none.
  final List<PieceExhibition> exhibitions;
  final List<String> styleTags;
  final bool aiDisclosed;
  final String? altText;
  final List<PostSummary>? relatedPosts;

  /// When it was first saved (Drafts' time line on a server without [updatedAt]).
  final DateTime? createdAt;

  /// When it was last edited (BACKEND_CHANGES B33): Drafts' time line.
  final DateTime? updatedAt;

  /// A draft: the posting step it stopped on, as the app named it (B33).
  final String? draftStep;

  /// A draft that saved but failed to go live, on any device (B33).
  final bool publishFailed;

  /// On the owner's own Collection (`?includeHidden=1`, B32): they hid this piece, so nobody
  /// else sees it there.
  final bool hidden;

  /// Convelio item type, packing and materials (FRONTEND_HANDOFF 8.1); null / empty unset.
  final String? shippingItemType;
  final String? shippingPacking;
  final List<String> shippingMaterials;

  /// The owner's what-is-missing-to-ship (8.1); null for anyone else or an older server.
  final ShippingReady? shippingReady;

  /// The viewer's own order on this piece (8.4); null for everyone else.
  final PieceViewerOrder? viewerOrder;

  bool get isLive => status == null || status == 'live';

  bool get isAuction => listingType == 'auction';

  /// The auction closed with a winning bid and is awaiting the winner's checkout.
  bool get isAuctionWon => status == 'auction_won';

  /// Buyable right now at a fixed price.
  ///
  /// Deliberately false for a live auction: the price shown there is a starting bid, and
  /// the only way to acquire the piece is to win it. The server reports those separately as
  /// `auction_live` for that reason.
  bool get isAvailableListing => _listingState == 'available';

  /// Sold, reserved, or otherwise no longer purchasable.
  bool get isCollectedListing => _listingState == 'collected';

  /// Bidding is open.
  bool get isAuctionLive => _listingState == 'auction_live';

  /// The auction closed with a winner, who has yet to complete checkout.
  bool get isAuctionEnded => _listingState == 'auction_ended';

  /// True for anything that should carry a marketplace badge, auctions included.
  bool get hasListingBadge => _listingState != 'none';

  String get _listingState => listingState ?? _derivedListingState;

  /// Fallback for cached payloads written before the server sent listingState.
  String get _derivedListingState {
    if (status == 'sold' || status == 'reserved') return 'collected';
    if (status == 'auction_won') return 'auction_ended';
    if (status == 'delisted' && isForSale) return 'collected';
    if (isForSale && isAuction && isLive) return 'auction_live';
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
      startingBidCents: _intFrom(json['startingBidCents']),
      bidIncrementCents: _intFrom(json['bidIncrementCents']),
      bidCount: _intFrom(json['bidCount']) ?? 0,
      minNextBidCents: _intFrom(json['minNextBidCents']),
      isHighestBidder: json['isHighestBidder'] as bool? ?? false,
      auction: AuctionSummary.maybeFrom(json),
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
      savesCount: _intFrom(json['savesCount']),
      lastAuction: EndedAuction.maybeFrom(json['lastAuction']),
      myTopBidCents: _intFrom(json['myTopBidCents']),
      myBidStatus: json['myBidStatus'] as String?,
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
      listingState: json['listingState'] as String?,
      imageUrls: _imageUrls(json),
      status: json['status'] as String?,
      materials: (json['materials'] as List?)?.whereType<String>().toList() ??
          const [],
      exhibitions: PieceExhibition.listFrom(json['exhibitions']),
      styleTags: (json['styleTags'] as List?)?.whereType<String>().toList() ??
          const [],
      aiDisclosed: json['aiDisclosed'] as bool? ?? false,
      altText: json['altText'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toLocal(),
      draftStep: json['draftStep'] as String?,
      publishFailed: json['publishFailed'] as bool? ?? false,
      hidden: json['hidden'] as bool? ?? false,
      shippingItemType: json['shippingItemType'] as String?,
      shippingPacking: json['shippingPacking'] as String?,
      shippingMaterials:
          (json['shippingMaterials'] as List?)?.whereType<String>().toList() ?? const [],
      shippingReady: ShippingReady.maybeFrom(json['shippingReady']),
      viewerOrder: PieceViewerOrder.maybeFrom(json['viewerOrder']),
      relatedPosts: relatedPostsJson is List
          ? relatedPostsJson
              .whereType<Map<String, dynamic>>()
              .map(PostSummary.fromJson)
              .toList()
          : null,
    );
  }

  static List<String> _imageUrls(Map<String, dynamic> json) {
    final raw = json['images'];
    if (raw is List) {
      final urls = <String>[];
      for (final item in raw) {
        if (item is String && item.isNotEmpty) {
          urls.add(item);
        } else if (item is Map && item['mediaUrl'] is String) {
          final url = item['mediaUrl'] as String;
          if (url.isNotEmpty) urls.add(url);
        }
      }
      if (urls.isNotEmpty) return urls;
    }
    final cover = json['mediaUrl'] as String?;
    if (cover != null && cover.isNotEmpty) return [cover];
    return const [];
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
        if (images.isNotEmpty)
          'images': images.map((i) => i.toJson()).toList()
        else if (imageUrls.isNotEmpty)
          'images': [for (final url in imageUrls) {'mediaUrl': url}],
        if (caption != null) 'caption': caption,
        if (medium != null) 'medium': medium,
        'isForSale': isForSale,
        if (priceCents != null) 'priceCents': priceCents,
        if (listingType != null) 'listingType': listingType,
        if (auctionDurationDays != null) 'auctionDurationDays': auctionDurationDays,
        if (auctionEndsAt != null) 'auctionEndsAt': auctionEndsAt!.toIso8601String(),
        if (highestBidCents != null) 'highestBidCents': highestBidCents,
        if (startingBidCents != null) 'startingBidCents': startingBidCents,
        if (bidIncrementCents != null) 'bidIncrementCents': bidIncrementCents,
        'bidCount': bidCount,
        if (minNextBidCents != null) 'minNextBidCents': minNextBidCents,
        'isHighestBidder': isHighestBidder,
        ...?auction?.toJson(),
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
        if (savesCount != null) 'savesCount': savesCount,
        if (lastAuction != null) 'lastAuction': lastAuction!.toJson(),
        if (myTopBidCents != null) 'myTopBidCents': myTopBidCents,
        if (myBidStatus != null) 'myBidStatus': myBidStatus,
        'isLiked': isLiked,
        'isSaved': isSaved,
        if (authorUsername != null) 'authorUsername': authorUsername,
        if (authorName != null) 'authorName': authorName,
        if (authorAvatarUrl != null) 'authorAvatarUrl': authorAvatarUrl,
        'authorIsFollowing': authorIsFollowing,
        if (series != null) 'series': series!.toJson(),
        if (listingState != null) 'listingState': listingState,
        if (status != null) 'status': status,
        'materials': materials,
        if (exhibitions.isNotEmpty) 'exhibitions': exhibitions.map((e) => e.toJson()).toList(),
        'styleTags': styleTags,
        'aiDisclosed': aiDisclosed,
        if (altText != null) 'altText': altText,
        if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
        if (draftStep != null) 'draftStep': draftStep,
        if (publishFailed) 'publishFailed': true,
        if (hidden) 'hidden': true,
        if (shippingItemType != null) 'shippingItemType': shippingItemType,
        if (shippingPacking != null) 'shippingPacking': shippingPacking,
        if (shippingMaterials.isNotEmpty) 'shippingMaterials': shippingMaterials,
        if (shippingReady != null) 'shippingReady': shippingReady!.toJson(),
        if (viewerOrder != null) 'viewerOrder': viewerOrder!.toJson(),
        if (relatedPosts != null)
          'relatedPosts': relatedPosts!.map((p) => p.toJson()).toList(),
      };

  String? get priceDisplay {
    if (priceCents == null) return null;
    return '\$${(priceCents! / 100).toStringAsFixed(0)}';
  }
}
