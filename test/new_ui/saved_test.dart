import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/screens/saved_page.dart';
import 'package:studio3/services/saved_content_store.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/theme/studio_metrics.dart';
import 'package:studio3/theme/studio_type.dart';
import 'package:studio3/widgets/saved/saved_collection_widgets.dart';
import 'package:studio3/widgets/studio/studio_button.dart';
import 'package:studio3/widgets/studio/studio_chip.dart';
import 'package:studio3/widgets/studio/studio_top_bar.dart';

SavedEntry _entry({
  required String id,
  required String title,
  String? author,
  bool available = false,
  int? priceCents,
  String? status,
  int savedAt = 0,
}) {
  return SavedEntry(
    id: id,
    kind: SavedContentKind.piece,
    savedAt: savedAt,
    preview: FeedPreviewItem(
      id: id,
      imageSeeds: const [],
      title: title,
      medium: 'Oil',
      year: 2024,
      dimensions: '',
      story: '',
      handle: '@amara',
      isAvailable: available,
      aspectRatio: FeedAspectRatio.portrait3x4,
      authorName: author,
      priceCents: priceCents,
      status: status,
    ),
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
    home: home,
  );
}

void main() {
  test('change lines use only facts already on the item', () {
    final listed = _entry(id: '1', title: 'Bodies', available: true, priceCents: 120000);
    expect(savedChangeLine(listed), 'Now listed · \$1200');
    expect(savedIsCollected(listed), isFalse);

    final noPrice = _entry(id: '2', title: 'Bodies', available: true);
    expect(savedChangeLine(noPrice), isNull);

    final collected = _entry(id: '3', title: 'Bodies', status: 'collected', priceCents: 80000);
    expect(savedChangeLine(collected), isNull);
    expect(savedIsCollected(collected), isTrue);

    final quiet = _entry(id: '4', title: 'Bodies');
    expect(savedChangeLine(quiet), isNull);
  });

  testWidgets('folder index is two across, with Available only when something is for sale', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final kept = _entry(id: 'a', title: 'Quiet', savedAt: 1);
    final listed = _entry(
      id: 'b',
      title: 'Bodies in Color',
      author: 'Amara Osei',
      available: true,
      priceCents: 120000,
      savedAt: 2,
    );
    String? opened;
    SavedCollection? held;
    final folder = SavedCollection(id: 'f1', name: 'Living room', createdAt: DateTime.utc(2026));

    await tester.pumpWidget(
      _app(
        home: SavedFolderIndex(
          entries: [kept, listed],
          collections: [folder],
          entriesForCollection: (_) => [listed],
          onOpenAll: () => opened = 'all',
          onOpenAvailable: () => opened = 'available',
          onOpenCollection: (collection) => opened = collection.name,
          onLongPressCollection: (collection) => held = collection,
          onRefresh: () async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Only you can see what you save.'), findsOneWidget);
    expect(find.text('All saved'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('2 pieces'), findsOneWidget);
    expect(find.text('YOUR FOLDERS'), findsOneWidget);
    expect(find.text('Living room'), findsOneWidget);
    expect(find.text('New collection'), findsNothing);

    final title = tester.widget<Text>(find.text('All saved'));
    expect(title.style!.fontSize, 15);
    expect(title.style!.fontWeight, StudioType.medium);
    expect(title.style!.fontFamily, StudioType.geist);
    expect(title.style!.color, StudioColors.light.textPrimary);

    final label = tester.widget<Text>(find.text('YOUR FOLDERS'));
    expect(label.style!.fontFamily, StudioType.geistMono);
    expect(label.style!.fontSize, 11);
    expect(label.style!.letterSpacing, 0.5);
    expect(label.style!.color, StudioColors.light.textTertiary);

    final cover = tester.getSize(find.byType(SavedCoverGrid).first);
    expect(cover.width, closeTo(167, 1));
    expect(cover.height, closeTo(167, 1));
    final clip = tester.widget<ClipRRect>(
      find.descendant(of: find.byType(SavedCoverGrid).first, matching: find.byType(ClipRRect)),
    );
    expect(clip.borderRadius, BorderRadius.circular(StudioRadius.panel));

    await tester.tap(find.text('All saved'));
    await tester.pump();
    expect(opened, 'all');

    await tester.tap(find.text('Available'));
    await tester.pump();
    expect(opened, 'available');

    await tester.longPress(find.text('Living room'));
    await tester.pump();
    expect(held?.id, 'f1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a folder piece is 167 by 223 with a real change line and no bookmark', (tester) async {
    final listed = _entry(
      id: 'b',
      title: 'Bodies in Color',
      author: 'Amara Osei',
      available: true,
      priceCents: 120000,
    );
    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 167,
              child: SavedPieceTile(entry: listed, onTap: () {}, onLongPress: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final ratio = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(ratio.aspectRatio, 167 / 223);
    expect(tester.getSize(find.byType(AspectRatio)).height, closeTo(223, 1));
    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clip.borderRadius, BorderRadius.circular(StudioRadius.card));
    expect(find.byIcon(Icons.bookmark), findsNothing);
    expect(find.byIcon(Icons.bookmark_border), findsNothing);

    final change = tester.widget<Text>(find.text('Now listed · \$1200'));
    expect(change.style!.color, StudioColors.light.positive);
    expect(change.style!.fontSize, 12);
    expect(change.style!.fontWeight, StudioType.medium);
    expect(tester.widget<Text>(find.text('Amara Osei')).style!.color, StudioColors.light.textSecondary);
    expect(tester.widget<Text>(find.text('Bodies in Color')).style!.fontWeight, StudioType.medium);
  });

  testWidgets('Collected uses the status chip and a quiet piece has no change line', (tester) async {
    final collected = _entry(id: 'c', title: 'Sold work', author: 'Ada', status: 'collected');
    await tester.pumpWidget(
      _app(
        reduceMotion: true,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 167,
              child: SavedPieceTile(entry: collected, onTap: () {}, onLongPress: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Collected'), findsOneWidget);
    expect(find.textContaining('Now listed'), findsNothing);
    expect(find.textContaining('Price dropped'), findsNothing);
    expect(find.textContaining('Auction'), findsNothing);
    expect(tester.widget<StudioStatusChip>(find.byType(StudioStatusChip)).status, StudioStatus.collected);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state is a text link back toward the feed', (tester) async {
    var browsed = false;
    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: ListView(children: [SavedEmptyState(onBrowse: () => browsed = true)]),
        ),
      ),
    );
    await tester.pump();

    final heading = tester.widget<Text>(find.text('Nothing saved yet'));
    expect(heading.style!.fontSize, 22);
    expect(heading.style!.fontWeight, StudioType.regular);
    expect(heading.style!.letterSpacing, -0.3);
    expect(find.text('Browse the feed'), findsOneWidget);
    expect(find.byType(StudioButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(tester.getSize(find.byKey(const Key('saved-browse'))).height, greaterThanOrEqualTo(44));

    await tester.tap(find.byKey(const Key('saved-browse')));
    expect(browsed, isTrue);
  });

  testWidgets('the Saved header keeps a 44 new-folder control and no back on the tab', (tester) async {
    var created = false;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: StudioTopBar(
              context: context,
              title: 'Saved',
              automaticallyImplyLeading: false,
              actions: [SavedNewFolderButton(onPressed: () => created = true)],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final title = tester.widget<Text>(find.text('Saved'));
    expect(title.style!.fontSize, 17);
    expect(title.style!.fontWeight, StudioType.medium);
    expect(find.byTooltip('Back'), findsNothing);
    expect(tester.getSize(find.byKey(const Key('saved-new-folder'))).height, greaterThanOrEqualTo(44));
    await tester.tap(find.byKey(const Key('saved-new-folder')));
    expect(created, isTrue);
  });

  testWidgets('guest Saved stays the sign-in placeholder', (tester) async {
    await tester.pumpWidget(_app(home: const SavedPage()));
    await tester.pump();
    expect(find.text('Keep track of the art you love'), findsOneWidget);
    expect(find.text('Nothing saved yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('375 at text scale 1.4 and 440 in dark do not overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final listed = _entry(
      id: 'b',
      title: 'Bodies in Color',
      author: 'Amara Osei',
      available: true,
      priceCents: 120000,
      savedAt: 2,
    );

    await tester.pumpWidget(
      _app(
        textScaler: const TextScaler.linear(1.4),
        home: SavedFolderIndex(
          entries: [listed],
          collections: [
            SavedCollection(id: 'f1', name: 'Living room', createdAt: DateTime.utc(2026)),
          ],
          entriesForCollection: (_) => [listed],
          onOpenAll: () {},
          onOpenAvailable: () {},
          onOpenCollection: (_) {},
          onLongPressCollection: (_) {},
          onRefresh: () async {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(440, 956));
    await tester.pumpWidget(
      _app(
        dark: true,
        home: Scaffold(
          body: SavedPieceTile(entry: listed, onTap: () {}, onLongPress: () {}),
        ),
      ),
    );
    await tester.pump();
    expect(tester.widget<Text>(find.text('Bodies in Color')).style!.color, StudioColors.dark.textPrimary);
    expect(tester.widget<Text>(find.text('Now listed · \$1200')).style!.color, StudioColors.dark.positive);
    expect(tester.takeException(), isNull);
  });
}
