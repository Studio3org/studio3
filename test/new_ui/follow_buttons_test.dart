import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/screens/profile/widgets/profile_header.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/home_feed_tokens.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/explore/explore_browse.dart';
import 'package:studio3/widgets/follow_button.dart';
import 'package:studio3/widgets/piece_detail/collect_artist_row.dart';
import 'package:studio3/widgets/piece_detail/piece_artist_row.dart';

Widget _app(Widget home) {
  return MaterialApp(
    key: UniqueKey(),
    theme: AppTheme.light,
    home: Scaffold(body: home),
  );
}

FeedPreviewItem _artist() {
  return FeedPreviewItem(
    id: 'piece',
    imageSeeds: const [],
    title: 'River',
    medium: 'Oil',
    year: 2024,
    dimensions: '',
    story: '',
    handle: '@amara',
    isAvailable: true,
    aspectRatio: FeedAspectRatio.portrait3x4,
    authorName: 'Amara Osei',
  );
}

/// Holds follow state in the test so a tap never calls the follow API.
class _Host extends StatefulWidget {
  const _Host({required this.builder});

  final Widget Function(FollowState state, VoidCallback toggle) builder;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  FollowState state = FollowState.none;

  @override
  Widget build(BuildContext context) {
    return widget.builder(state, () {
      setState(() {
        state = state == FollowState.none ? FollowState.following : FollowState.none;
      });
    });
  }
}

Color _nearestMaterialColor(WidgetTester tester, String label) {
  final text = tester.element(find.text(label));
  late Color color;
  text.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is Material && widget.color != null) {
      color = widget.color!;
      return false;
    }
    return true;
  });
  return color;
}

BoxDecoration _buttonDecoration(WidgetTester tester, String label) {
  return tester.widget<Container>(find.widgetWithText(Container, label)).decoration!
      as BoxDecoration;
}

void main() {
  test('Follow is the dark action; Following (with a check) is the light one', () {
    expect(FollowState.none.actionLabel, 'Follow');
    expect(FollowState.none.filled, isTrue);
    expect(FollowState.following.actionLabel, 'Following');
    expect(FollowState.following.icon, isNotNull); // the small check (`HandoffRules`)
    expect(FollowState.following.filled, isFalse);
    expect(FollowState.pending.actionLabel, 'Requested');
    expect(FollowState.pending.filled, isFalse);
  });

  // The Scene viewer's white Follow is covered in phase13_scenes_test.dart.
  testWidgets('Follow buttons on the piece, profile and explore toggle together', (
    tester,
  ) async {
    final artist = _artist();

    final surfaces = <String, Widget Function(FollowState, VoidCallback)>{
      'shared button': (state, toggle) => Align(
        alignment: Alignment.topCenter,
        child: FollowButton(state: state, onPressed: toggle),
      ),
      'piece detail': (state, toggle) =>
          PieceArtistRow(item: artist, followState: state, onFollowToggle: toggle),
      'collect detail': (state, toggle) =>
          CollectArtistRow(item: artist, followState: state, onFollowToggle: toggle),
      'profile': (state, toggle) => ProfileHeader(
        name: 'Amara Osei',
        handle: '@amara',
        followersCount: 12,
        followingCount: 4,
        bio: '',
        sellerMode: true,
        isOwnProfile: false,
        followState: state,
        onFollow: toggle,
      ),
      'explore artist': (state, toggle) =>
          ExploreArtistTile(name: 'Amara Osei', followLabel: state.actionLabel, onFollow: toggle),
    };

    for (final entry in surfaces.entries) {
      await tester.pumpWidget(_app(_Host(builder: entry.value)));
      await tester.pump();

      if (entry.key != 'shared button') {
        expect(find.text('Amara Osei'), findsWidgets, reason: entry.key);
      }
      expect(find.text('Follow'), findsOneWidget, reason: entry.key);
      expect(find.text('Following'), findsNothing, reason: entry.key);

      final followDark = entry.key == 'explore artist'
          ? _buttonDecoration(tester, 'Follow').color
          : _nearestMaterialColor(tester, 'Follow');
      expect(
        followDark,
        // Rebuilt surfaces read the new theme; the rest still use the old tokens.
        entry.key == 'profile' || entry.key == 'explore artist' || entry.key == 'collect detail'
            ? StudioColors.light.buttonFill
            : HomeFeedTokens.textPrimary,
        reason: entry.key,
      );

      await tester.tap(find.text('Follow'));
      await tester.pump();

      expect(find.text('Follow'), findsNothing, reason: entry.key);
      expect(find.text('Following'), findsOneWidget, reason: entry.key);

      final unfollowLight = entry.key == 'explore artist'
          ? _buttonDecoration(tester, 'Following').color
          : _nearestMaterialColor(tester, 'Following');
      expect(unfollowLight == followDark, isFalse, reason: entry.key);
      expect(
        unfollowLight,
        entry.key == 'explore artist' ? StudioColors.light.card : Colors.transparent,
        reason: entry.key,
      );

      await tester.tap(find.text('Following'));
      await tester.pump();
      expect(find.text('Follow'), findsOneWidget, reason: entry.key);
      expect(find.text('Following'), findsNothing, reason: entry.key);
    }
  });
}
