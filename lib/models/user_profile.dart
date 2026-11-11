import 'piece_summary.dart';
import 'studio_event.dart';

class UserProfile {
  const UserProfile({
    required this.username,
    required this.name,
    this.email,
    this.phone,
    this.bio,
    this.location,
    this.pronouns,
    this.website,
    this.instagram,
    this.twitter,
    this.category,
    this.tags = const [],
    this.latitude,
    this.longitude,
    this.profilePhotoUrl,
    this.coverPhotoUrl,
    this.role,
    this.onboardingComplete = false,
    this.sellerEnabled = false,
    this.canChangeUsername = true,
    this.lastUsernameChangeAt,
    this.followingCount = 0,
    this.followersCount = 0,
    this.piecesCount = 0,
    this.collectedCount = 0,
    this.savesCount = 0,
    this.rating,
    this.isFollowing = false,
    this.followRequestPending = false,
    this.tastePreferences,
    this.savedPieces = const [],
    this.banner,
    this.bannerTargetType,
    this.bannerTargetId,
    this.bannerAutoRule = 'none',
    this.messagePermission = 'everyone',
    this.profileVisibility = 'public',
    this.notificationPreferences,
    this.isLocked = false,
    this.followingKnown = true,
    this.statsKnown = true,
    this.upcomingEvent,
    this.profileMediums = const [],
    this.artistsCount,
    this.collectionPrivate,
  });

  final String username;
  final String name;
  final String? email;
  final String? phone;
  final String? bio;
  final String? location;
  final String? pronouns;
  final String? website;
  final String? instagram;
  final String? twitter;
  final String? category;
  final List<String> tags;
  final double? latitude;
  final double? longitude;
  final String? profilePhotoUrl;
  final String? coverPhotoUrl;
  final String? role;
  final bool onboardingComplete;
  final bool sellerEnabled;
  final bool canChangeUsername;

  /// When the username last changed; it can change again 30 days later (own profile only).
  final DateTime? lastUsernameChangeAt;
  final int followingCount;
  final int followersCount;
  final int piecesCount;
  final int collectedCount;
  final int savesCount;
  final double? rating;
  final bool isFollowing;
  final bool followRequestPending;
  final Map<String, dynamic>? tastePreferences;
  final List<PieceSummary> savedPieces;
  final ProfileBanner? banner;
  final String? bannerTargetType;
  final String? bannerTargetId;
  final String bannerAutoRule;
  final String messagePermission;
  final String profileVisibility;
  final NotificationPreferences? notificationPreferences;

  /// True when this came from the header-only "locked" response returned
  /// for a private profile the viewer can't yet see (see `isLocked` check
  /// in `fromJson`) — pieces/posts/series tabs must not be fetched.
  final bool isLocked;

  /// Whether the server sent the following count and the stats. A full profile always does;
  /// a locked one (`ProfilePrivate`) only once the server adds them (BACKEND_CHANGES B36),
  /// and until then the header leaves them off rather than showing zeros.
  final bool followingKnown;
  final bool statsKnown;

  /// Up to three mediums under the username, in order (`ProfileSeller`, `EditProfile`;
  /// BACKEND_CHANGES B31). Not the sign-up taste.
  final List<String> profileMediums;

  /// How many artists they've bought from: the collector's "artists" stat. Null from a server
  /// that doesn't send it.
  final int? artistsCount;

  /// Private Collection (`SettingsPrivacy`, B34), on your own profile only. Null from a server
  /// that doesn't have it, and then the switch isn't shown.
  final bool? collectionPrivate;

  /// The profile's Upcoming show (`ProfileSeller`, `ProfileOwn`): the soonest published event
  /// they host that hasn't ended (BACKEND_CHANGES B27). Null when there is none.
  final StudioEvent? upcomingEvent;

  bool get isPrivate => profileVisibility == 'private';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // The backend returns a header-only subset for a private profile the
    // viewer can't see yet (no counts, no bio) — detect it by the absence
    // of any count field alongside a present profileVisibility, rather than
    // trusting a single flag the backend doesn't explicitly send.
    final isLocked =
        json['profileVisibility'] != null &&
        json['followersCount'] == null &&
        json['followers'] == null &&
        json['piecesCount'] == null &&
        json['pieces'] == null;
    return UserProfile(
      username: json['username'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      pronouns: json['pronouns'] as String?,
      website: json['website'] as String?,
      instagram: json['instagram'] as String?,
      twitter: json['twitter'] as String?,
      category: json['category'] as String?,
      tags: (json['tags'] as List?)?.whereType<String>().toList() ?? const [],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      coverPhotoUrl: json['coverPhotoUrl'] as String?,
      role: json['role'] as String?,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      sellerEnabled:
          json['sellerEnabled'] as bool? ?? json['isSeller'] as bool? ?? false,
      canChangeUsername: json['canChangeUsername'] as bool? ?? true,
      lastUsernameChangeAt: DateTime.tryParse(json['lastUsernameChangeAt'] as String? ?? '')?.toLocal(),
      followingCount: _intFrom(json['followingCount'] ?? json['following']),
      followersCount: _intFrom(json['followersCount'] ?? json['followers']),
      piecesCount: _intFrom(json['piecesCount'] ?? json['pieces']),
      collectedCount: _intFrom(json['collectedCount'] ?? json['collected']),
      savesCount: _intFrom(json['savesCount'] ?? json['saves']),
      rating: _doubleFrom(json['rating'] ?? json['sellerRating']),
      isFollowing: json['isFollowing'] as bool? ?? false,
      followRequestPending: json['followRequestPending'] as bool? ?? false,
      tastePreferences: json['tastePreferences'] as Map<String, dynamic>?,
      savedPieces: _parseSavedPieces(json),
      banner: json['banner'] is Map<String, dynamic>
          ? ProfileBanner.fromJson(json['banner'] as Map<String, dynamic>)
          : null,
      bannerTargetType: json['bannerTargetType'] as String?,
      bannerTargetId: json['bannerTargetId'] as String?,
      bannerAutoRule: json['bannerAutoRule'] as String? ?? 'none',
      // A locked profile shows Message only when the owner takes messages from everyone
      // (`ProfilePrivate`); when the server doesn't say (before B36), it stays off.
      messagePermission: json['messagePermission'] as String? ?? (isLocked ? 'no_one' : 'everyone'),
      profileVisibility: json['profileVisibility'] as String? ?? 'public',
      notificationPreferences:
          json['notificationPreferences'] is Map<String, dynamic>
          ? NotificationPreferences.fromJson(
              json['notificationPreferences'] as Map<String, dynamic>,
            )
          : null,
      isLocked: isLocked,
      followingKnown: !isLocked || json['followingCount'] != null || json['following'] != null,
      statsKnown: !isLocked || json['collectedCount'] != null || json['savesCount'] != null,
      upcomingEvent: json['upcomingEvent'] is Map<String, dynamic>
          ? StudioEvent.fromJson(json['upcomingEvent'] as Map<String, dynamic>)
          : null,
      profileMediums:
          (json['profileMediums'] as List?)?.whereType<String>().where((m) => m.trim().isNotEmpty).take(3).toList() ??
          const [],
      artistsCount: json['artistsCount'] is num ? (json['artistsCount'] as num).toInt() : null,
      collectionPrivate: json['collectionPrivate'] as bool?,
    );
  }

  UserProfile copyWith({
    bool? isFollowing,
    bool? followRequestPending,
    int? followersCount,
  }) {
    return UserProfile(
      username: username,
      name: name,
      email: email,
      phone: phone,
      bio: bio,
      location: location,
      pronouns: pronouns,
      website: website,
      instagram: instagram,
      twitter: twitter,
      category: category,
      tags: tags,
      latitude: latitude,
      longitude: longitude,
      profilePhotoUrl: profilePhotoUrl,
      coverPhotoUrl: coverPhotoUrl,
      role: role,
      onboardingComplete: onboardingComplete,
      sellerEnabled: sellerEnabled,
      canChangeUsername: canChangeUsername,
      lastUsernameChangeAt: lastUsernameChangeAt,
      followingCount: followingCount,
      followersCount: followersCount ?? this.followersCount,
      piecesCount: piecesCount,
      collectedCount: collectedCount,
      savesCount: savesCount,
      rating: rating,
      isFollowing: isFollowing ?? this.isFollowing,
      followRequestPending: followRequestPending ?? this.followRequestPending,
      tastePreferences: tastePreferences,
      savedPieces: savedPieces,
      banner: banner,
      bannerTargetType: bannerTargetType,
      bannerTargetId: bannerTargetId,
      bannerAutoRule: bannerAutoRule,
      messagePermission: messagePermission,
      profileVisibility: profileVisibility,
      notificationPreferences: notificationPreferences,
      isLocked: isLocked,
      followingKnown: followingKnown,
      statsKnown: statsKnown,
      upcomingEvent: upcomingEvent,
      profileMediums: profileMediums,
      artistsCount: artistsCount,
      collectionPrivate: collectionPrivate,
    );
  }

  static int _intFrom(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static double? _doubleFrom(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }

  static List<PieceSummary> _parseSavedPieces(Map<String, dynamic> json) {
    final candidates = [
      json['savedPieces'],
      json['collectedPieces'],
      json['saved'],
    ];
    for (final list in candidates) {
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(PieceSummary.fromJson)
            .toList();
      }
    }
    return const [];
  }

  String get handle => '@$username';

  String get followingFollowers =>
      '$followingCount following · $followersCount followers';
}

/// Resolved profile "magnum opus" banner — either a manually-pinned piece/post
/// or one computed by the backend per `bannerAutoRule`.
class ProfileBanner {
  const ProfileBanner({this.targetType, this.targetId, this.mediaUrl});

  final String? targetType;
  final String? targetId;
  final String? mediaUrl;

  factory ProfileBanner.fromJson(Map<String, dynamic> json) {
    return ProfileBanner(
      targetType: json['targetType'] as String?,
      targetId: json['targetId'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
    );
  }
}

/// `notificationPreferences` blob from `GET /api/user/me` /
/// `PATCH /api/user/me/notification-preferences`.
class NotificationPreferences {
  const NotificationPreferences({
    this.push = const {
      'follow': true,
      'like': true,
      'save': true,
      'comment': true,
      'inquiry': true,
      'purchase': true,
    },
    this.dailyDigestEnabled = false,
    this.dailyDigestTime = '09:00',
    this.savesAndFollowsMode = savesAndFollowsDaily,
  });

  final Map<String, bool> push;
  final bool dailyDigestEnabled;
  final String dailyDigestTime;

  /// Saves and follows: one push a day ([savesAndFollowsDaily], the default) or one for each
  /// ([savesAndFollowsInstant]) (`NotifSettings`; BACKEND_CHANGES B7).
  final String savesAndFollowsMode;

  static const savesAndFollowsDaily = 'daily';
  static const savesAndFollowsInstant = 'instant';

  static const _defaultPush = {
    'follow': true,
    'like': true,
    'save': true,
    'comment': true,
    'inquiry': true,
    'purchase': true,
  };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    final pushJson = json['push'] as Map<String, dynamic>?;
    final digestJson = json['dailyDigest'] as Map<String, dynamic>?;
    return NotificationPreferences(
      push: {
        ..._defaultPush,
        if (pushJson != null)
          ...pushJson.map(
            (key, value) => MapEntry(key, value as bool? ?? true),
          ),
      },
      dailyDigestEnabled: digestJson?['enabled'] as bool? ?? false,
      dailyDigestTime: digestJson?['time'] as String? ?? '09:00',
      savesAndFollowsMode: json['savesAndFollowsMode'] == savesAndFollowsInstant
          ? savesAndFollowsInstant
          : savesAndFollowsDaily,
    );
  }

  NotificationPreferences copyWith({
    Map<String, bool>? push,
    bool? dailyDigestEnabled,
    String? dailyDigestTime,
    String? savesAndFollowsMode,
  }) {
    return NotificationPreferences(
      push: push ?? this.push,
      dailyDigestEnabled: dailyDigestEnabled ?? this.dailyDigestEnabled,
      dailyDigestTime: dailyDigestTime ?? this.dailyDigestTime,
      savesAndFollowsMode: savesAndFollowsMode ?? this.savesAndFollowsMode,
    );
  }
}

class SellerStatus {
  const SellerStatus({required this.enabled, this.location});

  final bool enabled;
  final String? location;

  factory SellerStatus.fromJson(Map<String, dynamic> json) {
    return SellerStatus(
      enabled:
          json['enabled'] as bool? ??
          json['sellerEnabled'] as bool? ??
          json['isSeller'] as bool? ??
          false,
      location:
          json['location'] as String? ?? json['sellerLocation'] as String?,
    );
  }
}

/// What a seller keeps on a sale at their own rate (`GET /api/user/me/commission-quote`):
/// the "You'll receive" line on the listing form.
class CommissionQuote {
  const CommissionQuote({
    required this.priceCents,
    required this.netCents,
    required this.commissionBps,
    this.reducedRate = false,
    this.reducedRateUntil,
  });

  final int priceCents;
  final int netCents;
  final int commissionBps;

  /// The seller's own rate is below the standard one (the founding-artist tier).
  final bool reducedRate;

  /// When the reduced rate ends (B3), or null when it has no end date or there is none. Not
  /// shown anywhere yet: the app never names the tier.
  final DateTime? reducedRateUntil;

  factory CommissionQuote.fromJson(Map<String, dynamic> json) {
    return CommissionQuote(
      priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
      netCents: (json['netCents'] as num?)?.toInt() ?? 0,
      commissionBps: (json['commissionBps'] as num?)?.toInt() ?? 0,
      reducedRate: json['reducedRate'] as bool? ?? false,
      reducedRateUntil: DateTime.tryParse(json['reducedRateUntil'] as String? ?? ''),
    );
  }
}

/// One thing keeping the account from being deleted (`/api/user/me/deletion-check`), e.g.
/// `running_auction`, `shipping_sale`, `fee_debt`; [message] is the server's words for it.
class DeletionBlocker {
  const DeletionBlocker({required this.kind, required this.message, this.count = 1, this.amountCents});

  final String kind;
  final String message;
  final int count;

  /// What is owed, on `fee_debt`.
  final int? amountCents;

  factory DeletionBlocker.fromJson(Map<String, dynamic> json) {
    return DeletionBlocker(
      kind: json['kind'] as String? ?? '',
      message: json['message'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 1,
      amountCents: (json['amountCents'] as num?)?.toInt(),
    );
  }
}

/// Whether the account can be deleted now, and what is in the way.
class DeletionCheck {
  const DeletionCheck({required this.canDelete, this.blockers = const []});

  final bool canDelete;
  final List<DeletionBlocker> blockers;

  factory DeletionCheck.fromJson(Map<String, dynamic> json) {
    final blockers = (json['blockers'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(DeletionBlocker.fromJson)
            .toList() ??
        const <DeletionBlocker>[];
    return DeletionCheck(
      canDelete: json['canDelete'] as bool? ?? blockers.isEmpty,
      blockers: blockers,
    );
  }
}

/// The account's own seller rates (`/api/user/me/seller-terms`). The app never names the tier
/// behind [reducedRate].
class SellerTerms {
  const SellerTerms({
    this.artCommissionPercent,
    this.ticketFeePercent,
    this.reducedRate = false,
    this.reducedRateUntil,
  });

  final double? artCommissionPercent;
  final double? ticketFeePercent;
  final bool reducedRate;
  final DateTime? reducedRateUntil;

  factory SellerTerms.fromJson(Map<String, dynamic> json) {
    double? percent(String percentKey, String bpsKey) {
      final p = json[percentKey];
      if (p is num) return p.toDouble();
      final bps = json[bpsKey];
      return bps is num ? bps / 100 : null;
    }

    return SellerTerms(
      artCommissionPercent: percent('artCommissionPercent', 'artCommissionBps'),
      ticketFeePercent: percent('ticketFeePercent', 'ticketFeeBps'),
      reducedRate: json['reducedRate'] as bool? ?? false,
      reducedRateUntil: DateTime.tryParse(json['reducedRateUntil'] as String? ?? ''),
    );
  }

  /// "15% on art · 8% on tickets" from what the server sent, or null when it sent neither.
  String? get summary {
    String fmt(double p) =>
        '${p.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')}%';
    final parts = [
      if (artCommissionPercent != null) '${fmt(artCommissionPercent!)} on art',
      if (ticketFeePercent != null) '${fmt(ticketFeePercent!)} on tickets',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class SellerAnalytics {
  const SellerAnalytics({
    this.savesCount,
    this.likesCount,
    this.inquiriesCount,
    this.salesCount,
    this.period,
  });

  final int? savesCount;
  final int? likesCount;
  final int? inquiriesCount;
  final int? salesCount;
  final String? period;

  factory SellerAnalytics.fromJson(Map<String, dynamic> json) {
    return SellerAnalytics(
      savesCount: json['savesCount'] as int?,
      likesCount: json['likesCount'] as int?,
      inquiriesCount: json['inquiriesCount'] as int?,
      salesCount: json['salesCount'] as int?,
      period: json['period'] as String?,
    );
  }
}
