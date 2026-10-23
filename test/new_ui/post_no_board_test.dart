import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/models/post_summary.dart';
import 'package:studio3/screens/edit_piece_page.dart';
import 'package:studio3/screens/edit_scene_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/create_flow/post_flow_widgets.dart';
import 'package:studio3/widgets/studio/studio_chip.dart';
import 'package:studio3/widgets/studio/studio_field.dart';
import 'package:studio3/widgets/studio/studio_switch.dart';

/// Phase 8 "No board": editing a piece and a Scene after posting
/// (docs/new-ui/NEW_UI_EXECUTION_PLAN.md).
Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

Finder get _list =>
    find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;

final _piece = PieceSummary.fromJson({
  'id': 'p1',
  'title': 'Portrait Dream',
  'isForSale': true,
  'priceCents': 360000,
  'status': 'live',
  'shippingRegion': 'Dallas, TX',
});

void main() {
  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    final theme = dark ? 'dark' : 'light';

    testWidgets('edit piece: Studio fields, switches, ships-from row, status chips ($theme)', (
      tester,
    ) async {
      await tester.pumpWidget(_app(EditPiecePage(piece: _piece), dark: dark));
      await tester.pump();
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, c.background);
      expect(find.byType(StudioUnderlineField), findsWidgets);
      expect(find.byType(TextField), findsWidgets);
      expect(find.byType(OutlineInputBorder), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      await tester.scrollUntilVisible(find.text('Ships from'), 300, scrollable: _list);
      expect(
        tester.widget<PostChevronRow>(find.byType(PostChevronRow)).value,
        'Dallas, TX',
      );
      await tester.scrollUntilVisible(find.text('Draft'), 300, scrollable: _list);
      final chips = tester.widgetList<StudioChip>(find.byType(StudioChip)).toList();
      expect(chips.map((ch) => ch.label), ['Draft', 'Live', 'Hidden']);
      expect(chips.map((ch) => ch.selected), [false, true, false]);
      expect(find.byType(StudioSwitch), findsNWidgets(2));
    });

    testWidgets('edit Scene: caption field, work-in-progress switch, linked pieces row ($theme)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          EditScenePage(
            post: PostSummary.fromJson({
              'id': 's1',
              'caption': 'Underpainting',
              'linkedPieceIds': ['p1'],
              'piece': {'id': 'p1', 'title': 'Portrait Dream'},
            }),
          ),
          dark: dark,
        ),
      );
      await tester.pump();
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, c.background);
      expect(find.text('Edit Scene'), findsOneWidget);
      expect(find.text('Underpainting'), findsOneWidget);
      expect(find.byType(StudioSwitch), findsOneWidget);
      expect(tester.widget<PostChevronRow>(find.byType(PostChevronRow)).value, 'Portrait Dream');
      expect(find.byType(Icon), findsNothing);
    });
  }
}
