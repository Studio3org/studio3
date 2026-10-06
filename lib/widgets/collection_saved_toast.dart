import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/home_feed_tokens.dart';

/// Instagram-style bottom toast shown after saving/unsaving a piece or scene
/// to the collection, with the item's thumbnail alongside the message.
void showCollectionSavedToast(
  BuildContext context, {
  required bool saved,
  String? thumbnailUrl,
  double bottomMargin = 16,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      backgroundColor: HomeFeedTokens.textPrimary,
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
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
                      errorWidget: (context, url, error) =>
                          _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              saved ? 'Added to Collection' : 'Removed from Collection',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: HomeFeedTokens.textInverse,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _placeholder() => ColoredBox(
      color: HomeFeedTokens.textInverse.withValues(alpha: 0.15),
      child: const Icon(
        Icons.image_outlined,
        color: HomeFeedTokens.textInverse,
        size: 18,
      ),
    );
