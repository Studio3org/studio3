import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/models/post_summary.dart';
import 'package:studio3/models/user_profile.dart';
import 'package:studio3/screens/list_piece_flow.dart';
import 'package:studio3/screens/piece_detail_page.dart';
import 'package:studio3/screens/related_scenes_page.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/create_flow/post_result_views.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// List it later (`ListOwnerPiece`, `PostListLater`, `ListPricing`, `ListDone`) and Related
/// Scenes (`PostRelatedScenes`) (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 8).
Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

const _piece = PieceSummary(
  id: 'p1',
  title: 'Bodies in Color',
  dimensions: '24x36 in',
  location: 'Dallas, TX',
  authorUsername: 'sarah',
);

Future<CommissionQuote?> _founding(int cents) async => CommissionQuote(
  priceCents: cents,
  netCents: cents - (cents * 15 ~/ 100),
  commissionBps: 1500,
  reducedRate: true,
);

const _details = ListLaterDetails(dimensions: '24x36x1.5 in', weightKg: 3.629, framing: 'Unframed');

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('list_later').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  test('sizes read back: width, height, depth and unit', () {
    expect(parseDimensions('24x36x1.5 in'), (width: '24', height: '36', depth: '1.5', unit: 'in'));
    expect(parseDimensions('30 × 40 cm'), (width: '30', height: '40', depth: null, unit: 'cm'));
    expect(parseDimensions(null).width, isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('before you list it: depth, weight, framing; Continue off until all three (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      Object? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await ListLaterDetailsSheet.show(context, piece: _piece),
                child: const Text('open'),
              ),
            ),
          ),
          dark: dark,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Before you list it'), findsOneWidget);
      expect(find.text('We need three more details to quote shipping for collectors.'), findsOneWidget);
      final fields = tester.widgetList<StudioUnderlineField>(find.byType(StudioUnderlineField));
      expect(fields.map((f) => (f.label, f.unit)), [('Depth', 'in'), ('Weight', 'lb')]);
      expect(find.text('Framing'), findsOneWidget);
      StudioButton next() =>
          tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Continue to pricing'));
      expect(next().onPressed, isNull);
      await tester.enterText(find.byType(TextField).first, '1.5');
      await tester.enterText(find.byType(TextField).last, '8');
      await tester.pump();
      expect(next().onPressed, isNull);
      await tester.tap(find.text('Framing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unframed'));
      await tester.pumpAndSettle();
      expect(next().onPressed, isNotNull);
      await tester.tap(find.text('Continue to pricing'));
      await tester.pumpAndSettle();
      final details = result! as ListLaterDetails;
      expect(details.dimensions, '24x36x1.5 in');
      expect(details.weightKg, closeTo(3.629, 0.001));
      expect(details.framing, 'Unframed');
    });
  }

  testWidgets('pricing: 2 of 2, Fixed price, earnings, List it sends the sale', (tester) async {
    setBoardViewport(tester);
    final patches = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      _app(
        ListPricingPage(
          piece: _piece,
          details: _details,
          quote: _founding,
          update: (id, body) async {
            patches.add(body);
            return PieceSummary(
              id: id,
              title: _piece.title,
              isForSale: true,
              priceCents: body['priceCents'] as int?,
              status: 'live',
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('How do you want to sell it?'), findsOneWidget);
    expect(find.text('Pick how collectors can buy Bodies in Color.'), findsOneWidget);
    final progress = tester.widget<StudioProgressSegments>(find.byType(StudioProgressSegments));
    expect((progress.current, progress.total), (2, 2));
    expect(find.text('Fixed price'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'List it')).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '3600');
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains(r'$3,060 after the 15% fee. See fees'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('List it'));
    // The listed screen's iridescent frame keeps moving, so pump instead of settling.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(patches.single, {
      'isForSale': true,
      'listingType': 'fixed',
      'priceCents': 360000,
      'dimensions': '24x36x1.5 in',
      'weightKg': 3.629,
      'framingMounting': 'Unframed',
      'shippingRegion': 'Dallas, TX',
    });
    expect(find.byType(ListDonePage), findsOneWidget);
    expect(find.text('Bodies in Color is listed'), findsOneWidget);
    expect(find.text('Add a Scene from the studio'), findsOneWidget);
    expect(find.text('Share your piece'), findsOneWidget);
    expect(find.text('View piece'), findsOneWidget);
  });

  group("owner's not-for-sale piece", () {
    late AuthUser? wasUser;
    setUp(() {
      wasUser = AuthSession.instance.user;
      AuthSession.instance.user = const AuthUser(username: 'sarah', name: 'Sarah', email: 's@x.test');
    });
    tearDown(() => AuthSession.instance.user = wasUser);

    FeedPreviewItem item({String? status}) => FeedPreviewItem(
      id: 'p1',
      imageSeeds: const [1],
      title: 'Bodies in Color',
      medium: 'Oil',
      year: 2025,
      dimensions: '24 × 36 in',
      story: '',
      handle: '@sarah',
      isAvailable: false,
      aspectRatio: FeedAspectRatio.portrait3x4,
      status: status,
    );

    testWidgets('bar: List for sale and the edit button', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(PieceDetailPage(item: item())));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(find.text('List for sale'), findsOneWidget);
      final edit = tester.widget<StudioMessageButton>(find.byType(StudioMessageButton));
      expect((edit.icon, edit.semanticLabel), (StudioIcons.edit, 'Edit piece'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });

    testWidgets('a sold piece has no bar', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(PieceDetailPage(item: item(status: 'sold'))));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(find.text('List for sale'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });
  });

  final scenes = [
    for (final (id, video) in [('s1', true), ('s2', false), ('s3', true), ('s4', false)])
      PostSummary.fromJson({'id': id, 'mediaType': video ? 'video' : 'image', 'status': 'live'}),
  ];

  for (final dark in [false, true]) {
    testWidgets('related Scenes: line, Mono count, 9:16 grid, tap to link, Done (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      setBoardViewport(tester);
      Object? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await Navigator.of(context).push(
                  MaterialPageRoute<List<PostSummary>>(
                    builder: (_) => RelatedScenesPage(selected: [scenes[0]], debugScenes: scenes),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
          dark: dark,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Related Scenes'), findsOneWidget);
      expect(find.textContaining('Pick Scenes that show how this piece came together.'), findsOneWidget);
      expect(tester.widget<Text>(find.text('1 linked')).style!.fontFamily, contains('Mono'));
      expect(find.text('Linked'), findsOneWidget);
      final tiles = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Scene');
      expect(tiles, findsNWidgets(4));
      expect(tester.getSize(tiles.first).aspectRatio, closeTo(9 / 16, 0.01));
      await tester.tap(tiles.at(2));
      await tester.pump();
      expect(find.text('2 linked'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect((result! as List<PostSummary>).map((s) => s.id), ['s1', 's3']);
    });
  }

  group('goldens', () {
    final skip = Platform.environment['NEW_UI_GOLDENS'] != '1';

    testWidgets('ListPricing', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(ListPricingPage(piece: _piece, details: _details, quote: _founding)),
      );
      await tester.enterText(find.byType(TextField), '3600');
      await tester.pump(const Duration(milliseconds: 400));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/ListPricing.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('PostListLater', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => ListLaterDetailsSheet.show(
                  context,
                  piece: const PieceSummary(id: 'p1', title: 'T', dimensions: '24x36x1.5 in'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/PostListLater.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('PostRelatedScenes', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(RelatedScenesPage(selected: scenes.take(2).toList(), debugScenes: scenes)),
      );
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/PostRelatedScenes.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('ListDone', (tester) async {
      setBoardViewport(tester);
      debugDisableShadows = false;
      await tester.pumpWidget(
        _app(
          PostPublishedView(
            title: 'Bodies in Color',
            heading: 'Bodies in Color is listed',
            subheading: 'Collectors can collect it now.',
            cover: const ColoredBox(color: Color(0xFF6FA3B0)),
            photoCount: 4,
            authorName: 'Amara Osei',
            avatarUrl: null,
            priceLabel: r'$3,600',
            onClose: () {},
            onAddScene: () {},
            onShare: () {},
            onView: () {},
          ),
        ),
      );
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/ListDone.png'));
      await checkAcceptance(tester);
      debugDisableShadows = true;
    }, skip: skip);
  });
}
