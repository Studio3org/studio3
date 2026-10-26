import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/screens/piece_detail_page.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/theme/studio_type.dart';
import 'package:studio3/widgets/piece_detail/available_collect_bar.dart';
import 'package:studio3/widgets/piece_detail/collect_artist_row.dart';
import 'package:studio3/widgets/piece_detail/piece_artist_row.dart';
import 'package:studio3/widgets/piece_detail/piece_page_sections.dart';
import 'package:studio3/widgets/studio/studio_chip.dart';
import 'package:studio3/widgets/studio/studio_on_image.dart';

import 'golden_harness.dart';

/// `PieceNotForSale` and the top of `ListOwnerPiece` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md,
/// Phase 7).
FeedPreviewItem _piece({String medium = 'Oil', String? status}) {
  return FeedPreviewItem(
    id: 'p1',
    imageSeeds: const [1],
    title: 'Bodies in Color',
    medium: medium,
    year: 2025,
    dimensions: '24 × 36 in',
    story: 'Started this one trying to paint skin as light rather than surface.',
    handle: '@amarasart',
    isAvailable: false,
    aspectRatio: FeedAspectRatio.portrait3x4,
    authorName: 'Amara Osei',
    status: status,
    materials: const ['Oil paint', 'Linen canvas'],
    location: 'Dallas, TX',
    framingNote: 'Unframed',
    styleTags: const ['Figurative'],
    seriesName: 'Bodies in Color',
    seriesThumbs: const [1, 2],
    seriesPieceCount: 6,
  );
}

Future<void> _pump(WidgetTester tester, FeedPreviewItem item, {bool dark = false}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: PieceDetailPage(item: item),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    // Real glyph widths, so the save line fits on one line beside the pill as on the board.
    await loadStudioFonts();
  });
  tearDown(() => AuthSession.instance.user = null);

  testWidgets('visitor: no bar; Not for sale as plain text and the save line under the facts', (
    tester,
  ) async {
    await _pump(tester, _piece());
    expect(find.byType(AvailableCollectBar), findsNothing);
    expect(find.text('Collect'), findsNothing);

    // Plain 13/500 Ink, never a chip (`PieceNotForSale`, `HandoffRules`).
    expect(find.byType(StudioStatusChip), findsNothing);
    final label = tester.widget<Text>(find.text('Not for sale'));
    expect(label.style!.fontFamily, isNot(StudioType.geistMono));
    expect((label.style!.fontSize, label.style!.fontWeight), (13, StudioType.medium));
    expect(label.style!.color, StudioColors.light.textPrimary);
    final line = tester.widget<Text>(find.text("Save it to hear if it's ever listed."));
    expect(line.style!.fontSize, 13);
    expect(line.style!.color, StudioColors.light.textSecondary);
    // The line sits under the Mono facts, 8 + 6 below them.
    final facts = tester.getRect(find.text('24 × 36 in · 2025'));
    expect(tester.getRect(find.text('Not for sale')).top - facts.bottom, closeTo(14, 1));
    // 10 between the label and the line.
    expect(
      tester.getTopLeft(find.text("Save it to hear if it's ever listed.")).dx -
          tester.getTopRight(find.text('Not for sale')).dx,
      10,
    );

    final icons = tester.widgetList<StudioTopIcon>(find.byType(StudioTopIcon));
    expect(icons.map((i) => i.semanticLabel), ['Back', 'Save', 'Share', 'More']);
    expect(find.byType(CollectArtistRow), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets('same body as the fixed-price page', (tester) async {
    await _pump(tester, _piece());
    expect(find.byType(PieceTitleBlock), findsOneWidget);
    expect(find.byType(PieceDescription), findsOneWidget);
    expect(find.text('Made with'), findsOneWidget);
    expect(find.textContaining('View Materials'), findsNothing);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Ships from'), findsOneWidget);
    expect(find.text('Part of a series'), findsOneWidget);
    expect(find.text('Like'), findsOneWidget);
    expect(find.text('Save'), findsNothing); // only in the top icons
  });

  testWidgets('owner: no Save at the top, "Your piece" instead of Follow, pill alone', (
    tester,
  ) async {
    AuthSession.instance.user = const AuthUser(
      username: 'amarasart',
      name: 'Amara Osei',
      email: 'amara@example.com',
    );
    await _pump(tester, _piece());
    final icons = tester.widgetList<StudioTopIcon>(find.byType(StudioTopIcon));
    expect(icons.map((i) => i.semanticLabel), ['Back', 'Share', 'Edit piece']);
    expect(find.text('Your piece'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
    expect(find.text('Not for sale'), findsOneWidget);
    expect(find.text("Save it to hear if it's ever listed."), findsNothing);
  });

  testWidgets('a sold piece shows Collected, not Not for sale', (tester) async {
    await _pump(tester, _piece(status: 'sold'));
    final chip = tester.widget<StudioStatusChip>(find.byType(StudioStatusChip));
    expect(chip.status, StudioStatus.collected);
    expect(find.text('Not for sale'), findsNothing);
  });

  testWidgets('Scenes keep this page as it was', (tester) async {
    await _pump(tester, _piece(medium: 'Scene'));
    expect(find.byType(PieceTopIcons), findsNothing);
    expect(find.byType(PieceArtistRow), findsOneWidget);
    expect(find.byType(StudioStatusChip), findsNothing);
    expect(find.textContaining('View Materials'), findsOneWidget);
  });

  testWidgets('dark theme and 375 wide render without overflow', (tester) async {
    await _pump(tester, _piece(), dark: true);
    expect(tester.takeException(), isNull);
    final title = tester.widget<Text>(find.text('Bodies in Color').first);
    expect(title.style!.color, StudioColors.dark.textPrimary);
    tester.view.physicalSize = const Size(375, 2400);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
