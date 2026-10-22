import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/screens/available_piece_detail_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/theme/studio_type.dart';
import 'package:studio3/widgets/piece_detail/available_collect_bar.dart';
import 'package:studio3/widgets/piece_detail/collect_artist_row.dart';
import 'package:studio3/widgets/piece_detail/piece_series_row.dart';
import 'package:studio3/widgets/studio/studio_avatar.dart';
import 'package:studio3/widgets/studio/studio_button.dart';
import 'package:studio3/widgets/studio/studio_chip.dart';
import 'package:studio3/widgets/studio/studio_icon.dart';
import 'package:studio3/widgets/studio/studio_on_image.dart';

/// `BuyPiece` / `BuyPieceFull` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 7).
FeedPreviewItem _piece({
  String? status,
  int? priceCents = 350000,
  List<String> materials = const ['Oil paint', 'Linen canvas'],
  String? location = 'Dallas, TX',
  String seriesName = 'Bodies in Color',
}) {
  return FeedPreviewItem(
    id: 'p1',
    imageSeeds: const [1],
    title: 'Bodies in Color',
    medium: 'Oil',
    year: 2025,
    dimensions: '24 × 36 in',
    story: 'Started this one trying to paint skin as light rather than surface.',
    handle: '@amarasart',
    isAvailable: true,
    aspectRatio: FeedAspectRatio.portrait3x4,
    authorName: 'Amara Osei',
    priceCents: priceCents,
    status: status,
    materials: materials,
    location: location,
    framingNote: 'Unframed',
    handlingNotes: 'Fragile, ships in a custom crate',
    styleTags: const ['Figurative', 'Portrait'],
    seriesName: seriesName,
    seriesThumbs: const [1, 2, 3],
    seriesPieceCount: 6,
  );
}

Widget _app(Widget home, {bool dark = false}) {
  return MaterialApp(
    key: UniqueKey(),
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: home,
  );
}

Future<void> _pumpPage(WidgetTester tester, FeedPreviewItem item, {bool dark = false}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(AvailablePieceDetailPage(item: item), dark: dark));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() => dotenv.loadFromString(envString: '', isOptional: true));

  testWidgets('top: white back / save / share / more over the image, no circles', (tester) async {
    await _pumpPage(tester, _piece());
    final icons = tester.widgetList<StudioTopIcon>(find.byType(StudioTopIcon)).toList();
    expect(icons.map((i) => i.semanticLabel), ['Back', 'Save', 'Share', 'More']);
    for (final icon in icons) {
      expect(icon.size, 20);
      expect(tester.getSize(find.byWidget(icon)).width, 44);
    }
    // Image is full width at 3:4 (`HandoffSizes`: 390 × 520).
    final hero = find.byType(AspectRatio).first;
    expect(tester.getSize(hero), const Size(390, 520));
  });

  testWidgets('artist row: 36 avatar, name 14/500, handle 12, small Follow', (tester) async {
    await _pumpPage(tester, _piece());
    final row = find.byType(CollectArtistRow);
    expect(tester.getSize(find.descendant(of: row, matching: find.byType(StudioAvatar))).width, 36);
    final name = tester.widget<Text>(find.descendant(of: row, matching: find.text('Amara Osei')));
    expect(name.style!.fontSize, 14);
    expect(name.style!.fontWeight, StudioType.medium);
    final follow = find.descendant(of: row, matching: find.byType(StudioButton));
    expect(tester.widget<StudioButton>(follow).variant, StudioButtonVariant.small);
    expect(tester.getSize(follow).height, 34);
  });

  testWidgets('body: title block, description, Made with, Details, series card', (tester) async {
    await _pumpPage(tester, _piece());
    final title = tester.widget<Text>(find.text('Bodies in Color').first);
    expect(title.style!.fontSize, 26);
    expect(title.style!.fontWeight, StudioType.medium);
    expect(title.style!.letterSpacing, -0.5);
    final meta = tester.widget<Text>(find.text('Oil · Figurative · Portrait'));
    expect(meta.style!.fontSize, 14);
    final facts = tester.widget<Text>(find.text('24 × 36 in · 2025'));
    expect(facts.style!.fontFamily, StudioType.geistMono);
    expect(facts.style!.fontSize, 13);
    final story = tester.widget<Text>(find.textContaining('Started this one'));
    expect(story.style!.fontSize, 16);
    expect(story.style!.height, 1.55);

    expect(find.text('Made with'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Oil paint')).style!.fontSize, 15);
    // Names only: no brand column, no MATERIALS / TOOLS labels, no "View Materials".
    expect(find.text('MATERIALS'), findsNothing);
    expect(find.textContaining('View Materials'), findsNothing);

    expect(find.text('Details'), findsOneWidget);
    for (final (label, value) in [
      ('Framing', 'Unframed'),
      ('Handling', 'Fragile, ships in a custom crate'),
      ('Ships from', 'Dallas, TX'),
    ]) {
      expect(find.text(label), findsOneWidget);
      expect(find.text(value), findsOneWidget);
    }

    final card = find.byType(PieceSeriesRow);
    expect(find.descendant(of: card, matching: find.text('Part of a series')), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('6 pieces', findRichText: true)),
      findsOneWidget,
    );
    expect(find.descendant(of: card, matching: find.byType(StudioIcon)), findsNothing);
  });

  testWidgets('sections without data stay off', (tester) async {
    await _pumpPage(tester, _piece(materials: const [], location: null, seriesName: ''));
    expect(find.text('Made with'), findsNothing);
    expect(find.text('Ships from'), findsNothing);
    expect(find.byType(PieceSeriesRow), findsNothing);
    expect(find.text('Part of a series'), findsNothing);
    expect(find.text('The story behind this piece'), findsNothing);
  });

  testWidgets('bar: Price in Geist 17 and Collect 52, no message button, no border', (
    tester,
  ) async {
    await _pumpPage(tester, _piece());
    final bar = find.byType(AvailableCollectBar);
    expect(find.descendant(of: bar, matching: find.text('Price')), findsOneWidget);
    final price = tester.widget<Text>(find.descendant(of: bar, matching: find.text(r'$3,500')));
    expect(price.style!.fontSize, 17);
    expect(price.style!.fontFamily, StudioType.geist);
    expect(find.descendant(of: bar, matching: find.text('Ships in')), findsNothing);
    final collect = find.descendant(of: bar, matching: find.byType(StudioButton));
    expect(tester.getSize(collect).height, 52);
    expect(tester.widget<StudioButton>(collect).fontSize, 16);
    expect(find.bySemanticsLabel('Message'), findsNothing);
  });

  testWidgets('sold: the Collected chip replaces Collect, never "Sold"', (tester) async {
    await _pumpPage(tester, _piece(status: 'sold'));
    expect(find.byType(StudioStatusChip), findsOneWidget);
    expect(find.text('Collected'), findsOneWidget);
    expect(find.text('Sold'), findsNothing);
    expect(find.text('Collect'), findsNothing);
  });

  testWidgets('reserved keeps a disabled button with its word', (tester) async {
    await _pumpPage(tester, _piece(status: 'reserved'));
    final button = tester.widget<StudioButton>(
      find.descendant(of: find.byType(AvailableCollectBar), matching: find.byType(StudioButton)),
    );
    expect(button.label, 'Reserved');
    expect(button.onPressed, isNull);
  });

  testWidgets('like and comment stay, in Ink with board-style icons', (tester) async {
    await _pumpPage(tester, _piece());
    expect(find.text('Like'), findsOneWidget);
    expect(find.text('Comment'), findsOneWidget);
    final like = tester.widget<StudioIcon>(
      find.byWidgetPredicate((w) => w is StudioIcon && w.asset == StudioIcons.like),
    );
    expect(like.color, StudioColors.light.textPrimary);
    // Save lives in the top icons only.
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('dark theme and a 375 wide phone render without overflow', (tester) async {
    await _pumpPage(tester, _piece(), dark: true);
    expect(tester.takeException(), isNull);
    final title = tester.widget<Text>(find.text('Bodies in Color').first);
    expect(title.style!.color, StudioColors.dark.textPrimary);

    tester.view.physicalSize = const Size(375, 2400);
    await tester.pumpWidget(_app(AvailablePieceDetailPage(item: _piece())));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
