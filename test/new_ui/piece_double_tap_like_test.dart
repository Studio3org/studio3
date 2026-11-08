import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/screens/piece_detail_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/piece_detail/piece_action_bar.dart';
import 'package:studio3/widgets/piece_detail/piece_double_tap_like.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// A piece page has no Like or Comment buttons: a double tap on the image likes the piece and
/// another takes the like back, with a heart burst; each visit opens with a "Double tap to
/// like" hint that fades away. Scenes keep their Like and Comment row.

class _Host extends StatefulWidget {
  const _Host({this.allow = true});

  /// False: the toggle does nothing (a guest who doesn't log in).
  final bool allow;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool liked = false;
  int toggles = 0;
  int opened = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 390,
      height: 520,
      child: PieceDoubleTapLike(
        liked: liked,
        onToggle: () async {
          toggles++;
          if (widget.allow) setState(() => liked = !liked);
        },
        child: GestureDetector(
          onTap: () => opened++,
          child: const ColoredBox(color: Color(0xFF6FA3B0)),
        ),
      ),
    ),
  );
}

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  home: Scaffold(body: home),
);

Future<void> _doubleTap(WidgetTester tester) async {
  await tester.tap(find.byType(PieceDoubleTapLike));
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tap(find.byType(PieceDoubleTapLike));
  await tester.pump();
  await tester.pump();
}

double _hintOpacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('double-tap-hint'))).opacity;

void main() {
  setUpAll(loadStudioFonts);

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('the hint shows on arrival, then fades ($theme)', (tester) async {
      await tester.pumpWidget(_app(const _Host(), dark: dark));
      expect(_hintOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_hintOpacity(tester), 1);
      expect(find.text('Double tap to like'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is StudioIcon && w.asset == StudioIcons.liked), findsOneWidget);
      await tester.pump(PieceDoubleTapLike.hintHold);
      expect(_hintOpacity(tester), 0);
      await tester.pumpAndSettle();
    });

    testWidgets('double tap likes with a filled heart; again unlikes with an outline ($theme)', (tester) async {
      await tester.pumpWidget(_app(const _Host(), dark: dark));
      final host = tester.state<_HostState>(find.byType(_Host));

      await _doubleTap(tester);
      expect(host.liked, isTrue);
      expect(find.byKey(const ValueKey('burst-liked')), findsOneWidget);
      expect(_hintOpacity(tester), 0, reason: 'a double tap puts the hint away');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('burst-liked')), findsNothing, reason: 'the burst fades');

      await _doubleTap(tester);
      expect(host.liked, isFalse);
      expect(find.byKey(const ValueKey('burst-unliked')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(host.opened, 0, reason: 'a double tap is not a tap on the picture');
    });
  }

  testWidgets('a single tap still opens the picture', (tester) async {
    await tester.pumpWidget(_app(const _Host()));
    final host = tester.state<_HostState>(find.byType(_Host));
    await tester.tap(find.byType(PieceDoubleTapLike));
    await tester.pump(const Duration(milliseconds: 400)); // past the double-tap wait
    expect(host.opened, 1);
    expect(host.toggles, 0);
  });

  testWidgets('no burst when nothing changed (a guest who stays logged out)', (tester) async {
    await tester.pumpWidget(_app(const _Host(allow: false)));
    await _doubleTap(tester);
    expect(tester.state<_HostState>(find.byType(_Host)).toggles, 1);
    expect(find.byKey(const ValueKey('burst-liked')), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('screen readers get Like, then Unlike, as an action', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const _Host()));
    final node = tester.getSemantics(find.byType(PieceDoubleTapLike));
    expect(node.getSemanticsData().customSemanticsActionIds, isNotEmpty);
    final like = CustomSemanticsAction.getIdentifier(const CustomSemanticsAction(label: 'Like'));
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(node.id, SemanticsAction.customAction, like);
    await tester.pump();
    expect(tester.state<_HostState>(find.byType(_Host)).liked, isTrue);
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets("a Scene's page keeps its Like and Comment row and has no double-tap like", (tester) async {
    setBoardViewport(tester, height: 1400);
    await tester.pumpWidget(
      _app(
        PieceDetailPage(
          item: const FeedPreviewItem(
            id: 's1',
            imageSeeds: [1],
            title: 'Late night layering',
            medium: 'Scene',
            year: 2025,
            dimensions: '',
            story: '',
            isAvailable: false,
            handle: '@amara',
            authorUsername: 'amara',
            authorName: 'Amara Osei',
            aspectRatio: FeedAspectRatio.portrait3x4,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(PieceActionBar), findsOneWidget);
    expect(find.text('Comment'), findsOneWidget);
    expect(find.byType(PieceDoubleTapLike), findsNothing);
    await tester.pump(const Duration(seconds: 11));
  });
}
