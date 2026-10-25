import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:studio3/data/post_location_options.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/post_image_transform.dart';
import 'package:studio3/screens/post_create_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/utils/crop_cover_math.dart';
import 'package:studio3/utils/post_image_renderer.dart';
import 'package:studio3/widgets/create_flow/post_result_views.dart';

import 'golden_harness.dart';

/// End to end through the real posting code: `PostCreatePage` → `PostPublishService` →
/// `MediaService` / `PieceService` / `PostService` → `ApiClient`, with a fake server in
/// place of the network that records every request. Photos are real PNG files rendered by
/// the real `PostImageRenderer`.
class _FakeServer implements HttpClientAdapter {
  final requests = <({String method, String path, Map<String, dynamic>? body})>[];

  /// Paths that answer 500, to make a step fail.
  final failing = <String>{};
  var _uploads = 0;

  Iterable<Map<String, dynamic>?> bodies(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).map((r) => r.body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : null;
    requests.add((method: options.method, path: path, body: body));
    if (failing.contains('${options.method} $path')) {
      return _json({'success': false, 'message': 'offline'}, 500);
    }
    Object? data;
    switch ('${options.method} $path') {
      case 'POST /api/media/presign':
        _uploads++;
        data = {'url': 'https://cdn.test/sarah/${body!['purpose']}/$_uploads', 'devMode': true};
      case 'POST /api/pieces':
        data = {...body!, 'id': 'p1', 'mediaUrl': body['mediaUrl'], 'status': body['status']};
      case 'PATCH /api/pieces/p1':
        final created = bodies('POST', '/api/pieces').first!;
        data = {...created, 'id': 'p1', 'status': body!['status']};
      case 'POST /api/posts':
        data = {...body!, 'id': 's1'};
      case 'GET /api/users/sarah/posts':
        data = [
          {
            'id': 's9',
            'mediaType': 'image',
            'status': 'live',
            'linkedPieceIds': ['old'],
          },
        ];
      case 'PATCH /api/posts/s9':
        data = {'id': 's9', ...body!};
      case 'GET /api/user/me/commission-quote':
        final cents = int.parse(options.uri.queryParameters['priceCents']!);
        data = {'priceCents': cents, 'netCents': cents * 80 ~/ 100, 'commissionBps': 2000};
      default:
        return _json({'success': false, 'message': 'no route $path'}, 404);
    }
    return _json({'success': true, 'data': data}, 200);
  }

  ResponseBody _json(Object json, int status) => ResponseBody.fromString(
    jsonEncode(json),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}

late String _landscape;
late String _portrait;
late String _clip;
late _FakeServer _server;

const _dallas = PostLocationOption(
  id: 'dallas',
  name: 'Dallas, TX',
  subtitle: 'United States',
  displayName: 'Dallas, TX, United States',
);

Future<String> _png(Directory dir, String name, int w, int h, img.Color color) async {
  final image = img.Image(width: w, height: h)..clear(color);
  return (File('${dir.path}/$name.png')..writeAsBytesSync(img.encodePng(image))).path;
}

Widget _page(PostCreatePage page) =>
    MaterialApp(theme: AppTheme.light, home: page);

/// Taps [label] in the real event loop, so the publish it starts (file reads, image
/// encoding, the fake server) actually runs, then lets it finish.
Future<void> _tapAndRun(WidgetTester tester, String label, {int ms = 2500}) async {
  await tester.runAsync(() async {
    await tester.tap(find.text(label));
    await Future<void>.delayed(Duration(milliseconds: ms));
  });
  await tester.pump();
  await tester.pump();
}

/// Lets file reads, image codecs and the fake server finish (they need the real event loop).
Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
  }
}

Future<void> _type(WidgetTester tester, int field, String text) async {
  await tester.enterText(find.byType(TextField).at(field), text);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final dir = Directory.systemTemp.createTempSync('post_e2e');
    _landscape = await _png(dir, 'landscape', 400, 300, img.ColorRgb8(120, 120, 120));
    _portrait = await _png(dir, 'portrait', 300, 400, img.ColorRgb8(60, 90, 120));
    _clip = (File('${dir.path}/clip.mp4')..writeAsBytesSync(List.filled(2048, 7))).path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
  });

  late bool wasSeller;
  late AuthUser? wasUser;
  late String? wasToken;
  setUp(() {
    _server = _FakeServer();
    ApiClient.instance.debugUseAdapter(_server);
    wasSeller = AuthSession.instance.sellerEnabled;
    wasUser = AuthSession.instance.user;
    wasToken = AuthSession.instance.accessToken;
    AuthSession.instance.user = const AuthUser(
      username: 'sarah',
      name: 'Sarah Osmei',
      email: 's@example.test',
    );
    AuthSession.instance.accessToken = 'token';
  });
  tearDown(() {
    AuthSession.instance.sellerEnabled = wasSeller;
    AuthSession.instance.user = wasUser;
    AuthSession.instance.accessToken = wasToken;
  });

  testWidgets('piece for sale: two photos uploaded in order, draft created, then live', (
    tester,
  ) async {
    AuthSession.instance.sellerEnabled = true;
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _page(
        PostCreatePage(
          postType: 'piece',
          imagePaths: [_portrait, _landscape],
          transforms: [PostImageTransform(), PostImageTransform()],
          previewImageIndex: 1, // the photo on show is not the cover
          onClose: () {},
          debugLocation: _dallas,
          debugMediumIds: const ['oil', 'charcoal'],
        ),
      ),
    );
    await tester.pump();

    // Availability: price and the real earnings quote.
    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField).at(0), '3600');
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await tester.pump();
    expect(_server.bodies('GET', '/api/user/me/commission-quote'), isNotEmpty);
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains(r'$2,880 after the 20% commission'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();

    // Details.
    await _type(tester, 0, 'Portrait Dream');
    await _type(tester, 1, 'Late light in the studio.');
    await _type(tester, 2, '24');
    await _type(tester, 3, '36');
    await _type(tester, 4, '1.5');
    await _type(tester, 5, '8');
    await tester.tap(find.text('Additional details'));
    await tester.pump();
    await _type(tester, 6, '2025');
    await tester.tap(find.text('Yes'));
    await tester.pump();
    await _tapAndRun(tester, 'Continue', ms: 500);

    // Review → Publish.
    expect(find.text('Look it over'), findsOneWidget);
    expect(find.text(r'$2,880'), findsOneWidget);
    await _tapAndRun(tester, 'Publish');

    expect(find.byType(PostPublishedView), findsOneWidget);
    expect(find.text('Portrait Dream is live'), findsOneWidget);

    final presigns = _server.bodies('POST', '/api/media/presign').toList();
    expect(presigns, hasLength(2));
    expect(presigns.every((b) => b!['purpose'] == 'piece' && b['contentType'] == 'image/png'), isTrue);

    final created = _server.bodies('POST', '/api/pieces').single!;
    expect(created['status'], 'draft');
    expect((created['images'] as List).map((i) => (i as Map)['mediaUrl']), [
      'https://cdn.test/sarah/piece/1',
      'https://cdn.test/sarah/piece/2',
    ]);
    expect(created['mediaUrl'], 'https://cdn.test/sarah/piece/1');
    expect(created['mediaAspectRatio'], '3:4');
    expect(created['title'], 'Portrait Dream');
    expect(created['caption'], 'Late light in the studio.');
    expect(created['medium'], 'oil');
    expect(created['mediums'], ['oil', 'charcoal']);
    expect(created['dimensions'], '24x36x1.5 in');
    expect(created['framingMounting'], 'Unframed');
    expect(created['yearCreated'], 2025);
    expect(created['edition'], '1 of 1');
    expect(created['signed'], true);
    expect(created['isForSale'], true);
    expect(created['priceCents'], 360000);
    expect(created['weightKg'], closeTo(3.629, 0.001));
    expect(created['location'], 'Dallas, TX, United States');
    expect(created['shippingRegion'], 'Dallas, TX, United States');
    expect(created['aiDisclosed'], false);

    expect(_server.bodies('PATCH', '/api/pieces/p1').single, {'status': 'live'});
  });

  testWidgets('piece not for sale: no price, weight or framing sent', (tester) async {
    AuthSession.instance.sellerEnabled = false;
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _page(
        PostCreatePage(
          postType: 'piece',
          imagePaths: [_portrait],
          transforms: [PostImageTransform()],
          previewImageIndex: 0,
          onClose: () {},
          debugLocation: _dallas,
          debugMediumIds: const ['acrylic'],
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await _type(tester, 0, 'Bodies in Color');
    await _type(tester, 2, '24');
    await _type(tester, 3, '36');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await _tapAndRun(tester, 'Publish');

    expect(find.text('Bodies in Color is live'), findsOneWidget);
    final created = _server.bodies('POST', '/api/pieces').single!;
    for (final key in ['isForSale', 'priceCents', 'weightKg', 'framingMounting', 'shippingRegion']) {
      expect(created.containsKey(key), isFalse, reason: key);
    }
    expect(created['dimensions'], '24x36 in');
    expect(created['images'], hasLength(1));
  });

  testWidgets('publish fails after the draft: error screen, Try again only makes it live', (
    tester,
  ) async {
    AuthSession.instance.sellerEnabled = false;
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _server.failing.add('PATCH /api/pieces/p1');
    await tester.pumpWidget(
      _page(
        PostCreatePage(
          postType: 'piece',
          imagePaths: [_portrait],
          transforms: [PostImageTransform()],
          previewImageIndex: 0,
          onClose: () {},
          debugLocation: _dallas,
          debugMediumIds: const ['oil'],
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await _type(tester, 0, 'Night Study');
    await _type(tester, 2, '10');
    await _type(tester, 3, '12');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await _tapAndRun(tester, 'Publish');

    expect(find.byType(PostErrorView), findsOneWidget);
    expect(find.textContaining('Saved as draft · '), findsOneWidget);

    _server.failing.clear();
    await _tapAndRun(tester, 'Try again');
    expect(find.text('Night Study is live'), findsOneWidget);
    expect(_server.bodies('POST', '/api/pieces'), hasLength(1)); // not created twice
    expect(_server.bodies('PATCH', '/api/pieces/p1'), hasLength(2));
  });

  testWidgets('Scene photo: the edited photo is posted with every linked piece', (tester) async {
    final edited = PostImageTransform()
      ..aspectRatio = CropAspectRatio.ratio4x5
      ..warmth = 70;
    await tester.pumpWidget(
      _page(
        PostCreatePage(
          postType: 'scene',
          imagePaths: [_landscape, _portrait],
          transforms: [PostImageTransform(), edited],
          previewImageIndex: 1,
          onClose: () {},
          initialLinkedPiece: const ScenePostArgs(pieceId: 'p1', pieceTitle: 'Portrait Dream'),
          debugLocation: _dallas,
        ),
      ),
    );
    await tester.pump();
    await _type(tester, 0, 'Underpainting, day two.');
    await _tapAndRun(tester, 'Post');

    expect(find.byType(SceneLiveView), findsOneWidget);
    expect(find.text('Now showing on 1 piece'), findsOneWidget);
    expect(_server.bodies('POST', '/api/media/presign').single!['purpose'], 'post');
    final post = _server.bodies('POST', '/api/posts').single!;
    expect(post['mediaType'], 'image');
    expect(post['mediaAspectRatio'], '4:5');
    expect(post['caption'], 'Underpainting, day two.');
    expect(post['linkedPieceId'], 'p1');
    expect(post['linkedPieceIds'], ['p1']);
    expect(post['location'], 'Dallas, TX, United States');
    expect(post['status'], 'live');
  });

  testWidgets('Scene video: the clip and its cover are uploaded, length shown', (tester) async {
    final cover = img.encodePng(img.Image(width: 90, height: 160));
    await tester.pumpWidget(
      _page(
        PostCreatePage(
          postType: 'scene',
          imagePaths: const [],
          transforms: const [],
          previewImageIndex: 0,
          onClose: () {},
          mediaKind: 'video',
          videoPath: _clip,
          videoThumbnailBytes: cover,
          videoLength: const Duration(seconds: 42),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('0:42'), findsOneWidget);
    await _tapAndRun(tester, 'Post');

    final presigns = _server.bodies('POST', '/api/media/presign').toList();
    expect(presigns.map((b) => b!['contentType']), ['video/mp4', 'image/jpeg']);
    final post = _server.bodies('POST', '/api/posts').single!;
    expect(post['mediaType'], 'video');
    expect(post['mediaUrl'], 'https://cdn.test/sarah/post/1');
    expect(post['thumbnailUrl'], 'https://cdn.test/sarah/post/2');
    expect(post.containsKey('linkedPieceIds'), isFalse);
    expect(find.byType(SceneLiveView), findsOneWidget);
  });

  group('renderer: the uploaded image matches what was chosen', () {
    Future<(int, int, Uint8List)> render(WidgetTester tester, String path, PostImageTransform t) async {
      late (int, int, Uint8List) out;
      await tester.runAsync(() async {
        final bytes = await PostImageRenderer.render(imagePath: path, transform: t);
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        out = (image.width, image.height, data!.buffer.asUint8List());
      });
      return out;
    }

    for (final (ratio, expected) in [
      (CropAspectRatio.ratio3x4, 3 / 4),
      (CropAspectRatio.ratio4x5, 4 / 5),
      (CropAspectRatio.ratio1x1, 1.0),
      (CropAspectRatio.ratio9x16, 9 / 16),
      (CropAspectRatio.ratio16x9, 16 / 9),
    ]) {
      testWidgets('size ${ratio.label}', (tester) async {
        final (w, h, _) = await render(
          tester,
          _landscape,
          PostImageTransform()..aspectRatio = ratio,
        );
        expect(w / h, closeTo(expected, 0.01));
        expect(w > h ? w : h, PostImageRenderer.maxOutputLongSide.round());
      });
    }

    testWidgets('Original keeps the photo shape', (tester) async {
      final (w, h, _) = await render(
        tester,
        _landscape,
        PostImageTransform()..originalAspect = 400 / 300,
      );
      expect(w / h, closeTo(4 / 3, 0.01));
    });

    testWidgets('warmth shifts red up and blue down; neutral leaves grey alone', (tester) async {
      final (_, _, plain) = await render(tester, _landscape, PostImageTransform());
      expect(plain[0], plain[2]); // grey: red == blue
      final (_, _, warm) = await render(tester, _landscape, PostImageTransform()..warmth = 100);
      expect(warm[0], greaterThan(plain[0]));
      expect(warm[2], lessThan(plain[2]));
    });

    testWidgets('brightness lifts every channel; contrast pivots around mid-grey', (tester) async {
      final (_, _, plain) = await render(tester, _landscape, PostImageTransform());
      final (_, _, bright) = await render(tester, _landscape, PostImageTransform()..brightness = 75);
      expect(bright[0], greaterThan(plain[0] + 40));
      // The grey (120) sits below the middle, so more contrast darkens it.
      final (_, _, punchy) = await render(tester, _landscape, PostImageTransform()..contrast = 75);
      expect(punchy[0], lessThan(plain[0]));
    });

    testWidgets('a quarter turn keeps the output shape', (tester) async {
      final (w, h, _) = await render(
        tester,
        _landscape,
        PostImageTransform()..rotationDegrees = -90,
      );
      expect(w / h, closeTo(3 / 4, 0.01));
    });
  });

  testWidgets('piece at auction: terms on review, created live with the auction, Scene linked', (
    tester,
  ) async {
    AuthSession.instance.sellerEnabled = true;
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _page(
        PostCreatePage(
          postType: 'piece',
          imagePaths: [_portrait],
          transforms: [PostImageTransform()],
          previewImageIndex: 0,
          onClose: () {},
          debugLocation: _dallas,
          debugMediumIds: const ['oil'],
        ),
      ),
    );
    await tester.pump();

    // Availability: Auction, a starting bid, 8 days, a private reserve.
    await tester.tap(find.text('Auction'));
    await tester.pump(const Duration(milliseconds: 400));
    await _type(tester, 0, '360');
    await _type(tester, 1, '1200');
    await tester.tap(find.bySemanticsLabel('More days'));
    await tester.pump();
    expect(find.text('8 days'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();

    // Details, with a related Scene.
    await _type(tester, 0, 'Portrait Dream');
    await _type(tester, 2, '24');
    await _type(tester, 3, '36');
    await _type(tester, 4, '1.5');
    await _type(tester, 5, '8');
    await _tapAndRun(tester, 'Related Scenes', ms: 600);
    // The page loads its Scenes from initState, inside the fake clock.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      await _settle(tester, rounds: 1);
    }
    expect(find.text('0 linked'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Scene'),
    );
    await tester.pump();
    expect(find.text('1 linked'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await _tapAndRun(tester, 'Continue', ms: 500);

    // Review.
    expect(
      find.text("You can edit anything after it's live, except a running auction."),
      findsOneWidget,
    );
    for (final text in ['Auction', r'$360', '8 days', r'$1,200 · private']) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    await _tapAndRun(tester, 'Publish');
    expect(find.text('Portrait Dream is live'), findsOneWidget);

    final created = _server.bodies('POST', '/api/pieces').single!;
    expect(created['status'], 'live');
    expect(created['isForSale'], true);
    expect(created['listingType'], 'auction');
    expect(created['priceCents'], 36000);
    expect(created['auctionDurationDays'], 8);
    expect(created['reserveCents'], 120000);
    // Created live: no draft to take live.
    expect(_server.bodies('PATCH', '/api/pieces/p1'), isEmpty);
    expect(_server.bodies('PATCH', '/api/posts/s9').single, {
      'linkedPieceIds': ['old', 'p1'],
    });
  });
}
