import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/models/post_summary.dart';
import 'package:studio3/screens/profile/profile_constants.dart';
import 'package:studio3/screens/profile/widgets/profile_masonry_grid.dart';

/// The profile grid renders both the Pieces/Collect tabs (pieces) and the
/// Scenes tab (posts). These pin three fixes: pieces drawn at the 3:4 they
/// were posted in, price chips replaced by an availability label, and video
/// scenes drawing their poster frame instead of a black rectangle.
void main() {
  PieceSummary piece(
    String id, {
    bool isForSale = false,
    String? status,
    String? listingType,
    int? priceCents,
  }) =>
      PieceSummary(
        id: id,
        title: id,
        mediaUrl: 'https://example.test/$id.jpg',
        isForSale: isForSale,
        status: status,
        listingType: listingType,
        priceCents: priceCents,
      );

  PostSummary post(String id, {String? mediaType, String? thumbnailUrl}) =>
      PostSummary(
        id: id,
        mediaUrl: 'https://example.test/$id.mp4',
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
      );

  /// Mirrors how ProfilePage hosts the grid: a sliver inside the profile's
  /// horizontal padding.
  Future<void> pumpGrid(WidgetTester tester, Widget grid) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kProfileHorizontalPad,
                ),
                sliver: grid,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('pieces', () {
    testWidgets('every piece tile is drawn at 3:4', (tester) async {
      await pumpGrid(
        tester,
        ProfileContentGrid.fromPieces([
          piece('a', isForSale: true, status: 'live'),
          piece('b'),
          piece('c'),
        ]),
      );
      final images = tester.widgetList<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(images, hasLength(3));
      // Pieces are captured at 3:4, so the grid draws them all at 3:4
      // rather than the old rotating masonry ratios.
      for (final image in images) {
        final size = tester.getSize(find.byWidget(image));
        expect(size.height / size.width, closeTo(4 / 3, 0.02));
      }
    });

    testWidgets('a price is never shown on a tile', (tester) async {
      await pumpGrid(
        tester,
        ProfileContentGrid.fromPieces([
          piece('a', isForSale: true, status: 'live', priceCents: 25000),
        ]),
      );
      expect(find.textContaining(r'$'), findsNothing);
      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('a for-sale piece reads Available', (tester) async {
      await pumpGrid(
        tester,
        ProfileContentGrid.fromPieces([
          piece('a', isForSale: true, status: 'live'),
        ]),
      );
      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('a sold piece reads Sold', (tester) async {
      await pumpGrid(
        tester,
        ProfileContentGrid.fromPieces([
          piece('a', isForSale: true, status: 'sold'),
        ]),
      );
      expect(find.text('Sold'), findsOneWidget);
      expect(find.text('Available'), findsNothing);
    });

    testWidgets('a live auction reads Bidding open, not Available', (
      tester,
    ) async {
      await pumpGrid(
        tester,
        ProfileContentGrid.fromPieces([
          piece('a', isForSale: true, status: 'live', listingType: 'auction'),
        ]),
      );
      expect(find.text('Bidding open'), findsOneWidget);
      expect(find.text('Available'), findsNothing);
    });

    testWidgets('a piece that is not for sale carries no label', (
      tester,
    ) async {
      await pumpGrid(tester, ProfileContentGrid.fromPieces([piece('a')]));
      expect(find.text('Available'), findsNothing);
      expect(find.text('Sold'), findsNothing);
    });
  });

  group('scenes', () {
    testWidgets('a video scene draws its poster frame', (tester) async {
      await pumpGrid(
        tester,
        ProfileContentGrid.fromPosts([
          post(
            'v',
            mediaType: 'video',
            thumbnailUrl: 'https://example.test/poster.jpg',
          ),
        ]),
      );
      // Regression: video tiles used to skip the image entirely and render
      // as a plain black rectangle behind the play button.
      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.imageUrl, 'https://example.test/poster.jpg');
    });

    testWidgets('a video scene keeps its play affordance', (tester) async {
      await pumpGrid(
        tester,
        ProfileContentGrid.fromPosts([
          post(
            'v',
            mediaType: 'video',
            thumbnailUrl: 'https://example.test/poster.jpg',
          ),
        ]),
      );
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('an image scene still draws its own media', (tester) async {
      await pumpGrid(
        tester,
        ProfileContentGrid.fromPosts([post('p', mediaType: 'image')]),
      );
      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.imageUrl, 'https://example.test/p.mp4');
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('scenes carry no listing label', (tester) async {
      await pumpGrid(
        tester,
        ProfileContentGrid.fromPosts([post('p', mediaType: 'image')]),
      );
      expect(find.text('Available'), findsNothing);
    });
  });
}
