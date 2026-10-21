import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';

class ExploreFeedImage extends StatelessWidget {
  const ExploreFeedImage({super.key, this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final fill = context.studio.surface;
    if (url == null || url!.isEmpty) {
      return ColoredBox(color: fill);
    }

    final fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final cacheWidth = (maxWidth * dpr).round().clamp(1, 1200);
        return CachedNetworkImage(
          imageUrl: url!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: cacheWidth,
          fadeInDuration: fade,
          placeholder: (context, url) => ColoredBox(color: fill),
          errorWidget: (context, error, stackTrace) => ColoredBox(color: fill),
        );
      },
    );
  }
}
