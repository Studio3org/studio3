import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/models/auction.dart';
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
    testWidgets('before you list it: depth, weight, packed size, framing; Continue off until all are in (${dark ? 'dark' : 'light'})', (
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
      expect(find.text('We need a few more details to quote shipping for collectors.'), findsOneWidget);
      final fields = tester.widgetList<StudioUnderlineField>(find.byType(StudioUnderlineField));
      expect(fields.map((f) => (f.label, f.unit)), [('Depth', 'in'), ('Weight', 'lb')]);
      expect(find.text('Framing'), findsOneWidget);
      // What the courier prices on (FRONTEND_HANDOFF 8.1).
      expect(find.text('Packed size'), findsOneWidget);
      expect(find.text('Packing'), findsOneWidget);
      expect(find.text('Item type'), findsOneWidget);
      expect(find.text('Materials or framing'), findsOneWidget);
      StudioButton next() =>
          tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Continue to pricing'));
      expect(next().onPressed, isNull);
      await tester.enterText(find.byType(TextField).at(0), '1.5');
      await tester.enterText(find.byType(TextField).at(1), '8');
      await tester.pump();
      expect(next().onPressed, isNull);
      await tester.enterText(find.byType(TextField).at(2), '30');
      await tester.enterText(find.byType(TextField).at(3), '40');
      await tester.enterText(find.byType(TextField).at(4), '5');
      await tester.pump();
      expect(next().onPressed, isNull);
      await tester.ensureVisible(find.text('Item type'));
      await tester.tap(find.text('Item type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Painting'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Materials or framing'));
      await tester.tap(find.text('Materials or framing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Framed under glass'));
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(StudioButton, 'Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(StudioButton, 'Done'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Framing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Framing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unframed'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue to pricing'));
      await tester.pumpAndSettle();
      expect(next().onPressed, isNotNull);
      await tester.tap(find.text('Continue to pricing'));
      await tester.pumpAndSettle();
      final details = result! as ListLaterDetails;
      expect(details.dimensions, '24x36x1.5 in');
      expect(details.weightKg, closeTo(3.629, 0.001));
      expect(details.framing, 'Unframed');
      expect(details.shipping, {
        'packageLengthCm': 76.2,
        'packageWidthCm': 101.6,
        'packageHeightCm': 12.7,
        'shippingItemType': 'fine_art.painting',
        'shippingMaterials': ['framed_glass'],
      });
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

  test('the listed line: who was told, else what collectors can do (B17)', () {
    PieceSummary listed({int? saved, String type = 'fixed'}) =>
        PieceSummary(id: 'p1', title: 'Bodies in Color', listingType: type, savesCount: saved);
    expect(listedSubheading(listed(saved: 12)), 'We let the 12 people who saved it know.');
    expect(listedSubheading(listed(saved: 1)), 'We let the person who saved it know.');
    expect(listedSubheading(listed(saved: 0)), 'Collectors can collect it now.');
    expect(listedSubheading(listed()), 'Collectors can collect it now.');
    expect(listedSubheading(listed(type: 'auction')), 'Collectors can bid on it now.');
    expect(savedPeople(1), '1 person');
    expect(PieceSummary.fromJson({'id': 'p1', 'title': 'T', 'savesCount': 3}).savesCount, 3);
    expect(PieceSummary.fromJson({'id': 'p1', 'title': 'T'}).savesCount, isNull);
  });

  // BACKEND_CHANGES B16: the server opens the auction on PATCH, so List later offers Auction.
  testWidgets('pricing: Auction sends the starting bid, length and reserve', (tester) async {
    setBoardViewport(tester, height: 1000);
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
              listingType: 'auction',
              priceCents: body['priceCents'] as int?,
              status: 'live',
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final rows = tester.widgetList<StudioSelectRow>(find.byType(StudioSelectRow)).map((r) => r.title);
    expect(rows, ['Fixed price', 'Auction']);
    await tester.tap(find.text('Auction'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).first, '360');
    await tester.enterText(find.byType(TextField).last, '1200');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('List it'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final sent = patches.single;
    expect(
      {for (final k in ['isForSale', 'listingType', 'priceCents', 'auctionDurationDays', 'reserveCents']) k: sent[k]},
      {
        'isForSale': true,
        'listingType': 'auction',
        'priceCents': 36000,
        'auctionDurationDays': 7,
        'reserveCents': 120000,
      },
    );
    expect(find.text('Bodies in Color is listed'), findsOneWidget);
    expect(find.text('Collectors can bid on it now.'), findsOneWidget);
  });

  testWidgets('relist as an auction: only Auction, filled in from the last run; relists it', (tester) async {
    setBoardViewport(tester, height: 1000);
    final relisted = <AuctionTerms>[];
    await tester.pumpWidget(
      _app(
        ListPricingPage(
          piece: const PieceSummary(id: 'p1', title: 'Quiet Hours', status: 'delisted'),
          relist: const EndedAuction(status: 'needs_seller_action', startingBidCents: 40000, reserveCents: 150000),
          quote: _founding,
          relistAuction: (id, terms) async {
            relisted.add(terms);
            return PieceSummary(id: id, title: 'Quiet Hours', isForSale: true, listingType: 'auction', status: 'live');
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Relist as an auction'), findsOneWidget);
    final rows = tester.widgetList<StudioSelectRow>(find.byType(StudioSelectRow)).map((r) => r.title);
    expect(rows, ['Auction']);
    expect(find.text(r'$400'), findsOneWidget);
    expect(find.text(r'$1,500'), findsOneWidget);
    await tester.tap(find.text('List it'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final terms = relisted.single;
    expect((terms.startingBidCents, terms.durationDays, terms.reserveCents), (40000, 7, 150000));
    expect(find.text('Quiet Hours is listed'), findsOneWidget);
  });

  testWidgets('a piece delisted by an unsold auction goes back up at a fixed price', (tester) async {
    setBoardViewport(tester);
    final patches = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      _app(
        ListPricingPage(
          piece: const PieceSummary(id: 'p1', title: 'Quiet Hours', status: 'delisted'),
          details: _details,
          quote: _founding,
          update: (id, body) async {
            patches.add(body);
            return PieceSummary(id: id, title: 'Quiet Hours', isForSale: true, status: 'live');
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), '900');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('List it'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(patches.single['status'], 'live');
    expect(patches.single['listingType'], 'fixed');
  });

  group("owner's not-for-sale piece", () {
    late AuthUser? wasUser;
    setUp(() {
      wasUser = AuthSession.instance.user;
      AuthSession.instance.user = const AuthUser(username: 'sarah', name: 'Sarah', email: 's@x.test');
    });
    tearDown(() => AuthSession.instance.user = wasUser);

    FeedPreviewItem item({String? status, int? savesCount}) => FeedPreviewItem(
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
      savesCount: savesCount,
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

    // BACKEND_CHANGES B17: "Saved by [N] people" and "[N] people saved this. They'll hear if you
    // list it." (`ListOwnerPiece`); with nobody, the bar has no info row and the line is "Not for
    // sale".
    testWidgets('saved by: the bar and the line count the people who saved it', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(PieceDetailPage(item: item(savesCount: 12))));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      final bar = tester.widget<StudioBottomBar>(find.byType(StudioBottomBar));
      expect((bar.left?.label, bar.left?.value), ('Saved by', '12 people'));
      expect(find.text("12 people saved this. They'll hear if you list it.", findRichText: true), findsOneWidget);
      expect(find.text('Not for sale'), findsNothing);

      await tester.pumpWidget(_app(PieceDetailPage(item: item(savesCount: 0))));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(tester.widget<StudioBottomBar>(find.byType(StudioBottomBar)).left, isNull);
      expect(find.text('Not for sale'), findsOneWidget);
      expect(find.textContaining('saved this'), findsNothing);
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
            // As the board: the 12 people who saved it were told (B12, B17).
            subheading: 'We let the 12 people who saved it know.',
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
