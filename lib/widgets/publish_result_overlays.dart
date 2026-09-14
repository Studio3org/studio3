import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/post_media_assets.dart';
import '../models/post_image_transform.dart';
import '../theme/home_feed_tokens.dart';
import 'post_crop_preview.dart';
import 'studio_loading.dart';

/// Stacks the publishing spinner, success, or fail screens over [child].
class StudioPublishFlowGate extends StatelessWidget {
  const StudioPublishFlowGate({
    super.key,
    required this.child,
    required this.publishing,
    required this.success,
    required this.failure,
    required this.publishingMessage,
    required this.successTitle,
    required this.onSuccessDismiss,
    required this.onRetry,
    this.imagePath,
    this.transform,
    this.videoThumbnailBytes,
  });

  final Widget child;
  final bool publishing;
  final bool success;
  final bool failure;
  final String publishingMessage;
  final String successTitle;
  final VoidCallback onSuccessDismiss;
  final VoidCallback onRetry;
  final String? imagePath;
  final PostImageTransform? transform;
  final Uint8List? videoThumbnailBytes;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (publishing)
          Positioned.fill(
            child: StudioPublishingOverlay(message: publishingMessage),
          ),
        if (success)
          Positioned.fill(
            child: PublishSuccessOverlay(
              title: successTitle,
              onDismiss: onSuccessDismiss,
              imagePath: imagePath,
              transform: transform,
              videoThumbnailBytes: videoThumbnailBytes,
            ),
          ),
        if (failure)
          Positioned.fill(child: PublishFailOverlay(onRetry: onRetry)),
      ],
    );
  }
}

/// Full-bleed published cover + cream confirmation (Figma 2761:12001).
class PublishSuccessOverlay extends StatelessWidget {
  const PublishSuccessOverlay({
    super.key,
    required this.title,
    required this.onDismiss,
    this.imagePath,
    this.transform,
    this.videoThumbnailBytes,
  });

  final String title;
  final VoidCallback onDismiss;
  final String? imagePath;
  final PostImageTransform? transform;
  final Uint8List? videoThumbnailBytes;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onDismiss();
      },
      child: GestureDetector(
        onTap: onDismiss,
        behavior: HitTestBehavior.opaque,
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
                    16,
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
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.geist(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: HomeFeedTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Visible on your profile now',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.geist(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: HomeFeedTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    final imagePath = this.imagePath;
    final transform = this.transform;
    if (imagePath != null && imagePath.isNotEmpty && transform != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return PostCropPreview(
            imagePath: imagePath,
            transform: transform,
            frameSize: Size(constraints.maxWidth, constraints.maxHeight),
          );
        },
      );
    }
    final bytes = videoThumbnailBytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity);
    }
    return const SizedBox.expand();
  }
}

/// Centered failure state with retry (Figma 2761:12029).
class PublishFailOverlay extends StatelessWidget {
  const PublishFailOverlay({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeFeedTokens.detailBackground,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                PostMediaAssets.publishFailAlert,
                width: 64,
                height: 64,
              ),
              const SizedBox(height: 24),
              Text(
                'Couldn’t publish',
                textAlign: TextAlign.center,
                style: GoogleFonts.geist(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.geist(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: HomeFeedTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 148,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onRetry,
                    borderRadius: BorderRadius.circular(8),
                    child: Ink(
                      height: 40,
                      decoration: BoxDecoration(
                        color: HomeFeedTokens.neutral800,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Try again',
                          style: GoogleFonts.geist(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: HomeFeedTokens.textInverse,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
