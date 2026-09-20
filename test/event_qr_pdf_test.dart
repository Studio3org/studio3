import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/event_qr_code.dart';
import 'package:studio3/utils/event_qr_pdf.dart';

/// The sheet a host downloads and prints.
///
/// A PDF that throws while laying out is indistinguishable, from the host's side, from a
/// feature that does not exist — so the thing worth asserting is that it builds at all, for
/// the awkward shapes as well as the tidy one.
EventQrCodes _codes(int pieceCount, {String? artistName = 'Amara Osmei'}) {
  return EventQrCodes(
    eventId: 'e1',
    eventUrl: 'https://studio-3.co/share/event/e1',
    pieces: [
      for (var i = 0; i < pieceCount; i++)
        EventQrCode(
          pieceId: 'p$i',
          url: 'https://studio-3.co/share/piece/p$i',
          title: 'Piece $i',
          mode: i.isEven ? 'bid' : 'sale',
          priceCents: 40000 + i,
          artistName: artistName,
        ),
    ],
  );
}

void main() {
  test('builds a real PDF', () async {
    final bytes = await EventQrPdf.build(
      eventTitle: "Collector's Preview",
      codes: _codes(3),
    );

    expect(bytes.length, greaterThan(1000));
    // The PDF magic number. Cheap, and it catches a writer that produced something else.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('a half-full last page does not break the layout', () async {
    // Six cards to a page, so seven means a page with one card on it — the case where a
    // grid can stretch its only child across the whole sheet.
    final bytes = await EventQrPdf.build(eventTitle: 'Night Market', codes: _codes(6));

    expect(bytes.length, greaterThan(1000));
  });

  test('an event with nothing on the bill still yields its own code', () async {
    // The event's own code goes by the door, so a bill-less event is not an empty sheet.
    final bytes = await EventQrPdf.build(eventTitle: 'Open Studio', codes: _codes(0));

    expect(bytes.length, greaterThan(1000));
  });

  test('a missing artist name does not break a card', () async {
    final bytes = await EventQrPdf.build(
      eventTitle: 'Group Show',
      codes: _codes(2, artistName: null),
    );

    expect(bytes.length, greaterThan(1000));
  });

  test('long titles and odd characters survive', () async {
    final codes = EventQrCodes(
      eventId: 'e1',
      eventUrl: 'https://studio-3.co/share/event/e1',
      pieces: [
        EventQrCode(
          pieceId: 'p1',
          url: 'https://studio-3.co/share/piece/p1',
          title: 'An extremely long title that would not fit on one line of a printed card '
              'no matter how small the type were set',
          mode: 'bid',
          priceCents: 1250000,
          artistName: 'Ñoël O\'Brien-Smith',
        ),
      ],
    );

    final bytes = await EventQrPdf.build(eventTitle: 'Test', codes: codes);

    expect(bytes.length, greaterThan(1000));
  });
}
