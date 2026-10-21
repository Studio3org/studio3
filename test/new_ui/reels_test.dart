import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/feed_item.dart';
import 'package:studio3/models/post_summary.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/reels/reel_overlay.dart';
import 'package:studio3/widgets/reels/scene_video_comment_sheet.dart';
import 'package:studio3/widgets/studio/studio_icon.dart';

FeedItem _reel() {
  return FeedItem.post(
    const PostSummary(
      id: 'scene-1',
      caption: 'In the studio',
      mediaType: 'video',
      authorName: 'Amara Osei',
      authorUsername: 'amara',
    ),
  );
}

Widget _app({
  required Widget home,
  bool dark = false,
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
        data: mq.copyWith(textScaler: textScaler),
        child: child!,
      );
    },
    home: Scaffold(body: home),
  );
}

void main() {
  testWidgets('the reel rail keeps its actions and uses the board icons we have', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        home: SizedBox(
          height: 700,
          child: ReelOverlay(
            item: _reel(),
            muted: false,
            onToggleMute: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final name = tester.widget<Text>(find.text('Amara Osei'));
    expect(name.style?.fontSize, 14);
    expect(name.style?.fontWeight, FontWeight.w500);
    expect(name.style?.fontFamily, 'Geist');
    expect(name.style?.color, StudioColors.galleryWhite);
    expect(find.text('In the studio'), findsOneWidget);
    expect(find.text('Like'), findsOneWidget);
    expect(find.text('Comment'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is StudioIcon && widget.asset == StudioIcons.chat),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((widget) => widget is StudioIcon && widget.asset == StudioIcons.save),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the comment sheet follows light and dark, and 375 does not overflow', (
    tester,
  ) async {
    Future<void> pump({required bool dark, TextScaler textScaler = TextScaler.noScaling}) {
      return tester.pumpWidget(
        _app(
          dark: dark,
          textScaler: textScaler,
          home: const SceneVideoCommentSheet(postId: 'scene-1', authorName: 'Amara Osei'),
        ),
      );
    }

    await tester.binding.setSurfaceSize(const Size(375, 667));
    await pump(dark: false, textScaler: const TextScaler.linear(1.4));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final lightTitle = tester.widget<Text>(find.text("Comment on Amara Osei's scene"));
    expect(lightTitle.style?.color, const Color(0xFF111111));
    expect(lightTitle.style?.fontFamily, 'Geist');
    expect(find.text('Post comment'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(440, 956));
    await pump(dark: true);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Text>(find.text("Comment on Amara Osei's scene")).style?.color,
      const Color(0xFFFAFAF8),
    );
    await tester.binding.setSurfaceSize(null);
  });
}
