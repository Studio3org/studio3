import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studio3/models/feed_item.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/models/series_summary.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/theme/studio_metrics.dart';
import 'package:studio3/theme/studio_type.dart';
import 'package:studio3/widgets/feed_skeleton.dart';
import 'package:studio3/widgets/home_feed/home_feed_widgets.dart';
import 'package:studio3/widgets/studio/studio.dart';

PieceSummary _piece({
  String title = 'Bodies in Color',
  bool forSale = true,
  String? listingState = 'available',
  List<String> images = const [],
  PieceSeriesInfo? series,
}) {
  return PieceSummary(
    id: 'piece-1',
    title: title,
    mediaUrl: images.isEmpty ? null : images.first,
    isForSale: forSale,
    listingState: listingState,
    imageUrls: images,
    authorName: 'Amara Osei',
    authorUsername: 'amara',
    series: series,
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

void main() {
  test('a gallery on the payload is the swipe list; a cover alone is one photo', () {
    final gallery = PieceSummary.fromJson({
      'id': '1',
      'title': 'Bodies in Color',
      'mediaUrl': 'https://example.com/cover.jpg',
      'listingState': 'available',
      'images': [
        {'mediaUrl': 'https://example.com/a.jpg'},
        {'mediaUrl': 'https://example.com/b.jpg'},
      ],
    });
    expect(gallery.imageUrls, ['https://example.com/a.jpg', 'https://example.com/b.jpg']);
    expect(FeedItem.piece(gallery).imageUrls, hasLength(2));

    final cover = PieceSummary.fromJson({
      'id': '2',
      'title': 'Companion Bloom',
      'mediaUrl': 'https://example.com/cover.jpg',
      'images': [],
    });
    expect(cover.imageUrls, ['https://example.com/cover.jpg']);
  });

  testWidgets('top bar is All, the wordmark, Saved and inbox', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    FeedAvailabilityFilter? picked;
    await tester.pumpWidget(
      _app(
        home: FeedHomeHeader(
          filter: FeedAvailabilityFilter.all,
          hasAvailableItems: true,
          onFilterChanged: (filter) => picked = filter,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('All'), findsOneWidget);
    expect(tester.widget<Text>(find.text('All')).style!.fontSize, 17);
    expect(tester.widget<Text>(find.text('All')).style!.fontWeight, FontWeight.w500);
    expect(find.byType(StudioLogo), findsOneWidget);
    expect(find.bySemanticsLabel('Post'), findsNothing);
    expect(tester.getSize(find.bySemanticsLabel('Saved')), const Size(44, 44));
    expect(tester.getSize(find.bySemanticsLabel('Inbox')), const Size(44, 44));

    await tester.tap(find.bySemanticsLabel('Filter feed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Available'), findsOneWidget);
    await tester.tap(find.text('Available'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(picked, FeedAvailabilityFilter.available);
  });

  testWidgets('unread inbox is a dot with no count', (tester) async {
    await tester.pumpWidget(_app(home: const Center(child: FeedUnreadDot())));
    expect(tester.getSize(find.byType(FeedUnreadDot)), const Size(12, 12));
    expect(find.descendant(of: find.byType(FeedUnreadDot), matching: find.byType(Text)), findsNothing);
  });

  testWidgets('piece is full width 3:4 with the artist row and an Available chip', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var opened = 0;
    await tester.pumpWidget(
      _app(
        home: FeedPieceCard(
          item: FeedItem.piece(_piece()),
          onTap: () => opened++,
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(image.aspectRatio, 3 / 4);
    expect(tester.getSize(find.byType(AspectRatio)).width, 390);
    expect(find.byType(ClipRRect), findsNothing);
    expect(find.byType(PageView), findsNothing);

    final name = tester.widget<Text>(find.text('Amara Osei'));
    expect(name.style!.fontSize, 14);
    expect(name.style!.fontWeight, FontWeight.w500);
    final title = tester.widget<Text>(find.text('Bodies in Color'));
    expect(title.style!.fontSize, 13);
    expect(find.text('Available'), findsOneWidget);
    expect(tester.getSize(find.byType(StudioAvatar)), const Size(32, 32));

    await tester.tap(find.text('Bodies in Color'));
    expect(opened, 1);
  });

  testWidgets('two photos show dots and a swipe moves to the next', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        home: FeedPieceCard(
          item: FeedItem.piece(
            _piece(images: const ['https://example.com/a.jpg', 'https://example.com/b.jpg']),
          ),
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Photo 1 of 2'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    final dots = tester.widgetList<Container>(find.byType(Container)).where((box) {
      final size = box.constraints;
      return size?.maxWidth == 6 && size?.maxHeight == 6;
    });
    expect(dots.length, 2);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.bySemanticsLabel('Photo 2 of 2'), findsOneWidget);
  });

  testWidgets('series row uses the 80 percent card and does not invent an event', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        home: SingleChildScrollView(
          child: FeedSeriesRow(
            artistName: 'Amara Osei',
            artistUsername: 'amara',
            series: PieceSeriesInfo(
              id: 'series-1',
              name: 'Paper Planes',
              pieceIds: const ['a', 'b', 'c', 'd', 'e'],
              previewPieces: const [
                SeriesPreviewPiece(id: 'a', title: 'Paper Planes I'),
                SeriesPreviewPiece(id: 'b', title: 'Paper Planes II'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Paper Planes'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-800, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('See all 5 pieces'), findsOneWidget);
    expect(find.text('Open the series'), findsOneWidget);
    expect(find.textContaining('EVENT'), findsNothing);

    final cardWidth = (390 - 32) * 0.8;
    final clips = tester.widgetList<ClipRRect>(find.byType(ClipRRect));
    expect(clips.first.borderRadius, BorderRadius.circular(StudioRadius.button));
    final sized = tester.widgetList<SizedBox>(find.byType(SizedBox)).where((box) => box.width == cardWidth);
    expect(sized, isNotEmpty);
    expect(tester.getSize(find.widgetWithText(TextButton, 'See all')).height, greaterThanOrEqualTo(44));
  });

  testWidgets('both themes, small and large phones, and a still skeleton', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final card = FeedPieceCard(item: FeedItem.piece(_piece(title: 'A long title that should wrap')), onTap: () {});

    await tester.pumpWidget(
      _app(
        textScaler: const TextScaler.linear(1.4),
        home: ListView(
          children: [
            FeedHomeHeader(filter: FeedAvailabilityFilter.all, onFilterChanged: (_) {}),
            card,
          ],
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(440, 956));
    await tester.pumpWidget(
      _app(
        dark: true,
        home: FeedPieceCard(item: FeedItem.piece(_piece()), onTap: () {}),
      ),
    );
    await tester.pump();
    expect(tester.widget<Text>(find.text('Amara Osei')).style!.color, StudioColors.dark.textPrimary);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_app(reduceMotion: true, home: const FeedListSkeleton(itemCount: 2)));
    await tester.pump();
    expect(find.byType(Shimmer), findsNothing);
    expect(tester.widget<AspectRatio>(find.byType(AspectRatio).first).aspectRatio, 3 / 4);
  });
}
