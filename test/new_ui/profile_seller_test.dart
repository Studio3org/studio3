import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/screens/profile/models/profile_series_data.dart';
import 'package:studio3/screens/profile/profile_constants.dart';
import 'package:studio3/screens/profile/widgets/profile_header.dart';
import 'package:studio3/screens/profile/widgets/profile_tab_content.dart';
import 'package:studio3/screens/profile/widgets/profile_hero.dart';
import 'package:studio3/screens/profile/widgets/profile_seller_pieces.dart';
import 'package:studio3/screens/profile/widgets/profile_tabs.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/theme/studio_type.dart';
import 'package:studio3/widgets/profile_avatar.dart';
import 'package:studio3/widgets/profile_cover_image.dart';
import 'package:studio3/widgets/studio/studio_chip.dart';

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

PieceSummary _piece({
  required String id,
  required String title,
  bool forSale = false,
  String? status,
}) {
  return PieceSummary(id: id, title: title, isForSale: forSale, status: status);
}

void main() {
  testWidgets('seller cover is 190 with a 44 overlap and white 44 controls', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: ProfileHero(
            width: 390,
            onBack: () {},
            onMore: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.widget<ProfileCoverImage>(find.byType(ProfileCoverImage)).height, kProfileCoverHeight);
    final avatar = tester.getRect(find.byType(ProfileAvatar));
    expect(avatar.width, 88);
    expect(avatar.top, kProfileAvatarTop + kProfileAvatarBorder);

    final back = tester.getRect(find.bySemanticsLabel('Back'));
    expect(back.width, 44);
    expect(back.height, 44);
    expect(back.left, 8);
    expect(back.top, 12);
    final more = tester.getRect(find.bySemanticsLabel('More options'));
    expect(more.width, 44);
    expect(more.right, 382);
  });

  testWidgets('seller header is name, three stats, and two 44 buttons', (tester) async {
    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: ProfileHeader(
            name: 'Sarah Osmei',
            handle: '@sarahsunnyart',
            followersCount: 100,
            followingCount: 60,
            bio: 'Artist working in oil, mostly figures and the natural world.',
            piecesCount: 24,
            scenesCount: 8,
            collectedCount: 9,
            savesCount: 1200,
            sellerMode: true,
            isOwnProfile: false,
            onFollow: () {},
            onMessage: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final name = tester.widget<Text>(find.text('Sarah Osmei'));
    expect(name.style!.fontSize, 22);
    expect(name.style!.fontWeight, StudioType.medium);
    expect(name.style!.letterSpacing, -0.3);
    expect(find.text('scenes'), findsNothing);
    expect(find.text('rating'), findsNothing);
    expect(find.textContaining('Upcoming'), findsNothing);
    expect(find.text('pieces'), findsOneWidget);
    expect(find.text('collected'), findsOneWidget);
    expect(find.text('saves'), findsOneWidget);
    final saves = tester.widget<Text>(find.text('1.2k'));
    expect(saves.style!.fontSize, 17);
    expect(saves.style!.fontFamily, StudioType.geistMono);
    expect(saves.style!.fontWeight, StudioType.medium);

    final message = tester.getSize(
      find.ancestor(of: find.text('Message'), matching: find.byType(SizedBox)).first,
    );
    expect(message.height, 44);
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets('seller pieces filter to for-sale and keep the Collected chip', (tester) async {
    var openedSeries = false;
    final pieces = [
      _piece(id: 'a', title: 'Bodies in Color I', forSale: true),
      _piece(id: 'b', title: 'Quiet study'),
      _piece(id: 'c', title: 'Sold figure', status: 'sold'),
    ];
    final series = [
      ProfileSeriesData(name: 'Bodies in Color', pieceCount: 8, previewUrls: const []),
    ];

    Future<void> pump(WidgetTester tester, {bool dark = false, TextScaler scaler = TextScaler.noScaling}) {
      return tester.pumpWidget(
        _app(
          dark: dark,
          textScaler: scaler,
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                ProfileSellerPieces(
                  pieces: pieces,
                  series: series,
                  onSeeAllSeries: () => openedSeries = true,
                ),
              ],
            ),
          ),
        ),
      );
    }

    await tester.binding.setSurfaceSize(const Size(390, 900));
    await pump(tester);
    await tester.pump();

    expect(find.text('Series'), findsOneWidget);
    expect(find.text('8 pieces'), findsOneWidget);
    expect(tester.getSize(find.byType(ClipRRect).first).width, 160);
    expect(find.text('Bodies in Color I'), findsOneWidget);
    expect(find.text('Quiet study'), findsOneWidget);
    expect(find.text('Collected'), findsOneWidget);
    expect(find.byKey(const Key('profile-available-filter')), findsOneWidget);
    expect(find.textContaining('Upcoming'), findsNothing);

    final image = tester.widget<AspectRatio>(find.byType(AspectRatio).first);
    expect(image.aspectRatio, 167 / 223);
    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect).at(1));
    expect(clip.borderRadius, BorderRadius.circular(kProfileCardRadius));

    await tester.tap(find.byKey(const Key('profile-available-filter')));
    await tester.pump();
    expect(find.text('Bodies in Color I'), findsOneWidget);
    expect(find.text('Quiet study'), findsNothing);
    expect(find.text('Sold figure'), findsNothing);
    expect(find.text('All 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-series-see-all')));
    expect(openedSeries, isTrue);

    await tester.binding.setSurfaceSize(const Size(375, 667));
    await pump(tester, scaler: const TextScaler.linear(1.4));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(440, 956));
    await pump(tester, dark: true);
    await tester.pump();
    expect(tester.widget<Text>(find.text('Series')).style!.color, StudioColors.dark.textPrimary);
    expect(tester.widget<Text>(find.text('Bodies in Color I')).style!.color, StudioColors.dark.textPrimary);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Available stays hidden when nothing is for sale, and tabs stay', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              ProfileSellerPieces(
                pieces: [_piece(id: 'q', title: 'Quiet study')],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('profile-available-filter')), findsNothing);
    expect(find.byType(StudioStatusChip), findsNothing);
    expect(find.text('Series'), findsNothing);
    expect(find.text('No pieces yet'), findsNothing);

    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              ProfileTabContent(
                currentTab: 'scenes',
                seriesItems: const [],
                sellerMode: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('No scenes yet'), findsNothing);

    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: ProfileTabs(
            currentTab: 'pieces',
            showCollect: true,
            onTabChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    for (final label in ['Pieces', 'Scenes', 'Series', 'Collect']) {
      expect(find.text(label), findsOneWidget);
    }
    final pieces = tester.getSize(
      find.ancestor(of: find.text('Pieces'), matching: find.byType(SizedBox)).first,
    );
    expect(pieces.height, 44);
    expect(tester.widget<Text>(find.text('Pieces')).style!.fontWeight, StudioType.medium);
    expect(tester.widget<Text>(find.text('Scenes')).style!.color, StudioColors.light.textTertiary);
    expect(tester.takeException(), isNull);
  });
}
