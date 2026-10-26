import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/studio_event.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/create_flow/post_result_views.dart';
import 'package:studio3/widgets/events/event_detail_widgets.dart';
import 'package:studio3/widgets/events/event_tickets_sheet.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Phase 13, 17.1 (docs/new-ui/NEW_UI_EXECUTION_PLAN.md): canvas changes on screens that were
/// already built — the iridescent frame on Published / Listed / Posted, "Not for sale" as text,
/// red on PostError, and the event times, ticket range and delivery line.

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

const _cover = ColoredBox(color: Color(0xFF6FA3B0));

PostPublishedView _published({String? priceLabel}) => PostPublishedView(
  title: 'Bodies in Color',
  cover: _cover,
  photoCount: 1,
  authorName: 'Amara Osei',
  avatarUrl: null,
  priceLabel: priceLabel,
  onClose: () {},
  onAddScene: () {},
  onShare: () {},
  onView: () {},
);

void main() {
  group('Published, Listed and Posted', () {
    testWidgets('PostSuccess: the preview in the iridescent frame (5 around, radius 20)', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_published(priceLabel: r'$3,600')));
      await tester.pump();
      final frame = tester.widget<StudioIridescent>(find.byType(StudioIridescent));
      expect(frame.padding, const EdgeInsets.all(5));
      expect(frame.borderRadius, BorderRadius.circular(20));
      expect(find.text("Here's how collectors see it in the feed."), findsOneWidget);
      expect(find.byType(StudioStatusChip), findsOneWidget); // Available
    });

    testWidgets('PostNFSDone: no line under the heading; Not for sale as plain text, not a chip', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(_published()));
      await tester.pump();
      expect(find.byType(StudioIridescent), findsOneWidget);
      expect(find.text("Here's how collectors see it in the feed."), findsNothing);
      expect(find.byType(StudioStatusChip), findsNothing);
      final label = tester.widget<Text>(find.text('Not for sale'));
      expect((label.style!.fontSize, label.style!.color), (13, StudioColors.light.textSecondary));
    });

    testWidgets('ScenePosted: the Scene preview in the frame too', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(
          SceneLiveView(
            preview: _cover,
            isVideo: true,
            authorName: 'Amara Osei',
            avatarUrl: null,
            linkedPieces: const [],
            onClose: () {},
            onShare: () {},
            onView: () {},
          ),
        ),
      );
      await tester.pump();
      final frame = tester.widget<StudioIridescent>(find.byType(StudioIridescent));
      expect(frame.padding, const EdgeInsets.all(5));
      expect(tester.getSize(find.byType(StudioIridescent)), const Size(250, 437)); // 240 × 427 inside
    });

    testWidgets('PostError: the ! ring and Couldn\'t publish in red; the reason stays Graphite', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(PostErrorView(isScene: false, savedAt: null, onClose: () {}, onRetry: () {}, onDrafts: () {})),
      );
      await tester.pump();
      final red = StudioColors.light.alert;
      expect(tester.widget<Text>(find.text("Couldn't publish")).style!.color, red);
      expect(tester.widget<Text>(find.text('!')).style!.color, red);
      final reason = tester.widget<Text>(find.textContaining('The connection dropped'));
      expect(reason.style!.color, StudioColors.light.textSecondary);
    });

    testWidgets('reduced motion: the frame holds still, so the screen settles', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
            child: _published(priceLabel: r'$3,600'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StudioIridescent), findsOneWidget);
    });
  });

  group('events', () {
    StudioEvent event({String? zone, DateTime? start, DateTime? end}) => StudioEvent(
      id: 'e',
      title: 'Open Studio',
      startsAt: start ?? DateTime(2037, 11, 21, 20),
      endsAt: end ?? DateTime(2037, 11, 21, 22),
      timezoneName: zone,
    );

    test('every start time shows the event\'s zone when it is known', () {
      expect(eventStartLabel(event(zone: 'CST')), 'Sat, Nov 21 · 8:00 PM CST');
      expect(eventStartLabel(event()), 'Sat, Nov 21 · 8:00 PM');
      // An IANA name is not shown to a reader.
      expect(eventStartLabel(event(zone: 'America/Chicago')), 'Sat, Nov 21 · 8:00 PM');
    });

    test('the event page line drops the first PM when both times share it', () {
      expect(event(zone: 'CST').scheduleLine, 'Sat, Nov 21 · 8:00 – 10:00 PM CST');
      expect(
        event(start: DateTime(2037, 11, 21, 11), end: DateTime(2037, 11, 21, 14)).scheduleLine,
        'Sat, Nov 21 · 11:00 AM – 2:00 PM',
      );
    });

    test("the bar's ticket range", () {
      const free = EventTicketType(id: 'ga', name: 'General Admission');
      const vip = EventTicketType(id: 'vip', name: 'VIP', priceCents: 2500);
      const early = EventTicketType(id: 'early', name: 'Early', priceCents: 1000);
      expect(eventTicketRange(const [free]), 'Free');
      expect(eventTicketRange(const [vip]), r'$25');
      expect(eventTicketRange(const [free, vip]), r'Free to $25');
      expect(eventTicketRange(const [vip, early]), r'$10 to $25');
    });

    test('pieces for sale say how they reach the buyer; work on show does not', () {
      const sale = EventLineupItem(id: 'a', pieceId: 'a', mode: 'sale', priceCents: 100, deliveryMode: 'pickup');
      const ship = EventLineupItem(id: 'b', pieceId: 'b', mode: 'sale', priceCents: 100, deliveryMode: 'ship');
      const shown = EventLineupItem(id: 'c', pieceId: 'c', mode: 'featured', deliveryMode: 'pickup');
      const sold = EventLineupItem(
        id: 'd',
        pieceId: 'd',
        mode: 'sale',
        priceCents: 100,
        deliveryMode: 'pickup',
        pieceStatus: 'sold',
      );
      expect(eventPieceDeliveryLine(sale), 'Pickup at the event');
      expect(eventPieceDeliveryLine(ship), 'Ships after the event');
      expect(eventPieceDeliveryLine(shown), isNull);
      expect(eventPieceDeliveryLine(sold), isNull);
    });
  });
}
