import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/post_media_assets.dart';
import '../../models/post_image_transform.dart';
import '../../theme/home_feed_tokens.dart';
import '../post_crop_preview.dart';
import '../share/share_sheet.dart';
import 'event_ticket_edit_page.dart' show ticketAccent;

/// Full-bleed cover + confirmation after publishing an event.
class EventPublishSuccessOverlay extends StatelessWidget {
  const EventPublishSuccessOverlay({
    super.key,
    required this.title,
    required this.onViewEvent,
    required this.shareText,
    this.imagePath,
    this.transform,
    this.kicker,
    this.scheduleLine,
    this.coverUploadFailed = false,
  });

  final String title;
  final String shareText;
  final VoidCallback onViewEvent;
  final String? imagePath;
  final PostImageTransform? transform;
  final String? kicker;
  final String? scheduleLine;
  /// The event published, but its cover photo upload didn't make it —
  /// flagged here rather than left for the host to discover as an
  /// unexplained blank banner on their own listing.
  final bool coverUploadFailed;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onViewEvent();
      },
      child: Material(
        color: HomeFeedTokens.detailBackground,
        child: Column(
          children: [
            Expanded(child: _hero()),
            ColoredBox(
              color: HomeFeedTokens.background,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  24,
                  16,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      PostMediaAssets.publishSuccessCheck,
                      width: 64,
                      height: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your event is live',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.geist(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: HomeFeedTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Visible on your Discover now',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.geist(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: HomeFeedTokens.textSecondary,
                      ),
                    ),
                    if (coverUploadFailed) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Your cover photo didn't upload — add one from "
                        'event settings.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.geist(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: ticketAccent,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: FilledButton(
                              onPressed: () => ShareSheet.show(
                                context,
                                shareText: shareText,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: HomeFeedTokens.neutral800,
                                foregroundColor: HomeFeedTokens.textInverse,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Share',
                                style: GoogleFonts.geist(
                                  fontSize: 16,
                                  color: HomeFeedTokens.textInverse,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: OutlinedButton(
                              onPressed: onViewEvent,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: HomeFeedTokens.textPrimary,
                                side: const BorderSide(
                                  color: HomeFeedTokens.textPrimary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'View Event',
                                style: GoogleFonts.geist(
                                  fontSize: 16,
                                  color: HomeFeedTokens.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    final imagePath = this.imagePath;
    final transform = this.transform;
    Widget image = const SizedBox.expand();
    if (imagePath != null && imagePath.isNotEmpty && transform != null) {
      image = LayoutBuilder(
        builder: (context, constraints) {
          return PostCropPreview(
            imagePath: imagePath,
            transform: transform,
            frameSize: Size(constraints.maxWidth, constraints.maxHeight),
          );
        },
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x00000000),
                Color(0x99000000),
              ],
              stops: [0.45, 1],
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kicker != null && kicker!.isNotEmpty)
                Text(
                  kicker!.toUpperCase(),
                  style: GoogleFonts.geist(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                    color: HomeFeedTokens.textInverse,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.geist(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: HomeFeedTokens.textInverse,
                  height: 1.2,
                ),
              ),
              if (scheduleLine != null && scheduleLine!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  scheduleLine!,
                  style: GoogleFonts.geist(
                    fontSize: 13,
                    color: HomeFeedTokens.textInverse,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
