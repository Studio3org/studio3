import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studio3/models/explore_feed_block.dart';
import 'package:studio3/models/nearby_seller.dart';
import 'package:studio3/models/feed_item.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/models/post_summary.dart';
import 'package:studio3/models/series_summary.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_metrics.dart';
import 'package:studio3/widgets/explore/explore_browse.dart';
import 'package:studio3/widgets/explore/explore_sticky_header.dart';
import 'package:studio3/widgets/feed_skeleton.dart';
import 'package:studio3/widgets/studio/studio_avatar.dart';
import 'package:studio3/widgets/studio/studio_chip.dart';

FeedItem _forSale(String id, {int? priceCents, PieceSeriesInfo? series}) {
  return FeedItem.piece(
    PieceSummary(
      id: id,
      title: 'Bodies in Color',
      isForSale: true,
      priceCents: priceCents,
      authorName: 'Amara Osei',
      authorUsername: 'amara',
      series: series,
    ),
  );
}

FeedItem _scene(String id, {String aspect = '16:9'}) {
  return FeedItem.post(
    PostSummary(
      id: id,
      caption: 'In the studio',
      mediaType: 'video',
      mediaAspectRatio: aspect,
      authorName: 'Amara Osei',
      authorUsername: 'amara',
    ),
  );
}

PieceSeriesInfo _series(String id) {
  return PieceSeriesInfo(
    id: id,
    name: 'Paper Planes',
    pieceIds: const ['1', '2', '3', '4', '5'],
    previewPieces: const [
      SeriesPreviewPiece(id: '1', mediaUrl: 'https://example.com/cover.jpg'),
    ],
  );
}

Widget _app({
  required Widget home,
  bool dark = false,
  bool reduceMotion = false,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    key: UniqueKey(),
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(disableAnimations: reduceMotion, textScaler: textScaler),
        child: child!,
      );
    },
    home: Scaffold(body: home),
  );
}

TextSpan? _findSpan(InlineSpan span, String text) {
  if (span is! TextSpan) return null;
  if (span.text == text) return span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    final found = _findSpan(child, text);
    if (found != null) return found;
  }
  return null;
}

void main() {
  test('mediums and search matches come from items already loaded', () {
    final painting = FeedItem.piece(
      const PieceSummary(id: '1', title: 'Bodies in Color', medium: 'Painting', authorName: 'Amara'),
    );
    final photo = FeedItem.piece(
      const PieceSummary(id: '2', title: 'Lens', medium: 'Photography'),
    );
    final again = FeedItem.piece(
      const PieceSummary(id: '3', title: 'Second', medium: 'Painting'),
    );
    expect(exploreMediumNames([painting, photo, again]), ['Painting', 'Photography']);
    expect(filterExploreByMedium([painting, photo], 'Photography').single.title, 'Lens');
    expect(exploreItemMatchesQuery(painting, 'bodies'), isTrue);
    expect(exploreItemMatchesQuery(painting, 'amara'), isTrue);
    expect(exploreItemMatchesQuery(painting, 'opening'), isFalse);

    final seller = NearbySeller.fromJson({
      'username': 'amara',
      'name': 'Amara',
      'distanceKm': 1.2,
      'isFollowing': true,
    });
    expect(seller.isFollowing, isTrue);
  });
  testWidgets('Explore header is 26/500 with a 48 search pill and the existing chips', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var selected = ExploreCategory.all;
    await tester.pumpWidget(
      _app(
        home: ExploreTop(
          searchController: controller,
          onSearchChanged: (_) {},
          selectedCategory: selected,
          onCategorySelected: (category) => selected = category,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('Explore'));
    expect(title.style?.fontSize, 26);
    expect(title.style?.fontWeight, FontWeight.w500);
    expect(title.style?.letterSpacing, -0.5);
    expect(tester.getSize(find.byKey(const Key('explore-search'))).height, 48);
    expect(find.text('Search artists, pieces, events'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Pieces'), findsOneWidget);
    expect(find.text('Scenes'), findsOneWidget);
    expect(find.text('Painting'), findsNothing);
    expect(tester.getSize(find.widgetWithText(StudioChip, 'All')).height, 36);

    await tester.tap(find.text('Pieces'));
    expect(selected, ExploreCategory.pieces);

    var medium = '';
    await tester.pumpWidget(
      _app(
        home: ExploreTop(
          searchController: controller,
          onSearchChanged: (_) {},
          selectedCategory: ExploreCategory.all,
          onCategorySelected: (_) {},
          mediums: const ['Painting', 'Photography'],
          onMediumSelected: (value) => medium = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Painting'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    await tester.tap(find.text('Painting'));
    expect(medium, 'Painting');
  });

  testWidgets('a shelf stays hidden under 6 and Available now is 160 by 3:4', (tester) async {
    await tester.pumpWidget(
      _app(
        home: ExplorePieceShelf(
          items: List.generate(5, (i) => _forSale('p$i')),
          onOpen: (_) {},
        ),
      ),
    );
    expect(find.text('Available now'), findsNothing);

    var sawSeeAll = false;
    await tester.pumpWidget(
      _app(
        home: ExplorePieceShelf(
          items: [
            _forSale('priced', priceCents: 12000),
            ...List.generate(5, (i) => _forSale('p$i')),
          ],
          onOpen: (_) {},
          onSeeAll: () => sawSeeAll = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Available now'), findsOneWidget);
    expect(find.text('\$120'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == explorePieceShelfWidth,
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == explorePieceShelfImageHeight,
      ),
      findsWidgets,
    );
    final name = tester.widget<Text>(find.text('Bodies in Color').first);
    expect(name.style?.fontSize, 14);
    expect(name.style?.fontWeight, FontWeight.w500);
    final seeAll = find.ancestor(
      of: find.text('See all'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox &&
            widget.constraints.minHeight >= StudioSize.tapTarget,
      ),
    );
    expect(tester.getSize(seeAll).height, greaterThanOrEqualTo(44));
    await tester.tap(find.text('See all'));
    expect(sawSeeAll, isTrue);

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect).first);
    expect(
      clip.borderRadius,
      BorderRadius.circular(StudioRadius.card),
    );
  });

  testWidgets('Behind the work is 140 by 249 and the grid snaps scene aspect', (tester) async {
    await tester.pumpWidget(
      _app(
        home: ListView(
          children: [
            ExploreSceneShelf(
              items: List.generate(6, (i) => _scene('s$i')),
              onOpen: (_) {},
            ),
            ExploreBrowseGrid(
              items: [
                _forSale('piece'),
                _scene('wide'),
                _scene('square', aspect: '1:1'),
              ],
              onOpen: (_) {},
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Behind the work'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.width == exploreSceneShelfWidth &&
            widget.height == exploreSceneShelfHeight,
      ),
      findsWidgets,
    );
    expect(find.bySemanticsLabel('Video'), findsWidgets);

    final aspects = tester
        .widgetList<AspectRatio>(find.byType(AspectRatio))
        .map((widget) => widget.aspectRatio)
        .toList();
    expect(aspects, contains(3 / 4));
    expect(aspects, contains(173 / 130));
    expect(aspects, contains(1));
    expect(tester.getSize(find.byKey(const Key('explore-gutter'))).width, 12);
  });

  testWidgets('New series renders only from series already on the items', (tester) async {
    final one = exploreSeriesEntries([_forSale('only', series: _series('series-1'))]);
    expect(one, hasLength(1));
    expect(one.single.pieceCount, 5);

    await tester.pumpWidget(
      _app(
        home: ExploreSeriesShelf(entries: one, onOpen: (_) {}),
      ),
    );
    expect(find.text('New series'), findsNothing);

    final six = List.generate(
      6,
      (i) => ExploreSeriesEntry(
        id: 's$i',
        name: 'Paper Planes',
        pieceCount: 5,
        coverUrl: null,
        authorName: 'Amara Osei',
        authorUsername: 'amara',
      ),
    );
    await tester.pumpWidget(
      _app(home: ExploreSeriesShelf(entries: six, onOpen: (_) {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('New series'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == exploreSeriesShelfWidth,
      ),
      findsWidgets,
    );
    final count = tester
        .widgetList<RichText>(
          find.byWidgetPredicate(
            (widget) => widget is RichText && widget.text.toPlainText().contains('5 pieces'),
          ),
        )
        .first;
    final pieces = _findSpan(count.text, '5 pieces')!;
    expect(pieces.style?.fontFamily, 'GeistMono');
    expect(pieces.style?.fontSize, 12);
  });

  testWidgets('an artist tile is 96 wide with a 76 avatar and no Follow button', (tester) async {
    await tester.pumpWidget(
      _app(
        home: const ExploreArtistTile(name: 'Amara Osei', subtitle: '1.2 km away'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(ExploreArtistTile)).width, exploreArtistTileWidth);
    expect(tester.widget<StudioAvatar>(find.byType(StudioAvatar)).size, exploreArtistAvatar);
    final name = tester.widget<Text>(find.text('Amara Osei'));
    expect(name.style?.fontSize, 13);
    expect(name.style?.fontWeight, FontWeight.w500);
    expect(find.text('Follow'), findsNothing);
    expect(find.text('1.2 km away'), findsOneWidget);

    var followed = false;
    await tester.pumpWidget(
      _app(
        home: ExploreArtistTile(
          name: 'Amara Osei',
          followLabel: 'Follow',
          onFollow: () => followed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.widgetWithText(Container, 'Follow')).height,
      StudioSize.buttonSmall,
    );
    await tester.tap(find.text('Follow'));
    expect(followed, isTrue);
  });

  testWidgets('375 at text scale 1.4 and 440 in dark do not overflow', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    Future<void> pump({
      required Size size,
      required bool dark,
      required bool reduceMotion,
    }) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _app(
          dark: dark,
          reduceMotion: reduceMotion,
          textScaler: dark ? TextScaler.noScaling : const TextScaler.linear(1.4),
          home: ListView(
            children: [
              ExploreTop(
                searchController: controller,
                onSearchChanged: (_) {},
                selectedCategory: ExploreCategory.all,
                onCategorySelected: (_) {},
              ),
              ExplorePieceShelf(
                items: List.generate(6, (i) => _forSale('p$i', priceCents: 5000)),
                onOpen: (_) {},
              ),
              ExploreBrowseGrid(
                items: [_forSale('grid'), _scene('scene')],
                onOpen: (_) {},
              ),
              const ExploreFeedSkeleton(),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await pump(size: const Size(375, 667), dark: false, reduceMotion: true);
    expect(tester.takeException(), isNull);
    expect(find.byType(Shimmer), findsNothing);
    expect(
      tester.widget<AspectRatio>(find.byType(AspectRatio).first).aspectRatio,
      3 / 4,
    );

    await pump(size: const Size(440, 956), dark: true, reduceMotion: true);
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Text>(find.text('Bodies in Color').first).style?.color,
      const Color(0xFFFAFAF8),
    );

    await tester.binding.setSurfaceSize(null);
  });
}
