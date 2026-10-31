import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/config/app_link_config.dart';
import 'package:studio3/screens/profile/widgets/profile_header.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/theme/studio_type.dart';

/// `ProfileOwn` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 6).
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

Widget _own({required bool isOwnProfile, VoidCallback? onEditProfile, VoidCallback? onShare}) {
  return Scaffold(
    body: SingleChildScrollView(
      child: ProfileHeader(
        name: 'Sarah Osmei',
        handle: '@sarahsunnyart',
        followersCount: 100,
        followingCount: 60,
        bio: 'Artist working in oil, mostly figures and the natural world.',
        piecesCount: 24,
        collectedCount: 9,
        savesCount: 1200,
        sellerMode: true,
        isOwnProfile: isOwnProfile,
        onEditProfile: onEditProfile,
        onShare: onShare,
        onFollow: () {},
        onMessage: () {},
      ),
    ),
  );
}

Material _buttonMaterial(WidgetTester tester, String label) => tester.widget<Material>(
  find.ancestor(of: find.text(label), matching: find.byType(Material)).first,
);

void main() {
  testWidgets('own profile: Edit profile (Ink, fills) and Share (outline, hugs), both 44', (
    tester,
  ) async {
    var edits = 0, shares = 0;
    await tester.pumpWidget(
      _app(
        home: _own(isOwnProfile: true, onEditProfile: () => edits++, onShare: () => shares++),
      ),
    );
    await tester.pump();

    expect(find.text('Message'), findsNothing);
    expect(find.text('Follow'), findsNothing);

    final edit = find
        .ancestor(of: find.text('Edit profile'), matching: find.byType(SizedBox))
        .first;
    final share = find.ancestor(of: find.text('Share'), matching: find.byType(SizedBox)).first;
    expect(tester.getSize(edit).height, 44);
    expect(tester.getSize(share).height, 44);
    expect(_buttonMaterial(tester, 'Edit profile').color, StudioColors.light.buttonFill);
    expect(_buttonMaterial(tester, 'Share').color, Colors.transparent);

    // Share hugs its label (16 each side); Edit profile takes the rest, 10 apart.
    final shareText = tester.getSize(find.text('Share')).width;
    expect(tester.getSize(share).width, closeTo(shareText + 32, 0.5));
    expect(tester.getTopLeft(share).dx - tester.getTopRight(edit).dx, 10);
    expect(tester.getSize(edit).width, greaterThan(tester.getSize(share).width * 2));

    final label = tester.widget<Text>(find.text('Edit profile'));
    expect(label.style!.fontSize, 14);
    expect(label.style!.fontWeight, StudioType.medium);

    await tester.tap(find.text('Edit profile'));
    await tester.tap(find.text('Share'));
    expect(edits, 1);
    expect(shares, 1);
  });

  testWidgets('other people (and viewer mode) still see Message and Follow', (tester) async {
    await tester.pumpWidget(_app(home: _own(isOwnProfile: false)));
    await tester.pump();
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Edit profile'), findsNothing);
    expect(find.text('Share'), findsNothing);
  });

  testWidgets('no insights card or view counts: nothing tracks views', (tester) async {
    await tester.pumpWidget(
      _app(
        home: _own(isOwnProfile: true, onEditProfile: () {}, onShare: () {}),
      ),
    );
    await tester.pump();
    expect(find.text('Last 7 days'), findsNothing);
    expect(find.text('Only you can see this'), findsNothing);
    expect(find.textContaining('views'), findsNothing);
  });

  testWidgets('own header fits at 375 with large text and at 440 in dark', (tester) async {
    for (final (size, dark, scale) in [
      (const Size(375, 667), false, 1.4),
      (const Size(440, 956), true, 1.0),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          home: _own(isOwnProfile: true, onEditProfile: () {}, onShare: () {}),
          dark: dark,
          textScaler: TextScaler.linear(scale),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (dark) {
        expect(_buttonMaterial(tester, 'Edit profile').color, StudioColors.dark.buttonFill);
      }
    }
  });

  test('Share links to the website profile page', () {
    dotenv.loadFromString(envString: '', isOptional: true);
    expect(AppLinkConfig.profileUrl('sarahsunnyart'), 'https://studio-3.co/profile/sarahsunnyart');
    expect(AppLinkConfig.profileUrl('a b'), 'https://studio-3.co/profile/a%20b');
  });
}
