import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/data/post_material_options.dart';
import 'package:studio3/screens/add_materials_page.dart';
import 'package:studio3/screens/pick_materials_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';

import 'golden_harness.dart';

/// `PostMaterials`, `PostMaterialsSearch` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 8).
PostMaterialOption _m(String id) => PostMaterialOptions.byId(id)!;

final _picked = [
  _m('winsor_newton_oil_paint'),
  _m('belle_arti_linen_canvas'),
  _m('gamblin_cold_wax_medium'),
  _m('liquitex_palette_knife'),
];
final _recent = [
  _m('gamblin_gamsol'),
  _m('princeton_filbert_brush'),
  _m('liquitex_gesso'),
];

Widget _host(Widget Function(BuildContext) open, {bool dark = false, void Function(Object?)? onResult}) =>
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final r = await Navigator.push<Object?>(
                context,
                MaterialPageRoute(builder: open),
              );
              onResult?.call(r);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  setUpAll(loadStudioFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('catalog: type + brand + kind, search by type then brand, own entries', () {
    final oil = PostMaterialOptions.search('oil pa');
    expect(oil.map((m) => m.name).take(4), [
      'Oil paint · Winsor & Newton',
      'Oil paint · Gamblin',
      'Oil paint · Michael Harding',
      'Oil paint · M. Graham',
    ]);
    expect(oil.any((m) => m.kind == MaterialKind.tool), isTrue); // brush set
    expect(PostMaterialOptions.search('gamblin').first.brand, 'Gamblin');
    final own = PostMaterialOption.custom(' Beeswax ');
    expect((own.name, own.isCustom, PostMaterialOptions.byId(own.id)), ('Beeswax', true, own));
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    testWidgets('list: heading, search, Recent chips, Materials / Tools groups (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1000);
      Object? result;
      await tester.pumpWidget(
        _host(
          (_) => AddMaterialsPage(initialMaterials: _picked, recent: _recent),
          dark: dark,
          onResult: (r) => result = r,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor, c.background);
      expect(find.text('Materials and tools'), findsOneWidget);
      expect(find.text("Credit where it's due. Brushes included."), findsOneWidget);
      expect(find.text('Search paints, surfaces, brushes…'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      expect(find.bySemanticsLabel('Add Gamsol · Gamblin'), findsOneWidget);
      expect(find.text('Materials'), findsOneWidget);
      expect(find.text('Tools'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Add Gesso · Liquitex'));
      await tester.pump();
      expect(find.text('4'), findsOneWidget);
      expect(find.bySemanticsLabel('Add Gesso · Liquitex'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Remove Linen canvas · Belle Arti'));
      await tester.pump();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      final names = (result! as List<PostMaterialOption>).map((m) => m.name);
      expect(names, contains('Gesso · Liquitex'));
      expect(names, isNot(contains('Linen canvas · Belle Arti')));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('recent_materials'), contains('liquitex_gesso'));
    });
  }

  testWidgets('search: bold match, material / tool tags, own entry only without matches', (
    tester,
  ) async {
    setBoardViewport(tester);
    Object? result;
    await tester.pumpWidget(
      _host((_) => const PickMaterialsPage(selected: []), onResult: (r) => result = r),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Oil pa');
    await tester.pump();

    expect(find.text('material'), findsWidgets);
    expect(find.text('tool'), findsOneWidget);
    final title = tester.widget<RichText>(
      find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == 'Oil paint').first,
    );
    final spans = (title.text as TextSpan).children!.first as TextSpan;
    expect(
      (spans.children![1] as TextSpan).style!.fontWeight,
      FontWeight.w500,
    );
    expect(find.textContaining('as your own'), findsNothing);
    expect(find.textContaining('Picking from the list'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Beeswax');
    await tester.pump();
    expect(find.text('Add “Beeswax” as your own'), findsOneWidget);
    await tester.tap(find.text('Add “Beeswax” as your own'));
    await tester.pumpAndSettle();
    expect((result! as PostMaterialOption).name, 'Beeswax');
  });

  testWidgets('golden: PostMaterials', (tester) async {
    setBoardViewport(tester, height: 1000);
    await tester.pumpWidget(
      _host((_) => AddMaterialsPage(initialMaterials: _picked, recent: _recent)),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/PostMaterials.png'));
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');

  testWidgets('golden: PostMaterialsSearch', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_host((_) => const PickMaterialsPage(selected: [])));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Oil pa');
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/PostMaterialsSearch.png'),
    );
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}
