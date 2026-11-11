import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/feed_preview_item.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/screens/event_detail_page.dart';
import 'package:studio3/screens/event_invites_page.dart';
import 'package:studio3/screens/event_piece_request_page.dart';
import 'package:studio3/screens/host/host_event_page.dart';
import 'package:studio3/screens/host/host_manage_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/accept_decline_buttons.dart';
import 'package:studio3/widgets/host/host_widgets.dart';
import 'package:studio3/widgets/piece_detail/piece_page_sections.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Phase 5 of the backend handoff: co-host and featured-artist invites, artists approving
/// tagged pieces, when bidding ends, and Exhibited; with Step 0.1–0.4 (saving an event no
/// longer resets invites or approvals, and waiting pieces stay off public lists).
class _Server implements HttpClientAdapter {
  final requests = <({String method, String path, Map<String, dynamic>? body})>[];
  final routes = <String, (int, Object?)>{};

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : null;
    requests.add((method: options.method, path: path, body: body));
    final route = routes['${options.method} $path'];
    if (route == null) return _json({'success': false, 'message': 'no route'}, 404);
    final (status, data) = route;
    if (status >= 400) return _json({'success': false, 'message': data}, status);
    return _json({'success': true, 'data': data}, status);
  }

  Iterable<({String method, String path, Map<String, dynamic>? body})> calls(String method, [String? path]) =>
      requests.where((r) => r.method == method && (path == null || r.path == path));

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

late _Server _server;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await _settle(tester);
}

Widget _app(Widget home) =>
    MaterialApp(key: UniqueKey(), debugShowCheckedModeBanner: false, theme: AppTheme.light, home: home);

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

Map<String, dynamic> _eventJson({
  bool isHost = true,
  bool canEdit = true,
  String status = 'published',
  Map<String, dynamic>? viewerInvite,
  List<Map<String, dynamic>>? lineup,
}) => {
  'id': 'ev1',
  'title': 'Night Market',
  'startsAt': '2037-11-21T20:00:00Z',
  'endsAt': '2037-11-21T23:00:00Z',
  'status': status,
  'venueName': 'Cedars Union',
  'address': '1414 Dragon St, Dallas, TX',
  'category': 'gallery_walk',
  'coverMediaUrl': 'https://example.com/flyer.jpg',
  'timezone': 'CST',
  'hostUsername': 'ana',
  'hostName': 'Ana',
  'isHost': isHost,
  'viewerCanEdit': canEdit,
  'viewerInvite': ?viewerInvite,
  'cohosts': [
    {'username': 'sarah', 'name': 'Sarah Osmei'},
  ],
  'artists': const <Map<String, dynamic>>[],
  'invites': [
    {'username': 'sarah', 'name': 'Sarah Osmei', 'role': 'cohost', 'status': 'accepted'},
    {'username': 'mira', 'name': 'Mira Lane', 'role': 'artist', 'status': 'invited'},
    {'username': 'leo', 'name': 'Leo Park', 'role': 'artist', 'status': 'declined'},
  ],
  'lineup':
      lineup ??
      [
        {
          'id': 'l1',
          'pieceId': 'p1',
          'mode': 'sale',
          'priceCents': 50000,
          'deliveryMode': 'pickup',
          'title': 'Paper Planes III',
          'artistUsername': 'mira',
          'artistName': 'Mira Lane',
          'approvalStatus': 'approved',
        },
        {
          'id': 'l2',
          'pieceId': 'p2',
          'mode': 'sale',
          'priceCents': 80000,
          'deliveryMode': 'pickup',
          'title': 'Low Tide',
          'artistUsername': 'mira',
          'artistName': 'Mira Lane',
          'approvalStatus': 'waiting',
        },
      ],
};

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final tmp = Directory.systemTemp.createTempSync('phase5').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
  });

  String? wasToken;
  AuthUser? wasUser;
  setUp(() {
    _server = _Server();
    ApiClient.instance.debugUseAdapter(_server);
    wasToken = AuthSession.instance.accessToken;
    wasUser = AuthSession.instance.user;
    AuthSession.instance.accessToken = 'token';
  });
  tearDown(() {
    AuthSession.instance.accessToken = wasToken;
    AuthSession.instance.user = wasUser;
  });

  group('models', () {
    test('invites, viewerInvite, viewerCanEdit and lineup approvals', () {
      final e = StudioEvent.fromJson(_eventJson(isHost: false, viewerInvite: {'roles': ['cohost'], 'status': 'accepted'}));
      expect(e.invites.map((i) => (i.username, i.role, i.statusLabel)), [
        ('sarah', 'cohost', 'Accepted'),
        ('mira', 'artist', 'Invited'),
        ('leo', 'artist', 'Declined'),
      ]);
      expect((e.viewerInvite!.isCohost, e.viewerInvite!.status, e.viewerCanEdit, e.canManage), (true, 'accepted', true, true));
      expect(e.hasPendingInvite, isFalse);
      expect(e.lineup.map((i) => i.approvalLine), ['Approved by Mira Lane', 'Waiting for Mira Lane']);
      // Only approved (or unmarked) pieces are on the event for everyone.
      expect(e.liveLineup.map((i) => i.pieceId), ['p1']);
      expect(e.sellingLineup.map((i) => i.pieceId), ['p1']);
      // An older server sends no approval fields: everything is live.
      expect(const EventLineupItem(id: 'x', pieceId: 'x', mode: 'featured').isLive, isTrue);
      final back = StudioEvent.fromJson(e.toJson());
      expect((back.invites.length, back.viewerInvite?.status, back.viewerCanEdit), (3, 'accepted', true));
      final copy = e.copyWith(viewerCanEdit: false);
      expect((copy.viewerCanEdit, copy.invites.length), (false, 3));
    });

    test('piece requests and invites from /me', () {
      final request = EventPieceRequest.fromJson({
        ..._eventJson()['lineup'][1] as Map<String, dynamic>,
        'preview': {'endsAuction': true, 'endsFixedListing': false, 'activeBidCount': 3},
        'event': _eventJson(),
      });
      expect((request.item.isWaiting, request.event.title, request.preview!.activeBidCount), (true, 'Night Market', 3));
      final invite = EventInviteRequest.fromJson({'role': 'cohost', 'invitedAt': '2037-11-01T10:00:00Z', 'event': _eventJson()});
      expect((invite.roleLabel, invite.event.id), ('Co-host', 'ev1'));
    });

    test('exhibitions round-trip through the piece cache', () {
      final piece = PieceSummary.fromJson({
        'id': 'p1',
        'title': 'Paper Planes III',
        'exhibitions': [
          {
            'eventId': 'ev1',
            'title': 'Night Market',
            'venueName': 'Cedars Union',
            'city': 'Austin',
            'date': '2026-11-21T02:00:00+00:00',
            'month': 'November 2026',
          },
          {'eventId': null, 'title': 'Old Show', 'month': 'May 2025'},
        ],
      });
      expect(piece.exhibitions.map((e) => (e.title, e.place, e.month, e.eventId)), [
        ('Night Market', 'Cedars Union, Austin', 'November 2026', 'ev1'),
        ('Old Show', '', 'May 2025', null),
      ]);
      expect(PieceSummary.fromJson(piece.toJson()).exhibitions.length, 2);
      final item = FeedPreviewItem.fromPieceSummary(piece);
      expect(item.exhibitions.length, 2);
      expect(FeedPreviewItem.fromCacheJson(item.toJson()).exhibitions.first.month, 'November 2026');
      expect(item.copyWith(exhibitions: const []).exhibitions, isEmpty);
      expect(PieceSummary.fromJson({'id': 'p2', 'title': 'x'}).exhibitions, isEmpty);
    });
  });

  testWidgets('Exhibited: title and venue left, the month right', (tester) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: PieceExhibited(
            exhibitions: [
              PieceExhibition(eventId: 'ev1', title: 'Night Market', venueName: 'Cedars Union', city: 'Austin', month: 'November 2026'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Exhibited'), findsOneWidget);
    expect(find.text('Night Market'), findsOneWidget);
    expect(find.text('Cedars Union, Austin'), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);
  });

  group('event page', () {
    testWidgets('an invite waiting for an answer: Accept and Decline in the bar', (tester) async {
      setBoardViewport(tester, height: 900);
      final json = _eventJson(isHost: false, canEdit: false, status: 'draft', viewerInvite: {'roles': ['artist'], 'status': 'invited'});
      _server.routes['POST /api/events/ev1/invite/accept'] = (200, json);
      _server.routes['GET /api/events/ev1'] = (
        200,
        _eventJson(isHost: false, canEdit: false, status: 'draft', viewerInvite: {'roles': ['artist'], 'status': 'accepted'}),
      );
      await tester.pumpWidget(_app(EventDetailPage(event: StudioEvent.fromJson(json), debugDetail: StudioEvent.fromJson(json))));
      await tester.pump();
      expect(find.text('Invited as'), findsOneWidget);
      expect(find.text('Featured artist'), findsOneWidget);
      expect(find.byType(AcceptDeclineButtons), findsOneWidget);
      await _tap(tester, _button('Accept'));
      expect(_server.calls('POST', '/api/events/ev1/invite/accept').length, 1);
      expect(find.byType(AcceptDeclineButtons), findsNothing);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('a co-host gets Manage; waiting pieces stay off the public strip', (tester) async {
      setBoardViewport(tester, height: 1400);
      final e = StudioEvent.fromJson(_eventJson(isHost: false));
      await tester.pumpWidget(_app(EventDetailPage(event: e, debugDetail: e)));
      await tester.pump();
      expect(_button('Manage event'), findsOneWidget);
      expect(find.text('Pieces at this event'), findsOneWidget);
      expect(find.text('Low Tide'), findsNothing);
    });

    testWidgets("the artist's own waiting piece: Review request opens the request", (tester) async {
      setBoardViewport(tester, height: 900);
      AuthSession.instance.user = AuthUser.fromJson({'id': 'u2', 'username': 'mira', 'name': 'Mira Lane', 'email': 'mira@x.com'});
      final e = StudioEvent.fromJson(_eventJson(isHost: false, canEdit: false));
      _server.routes['GET /api/user/me/piece-requests'] = (200, {'requests': const []});
      await tester.pumpWidget(_app(EventDetailPage(event: e, debugDetail: e)));
      await tester.pump();
      await _tap(tester, _button('Review request'));
      expect(find.byType(EventPieceRequestPage), findsOneWidget);
    });
  });

  group('piece request', () {
    EventPieceRequest request({bool auction = true}) => EventPieceRequest.fromJson({
      ..._eventJson()['lineup'][1] as Map<String, dynamic>,
      'mode': auction ? 'bid' : 'sale',
      'preview': {'endsAuction': auction, 'endsFixedListing': !auction, 'activeBidCount': auction ? 2 : 0},
      'event': _eventJson(),
    });

    testWidgets('warns, then approves at the artist\'s own price', (tester) async {
      setBoardViewport(tester, height: 900);
      _server.routes['POST /api/events/ev1/pieces/p2/approve'] = (200, _eventJson()['lineup'][1]);
      await tester.pumpWidget(_app(EventPieceRequestPage(request: request(), debugSkipLoad: true)));
      await tester.pump();
      expect(find.text('Auction'), findsOneWidget);
      expect(find.text('Pickup at the event'), findsOneWidget);
      expect(find.textContaining('Approving ends its current auction'), findsOneWidget);
      await _tap(tester, find.text('Starting bid'));
      await tester.enterText(find.byType(TextField).last, '900');
      await tester.pump();
      await _tap(tester, _button('Done'));
      expect(find.text(r'$900'), findsOneWidget);
      await _tap(tester, _button('Approve'));
      expect(find.text('This will end its current auction'), findsOneWidget);
      await _tap(tester, _button('Continue'));
      expect(_server.calls('POST', '/api/events/ev1/pieces/p2/approve').single.body, {'priceCents': 90000});
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('the onboarding 403 shows as it is', (tester) async {
      setBoardViewport(tester, height: 900);
      _server.routes['POST /api/events/ev1/pieces/p2/approve'] = (403, 'Please complete onboarding before performing this action.');
      await tester.pumpWidget(_app(EventPieceRequestPage(request: request(auction: false), debugSkipLoad: true)));
      await tester.pump();
      await _tap(tester, _button('Approve'));
      await _tap(tester, _button('Continue'));
      expect(find.text('Please complete onboarding before performing this action.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Decline', (tester) async {
      setBoardViewport(tester, height: 900);
      _server.routes['POST /api/events/ev1/pieces/p2/decline'] = (200, const {});
      await tester.pumpWidget(_app(EventPieceRequestPage(request: request(), debugSkipLoad: true)));
      await tester.pump();
      await _tap(tester, _button('Decline'));
      expect(_server.calls('POST', '/api/events/ev1/pieces/p2/decline').length, 1);
      await tester.pump(const Duration(seconds: 11));
    });
  });

  testWidgets('Event invites: invites with Accept / Decline, then piece requests', (tester) async {
    setBoardViewport(tester, height: 900);
    _server.routes['POST /api/events/ev1/invite/decline'] = (200, _eventJson());
    await tester.pumpWidget(
      _app(
        EventInvitesPage(
          debugInvites: [EventInviteRequest.fromJson({'role': 'cohost', 'event': _eventJson()})],
          debugRequests: [
            EventPieceRequest.fromJson({..._eventJson()['lineup'][1] as Map<String, dynamic>, 'event': _eventJson()}),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('INVITES'), findsOneWidget);
    expect(find.text('PIECE REQUESTS'), findsOneWidget);
    expect(find.text('For sale at Night Market'), findsOneWidget);
    await _tap(tester, _button('Decline'));
    expect(_server.calls('POST', '/api/events/ev1/invite/decline').single.body, {'role': 'cohost'});
    expect(find.text('INVITES'), findsNothing);
  });

  group('Manage', () {
    testWidgets('People with their status; a co-host has no Cancel or Reschedule', (tester) async {
      setBoardViewport(tester, height: 1600);
      final e = StudioEvent.fromJson(_eventJson(isHost: false));
      await tester.pumpWidget(_app(HostManagePage(event: e, debugEvent: e, debugNow: DateTime(2037, 11, 1))));
      await tester.pump();
      expect(find.text('PEOPLE'), findsOneWidget);
      expect(find.text('Mira Lane · Featured artist'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      // One approved piece; the waiting one isn't on the event yet.
      expect(find.text('piece'), findsOneWidget);
      expect(find.text('Cancel event'), findsNothing);
      expect(find.text('Reschedule'), findsNothing);
    });

    testWidgets('the host keeps Cancel and Reschedule', (tester) async {
      setBoardViewport(tester, height: 1600);
      final e = StudioEvent.fromJson(_eventJson());
      await tester.pumpWidget(_app(HostManagePage(event: e, debugEvent: e, debugNow: DateTime(2037, 11, 1))));
      await tester.pump();
      expect(find.text('Cancel event'), findsOneWidget);
      expect(find.text('Reschedule'), findsOneWidget);
    });
  });

  group('editing an event', () {
    void routes() {
      _server.routes['PATCH /api/events/ev1'] = (200, _eventJson());
      _server.routes['PUT /api/events/ev1/people'] = (200, _eventJson());
      _server.routes['DELETE /api/events/ev1/pieces/p1'] = (200, {'removed': true});
      _server.routes['DELETE /api/events/ev1/pieces/p2'] = (200, {'removed': true});
      _server.routes['POST /api/events/ev1/pieces'] = (201, {'id': 'new', 'pieceId': 'p1', 'mode': 'bid', 'approvalStatus': 'waiting'});
      _server.routes['GET /api/events/ev1/ticket-types'] = (200, {'ticketTypes': const []});
    }

    testWidgets('statuses under people; an untouched save leaves people and pieces alone', (tester) async {
      setBoardViewport(tester, height: 1400);
      routes();
      final e = StudioEvent.fromJson(_eventJson());
      await tester.pumpWidget(_app(HostEventPage(editing: e, debugNow: DateTime(2037, 11, 1), debugStep: 2)));
      await tester.pump();
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Invited'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('Approved by Mira Lane'), findsOneWidget);
      expect(find.text('Waiting for Mira Lane'), findsOneWidget);
      await _tap(tester, find.text('Review'));
      await _tap(tester, _button('Save changes'));
      expect(_server.calls('PATCH', '/api/events/ev1').length, 1);
      expect(_server.calls('PATCH', '/api/events/ev1').single.body!.containsKey('auctionEndsAt'), isFalse);
      expect(_server.calls('PUT'), isEmpty);
      expect(_server.calls('DELETE'), isEmpty);
      expect(_server.calls('POST'), isEmpty);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('a removed person sends the list without those who declined', (tester) async {
      setBoardViewport(tester, height: 1400);
      routes();
      final e = StudioEvent.fromJson(_eventJson());
      await tester.pumpWidget(_app(HostEventPage(editing: e, debugNow: DateTime(2037, 11, 1), debugStep: 2)));
      await tester.pump();
      await _tap(tester, find.text('Sarah'));
      await _tap(tester, _button('Remove'));
      await _tap(tester, find.text('Review'));
      await _tap(tester, _button('Save changes'));
      expect(_server.calls('PUT', '/api/events/ev1/people').single.body, {
        'cohostUsernames': <String>[],
        'artistUsernames': ['mira'],
      });
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('selling to auction: asks first, takes every piece off, then adds them back', (tester) async {
      setBoardViewport(tester, height: 1400);
      routes();
      final e = StudioEvent.fromJson(_eventJson());
      await tester.pumpWidget(_app(HostEventPage(editing: e, debugNow: DateTime(2037, 11, 1))));
      await tester.pump();
      expect(find.text('Bidding ends'), findsNothing);
      await _tap(tester, find.text('Event art'));
      await _tap(tester, find.text('Auction').last);
      await _tap(tester, _button('Done'));
      // Bidding ends (Phase 5.3): 30 minutes before the end by default.
      expect(find.text('Bidding ends'), findsOneWidget);
      await _tap(tester, find.text('Lineup'));
      final auction = find.byWidgetPredicate((w) => w is StudioChip && w.label == 'Auction');
      expect(auction, findsNWidgets(2));
      await _tap(tester, auction.at(0));
      await _tap(tester, auction.at(1));
      expect(find.textContaining('Ends at'), findsNWidgets(2));
      await _tap(tester, find.text('Review'));
      await _tap(tester, _button('Save changes'));
      // Mira's pieces go back to her.
      expect(find.text('Mira Lane will be asked again'), findsOneWidget);
      await _tap(tester, _button('Save'));
      final pieceCalls = _server.requests.where((r) => r.path.contains('/pieces')).map((r) => r.method).toList();
      expect(pieceCalls, ['DELETE', 'DELETE', 'POST', 'POST']);
      expect(_server.calls('POST', '/api/events/ev1/pieces').map((r) => r.body!['mode']), ['bid', 'bid']);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('a co-host: no people tiles to add, the date stays, nothing is published', (tester) async {
      setBoardViewport(tester, height: 1400);
      routes();
      final e = StudioEvent.fromJson(_eventJson(isHost: false, status: 'draft'));
      await tester.pumpWidget(_app(HostEventPage(editing: e, debugNow: DateTime(2037, 11, 1))));
      await tester.pump();
      expect(find.text('Only the host can change the date.'), findsOneWidget);
      await _tap(tester, find.text('Lineup'));
      expect(find.byType(HostAddTile), findsNothing);
      await _tap(tester, find.text('Review'));
      await _tap(tester, _button('Save changes'));
      final patch = _server.calls('PATCH', '/api/events/ev1').single.body!;
      expect(patch.containsKey('startsAt'), isFalse);
      expect(_server.calls('PUT'), isEmpty);
      expect(_server.calls('POST', '/api/events/ev1/publish'), isEmpty);
      await tester.pump(const Duration(seconds: 11));
    });
  });
}
