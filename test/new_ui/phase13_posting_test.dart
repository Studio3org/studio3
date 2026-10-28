import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/screens/drafts_page.dart';
import 'package:studio3/screens/post_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/drafts_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/post_gallery/post_gallery_picker.dart';
import 'package:studio3/widgets/post_share_type_sheet.dart';
import 'package:studio3/widgets/studio/studio.dart';
import 'package:studio3/utils/app_clock.dart';

import 'golden_harness.dart';

/// Phase 13, 17.4 (docs/new-ui/NEW_UI_EXECUTION_PLAN.md): "What are you sharing?", the light
/// photo picker, and Drafts, against a fake server.

const _user = {'id': 'u1', 'username': 'jordanlee', 'name': 'Jordan Lee', 'email': 'jordan@email.com'};

Map<String, dynamic> _piece(String id, {String title = 'Untitled', String status = 'draft', Map<String, dynamic> extra = const {}}) => {
  'id': id,
  'title': title,
  'status': status,
  'mediaUrl': '',
  'createdAt': '2026-10-27T14:14:00',
  ...extra,
};

class _Fake implements HttpClientAdapter {
  final requests = <({String method, String path, Map<String, dynamic>? body})>[];
  List<Map<String, dynamic>> pieces = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : null;
    final path = options.uri.path;
    requests.add((method: options.method, path: path, body: body));
    Object json;
    var code = 200;
    if (options.method == 'GET' && path == '/api/users/jordanlee/pieces') {
      json = {'success': true, 'data': pieces};
    } else if (options.method == 'PATCH' && path.startsWith('/api/pieces/')) {
      final id = path.split('/').last;
      json = {
        'success': true,
        'data': {...pieces.firstWhere((p) => p['id'] == id), ...?body},
      };
    } else if (options.method == 'DELETE' && path.startsWith('/api/pieces/')) {
      json = {'success': true, 'data': {}};
    } else {
      code = 404;
      json = {'success': false, 'message': 'no route'};
    }
    return ResponseBody.fromString(
      jsonEncode(json),
      code,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

late _Fake _server;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 350));
  }
}

/// Opens the + sheet and shows where it went.
class _PlusRunner extends StatelessWidget {
  const _PlusRunner();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(onPressed: () => PostShareTypeSheet.showAndOpenPost(context), child: const Text('plus')),
    ),
  );
}

class _ArgsPage extends StatelessWidget {
  const _ArgsPage(this.name);

  final String name;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text('$name ${ModalRoute.of(context)?.settings.arguments}'));
}

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.light,
  initialRoute: '/under-test',
  routes: {
    '/under-test': (_) => home,
    '/post': (_) => const _ArgsPage('post page'),
    '/drafts': (_) => const _ArgsPage('drafts page'),
  },
);

/// The board's grid of plain colours, two picked.
Widget _pickerStill() {
  const colours = [
    0xFF6FA3B0, 0xFF2F5D8A, 0xFFB9A98C, 0xFF3F4A3A, 0xFFC9B8C9, 0xFFCDB98F, //
    0xFF8C6A4F, 0xFF5A5672, 0xFFD9652B, 0xFFA48E78, 0xFF6E5A48, 0xFF2F5D8A, //
    0xFFB87631, 0xFF3B3836, 0xFFC9B8C9,
  ];
  return Scaffold(
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PostPickerHeader(title: 'New piece', albumName: 'Recents', onClose: () {}, onNext: () {}, countLabel: '2 of 4 selected'),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < colours.length; i++)
                  PostGalleryCell(
                    number: i == 0 ? 1 : (i == 3 ? 2 : null),
                    onTap: () {},
                    child: ColoredBox(color: Color(colours[i])),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  // Drafts' times ("Today, 2:14 PM", "Yesterday") against a fixed day.
  setUp(() => appNow = () => DateTime(2026, 10, 27, 18));
  tearDown(() => appNow = DateTime.now);
  setUpAll(() async {
    await loadStudioFonts();
    dotenv.loadFromString(envString: '', isOptional: true);
  });

  late AuthUser? wasUser;
  late String? wasToken;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _server = _Fake();
    ApiClient.instance.debugUseAdapter(_server);
    wasUser = AuthSession.instance.user;
    wasToken = AuthSession.instance.accessToken;
    AuthSession.instance.user = AuthUser.fromJson(_user);
    AuthSession.instance.accessToken = 'token';
  });
  tearDown(() {
    AuthSession.instance.user = wasUser;
    AuthSession.instance.accessToken = wasToken;
  });

  group('What are you sharing?', () {
    testWidgets('Piece and Scene; no Drafts row without drafts', (tester) async {
      _server.pieces = [_piece('p1', title: 'Live one', status: 'live')];
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const _PlusRunner()));
      await tester.tap(find.text('plus'));
      await _settle(tester);
      expect(find.text('What are you sharing?'), findsOneWidget);
      expect(find.text('A finished work, up to 4 angles'), findsOneWidget);
      expect(find.text('Process, studio, or anything else'), findsOneWidget);
      expect(find.text('Drafts'), findsNothing);
      await tester.tap(find.text('Scene'));
      await _settle(tester);
      expect(find.text('post page scene'), findsOneWidget);
    });

    testWidgets('with drafts: the Drafts row and its count open Drafts', (tester) async {
      _server.pieces = [_piece('d1'), _piece('d2'), _piece('p1', status: 'live')];
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const _PlusRunner()));
      await tester.tap(find.text('plus'));
      await _settle(tester);
      expect(find.text('Drafts'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.text('Drafts'));
      await _settle(tester);
      expect(find.text('drafts page null'), findsOneWidget);
    });

    testWidgets('Piece opens the piece picker', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const _PlusRunner()));
      await tester.tap(find.text('plus'));
      await _settle(tester);
      await tester.tap(find.text('Piece'));
      await _settle(tester);
      expect(find.text('post page piece'), findsOneWidget);
    });
  });

  testWidgets('picker: numbered picks, the count, Next only once something is picked', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: _pickerStill()));
    expect(find.text('New piece'), findsOneWidget);
    expect(find.text('2 of 4 selected'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PostPickerHeader(title: 'New Scene', albumName: 'Recents', onClose: () {}, onNext: null),
        ),
      ),
    );
    final next = tester.widget<Text>(find.text('Next'));
    expect(next.style?.color, tester.element(find.text('Next')).studio.textTertiary);
    expect(find.textContaining('selected'), findsNothing);
  });

  group('Drafts', () {
    void seed() {
      _server.pieces = [
        _piece('p0', title: 'Already up', status: 'live'),
        _piece('d1', title: 'Portrait Dream', extra: {'medium': 'Oil', 'dimensions': '24x36 in'}),
        _piece('d2', extra: {'medium': 'Oil'}),
        _piece('d3', title: 'Night Studies II', extra: {'medium': 'Ink', 'dimensions': '9x12 in', 'isForSale': true}),
        _piece('d4', title: 'Ready one', extra: {'medium': 'Ink', 'dimensions': '9x12 in'}),
      ];
    }

    testWidgets('rows say what is left; a failed one is red; Scenes is empty for now', (tester) async {
      seed();
      await DraftsService.instance.markFailed('d1');
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const DraftsPage()));
      await _settle(tester);
      expect(find.text('Already up'), findsNothing);
      expect(find.text('Portrait Dream'), findsOneWidget);
      expect(find.text("Didn't publish. Tap to try again."), findsOneWidget);
      expect(find.text('Untitled piece'), findsOneWidget);
      expect(find.text('Title and size left'), findsOneWidget);
      expect(find.text('Price and shipping details left'), findsOneWidget);
      expect(find.text('Ready to post'), findsOneWidget);
      expect(find.textContaining('PIECE · '), findsNWidgets(4));
      await tester.tap(find.text('Scenes'));
      await tester.pump();
      expect(find.text('No drafts'), findsOneWidget);
    });

    testWidgets('tapping a failed draft tries again and it leaves the list', (tester) async {
      seed();
      await DraftsService.instance.markFailed('d1');
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const DraftsPage()));
      await _settle(tester);
      await tester.tap(find.text('Portrait Dream'));
      await _settle(tester);
      final patch = _server.requests.where((r) => r.method == 'PATCH').single;
      expect(patch.path, '/api/pieces/d1');
      expect(patch.body, {'status': 'live'});
      expect(find.text('Portrait Dream'), findsNothing);
      expect(await DraftsService.instance.failedIds(), isEmpty);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('swipe left asks, then deletes', (tester) async {
      seed();
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const DraftsPage()));
      await _settle(tester);
      await tester.drag(find.text('Ready one'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Delete this draft?'), findsOneWidget);
      await tester.tap(find.byWidgetPredicate((w) => w is StudioButton && w.label == 'Delete'));
      await _settle(tester);
      expect(_server.requests.where((r) => r.method == 'DELETE').single.path, '/api/pieces/d4');
      expect(find.text('Ready one'), findsNothing);
    });

    testWidgets('no drafts: the grey mark and No drafts', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const DraftsPage()));
      await _settle(tester);
      expect(find.text('No drafts'), findsOneWidget);
    });
  });

  test('time line: today with the time, yesterday, then the date', () {
    final now = DateTime(2026, 10, 27, 18);
    expect(draftTimeLabel(DateTime(2026, 10, 27, 14, 14), now: now), 'Today, 2:14 PM');
    expect(draftTimeLabel(DateTime(2026, 10, 26, 9), now: now), 'Yesterday');
    expect(draftTimeLabel(DateTime(2026, 10, 21), now: now), 'Oct 21');
    expect(draftTimeLabel(DateTime(2025, 12, 3), now: now), 'Dec 3, 2025');
  });

  test('what is left', () {
    PieceSummary p(Map<String, dynamic> j) => PieceSummary.fromJson({'id': 'x', 'title': 'T', ...j});
    expect(draftLeftLine(p({'medium': 'Oil', 'dimensions': '1x1 in'})), 'Ready to post');
    expect(draftLeftLine(p({'title': 'Untitled'})), '3 details left before you can post');
    expect(draftLeftLine(p({'medium': 'Oil'})), 'Size left');
  });

  group('goldens', () {
    final skip = Platform.environment['NEW_UI_GOLDENS'] != '1';
    Future<void> snap(WidgetTester tester, String name) async {
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
      await checkAcceptance(tester);
    }

    Widget still(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), padding: EdgeInsets.only(bottom: 34), disableAnimations: true),
        child: home,
      ),
    );

    testWidgets('golden: PostCreate', (tester) async {
      _server.pieces = [for (var i = 0; i < 4; i++) _piece('d$i')];
      setBoardViewport(tester);
      await tester.pumpWidget(still(const _PlusRunner()));
      await tester.tap(find.text('plus'));
      await _settle(tester);
      await snap(tester, 'PostCreate');
    }, skip: skip);

    testWidgets('golden: PostPicker', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(still(_pickerStill()));
      await snap(tester, 'PostPicker');
    }, skip: skip);

    testWidgets('golden: Drafts', (tester) async {
      _server.pieces = [
        _piece('d1', title: 'Portrait Dream', extra: {'medium': 'Oil', 'dimensions': '24x36 in'}),
        _piece('d2', extra: {'createdAt': '2026-10-26T10:00:00'}),
        _piece('d3', title: 'Night Studies II', extra: {'medium': 'Ink', 'dimensions': '9x12 in', 'isForSale': true, 'createdAt': '2026-10-18T10:00:00'}),
      ];
      await DraftsService.instance.markFailed('d1');
      setBoardViewport(tester);
      await tester.pumpWidget(still(const DraftsPage()));
      await _settle(tester);
      await snap(tester, 'Drafts');
    }, skip: skip);
  });
}
