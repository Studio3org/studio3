import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/theme/studio_metrics.dart';
import 'package:studio3/theme/studio_type.dart';
import 'package:studio3/widgets/collection_name_sheet.dart';
import 'package:studio3/widgets/save_to_collection_sheet.dart';
import 'package:studio3/widgets/saved/saved_collection_widgets.dart';
import 'package:studio3/widgets/saved/saved_sheet_menus.dart';
import 'package:studio3/widgets/studio/studio_button.dart';
import 'package:studio3/widgets/studio/studio_top_bar.dart';

Widget _app({
  required Widget home,
  bool dark = false,
  bool reduceMotion = false,
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
        data: mq.copyWith(disableAnimations: reduceMotion, textScaler: textScaler),
        child: child!,
      );
    },
    home: home,
  );
}

SavedSheetFolder _folder(String id, String name, int count) {
  return SavedSheetFolder(id: id, name: name, count: count);
}

void main() {
  test('a dismissed save still cancels, and no folders skips the sheet', () {
    expect(SaveResolution.cancelledResult.cancelled, isTrue);
    expect(SaveResolution.proceedDefault.collectionIds, isEmpty);
    expect(SaveResolution.proceedMany(const ['a', 'b']).collectionIds, ['a', 'b']);
    expect(SaveResolution.proceed('room').collectionId, 'room');
  });

  testWidgets('folder tiles are 3 across, 102, radius 12, with a checked outline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    List<String>? done;
    Set<String>? createdFrom;

    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: SavedFolderPicker(
          pieceTitle: 'Bodies in Color I',
          forSale: true,
          allSavedCount: 33,
          folders: [_folder('room', 'Living room', 8), _folder('gifts', 'Gift ideas', 3)],
          onDone: (ids) => done = ids,
          onNewFolder: (selected) => createdFrom = selected,
        ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Saved'), findsOneWidget);
    expect(
      find.text('Bodies in Color I · for sale, so it\'s also in Available'),
      findsOneWidget,
    );
    expect(find.text('All saved'), findsOneWidget);
    expect(find.text('33'), findsOneWidget);
    expect(find.text('Living room'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Available'), findsNothing);
    expect(find.text('New folder'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    final title = tester.widget<Text>(find.text('All saved'));
    expect(title.style!.fontSize, 13);
    expect(title.style!.fontWeight, StudioType.medium);
    expect(title.style!.fontFamily, StudioType.geist);

    final count = tester.widget<Text>(find.text('33'));
    expect(count.style!.fontFamily, StudioType.geistMono);
    expect(count.style!.fontSize, 11);

    final cover = tester.getSize(find.byType(SavedCoverGrid).first);
    expect(cover.width, closeTo(102, 1));
    expect(cover.height, closeTo(102, 1));
    final clip = tester.widget<ClipRRect>(
      find.descendant(of: find.byType(SavedCoverGrid).first, matching: find.byType(ClipRRect)).first,
    );
    expect(clip.borderRadius, BorderRadius.circular(StudioRadius.button));

    BoxDecoration? outlineOf(String id) {
      final boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byKey(Key('saved-folder-outline-$id')),
          matching: find.byType(DecoratedBox),
        ),
      );
      if (boxes.isEmpty) return null;
      return boxes.first.decoration as BoxDecoration;
    }

    expect(outlineOf('all')!.border!.top.width, 2);
    expect(outlineOf('all')!.border!.top.color, StudioColors.light.textPrimary);
    expect(outlineOf('room'), isNull);

    await tester.tap(find.text('Living room'));
    await tester.pump();
    expect(outlineOf('room')!.border!.top.width, 2);
    expect(tester.widget<Text>(find.text('Living room')).style!.fontWeight, StudioType.medium);

    await tester.tap(find.text('Gift ideas'));
    await tester.pump();
    await tester.tap(find.widgetWithText(StudioButton, 'Done'));
    expect(done, containsAll(['room', 'gifts']));

    await tester.tap(find.byKey(const Key('saved-new-folder-tile')));
    expect(createdFrom, containsAll(['room', 'gifts']));
    expect(tester.getSize(find.widgetWithText(StudioButton, 'Done')).height, 52);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new folder keeps the name to 40 characters', (tester) async {
    await tester.pumpWidget(
      _app(
        home: const Scaffold(body: CollectionNameSheet(pieceTitle: 'Bodies in Color I')),
      ),
    );
    await tester.pump();

    expect(find.text('New folder'), findsOneWidget);
    expect(find.text('Bodies in Color I will go in it.'), findsOneWidget);
    expect(find.text('Folder name'), findsOneWidget);
    expect(tester.widget<StudioButton>(find.byType(StudioButton)).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'x' * 50);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text.length, 40);
    expect(tester.widget<StudioButton>(find.byType(StudioButton)).onPressed, isNotNull);
    expect(tester.widget<Text>(find.text('New folder')).style!.fontSize, 22);
    expect(tester.widget<Text>(find.text('New folder')).style!.fontWeight, StudioType.medium);
  });

  testWidgets('create folder returns the trimmed name', (tester) async {
    String? name;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                name = await CollectionNameSheet.show(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Living room  ');
    await tester.pump();
    await tester.tap(find.widgetWithText(StudioButton, 'Create folder'));
    await tester.pumpAndSettle();
    expect(name, 'Living room');
  });

  testWidgets('folder options rename and delete, and the hold menu', (tester) async {
    String? menu;
    bool? deleted;
    SavedHoldAction? held;

    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: StudioTopBar(
              context: context,
              title: 'Living room',
              actions: [
                SavedFolderOptionsButton(
                  onPressed: () async {
                    menu = await SavedFolderMenu.show(context);
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                TextButton(
                  onPressed: () async {
                    deleted = await SavedDeleteFolderSheet.show(context, name: 'Living room');
                  },
                  child: const Text('ask delete'),
                ),
                TextButton(
                  onPressed: () async {
                    held = await SavedHoldMenu.show(context);
                  },
                  child: const Text('hold'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Back'), findsNothing);
    expect(tester.getSize(find.byKey(const Key('saved-folder-options'))).height, greaterThanOrEqualTo(44));
    await tester.tap(find.byKey(const Key('saved-folder-options')));
    await tester.pumpAndSettle();
    expect(find.text('Rename folder'), findsOneWidget);
    expect(find.text('Delete folder'), findsOneWidget);
    expect(find.text('The pieces stay in All saved'), findsOneWidget);
    expect(tester.getSize(find.text('Rename folder')).height, greaterThan(0));
    final row = tester.getSize(find.ancestor(of: find.text('Rename folder'), matching: find.byType(GestureDetector)).first);
    expect(row.height, greaterThanOrEqualTo(44));
    await tester.tap(find.text('Rename folder'));
    await tester.pumpAndSettle();
    expect(menu, 'rename');

    await tester.tap(find.text('ask delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Living room"?'), findsOneWidget);
    expect(find.text('The pieces stay in All saved.'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);

    await tester.tap(find.text('hold'));
    await tester.pumpAndSettle();
    expect(find.text('Move to folder'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Remove from Saved'), findsOneWidget);
    expect(
      tester.getSize(find.ancestor(of: find.text('Share'), matching: find.byType(GestureDetector)).first).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tapAt(const Offset(780, 20));
    await tester.pumpAndSettle();
    expect(held, isNull);
    expect(find.text('Move to folder'), findsNothing);

    await tester.tap(find.text('hold'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from Saved'));
    await tester.pumpAndSettle();
    expect(held, SavedHoldAction.remove);
  });

  testWidgets('375 at text scale 1.4 and 440 in dark do not overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final picker = Scaffold(
      body: SavedFolderPicker(
        pieceTitle: 'Bodies in Color I',
        forSale: true,
        allSavedCount: 2,
        folders: [_folder('room', 'Living room', 1)],
        onDone: (_) {},
        onNewFolder: (_) {},
      ),
    );

    await tester.pumpWidget(_app(textScaler: const TextScaler.linear(1.4), home: picker));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _app(
        textScaler: const TextScaler.linear(1.4),
        home: const Scaffold(body: CollectionNameSheet()),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _app(
        textScaler: const TextScaler.linear(1.4),
        home: const Scaffold(body: SavedFolderMenu()),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(440, 956));
    await tester.pumpWidget(
      _app(
        dark: true,
        home: SavedHoldMenuCard(
          onDismiss: () {},
          onMove: () {},
          onShare: () {},
          onRemove: () {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.widget<Text>(find.text('Move to folder')).style!.color, StudioColors.dark.textPrimary);
    expect(tester.takeException(), isNull);
  });
}
