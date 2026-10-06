import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/utils/qr_image_share.dart';

/// Rendering one code as an image.
///
/// Rendered from the QR painter rather than screenshotted from the widget tree, so this can
/// be checked without putting anything on screen — which is also why it works for a code the
/// host is not currently looking at.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('produces a real PNG', () async {
    final bytes = await QrImageShare.render('https://studio-3.co/share/piece/p1');

    expect(bytes.length, greaterThan(500));
    // PNG magic number. Cheap, and it catches a renderer that produced something else.
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  test('a long URL still encodes', () async {
    // QR capacity is finite and a share link with a UUID in it is not short.
    final long = 'https://api.studio-3.co/share/piece/'
        '0f4d1a8c-1111-2222-3333-444455556666';

    final bytes = await QrImageShare.render(long);

    expect(bytes.length, greaterThan(500));
  });

  test('renders at the size asked for', () async {
    // Big enough to stay sharp in a poster; a code shared as an image is as likely to be
    // printed as one from the PDF.
    final small = await QrImageShare.render('https://studio-3.co/p/1', size: 128);
    final large = await QrImageShare.render('https://studio-3.co/p/1', size: 1024);

    expect(large.length, greaterThan(small.length));
  });

  test('the custom scheme encodes too', () async {
    // What the codes fall back to before any domain is pointed anywhere.
    final bytes = await QrImageShare.render('studio3://piece/p1');

    expect(bytes.length, greaterThan(500));
  });
}
