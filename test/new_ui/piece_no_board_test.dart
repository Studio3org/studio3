import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/screens/image_preview_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/piece_detail/piece_comment_sheet.dart';
import 'package:studio3/widgets/piece_detail/piece_share_sheet.dart';
import 'package:studio3/widgets/studio/studio_action_row.dart';
import 'package:studio3/widgets/studio/studio_icon.dart';
import 'package:studio3/widgets/studio/studio_on_image.dart';
import 'package:studio3/widgets/studio/studio_sheet.dart';

/// Phase 7 "No board": share sheet, comment sheet, image preview
/// (docs/new-ui/NEW_UI_EXECUTION_PLAN.md).
const _item = FeedPreviewItem(
  id: 'p1',
  imageSeeds: [1],
  title: 'Bodies in Color',
  medium: 'Oil',
  year: 2025,
  dimensions: '',
  story: '',
  handle: '@amarasart',
  isAvailable: true,
  aspectRatio: FeedAspectRatio.portrait3x4,
  authorName: 'Amara Osei',
);

Widget _app(Widget Function(BuildContext) onOpen, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(onPressed: () => onOpen(context), child: const Text('open')),
    ),
  ),
);

void main() {
  setUpAll(() => dotenv.loadFromString(envString: '', isOptional: true));

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    final theme = dark ? 'dark' : 'light';

    testWidgets('share sheet: board sheet, Ink action rows, no brand colors ($theme)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app((context) {
          PieceShareSheet.show(context, _item);
          return const SizedBox();
        }, dark: dark),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(StudioSheetGrabber), findsOneWidget);
      expect(tester.widget<Text>(find.text('Share')).style!.fontSize, 22);
      final rows = tester.widgetList<StudioActionRow>(find.byType(StudioActionRow)).toList();
      expect(rows.map((r) => r.title), ['WhatsApp', 'Messages', 'More', 'Copy link']);
      for (final icon in tester.widgetList<StudioIcon>(
        find.descendant(of: find.byType(StudioActionRow), matching: find.byType(StudioIcon)),
      )) {
        expect(icon.color, c.textPrimary);
      }
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('comment sheet: grabber, title, composer with send off until text ($theme)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app((context) {
          PieceCommentSheet.show(context, contentId: 'p1', isScene: false);
          return const SizedBox();
        }, dark: dark),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(StudioSheetGrabber), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      // Guests see the login hint; the send button stays in its off color.
      expect(find.text('Log in to comment'), findsOneWidget);
      final send = tester.widget<Container>(
        find
            .ancestor(
              of: find.byWidgetPredicate((w) => w is StudioIcon && w.asset == StudioIcons.send),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((send.decoration! as BoxDecoration).color, c.line);
      expect(find.byType(Icon), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('image preview: Ink, white close with no circle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const ImagePreviewPage(imageUrls: ['https://example.com/a.jpg']),
      ),
    );
    await tester.pump();
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, StudioColors.ink);
    final close = tester.widget<StudioTopIcon>(find.byType(StudioTopIcon));
    expect(close.semanticLabel, 'Close');
    expect(find.byType(IconButton), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
