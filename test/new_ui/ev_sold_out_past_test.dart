import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/event_detail_page.dart';
import 'package:studio3/services/saved_content_store.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/events/event_detail_widgets.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// `EvSoldOut` and `EvPast`: the event page when every ticket is gone and after it ends
/// (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 17.1).
StudioEvent _event({
  String id = 'ev1',
  bool full = false,
  bool ended = false,
  bool going = false,
  bool host = false,
  bool cancelled = false,
}) => StudioEvent(
  id: id,
  title: 'Inside the Mind of an Artist',
  startsAt: ended ? DateTime(2020, 11, 21, 20) : DateTime(2037, 11, 21, 20),
  endsAt: ended ? DateTime(2020, 11, 21, 22) : DateTime(2037, 11, 21, 22),
  status: cancelled ? 'cancelled' : 'published',
  category: 'gallery_walk',
  venueName: 'Dec on Dragon',
  address: '1414 Dragon St, Dallas, TX 75201',
  hostUsername: 'amara',
  hostName: 'Amara Osei',
  isFull: full,
  spotsLeft: full ? 0 : null,
  viewerIsGoing: going,
  isHost: host,
  description: 'An evening inside the studio with five Dallas painters, an artist talk and new work for sale.',
  lineup: const [
    EventLineupItem(id: 'l1', pieceId: 'p1', mode: 'sale', priceCents: 350000, title: 'Bodies in Color I'),
    EventLineupItem(id: 'l2', pieceId: 'p2', mode: 'sale', priceCents: 95000, title: 'Blue Hour'),
    EventLineupItem(id: 'l3', pieceId: 'p3', mode: 'featured', title: 'Paper Planes III'),
  ],
);

Widget _app(StudioEvent event, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: EventDetailPage(event: event, debugDetail: event),
);

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('ev_states').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  group('EvSoldOut', () {
    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('the grey bar: Sold out, the line, Save (${dark ? 'dark' : 'light'})', (tester) async {
        setBoardViewport(tester);
        await tester.pumpWidget(_app(_event(full: true), dark: dark));
        await tester.pump();
        final bar = find.byType(EventSoldOutBar);
        expect(bar, findsOneWidget);
        final box = tester.widget<Container>(find.descendant(of: bar, matching: find.byType(Container)).first);
        expect((box.decoration! as BoxDecoration).color, c.surface);
        expect(tester.getSize(find.descendant(of: bar, matching: find.byType(Container)).first).height, 68);
        final title = tester.widget<Text>(find.text('Sold out'));
        expect((title.style!.fontSize, title.style!.fontWeight), (16, StudioType.medium));
        expect(find.text('Save it to hear if tickets open up'), findsOneWidget);
        expect(tester.widget<StudioButton>(_button('Save')).variant, StudioButtonVariant.outline);
        expect(_button('Get tickets'), findsNothing);
        expect(find.text('From'), findsNothing);
      });
    }

    testWidgets('Save asks a signed-out viewer to sign in; saved says Saved', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_event(full: true)));
      await tester.pump();
      await tester.tap(_button('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to save events'), findsOneWidget);

      final saved = _event(id: 'ev-saved', full: true);
      SavedContentStore.instance.toggleEvent(saved);
      await tester.pumpWidget(_app(saved));
      await tester.pump();
      expect(_button('Saved'), findsOneWidget);
    });

    testWidgets('going or hosting a full event keeps its own bar', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_event(full: true, going: true)));
      await tester.pump();
      expect(find.byType(EventSoldOutBar), findsNothing);
      expect(_button("You're going"), findsOneWidget);

      await tester.pumpWidget(_app(_event(full: true, host: true)));
      await tester.pump();
      expect(find.byType(EventSoldOutBar), findsNothing);
      expect(_button('Manage event'), findsOneWidget);
    });

    testWidgets('golden: EvSoldOut', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_event(full: true)));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/EvSoldOut.png'));
    }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
  });

  group('EvPast', () {
    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('no bar; the ended note; Work from the show (${dark ? 'dark' : 'light'})', (tester) async {
        setBoardViewport(tester, height: 1400);
        await tester.pumpWidget(_app(_event(ended: true), dark: dark));
        await tester.pump();
        expect(find.byType(StudioBottomBar), findsNothing);
        expect(find.byType(EventSoldOutBar), findsNothing);
        final note = find.byType(EventEndedNote);
        final box = tester.widget<Container>(find.descendant(of: note, matching: find.byType(Container)));
        expect((box.decoration! as BoxDecoration).color, c.surface);
        expect(find.text('This event has ended. The pieces shown here are still on Studio 3.'), findsOneWidget);
        final heading = tester.widget<Text>(find.text('Work from the show'));
        expect((heading.style!.fontSize, heading.style!.fontWeight), (17, StudioType.medium));
        final tiles = find.descendant(of: find.byType(EventShowWorkRow), matching: find.byType(ClipRRect));
        expect(tiles, findsNWidgets(3));
        expect(tester.getSize(tiles.first), const Size(110, 147));
        expect(find.text('Pieces at this event'), findsNothing);
      });
    }

    testWidgets('nothing tagged: just the note; cancelled: the reason in the same box', (tester) async {
      setBoardViewport(tester, height: 1400);
      final bare = StudioEvent(
        id: 'b',
        title: 'Quiet Night',
        startsAt: DateTime(2020, 1, 1, 20),
        endsAt: DateTime(2020, 1, 1, 22),
      );
      await tester.pumpWidget(_app(bare));
      await tester.pump();
      expect(find.text('This event has ended.'), findsOneWidget);
      expect(find.text('Work from the show'), findsNothing);

      await tester.pumpWidget(_app(_event(cancelled: true)));
      await tester.pump();
      expect(find.text('This event was cancelled.'), findsOneWidget);
      expect(find.byType(EventEndedNote), findsOneWidget);
    });

    testWidgets('golden: EvPast', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_event(ended: true)));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/EvPast.png'));
    }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
  });
}
