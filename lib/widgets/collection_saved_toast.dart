import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';

/// Confirmation after a save or unsave. The save sheet carries its own
/// "Saved" header; this toast still reports the result once that sheet closes,
/// and it is the only confirmation when there is no folder to pick.
void showCollectionSavedToast(
  BuildContext context, {
  required bool saved,
  String? thumbnailUrl,
  double bottomMargin = 16,
}) {
  final c = context.studio;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      backgroundColor: c.buttonFill,
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioRadius.button),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      content: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 36,
              height: 36,
              child: (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => _placeholder(c),
                    )
                  : _placeholder(c),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              saved ? 'Added to Collection' : 'Removed from Collection',
              style: StudioType.label13(weight: StudioType.medium, color: c.buttonText),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _placeholder(StudioColors c) => ColoredBox(
      color: c.buttonText.withValues(alpha: 0.15),
      child: Icon(Icons.image_outlined, color: c.buttonText, size: 18),
    );
