import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/feed_item.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/models/post_summary.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/available_piece_detail_page.dart';
import 'package:studio3/screens/behind_the_work_page.dart';
import 'package:studio3/screens/drafts_page.dart';
import 'package:studio3/screens/edit_profile_page.dart';
import 'package:studio3/screens/event_detail_page.dart';
import 'package:studio3/screens/forgot_password_page.dart';
import 'package:studio3/screens/login_page.dart';
import 'package:studio3/screens/login_password_page.dart';
import 'package:studio3/screens/post_page.dart';
import 'package:studio3/screens/seller/seller_setup_flow.dart';
import 'package:studio3/screens/series_view_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/cache_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/events/event_waitlist_sheets.dart';
import 'package:studio3/widgets/piece_detail/piece_comment_sheet.dart';
import 'package:studio3/widgets/post_gallery/post_gallery_picker.dart';
import 'package:studio3/widgets/post_share_type_sheet.dart';
import 'package:studio3/widgets/reels/reel_overlay.dart';
import 'package:studio3/widgets/reels/reel_player_page.dart';

import 'golden_harness.dart';

/// Section 19.1 acceptance checks, run over every screen built in Phase 13
/// (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 17), each in light and dark:
///
/// * 390 × 844 light and dark: tap targets at least 44 × 44 and every tappable thing labelled
///   (Flutter's own accessibility guidelines), and every piece of text drawn in a theme colour
///   token (or white / Ink on a picture), so its contrast is the token's: see the token test at
///   the bottom. Flutter's pixel contrast check is not used: it reads thin 11–12 px text below
///   its real contrast (dark tertiary on Surface measured 2.55 where the colours give 5.2);
/// * 375 × 667 (SE) at text scale 1.4, 390 × 844 at 2.0 (the largest the screens are held
///   to) and 440 × 956 (Pro Max) in dark: nothing overflows;
/// * reduced motion on throughout: once settled, nothing keeps animating.
///
/// The phases before 13 ran the same checks in their own QA tests.

const _user = {'id': 'u1', 'username': 'jordanlee', 'name': 'Jordan Lee', 'email': 'jordan@email.com'};

Map<String, dynamic> _piece(String id, String title, Map<String, dynamic> extra) => {
  'id': id,
  'title': title,
  'mediaUrl': '',
  'createdAt': '2026-10-20T10:00:00Z',
  'author': {'username': 'amarasart', 'name': 'Amara Osei'},
  ...extra,
};

class _Fake implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    final now = DateTime.now().toUtc();
    Object? data;
    switch ('${options.method} $path') {
      case 'GET /api/user/me':
        data = {..._user, 'bio': 'Painter in Dallas.', 'location': 'Dallas, TX'};
      case 'GET /api/users/jordanlee/pieces':
        data = [
          _piece('d1', 'Portrait Dream', {'status': 'draft', 'medium': 'Oil', 'dimensions': '24x36 in'}),
          _piece('d2', 'Night Studies II', {'status': 'draft', 'medium': 'Ink', 'isForSale': true}),
        ];
      case 'GET /api/artists/connect/status':
        data = {'onboarded': false, 'canListForSale': false, 'requirementsDue': <String>[]};
      case 'GET /api/pieces/p1':
        data = _piece('p1', 'Bodies in Color I', {
          'status': 'sold',
          'isForSale': true,
          'priceCents': 350000,
          'listingState': 'collected',
          'medium': 'Oil on canvas',
          'caption': 'Started this one trying to paint skin as light rather than surface.',
          'materials': ['Oil paint', 'Linen canvas'],
        });
      case 'GET /api/pieces/p2':
        data = _piece('p2', 'Bodies in Color II', {'status': 'live'});
      case 'GET /api/user/me/orders':
        data = {
          'items': [
            {
              'id': 'o1',
              'status': 'shipped',
              'items': [
                {'pieceId': 'p1', 'priceCents': 350000},
              ],
              'shipment': {'courier': 'Convelio', 'trackingNumber': 'CV1', 'status': 'in_transit'},
              'createdAt': '2026-11-01T10:00:00Z',
            },
          ],
          'nextCursor': null,
        };
      case 'GET /api/series/s1':
        data = {
          'id': 's1',
          'name': 'Bodies in Color',
          'description': 'A study of skin under colored light.',
          'pieceIds': ['p1', 'p2', 'p3'],
          'pieces': [
            _piece('p1', 'Bodies in Color I', {'status': 'live', 'isForSale': true, 'priceCents': 350000, 'listingState': 'available'}),
            _piece('p2', 'Bodies in Color II', {'status': 'sold', 'isForSale': true, 'listingState': 'collected'}),
            _piece('p3', 'Bodies in Color IV', {
              'status': 'live',
              'isForSale': true,
              'listingType': 'auction',
              'listingState': 'auction_live',
              'highestBidCents': 130000,
              'auctionEndsAt': now.add(const Duration(hours: 6)).toIso8601String(),
            }),
          ],
          'author': {'username': 'amarasart', 'name': 'Amara Osei'},
        };
      case 'GET /api/users/amarasart/posts':
        data = [
          {'type': 'post', 'id': 'sc1', 'mediaUrl': '', 'mediaType': 'video', 'linkedPieceIds': ['p1']},
        ];
      case 'GET /api/user/amarasart':
        data = {'username': 'amarasart', 'name': 'Amara Osei', 'isFollowing': false};
      case 'GET /api/feed/explore':
        data = {'items': <Object>[], 'nextCursor': null};
      case 'GET /api/posts/s1/comments':
        data = {
          'items': [
            {
              'id': 'c1',
              'body': 'The teal underneath makes the whole thing glow.',
              'user': {'username': 'jordan', 'name': 'Jordan Lee'},
              'createdAt': now.subtract(const Duration(hours: 2)).toIso8601String(),
            },
            {
              'id': 'c2',
              'body': '@Jordan Lee around nine.',
              'user': {'username': 'amara', 'name': 'Amara Osei'},
              'createdAt': now.subtract(const Duration(hours: 1)).toIso8601String(),
            },
          ],
          'nextCursor': null,
        };
    }
    return ResponseBody.fromString(
      jsonEncode(data == null ? {'success': false, 'message': 'no route'} : {'success': true, 'data': data}),
      data == null ? 404 : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Opens a sheet as soon as it is on screen, so nothing else sits under the checks.
class _AutoOpen extends StatefulWidget {
  const _AutoOpen(this.open);

  final Future<Object?> Function(BuildContext context) open;

  @override
  State<_AutoOpen> createState() => _AutoOpenState();
}

class _AutoOpenState extends State<_AutoOpen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.open(context);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}

const _ga = EventTicketType(id: 'ga', name: 'General Admission', includes: 'Open to everyone', left: 0, perOrderLimit: 4);
const _vip = EventTicketType(id: 'vip', name: 'VIP', priceCents: 2500, includes: 'Early entry', left: 0, perOrderLimit: 2);

StudioEvent _event(EventWaitlist waitlist) => StudioEvent(
  id: 'ev1',
  title: 'Inside the Mind of an Artist',
  startsAt: DateTime(2037, 11, 21, 20),
  endsAt: DateTime(2037, 11, 21, 22),
  venueName: 'Dec on Dragon',
  address: '1414 Dragon St, Dallas, TX 75201',
  hostUsername: 'amara',
  hostName: 'Amara Osei',
  isFull: true,
  spotsLeft: 0,
  description: 'An evening inside the studio.',
  ticketTypes: const [_ga, _vip],
  waitlist: waitlist,
);

final _held = EventWaitlist(
  open: true,
  wanted: const {'ga': 1, 'vip': 2},
  held: const {'vip': 2},
  heldUntil: DateTime(2037, 11, 21, 18),
);

FeedItem _scene({bool video = true, List<String> linked = const ['p1']}) => FeedItem.post(
  PostSummary(
    id: 's1',
    caption: 'Late night layering on Bodies in Color. The teal came first.',
    mediaType: video ? 'video' : 'image',
    mediaAspectRatio: video ? null : '3:2',
    authorName: 'Amara Osei',
    authorUsername: 'amara',
    commentCount: 18,
    saveCount: 214,
    linkedPieceIds: linked,
    linkedPiece: linked.length == 1
        ? PieceSummary.fromJson(_piece('p1', 'Bodies in Color', {'isForSale': true, 'priceCents': 350000}))
        : null,
  ),
);

FeedPreviewItem _soldPiece() => FeedPreviewItem(
  id: 'p1',
  imageSeeds: const [1],
  title: 'Bodies in Color I',
  medium: 'Oil on canvas',
  year: 2025,
  dimensions: '24 × 36 in',
  story: 'Started this one trying to paint skin as light rather than surface.',
  handle: '@amarasart',
  authorUsername: 'amarasart',
  isAvailable: true,
  aspectRatio: FeedAspectRatio.portrait3x4,
  authorName: 'Amara Osei',
  priceCents: 350000,
  status: 'sold',
  materials: const ['Oil paint', 'Linen canvas'],
);

/// Every Phase 13 screen, as it is reached.
final Map<String, Widget Function()> _screens = {
  'PostCreate': () => _AutoOpen((context) => PostShareTypeSheet.show(context)),
  'PostPicker': () => Scaffold(
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PostPickerHeader(title: 'New piece', albumName: 'Recents', onClose: () {}, onNext: () {}, onAlbum: () {}, countLabel: '2 of 4 selected'),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: [
                for (var i = 0; i < 9; i++)
                  PostGalleryCell(number: i == 0 ? 1 : null, onTap: () {}, child: const ColoredBox(color: Color(0xFF6FA3B0))),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
  'Drafts': () => const DraftsPage(),
  'SellerPrompt': () => _AutoOpen((context) => showSellerPrompt(context)),
  'SellerIntro': () => _AutoOpen((context) => SellerSetupPage.start(context)),
  'SignInFirst': () => const LoginPage(),
  'LoginPassword': () => const LoginPasswordPage(email: 'jordan@email.com'),
  'LoginReset': () => const ForgotPasswordPage(email: 'jordan@email.com'),
  'EditProfile': () => _AutoOpen(
    (context) => Navigator.push<Object?>(context, MaterialPageRoute<Object?>(builder: (_) => const EditProfilePage())),
  ),
  'SceneViewer': () => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF3A3632)),
        ReelOverlay(item: _scene(), soundOn: false, onToggleSound: () {}, progress: ValueNotifier(0.4)),
      ],
    ),
  ),
  'SceneViewerPhoto': () => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        ScenePhotos(
          urls: const ['a', 'b'],
          aspectRatio: 1.5,
          pageBuilder: (context, i) => const ColoredBox(color: Color(0xFF3A3632)),
        ),
        ReelOverlay(item: _scene(video: false, linked: const ['p1', 'p2'])),
      ],
    ),
  ),
  'ScenePiecesSheet': () => _AutoOpen(
    (context) => ScenePiecesSheet.show(
      context,
      pieces: [
        PieceSummary.fromJson(_piece('p1', 'Bodies in Color', {'isForSale': true, 'priceCents': 350000})),
        PieceSummary.fromJson(_piece('p2', 'Bodies in Color II', {})),
      ],
    ),
  ),
  'SceneComments': () => _AutoOpen(
    (context) => PieceCommentSheet.show(
      context,
      contentId: 's1',
      isScene: true,
      commentCount: 18,
      artistUsername: 'amara',
      overMedia: true,
    ),
  ),
  'PieceCollected': () => AvailablePieceDetailPage(item: _soldPiece()),
  'SeriesPage': () => const SeriesViewPage(seriesId: 's1'),
  'BehindTheWork': () => BehindTheWorkPage(
    initialItems: [
      for (final name in ['Amara Osei', 'Cedric Okafor', 'Daisy Smith', 'Jordan Lee'])
        FeedItem.post(PostSummary(id: name, mediaType: 'video', authorName: name, authorUsername: name.toLowerCase())),
    ],
  ),
  'EvSoldOut': () {
    final e = _event(const EventWaitlist(open: true));
    return EventDetailPage(event: e, debugDetail: e);
  },
  'EvWaitlistJoin': () => _AutoOpen((context) => EventWaitlistJoinSheet.show(context, _event(const EventWaitlist(open: true)))),
  'EvWaitlistHeld': () => _AutoOpen(
    (context) => EventWaitlistHeldSheet.show(context, _event(_held), now: () => DateTime(2037, 11, 21, 16)),
  ),
};

/// Screens that keep moving with reduced motion for a reason (see the check).
const _moving = {'EvWaitlistHeld'};

/// Every colour text is drawn in on screen.
Iterable<Color> _textColours(WidgetTester tester) sync* {
  for (final paragraph in tester.allRenderObjects.whereType<RenderParagraph>()) {
    final colours = <Color>[];
    paragraph.text.visitChildren((span) {
      final colour = span.style?.color;
      if (colour != null) colours.add(colour);
      return true;
    });
    yield* colours;
  }
}

/// A theme token, or white / Ink at any opacity (text and marks on a picture or the dark viewer).
bool _allowed(StudioColors c, Color colour) {
  final tokens = [
    c.background, c.surface, c.card, c.line, c.lineStrong, c.textPrimary, c.textBody, c.textSecondary,
    c.textTertiary, c.textPlaceholder, c.buttonFill, c.buttonText, c.buttonDisabledFill,
    c.buttonDisabledText, c.navActive, c.navIconActive, c.navIconInactive, c.available, c.positive,
    c.alert, c.tooltipText, StudioColors.ink, StudioColors.galleryWhite, StudioColors.onDarkSecondary,
  ];
  if (tokens.contains(colour)) return true;
  final rgb = colour.toARGB32() & 0xFFFFFF;
  return rgb == 0xFFFFFF || rgb == 0xFAFAF8 || rgb == 0x111111 || rgb == 0x000000;
}

/// WCAG relative luminance contrast.
double _contrast(Color a, Color b) {
  double l(Color c) => c.computeLuminance();
  final hi = l(a) > l(b) ? l(a) : l(b);
  final lo = l(a) > l(b) ? l(b) : l(a);
  return (hi + 0.05) / (lo + 0.05);
}

class _Config {
  const _Config(this.name, this.size, {this.dark = false, this.textScale = 1.0, this.guidelines = false});

  final String name;
  final Size size;
  final bool dark;
  final double textScale;

  /// Tap targets, labels and contrast (at the standard size and text).
  final bool guidelines;
}

const _configs = [
  _Config('390 light', Size(390, 844), guidelines: true),
  _Config('390 dark', Size(390, 844), dark: true, guidelines: true),
  _Config('375 light, text 1.4', Size(375, 667), textScale: 1.4),
  _Config('390 dark, text 2.0', Size(390, 844), dark: true, textScale: 2.0),
  _Config('440 dark', Size(440, 956), dark: true),
];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async {
    await loadStudioFonts();
    dotenv.loadFromString(envString: '', isOptional: true);
    final tmp = Directory.systemTemp.createTempSync('acceptance').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  late AuthUser? wasUser;
  late String? wasToken;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheService.instance.clearAll();
    ApiClient.instance.debugUseAdapter(_Fake());
    wasUser = AuthSession.instance.user;
    wasToken = AuthSession.instance.accessToken;
    AuthSession.instance.user = AuthUser.fromJson(_user);
    AuthSession.instance.accessToken = 'token';
  });
  tearDown(() {
    AuthSession.instance.user = wasUser;
    AuthSession.instance.accessToken = wasToken;
  });

  for (final screen in _screens.entries) {
    for (final config in _configs) {
      testWidgets('${screen.key} · ${config.name}', (tester) async {
        final handle = tester.ensureSemantics();
        try {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = config.size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: config.dark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(config.textScale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: _screens[screen.key]!(),
          ),
        );
        await _settle(tester);

        // Nothing overflows or throws.
        expect(tester.takeException(), isNull);

        if (config.guidelines) {
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          final palette = config.dark ? StudioColors.dark : StudioColors.light;
          final offPalette = _textColours(tester).where((colour) => !_allowed(palette, colour)).toSet();
          expect(offPalette, isEmpty, reason: 'text in colours outside the theme tokens');
        }

        // Reduced motion: settled means still (the held sheet's countdown ticks once a second).
        if (!_moving.contains(screen.key)) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.binding.hasScheduledFrame, isFalse, reason: 'still animating with reduced motion');
        }

        } finally {
          handle.dispose();
        }
        // Let the image cache's cleanup timer run out.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 11));
      });
    }
  }

  // Text contrast in both themes, from the tokens. Text on the page, on Surface and on Card:
  // primary, body, secondary, tertiary and the status colours reach 4.5:1 in both themes (light
  // tertiary darkened to #6D6D6D on 2026-10-28). Placeholder (hints, disabled) is the boards'.
  test('token contrast', () {
    for (final (name, c) in [('light', StudioColors.light), ('dark', StudioColors.dark)]) {
      final grounds = [c.background, c.surface, c.card];
      final text = {
        'primary': c.textPrimary,
        'body': c.textBody,
        'secondary': c.textSecondary,
        'alert': c.alert,
        'positive': c.positive,
        'tertiary': c.textTertiary,
      };
      for (final entry in text.entries) {
        for (final ground in grounds) {
          expect(_contrast(entry.value, ground), greaterThanOrEqualTo(4.5), reason: '$name ${entry.key}');
        }
      }
      // The button's own text on its fill.
      expect(_contrast(c.buttonText, c.buttonFill), greaterThanOrEqualTo(4.5), reason: '$name button');
    }
  });
}
