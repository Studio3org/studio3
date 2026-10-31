import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/feed_item.dart';
import 'package:studio3/models/post_summary.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/reels/reel_overlay.dart';
import 'package:studio3/widgets/studio/studio_icon.dart';

FeedItem _reel() {
  return FeedItem.post(
    const PostSummary(
      id: 'scene-1',
      caption: 'In the studio',
      mediaType: 'video',
      authorName: 'Amara Osei',
      authorUsername: 'amara',
      commentCount: 3,
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
  testWidgets('the Scene viewer controls: Save, Comments, Share, no likes, the board icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        home: SizedBox(
          height: 700,
          child: ReelOverlay(
            item: _reel(),
            onToggleSound: () {},
            progress: ValueNotifier(0.2),
          ),
        ),
      ),
    );
    await tester.pump();

    final name = tester.widget<Text>(find.text('Amara Osei'));
    expect(name.style?.fontSize, 15);
    expect(name.style?.fontWeight, FontWeight.w500);
    expect(name.style?.fontFamily, 'Geist');
    expect(name.style?.color, StudioColors.galleryWhite);
    expect(find.text('In the studio'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    for (final asset in [StudioIcons.save, StudioIcons.chat, StudioIcons.share, StudioIcons.soundOff, StudioIcons.more]) {
      expect(
        find.byWidgetPredicate((widget) => widget is StudioIcon && widget.asset == asset && widget.color == StudioColors.galleryWhite),
        findsOneWidget,
        reason: asset,
      );
    }
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.text('Like'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('375 wide with large text does not overflow, light and dark', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        _app(
          dark: dark,
          textScaler: const TextScaler.linear(1.4),
          home: ReelOverlay(item: _reel(), onToggleSound: () {}, progress: ValueNotifier(0)),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      // The viewer is dark in both themes.
      expect(tester.widget<Text>(find.text('Amara Osei')).style?.color, StudioColors.galleryWhite);
    }
    await tester.binding.setSurfaceSize(null);
  });
}
