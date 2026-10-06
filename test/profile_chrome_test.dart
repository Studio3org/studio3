import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studio3/screens/profile/widgets/profile_hero.dart';

/// The back chevron and the more (…) button sit on the same line at the top
/// of the profile cover. These pin the two things that were wrong: the more
/// mark being squashed to a fraction of its size, and its tap target being
/// shorter than the platform minimum.
void main() {
  Future<void> pumpHero(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 47)),
          child: Scaffold(
            body: ProfileHero(
              width: 390,
              onBack: () {},
              onMore: () {},
              onAvatarTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The tappable box for a chrome button.
  Finder hit(String label) => find.ancestor(
        of: find.bySemanticsLabel(label),
        matching: find.byType(SizedBox),
      );

  /// The drawn mark itself.
  Finder mark(String label) => find.descendant(
        of: find.bySemanticsLabel(label),
        matching: find.byType(SvgPicture),
      );

  testWidgets('the more mark is drawn at its own aspect ratio', (tester) async {
    await pumpHero(tester);
    // The artboard is 17x3.4, i.e. 5:1. Drawn into a box of a different
    // aspect, BoxFit.contain shrinks the whole mark to fit the tighter
    // dimension — which is how it ended up 12x2.4 instead of full size.
    final size = tester.getSize(mark('More options'));
    expect(size.width / size.height, closeTo(5.0, 0.001));
  });

  testWidgets('the more mark is no longer hairline', (tester) async {
    await pumpHero(tester);
    final more = tester.getSize(mark('More options'));
    final back = tester.getSize(mark('Back'));
    // Each dot is as tall as the mark. 2.4pt read as a hairline next to the
    // 16.5pt chevron; 4pt is the fix.
    expect(more.height, greaterThanOrEqualTo(4.0));
    expect(more.width, greaterThan(back.width));
  });

  testWidgets('both chrome buttons meet the 44pt minimum target', (
    tester,
  ) async {
    await pumpHero(tester);
    for (final label in ['Back', 'More options']) {
      final size = tester.getSize(hit(label).first);
      expect(size.width, greaterThanOrEqualTo(44.0), reason: '$label width');
      expect(size.height, greaterThanOrEqualTo(44.0), reason: '$label height');
    }
  });

  testWidgets('both marks share one vertical centre', (tester) async {
    await pumpHero(tester);
    expect(
      tester.getRect(mark('Back')).center.dy,
      closeTo(tester.getRect(mark('More options')).center.dy, 0.01),
    );
  });

  testWidgets('the more mark stays on its Figma right margin', (tester) async {
    await pumpHero(tester);
    // Growing the hit box must not push the icon off its designed inset.
    final right = tester.getRect(mark('More options')).right;
    expect(390 - right, closeTo(10.0, 0.01));
  });
}
