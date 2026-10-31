import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import 'studio_icon.dart';

/// Round avatar at the board sizes: 22, 32, 36, 52, 56, 72, 76, 88. With no photo it shows
/// the person icon on Paper (`SignIn3Profile` "Add a photo": 72 circle, 26 icon).
///
/// The 88 profile avatar has a 4 px ring in the page color ([StudioAvatar.profile]);
/// the nav avatar has a 1.5 px Gallery White ring.
class StudioAvatar extends StatelessWidget {
  const StudioAvatar({
    super.key,
    required this.url,
    required this.size,
    this.ringWidth = 0,
    this.ringColor,
    this.ringInside = false,
    this.semanticLabel,
  });

  /// The 88 profile header avatar with its 4 px background-colored ring outside it.
  const StudioAvatar.profile({super.key, required this.url, this.semanticLabel})
    : size = 88,
      ringWidth = 4,
      ringColor = null,
      ringInside = false;

  final String? url;

  /// Photo size. The boards' rings are CSS borders with `box-sizing: content-box`, so the
  /// ring adds outside it (88 + 4 + 4 = 96 on profiles) unless [ringInside] is set.
  final double size;
  final double ringWidth;

  /// Defaults to the page background.
  final Color? ringColor;
  final bool ringInside;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final inner = ringInside ? size - ringWidth * 2 : size;
    final hasUrl = url != null && url!.isNotEmpty;
    final placeholder = Container(
      width: inner,
      height: inner,
      color: c.surface,
      alignment: Alignment.center,
      child: StudioIcon(StudioIcons.profile, size: inner * 0.36, color: c.textTertiary),
    );
    Widget photo = ClipOval(
      child: hasUrl
          ? CachedNetworkImage(
              imageUrl: url!,
              width: inner,
              height: inner,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(width: inner, height: inner, color: c.surface),
              errorWidget: (_, _, _) => placeholder,
            )
          : placeholder,
    );
    if (ringWidth > 0) {
      photo = Container(
        padding: EdgeInsets.all(ringWidth),
        decoration: BoxDecoration(color: ringColor ?? c.background, shape: BoxShape.circle),
        child: photo,
      );
    }
    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel == null,
      child: photo,
    );
  }
}
