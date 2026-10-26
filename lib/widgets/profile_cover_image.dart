import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/studio_colors.dart';

/// Profile cover banner — network URL or bundled art default.
class ProfileCoverImage extends StatelessWidget {
  const ProfileCoverImage({
    super.key,
    this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
    this.showDefaultWhenEmpty = true,
  });

  static const defaultAsset = 'assets/profile/default_cover.jpg';

  final String? url;
  final double width;
  final double height;
  final BoxFit fit;
  final Alignment alignment;

  /// When false and [url] is empty, renders a neutral placeholder instead of
  /// the bundled default cover — for callers still waiting on the real
  /// profile to load, so "no data yet" isn't shown as "no cover set".
  final bool showDefaultWhenEmpty;

  bool get _hasUrl => url != null && url!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: _hasUrl
          ? _networkImage()
          : (showDefaultWhenEmpty ? _defaultImage() : _neutralPlaceholder()),
    );
  }

  Widget _networkImage() {
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      fadeInDuration: const Duration(milliseconds: 280),
      placeholder: (context, url) => _neutralPlaceholder(),
      errorWidget: (context, url, error) => _defaultImage(),
    );
  }

  Widget _defaultImage() {
    return Image.asset(
      defaultAsset,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => ColoredBox(color: context.studio.surface),
    );
  }

  /// The theme's Surface while the real cover is on its way.
  Widget _neutralPlaceholder() => Builder(builder: (context) => ColoredBox(color: context.studio.surface));
}
