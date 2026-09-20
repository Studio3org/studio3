import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/screens/scan_qr_page.dart';
import 'package:studio3/utils/app_destination.dart';

/// Reading a scanned code.
///
/// The code carries a link, not a token — so all this has to do is recognise a Studio 3 URL
/// in either of the two shapes one can take, from any host that serves them.
void main() {
  group('a printed https code', () {
    test('opens the piece it points at', () {
      final d = ScanQrPage.destinationFor(
        'https://studio3-backend.onrender.com/share/piece/p1',
      );

      expect(d.type, AppDestinationType.piece);
      expect(d.id, 'p1');
    });

    test('works from the production domain too', () {
      // The host is deliberately not checked: staging and production serve the same links,
      // and a scanner that only knew one would break the day the domain is switched.
      final d = ScanQrPage.destinationFor('https://studio-3.co/share/piece/p1');

      expect(d.type, AppDestinationType.piece);
      expect(d.id, 'p1');
    });

    test('an event code opens the event', () {
      final d = ScanQrPage.destinationFor('https://studio-3.co/share/event/e1');

      expect(d.type, AppDestinationType.event);
      expect(d.id, 'e1');
    });

    test('a bare link without the share prefix works as well', () {
      expect(
        ScanQrPage.destinationFor('https://studio-3.co/piece/p1').type,
        AppDestinationType.piece,
      );
    });
  });

  group('the custom scheme', () {
    test('resolves without any domain being pointed anywhere', () {
      // This is what makes the whole flow testable before Universal Links verify.
      final d = ScanQrPage.destinationFor('studio3://piece/p1');

      expect(d.type, AppDestinationType.piece);
      expect(d.id, 'p1');
    });

    test('carries events too', () {
      expect(
        ScanQrPage.destinationFor('studio3://event/e1').type,
        AppDestinationType.event,
      );
    });
  });

  group('anything else', () {
    test('somebody elses QR code resolves to nothing', () {
      expect(ScanQrPage.destinationFor('https://example.com/hello').isKnown, isFalse);
      expect(ScanQrPage.destinationFor('WIFI:S=cafe;T=WPA;P=hunter2;;').isKnown, isFalse);
    });

    test('plain text and empty codes do not throw', () {
      expect(ScanQrPage.destinationFor('just some text').isKnown, isFalse);
      expect(ScanQrPage.destinationFor('').isKnown, isFalse);
    });

    test('surrounding whitespace is tolerated', () {
      expect(
        ScanQrPage.destinationFor('  https://studio-3.co/share/piece/p1  ').type,
        AppDestinationType.piece,
      );
    });
  });
}
