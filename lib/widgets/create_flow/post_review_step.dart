import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../studio/studio_button.dart';
import 'post_flow_widgets.dart';

/// "Look it over" (`PostReview`, `PostNFSReview`): step 3 of 3 of posting a piece.
///
/// The piece card, the heading, an Availability card (Selling, and for a sale the price and
/// what the artist receives) and a Details card, each with Edit back to its step; Publish.
class PostReviewStep extends StatelessWidget {
  const PostReviewStep({
    super.key,
    required this.cover,
    required this.title,
    required this.photoCount,
    required this.forSale,
    required this.availabilityRows,
    required this.detailRows,
    required this.onBack,
    required this.onEditPhotos,
    required this.onEditAvailability,
    required this.onEditDetails,
    required this.onPublish,
    this.publishing = false,
  });

  final Widget cover;
  final String title;
  final int photoCount;
  final bool forSale;
  final List<PostReviewRow> availabilityRows;
  final List<PostReviewRow> detailRows;
  final VoidCallback onBack;
  final VoidCallback onEditPhotos;
  final VoidCallback onEditAvailability;
  final VoidCallback onEditDetails;
  final VoidCallback onPublish;
  final bool publishing;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PostStepHeader(onBack: onBack, current: 3),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PostPieceCard(
                      cover: cover,
                      title: title,
                      photoCount: photoCount,
                      onEdit: onEditPhotos,
                    ),
                    const SizedBox(height: 20),
                    PostHeading(
                      title: 'Look it over',
                      // No auctions in the app, so the board's "except a running auction"
                      // is left off.
                      subtitle: forSale
                          ? "You can edit anything after it's live."
                          : 'You can list it for sale anytime from the piece page.',
                    ),
                    const SizedBox(height: 20),
                    PostReviewCard(
                      title: 'Availability',
                      onEdit: onEditAvailability,
                      rows: availabilityRows,
                    ),
                    const SizedBox(height: 20),
                    PostReviewCard(title: 'Details', onEdit: onEditDetails, rows: detailRows),
                  ],
                ),
              ),
            ),
            PostBottomAction(
              button: StudioButton(
                label: 'Publish',
                height: 54,
                loading: publishing,
                onPressed: publishing ? null : onPublish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
