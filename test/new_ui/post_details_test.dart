import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:studio3/data/post_location_options.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/models/post_image_transform.dart';
import 'package:studio3/models/post_summary.dart';
import 'package:studio3/models/user_profile.dart';
import 'package:studio3/screens/post_create_page.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/post_publish_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/create_flow/listing_details_form.dart';
import 'package:studio3/widgets/create_flow/post_flow_widgets.dart';
import 'package:studio3/widgets/create_flow/post_result_views.dart';
import 'package:studio3/widgets/create_flow/post_review_step.dart';
import 'package:studio3/widgets/create_flow/scene_details_step.dart';
import 'package:studio3/widgets/studio/studio_button.dart';
import 'package:studio3/widgets/studio/studio_field.dart';
import 'package:studio3/widgets/studio/studio_progress_segments.dart';

import 'golden_harness.dart';

/// Phase 8: `PostDetailsForSale` / `PostDetailsProgress` / `PostNFSDetails`, `PostReview` /
/// `PostNFSReview`, `PostSuccess` / `PostNFSDone`, `PostError`, `ScenePhotoDetails` /
/// `SceneDetails`, `ScenePhotoPosted` / `ScenePosted`
/// (docs/new-ui/NEW_UI_EXECUTION_PLAN.md). Goldens: `NEW_UI_GOLDENS=1 ... --update-goldens`.
late String _photo;

const _dallas = PostLocationOption(
  id: 'dallas',
  name: 'Dallas, TX',
  subtitle: 'Texas',
  displayName: 'Dallas, TX',
);

Widget _app(Widget child, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: child,
);

const _cover = ColoredBox(color: Color(0xFF6FA3B0));

Widget _details({
  required bool forSale,
  TextEditingController? title,
  String? location,
  String? medium,
  GlobalKey<PieceDetailsStepState>? key,
  VoidCallback? onContinue,
}) => PieceDetailsStep(
  key: key,
  forSale: forSale,
  titleController: title ?? TextEditingController(),
  descriptionController: TextEditingController(),
  location: location,
  medium: medium,
  style: 'Figurative',
  materialsCount: 4,
  series: 'Bodies in Color',
  onLocation: () {},
  onMedium: () {},
  onStyle: () {},
  onMaterials: () {},
  onSeries: () {},
  onBack: () {},
  onContinue: onContinue ?? () {},
);

Finder _field(String label) =>
    find.byWidgetPredicate((w) => w is StudioUnderlineField && w.label == label);

Finder _row(String label) =>
    find.byWidgetPredicate((w) => w is PostChevronRow && w.label == label);

StudioButton _button(WidgetTester tester, String label) =>
    tester.widget<StudioButton>(find.widgetWithText(StudioButton, label));

Finder get _dots => find.byType(StudioRequiredDot);

PieceSummary _piece(String status) => PieceSummary.fromJson({
  'id': 'p1',
  'title': 'Portrait Dream',
  'mediaUrl': 'https://example.test/p.jpg',
  'isForSale': true,
  'priceCents': 360000,
  'status': status,
});

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final dir = Directory.systemTemp.createTempSync('post_details');
    final photo = img.Image(width: 300, height: 400)..clear(img.ColorRgb8(0x6F, 0xA3, 0xB0));
    _photo = (File('${dir.path}/cover.png')..writeAsBytesSync(img.encodePng(photo))).path;
  });

  group('details', () {
    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      final theme = dark ? 'dark' : 'light';
      testWidgets('for sale, empty: step 2/3, red dots, Continue off with the count ($theme)', (
        tester,
      ) async {
        setBoardViewport(tester, height: 1600);
        await tester.pumpWidget(_app(_details(forSale: true), dark: dark));
        await tester.pump();

        expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, c.background);
        final bar = tester.widget<StudioProgressSegments>(find.byType(StudioProgressSegments));
        expect((bar.current, bar.total), (2, 3));
        expect(find.text('Tell us about it'), findsOneWidget);
        expect(find.text('Fields with a red dot still need something.'), findsOneWidget);
        // Title, dimensions, weight, location, medium (framing starts as Unframed).
        expect(_dots, findsNWidgets(5));
        expect(_button(tester, 'Continue').onPressed, isNull);
        expect(find.text(' required fields left', findRichText: true), findsNothing);
        expect(
          find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == '6 required fields left',
          ),
          findsOneWidget,
        );
        expect(_row('Framing'), findsOneWidget);
        expect(_field('Weight'), findsOneWidget);
        expect(find.text('Unframed'), findsOneWidget);
        expect(
          find.text(
            'Only your city is shown. Your pickup address stays private in your payout settings.',
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('filling the required fields turns Continue on and changes the subhead', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1600);
      var continued = false;
      final key = GlobalKey<PieceDetailsStepState>();
      await tester.pumpWidget(
        _app(
          _details(
            forSale: true,
            key: key,
            location: 'Dallas, TX',
            medium: 'Oil',
            onContinue: () => continued = true,
          ),
        ),
      );
      await tester.pump();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Portrait Dream');
      await tester.enterText(fields.at(2), '24');
      await tester.enterText(fields.at(3), '36');
      await tester.pump();
      expect(find.text('Depth is needed to sell.'), findsOneWidget);
      await tester.enterText(fields.at(4), '1.5');
      await tester.enterText(fields.at(5), '8');
      await tester.pump();

      expect(_dots, findsNothing);
      expect(find.text('What collectors see on the piece page.'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      expect(continued, isTrue);

      final details = key.currentState!.buildListingDetails(priceUsd: 3600);
      expect(details.dimensionsLabel, '24 × 36 × 1.5 in');
      expect(details.weight, 8);
      expect(details.weightKg, closeTo(3.629, 0.001));
      expect(details.framingMounting, 'Unframed');
      expect(details.edition, '1 of 1');
    });

    testWidgets('not for sale: no weight or framing, "depth optional", depth not required', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1150);
      await tester.pumpWidget(
        _app(_details(forSale: false, location: 'Dallas, TX', medium: 'Oil')),
      );
      await tester.pump();
      expect(_field('Weight'), findsNothing);
      expect(_row('Framing'), findsNothing);
      expect(find.text('depth optional'), findsOneWidget);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Bodies in Color');
      await tester.enterText(fields.at(2), '24');
      await tester.enterText(fields.at(3), '36');
      await tester.pump();
      expect(_dots, findsNothing);
      expect(_button(tester, 'Continue').onPressed, isNotNull);
    });

    testWidgets('Additional details opens: year, edition 1 of 1, signed chips, notes', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1600);
      final key = GlobalKey<PieceDetailsStepState>();
      await tester.pumpWidget(_app(_details(forSale: true, key: key)));
      await tester.pump();
      await tester.tap(_row('Additional details'));
      await tester.pump();
      expect(_field('Year created'), findsOneWidget);
      expect(find.text('1 of 1'), findsOneWidget);
      await tester.tap(find.text('Yes'));
      await tester.pump();
      expect(key.currentState!.buildListingDetails().signed, isTrue);
      await tester.tap(find.text('Yes'));
      await tester.pump();
      expect(key.currentState!.buildListingDetails().signed, isNull);
      expect(_field('Handling notes'), findsOneWidget);
    });

    testWidgets('Framing opens a sheet of options', (tester) async {
      setBoardViewport(tester, height: 1600);
      final key = GlobalKey<PieceDetailsStepState>();
      await tester.pumpWidget(_app(_details(forSale: true, key: key)));
      await tester.pump();
      await tester.tap(_row('Framing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ready to hang'));
      await tester.pumpAndSettle();
      expect(key.currentState!.buildListingDetails().framingMounting, 'Ready to hang');
    });

    testWidgets('unit cells flip in ↔ cm and lb ↔ kg', (tester) async {
      setBoardViewport(tester, height: 1600);
      final key = GlobalKey<PieceDetailsStepState>();
      await tester.pumpWidget(_app(_details(forSale: true, key: key)));
      await tester.pump();
      await tester.tap(find.text('in'));
      await tester.tap(find.text('lb'));
      await tester.pump();
      final d = key.currentState!.buildListingDetails();
      expect((d.dimensionUnit, d.weightUnit), ('cm', 'kg'));
    });
  });

  group('review, publish, results', () {
    late bool wasSeller;
    late AuthUser? wasUser;
    setUp(() {
      wasSeller = AuthSession.instance.sellerEnabled;
      wasUser = AuthSession.instance.user;
      AuthSession.instance.user = const AuthUser(
        username: 'sarah',
        name: 'Sarah Osmei',
        email: 's@example.test',
      );
    });
    tearDown(() {
      AuthSession.instance.sellerEnabled = wasSeller;
      AuthSession.instance.user = wasUser;
    });

    Widget page(PostPublisher publisher, {bool seller = true}) {
      AuthSession.instance.sellerEnabled = seller;
      return _app(
        PostCreatePage(
          postType: 'piece',
          imagePaths: [_photo, _photo],
          transforms: [PostImageTransform(), PostImageTransform()],
          previewImageIndex: 0,
          onClose: () {},
          onEdit: () {},
          commissionQuote: (cents) async => CommissionQuote(
            priceCents: cents,
            netCents: cents * 85 ~/ 100,
            commissionBps: 1500,
            reducedRate: true,
          ),
          publisher: publisher,
          debugLocation: _dallas,
          debugMediumIds: const ['oil'],
        ),
      );
    }

    Future<void> toReview(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).first, '3600');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Portrait Dream');
      await tester.enterText(fields.at(2), '24');
      await tester.enterText(fields.at(3), '36');
      await tester.enterText(fields.at(4), '1.5');
      await tester.enterText(fields.at(5), '8');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('review: 3/3, cards with the entered values, Publish → live screen', (
      tester,
    ) async {
      setBoardViewport(tester, height: 900);
      final calls = <String>[];
      PostDraft? sent;
      await tester.pumpWidget(
        page(
          PostPublisher(
            saveDraft: (d) async {
              calls.add('draft');
              sent = d;
              return _piece('draft');
            },
            goLive: (id) async {
              calls.add('live:$id');
              return _piece('live');
            },
            postScene: (_) async => throw UnimplementedError(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await toReview(tester);

      final bar = tester.widget<StudioProgressSegments>(find.byType(StudioProgressSegments));
      expect(bar.current, 3);
      expect(find.text('Look it over'), findsOneWidget);
      expect(find.text("You can edit anything after it's live."), findsOneWidget);
      expect(find.text('Portrait Dream'), findsOneWidget);
      expect(find.text('2 photos'), findsOneWidget);
      for (final v in [
        'Fixed price',
        r'$3,600',
        r'$3,060',
        '24 × 36 × 1.5 in',
        '8 lb',
        'Unframed',
        'Dallas, TX',
        'Oil',
      ]) {
        expect(find.text(v), findsOneWidget, reason: v);
      }

      await tester.tap(find.text('Publish'));
      await tester.pump();
      await tester.pump();
      expect(calls, ['draft', 'live:p1']);
      expect(sent!.isForSale, isTrue);
      expect(sent!.imagePaths, hasLength(2));
      expect(sent!.mediumIds, ['oil']);
      expect(sent!.listingDetails!.priceCents, 360000);

      expect(find.byType(PostPublishedView), findsOneWidget);
      expect(find.text('Portrait Dream is live'), findsOneWidget);
      expect(find.text("Here's how collectors see it in the feed."), findsOneWidget);
      expect(find.text('Sarah Osmei'), findsOneWidget);
      expect(find.text(r'$3,600'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Add a Scene from the studio'), findsOneWidget);
      expect(find.text('Share your piece'), findsOneWidget);
      expect(find.text('View piece'), findsOneWidget);
    });

    testWidgets('publish fails after the draft saved: "Saved as draft", retry only goes live', (
      tester,
    ) async {
      setBoardViewport(tester, height: 900);
      final calls = <String>[];
      var fail = true;
      await tester.pumpWidget(
        page(
          PostPublisher(
            saveDraft: (_) async {
              calls.add('draft');
              return _piece('draft');
            },
            goLive: (id) async {
              calls.add('live');
              if (fail) throw Exception('offline');
              return _piece('live');
            },
            postScene: (_) async => throw UnimplementedError(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await toReview(tester);
      await tester.tap(find.text('Publish'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(PostErrorView), findsOneWidget);
      expect(find.text("Couldn't publish"), findsOneWidget);
      expect(find.textContaining('Saved as draft · '), findsOneWidget);
      expect(find.text('Go to drafts'), findsOneWidget);
      expect(find.text('!'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(calls, ['draft', 'live', 'live']);
      expect(find.text('Portrait Dream is live'), findsOneWidget);
    });

    testWidgets('nothing saved: no draft line, no Go to drafts', (tester) async {
      setBoardViewport(tester, height: 900);
      await tester.pumpWidget(
        page(
          PostPublisher(
            saveDraft: (_) async => throw Exception('offline'),
            goLive: (_) async => throw UnimplementedError(),
            postScene: (_) async => throw UnimplementedError(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await toReview(tester);
      await tester.tap(find.text('Publish'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(PostErrorView), findsOneWidget);
      expect(find.textContaining('Saved as draft'), findsNothing);
      expect(find.text('Go to drafts'), findsNothing);
    });

    testWidgets('not for sale: review says so; published card shows Not for sale', (
      tester,
    ) async {
      setBoardViewport(tester, height: 900);
      await tester.pumpWidget(
        page(
          PostPublisher(
            saveDraft: (_) async => _piece('draft'),
            goLive: (_) async => _piece('live'),
            postScene: (_) async => throw UnimplementedError(),
          ),
          seller: false,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Bodies in Color');
      await tester.enterText(fields.at(2), '24');
      await tester.enterText(fields.at(3), '36');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(
        find.text('You can list it for sale anytime from the piece page.'),
        findsOneWidget,
      );
      expect(find.text('Not for sale'), findsOneWidget);
      expect(find.text('24 × 36 in'), findsOneWidget);
      expect(find.text('8 lb'), findsNothing);
      await tester.tap(find.text('Publish'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Not for sale'), findsOneWidget);
      expect(find.text('Available'), findsNothing);
    });
  });

  group('scenes', () {
    late AuthUser? wasUser;
    setUp(() {
      wasUser = AuthSession.instance.user;
      AuthSession.instance.user = const AuthUser(
        username: 'sarah',
        name: 'Sarah Osmei',
        email: 's@example.test',
      );
    });
    tearDown(() => AuthSession.instance.user = wasUser);

    for (final dark in [false, true]) {
      testWidgets('details: preview, caption optional, linked tiles, Post on at once (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        setBoardViewport(tester);
        final unlinked = <String>[];
        await tester.pumpWidget(
          _app(
            SceneDetailsStep(
              preview: _cover,
              captionController: TextEditingController(),
              linkedPieces: const [
                SceneLinkedPiece(id: 'a', title: 'Bodies in Color'),
                SceneLinkedPiece(id: 'b', title: 'Companion Bloom'),
              ],
              location: null,
              onBack: () {},
              onLinkPiece: () {},
              onUnlink: (p) => unlinked.add(p.id),
              onLocation: () {},
              onPost: () {},
            ),
            dark: dark,
          ),
        );
        await tester.pump();
        expect(find.byType(StudioProgressSegments), findsNothing);
        expect(find.text('Linked pieces'), findsOneWidget);
        expect(find.text('Bodies in Color'), findsOneWidget);
        expect(find.bySemanticsLabel('Link a piece'), findsOneWidget);
        expect(find.text('Add a city'), findsOneWidget);
        expect(find.text('Optional. Only a city is ever shown.'), findsOneWidget);
        expect(_button(tester, 'Post').onPressed, isNotNull);
        await tester.tap(find.bySemanticsLabel('Unlink Companion Bloom'));
        expect(unlinked, ['b']);
      });
    }

    testWidgets('a video shows its length on the preview', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          SceneDetailsStep(
            preview: _cover,
            videoLength: '0:42',
            captionController: TextEditingController(),
            linkedPieces: const [],
            location: 'Dallas, TX',
            onBack: () {},
            onLinkPiece: () {},
            onUnlink: (_) {},
            onLocation: () {},
            onPost: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('0:42'), findsOneWidget);
      expect(find.text('Dallas, TX'), findsOneWidget);
    });

    testWidgets('pre-linked Scene posts with the link, then "Now showing on 1 piece"', (
      tester,
    ) async {
      setBoardViewport(tester);
      PostDraft? sent;
      await tester.pumpWidget(
        _app(
          PostCreatePage(
            postType: 'scene',
            imagePaths: [_photo],
            transforms: [PostImageTransform()],
            previewImageIndex: 0,
            onClose: () {},
            initialLinkedPiece: const ScenePostArgs(pieceId: 'p1', pieceTitle: 'Portrait Dream'),
            publisher: PostPublisher(
              saveDraft: (_) async => throw UnimplementedError(),
              goLive: (_) async => throw UnimplementedError(),
              postScene: (d) async {
                sent = d;
                return const PostSummary(id: 's1');
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Portrait Dream'), findsOneWidget);
      await tester.tap(find.text('Post'));
      await tester.pump();
      await tester.pump();
      expect(sent!.linkedPieceIds, ['p1']);
      expect(find.byType(SceneLiveView), findsOneWidget);
      expect(find.text('Your Scene is live'), findsOneWidget);
      expect(find.text('Now showing on 1 piece'), findsOneWidget);
      expect(find.text('Share your Scene'), findsOneWidget);
      expect(find.text('View Scene'), findsOneWidget);
    });

    testWidgets('a Scene that fails says so and offers Try again only', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          PostCreatePage(
            postType: 'scene',
            imagePaths: [_photo],
            transforms: [PostImageTransform()],
            previewImageIndex: 0,
            onClose: () {},
            publisher: PostPublisher(
              saveDraft: (_) async => throw UnimplementedError(),
              goLive: (_) async => throw UnimplementedError(),
              postScene: (_) async => throw Exception('offline'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Post'));
      await tester.pump();
      await tester.pump();
      expect(find.text("Couldn't post"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Go to drafts'), findsNothing);
    });
  });

  testWidgets('375 wide at text scale 1.4: details, review and results do not overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget scaled(Widget w) => MediaQuery(
      data: const MediaQueryData(size: Size(375, 667), textScaler: TextScaler.linear(1.4)),
      child: _app(w),
    );
    for (final w in <Widget>[
      _details(forSale: true),
      PostReviewStep(
        cover: _cover,
        title: 'Portrait Dream',
        photoCount: 4,
        forSale: true,
        availabilityRows: const [PostReviewRow('Selling', 'Fixed price')],
        detailRows: const [PostReviewRow('Size', '24 × 36 × 1.5 in', mono: true)],
        onBack: () {},
        onEditPhotos: () {},
        onEditAvailability: () {},
        onEditDetails: () {},
        onPublish: () {},
      ),
      PostPublishedView(
        title: 'Portrait Dream',
        cover: _cover,
        photoCount: 4,
        authorName: 'Sarah Osmei',
        avatarUrl: null,
        priceLabel: r'$3,600',
        onClose: () {},
        onAddScene: () {},
        onShare: () {},
        onView: () {},
      ),
      PostErrorView(
        isScene: false,
        savedAt: DateTime(2026, 10, 23, 16, 12),
        onClose: () {},
        onRetry: () {},
        onDrafts: () {},
      ),
    ]) {
      await tester.pumpWidget(scaled(w));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  group('goldens', () {
    final skip = Platform.environment['NEW_UI_GOLDENS'] != '1';

    testWidgets('PostDetailsProgress', (tester) async {
      setBoardViewport(tester, height: 1600);
      final key = GlobalKey<PieceDetailsStepState>();
      await tester.pumpWidget(
        _app(
          _details(
            forSale: true,
            key: key,
            title: TextEditingController(text: 'Portrait Dream'),
          ),
        ),
      );
      await tester.pump();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(2), '24');
      await tester.enterText(fields.at(3), '36');
      await tester.tap(find.text('Additional details'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(6), '2025');
      await tester.tap(find.text('Yes'));
      await tester.pump(const Duration(milliseconds: 400));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/PostDetailsProgress.png'),
      );
    }, skip: skip);

    testWidgets('PostReview', (tester) async {
      setBoardViewport(tester, height: 900);
      await tester.pumpWidget(
        _app(
          PostReviewStep(
            cover: _cover,
            title: 'Portrait Dream',
            photoCount: 4,
            forSale: true,
            availabilityRows: const [
              PostReviewRow('Selling', 'Fixed price'),
              PostReviewRow('Price', r'$3,600', small: true),
              PostReviewRow('You receive', r'$3,060', small: true),
            ],
            detailRows: const [
              PostReviewRow('Size', '24 × 36 × 1.5 in', mono: true),
              PostReviewRow('Weight', '8 lb', mono: true),
              PostReviewRow('Framing', 'Unframed'),
              PostReviewRow('Location', 'Dallas, TX'),
              PostReviewRow('Medium', 'Oil'),
              PostReviewRow('Series', 'Bodies in Color'),
            ],
            onBack: () {},
            onEditPhotos: () {},
            onEditAvailability: () {},
            onEditDetails: () {},
            onPublish: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/PostReview.png'));
    }, skip: skip);

    testWidgets('PostSuccess', (tester) async {
      setBoardViewport(tester);
      debugDisableShadows = false;
      await tester.pumpWidget(
        _app(
          PostPublishedView(
            title: 'Portrait Dream',
            cover: const SizedBox(width: 342, height: 300, child: _cover),
            photoCount: 4,
            authorName: 'Sarah Osmei',
            avatarUrl: null,
            priceLabel: r'$3,600',
            onClose: () {},
            onAddScene: () {},
            onShare: () {},
            onView: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/PostSuccess.png'));
      debugDisableShadows = true;
    }, skip: skip);

    testWidgets('PostError', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          PostErrorView(
            isScene: false,
            savedAt: DateTime(2026, 10, 23, 16, 12),
            onClose: () {},
            onRetry: () {},
            onDrafts: () {},
          ),
        ),
      );
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/PostError.png'));
    }, skip: skip);

    testWidgets('ScenePhotoDetails', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          SceneDetailsStep(
            preview: const SizedBox(
              width: 96,
              height: 170,
              child: ColoredBox(color: Color(0xFF3A3632)),
            ),
            captionController: TextEditingController(),
            linkedPieces: const [
              SceneLinkedPiece(id: 'a', title: 'Bodies in Color'),
              SceneLinkedPiece(id: 'b', title: 'Companion Bloom'),
            ],
            location: null,
            onBack: () {},
            onLinkPiece: () {},
            onUnlink: (_) {},
            onLocation: () {},
            onPost: () {},
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/ScenePhotoDetails.png'),
      );
    }, skip: skip);

    testWidgets('ScenePhotoPosted', (tester) async {
      setBoardViewport(tester);
      debugDisableShadows = false;
      await tester.pumpWidget(
        _app(
          SceneLiveView(
            preview: const SizedBox(
              width: 240,
              height: 427,
              child: ColoredBox(color: Color(0xFF3A3632)),
            ),
            isVideo: false,
            authorName: 'Sarah Osmei',
            avatarUrl: null,
            linkedPieces: const [
              LinkedPieceThumb(title: 'Bodies in Color'),
              LinkedPieceThumb(title: 'Companion Bloom'),
            ],
            onClose: () {},
            onShare: () {},
            onView: () {},
            onLinked: () {},
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/ScenePhotoPosted.png'),
      );
      debugDisableShadows = true;
    }, skip: skip);
  });
}
