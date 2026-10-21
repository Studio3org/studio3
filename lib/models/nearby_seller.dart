class NearbySeller {
  const NearbySeller({
    required this.username,
    this.name,
    this.profilePhotoUrl,
    this.location,
    required this.distanceKm,
    this.isFollowing = false,
  });

  final String username;
  final String? name;
  final String? profilePhotoUrl;
  final String? location;
  final double distanceKm;

  /// Already on the nearby payload (`user_to_dict` sends `isFollowing`).
  final bool isFollowing;

  factory NearbySeller.fromJson(Map<String, dynamic> json) {
    return NearbySeller(
      username: json['username'] as String? ?? '',
      name: json['name'] as String?,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      location: json['location'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      isFollowing: json['isFollowing'] as bool? ?? false,
    );
  }

  String get displayName =>
      (name != null && name!.isNotEmpty) ? name! : username;

  String get distanceDisplay => '${distanceKm.toStringAsFixed(1)} km away';
}
