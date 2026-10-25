import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/studio_event.dart';

/// What the RSVP button says and whether it does anything.
///
/// An RSVP is not a ticket — entry is free and open — so none of this copy may imply a
/// purchase or a door charge.
StudioEvent _event({
  String status = 'published',
  bool isHost = false,
  bool viewerIsGoing = false,
  bool isFull = false,
  int rsvpCount = 0,
  int? spotsLeft,
  int? capacity,
  Duration startsIn = const Duration(days: 3),
}) {
  final starts = DateTime.now().add(startsIn);
  return StudioEvent(
    id: 'e1',
    title: 'Collector\'s Preview',
    startsAt: starts,
    endsAt: starts.add(const Duration(hours: 3)),
    status: status,
    isHost: isHost,
    viewerIsGoing: viewerIsGoing,
    isFull: isFull,
    rsvpCount: rsvpCount,
    spotsLeft: spotsLeft,
    capacity: capacity,
  );
}

void main() {
  group('the RSVP button', () {
    test('invites an ordinary viewer to say they are going', () {
      final e = _event();

      expect(e.canRsvp, isTrue);
      expect(e.rsvpCtaLabel, "I'm going");
    });

    test('reflects an RSVP already made, and stays tappable to undo it', () {
      final e = _event(viewerIsGoing: true, rsvpCount: 1);

      expect(e.rsvpCtaLabel, "You're going");
      expect(e.canRsvp, isTrue, reason: 'changing your mind has to be possible');
    });

    test('a full event says so and goes inert', () {
      final e = _event(isFull: true, spotsLeft: 0, capacity: 20, rsvpCount: 20);

      expect(e.rsvpCtaLabel, 'Event is full');
      expect(e.canRsvp, isFalse);
    });

    test('someone already going is unaffected by the event being full', () {
      // Otherwise the last person to get a place could never give it back.
      final e = _event(isFull: true, viewerIsGoing: true, spotsLeft: 0, rsvpCount: 20);

      expect(e.canRsvp, isTrue);
    });

    test('the host is not offered an RSVP to their own event', () {
      expect(_event(isHost: true).canRsvp, isFalse);
    });

    test('a finished event takes no more RSVPs', () {
      expect(_event(startsIn: const Duration(days: -5)).canRsvp, isFalse);
    });

    test('a draft takes no RSVPs', () {
      expect(_event(status: 'draft').canRsvp, isFalse);
    });

    test('a cancelled event takes no RSVPs', () {
      expect(_event(status: 'cancelled').canRsvp, isFalse);
    });
  });

  group('the line under the button', () {
    test('an uncapped event shows the headcount alone', () {
      // There is no number of places to report, and inventing one would imply a limit that
      // does not exist.
      expect(_event(rsvpCount: 12).rsvpSummary, '12 going');
    });

    test('a capped event shows what is left', () {
      expect(_event(rsvpCount: 12, spotsLeft: 8).rsvpSummary, '12 going · 8 places left');
    });

    test('singulars read properly', () {
      expect(_event(rsvpCount: 1, spotsLeft: 1).rsvpSummary, '1 going · 1 place left');
    });

    test('a full event says full rather than zero places left', () {
      expect(_event(rsvpCount: 20, spotsLeft: 0).rsvpSummary, '20 going · full');
    });
  });

  group('entry stays free', () {
    test('the price label never implies a charge', () {
      expect(_event().priceLabel, 'Free');
      expect(_event().isFree, isTrue);
    });
  });
}
