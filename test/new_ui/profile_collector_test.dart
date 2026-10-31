import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/screens/profile/widgets/profile_header.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/theme/studio_type.dart';

/// `ProfileCollector` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 6).
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
    home: home,
  );
}

Widget _collector({bool collectorMode = true, bool sellerMode = false}) {
  return Scaffold(
    body: SingleChildScrollView(
      child: ProfileHeader(
        name: 'Jordan Lee',
        handle: '@jordanlee',
        followersCount: 3,
        followingCount: 14,
        bio: 'Collecting work from Dallas artists.',
        piecesCount: 0,
        scenesCount: 0,
        collectedCount: 6,
        savesCount: 32,
        sellerMode: sellerMode,
        collectorMode: collectorMode,
        isOwnProfile: false,
        onFollow: () {},
        onMessage: () {},
      ),
    ),
  );
}

void main() {
  testWidgets('collector stats are collected and saves in Mono 17, no artists', (tester) async {
    await tester.pumpWidget(_app(home: _collector()));
    await tester.pump();

    for (final (value, label) in [('6', 'collected'), ('32', 'saves')]) {
      final stat = tester.widget<Text>(find.text(value));
      expect(stat.style!.fontFamily, StudioType.geistMono);
      expect(stat.style!.fontSize, 17);
      expect(stat.style!.fontWeight, StudioType.medium);
      final caption = tester.widget<Text>(find.text(label));
      expect(caption.style!.fontSize, 12);
      expect(caption.style!.color, StudioColors.light.textSecondary);
    }
    // The payload has no artists count, so that stat stays off rather than faked.
    expect(find.text('artists'), findsNothing);
    expect(find.text('pieces'), findsNothing);
    expect(find.text('scenes'), findsNothing);
    // The two stats share the row equally.
    expect(
      tester.getCenter(find.text('collected')).dx,
      lessThan(tester.getCenter(find.text('saves')).dx),
    );
  });

  testWidgets('collector header keeps name, handle, follow counts, bio and 44 buttons', (
    tester,
  ) async {
    await tester.pumpWidget(_app(home: _collector()));
    await tester.pump();

    final name = tester.widget<Text>(find.text('Jordan Lee'));
    expect(name.style!.fontSize, 22);
    expect(name.style!.fontWeight, StudioType.medium);
    expect(find.text('@jordanlee'), findsOneWidget);
    // Followers stays (a working link to the followers list), though the board shows
    // only following.
    expect(find.text('3 followers'), findsOneWidget);
    expect(find.text('14 following'), findsOneWidget);
    expect(find.text('Collecting work from Dallas artists.'), findsOneWidget);
    final message = find.ancestor(of: find.text('Message'), matching: find.byType(SizedBox)).first;
    expect(tester.getSize(message).height, 44);
  });

  testWidgets('non-collectors keep their own stats', (tester) async {
    await tester.pumpWidget(_app(home: _collector(collectorMode: false)));
    await tester.pump();
    expect(find.text('pieces'), findsOneWidget);
    expect(find.text('scenes'), findsOneWidget);
    expect(find.text('collected'), findsNothing);

    await tester.pumpWidget(_app(home: _collector(collectorMode: false, sellerMode: true)));
    await tester.pump();
    expect(find.text('pieces'), findsOneWidget);
    expect(find.text('collected'), findsOneWidget);
    expect(find.text('scenes'), findsNothing);
  });

  testWidgets('collector header fits at 375 with large text and at 440 in dark', (tester) async {
    for (final (size, dark, scale) in [
      (const Size(375, 667), false, 1.4),
      (const Size(440, 956), true, 1.0),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(home: _collector(), dark: dark, textScaler: TextScaler.linear(scale)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (dark) {
        final stat = tester.widget<Text>(find.text('6'));
        expect(stat.style!.color, StudioColors.dark.textPrimary);
      }
    }
  });
}
