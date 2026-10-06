import 'piece_summary.dart';

class UserProfile {
  const UserProfile({
    required this.username,
    required this.name,
    this.email,
    this.phone,
    this.bio,
    this.location,
    this.pronouns,
    this.latitude,
    this.longitude,
    this.profilePhotoUrl,
    this.coverPhotoUrl,
    this.role,
    this.onboardingComplete = false,
    this.sellerEnabled = false,
    this.canChangeUsername = true,
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
  });

  final String username;
  final String name;
  final String? email;
  final String? phone;
  final String? bio;
  final String? location;
  final String? pronouns;
  final double? latitude;
  final double? longitude;
  final String? profilePhotoUrl;
  final String? coverPhotoUrl;
  final String? role;
  final bool onboardingComplete;
  final bool sellerEnabled;
  final bool canChangeUsername;
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
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      coverPhotoUrl: json['coverPhotoUrl'] as String?,
      role: json['role'] as String?,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      sellerEnabled:
          json['sellerEnabled'] as bool? ?? json['isSeller'] as bool? ?? false,
      canChangeUsername: json['canChangeUsername'] as bool? ?? true,
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
      messagePermission: json['messagePermission'] as String? ?? 'everyone',
      profileVisibility: json['profileVisibility'] as String? ?? 'public',
      notificationPreferences:
          json['notificationPreferences'] is Map<String, dynamic>
          ? NotificationPreferences.fromJson(
              json['notificationPreferences'] as Map<String, dynamic>,
            )
          : null,
      isLocked: isLocked,
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
      latitude: latitude,
      longitude: longitude,
      profilePhotoUrl: profilePhotoUrl,
      coverPhotoUrl: coverPhotoUrl,
      role: role,
      onboardingComplete: onboardingComplete,
      sellerEnabled: sellerEnabled,
      canChangeUsername: canChangeUsername,
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
  });

  final Map<String, bool> push;
  final bool dailyDigestEnabled;
  final String dailyDigestTime;

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
    );
  }

  NotificationPreferences copyWith({
    Map<String, bool>? push,
    bool? dailyDigestEnabled,
    String? dailyDigestTime,
  }) {
    return NotificationPreferences(
      push: push ?? this.push,
      dailyDigestEnabled: dailyDigestEnabled ?? this.dailyDigestEnabled,
      dailyDigestTime: dailyDigestTime ?? this.dailyDigestTime,
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
