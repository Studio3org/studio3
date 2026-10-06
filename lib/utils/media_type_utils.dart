const _staticImageExtensions = {
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'heic',
  'heif',
};

/// Some gallery pickers (Live Photos, Motion Photos) misreport a static
/// image as a video asset, which then gets published with `mediaType:
/// 'video'` baked into the backend record permanently. A file extension on
/// the media URL that's unambiguously a still-image format overrides that
/// bad `mediaType` so the item doesn't render with video-only chrome (an
/// inline autoplay player, a mute button) over what is actually a photo.
bool isVideoMediaType(String? mediaType, String? mediaUrl) {
  final t = mediaType?.toLowerCase();
  if (t != 'video' && t != 'reel' && t != 'reels') return false;

  final url = mediaUrl;
  if (url == null) return true;
  final withoutQuery = url.split('?').first;
  final dotIndex = withoutQuery.lastIndexOf('.');
  if (dotIndex == -1) return true;
  final ext = withoutQuery.substring(dotIndex + 1).toLowerCase();
  return !_staticImageExtensions.contains(ext);
}
