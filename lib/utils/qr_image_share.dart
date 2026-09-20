import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Sharing one code as an image.
///
/// The PDF covers a whole room's worth of cards. This covers the other half of the job: a
/// host messaging one artist "here's the code for your piece", or dropping a single code
/// into a poster or an Instagram story.
///
/// Rendered straight from the QR painter rather than screenshotted from the widget tree, so
/// the image is exactly the code at whatever size is asked for — no surrounding UI, no device
/// pixel ratio to reason about, and no dependency on the code being on screen at the time.
abstract final class QrImageShare {
  QrImageShare._();

  /// Big enough to stay sharp if somebody drops it into a poster or prints it on its own.
  static const _size = 1024.0;

  /// Render [url] as a PNG.
  static Future<Uint8List> render(String url, {double size = _size}) async {
    final painter = QrPainter(
      data: url,
      version: QrVersions.auto,
      // Matches the printed card. A code shared as an image is just as likely to end up on
      // a wall as one from the PDF.
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      // Black on transparent would vanish against a dark chat background, and a QR needs
      // its light quiet zone to scan at all.
      emptyColor: const Color(0xFFFFFFFF),
    );
    final image = await painter.toImage(size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Could not render the code as an image.');
    }
    return data.buffer.asUint8List();
  }

  /// Render and hand to the system share sheet.
  ///
  /// The URL goes along as the share text, so a recipient whose app strips the image — or
  /// who simply cannot scan a code on the screen they are reading it from — still has
  /// something to tap.
  static Future<void> share({
    required String url,
    required String title,
    Rect? origin,
  }) async {
    final bytes = await render(url);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_slug(title)}-code.png');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        text: '$title\n$url',
        files: [XFile(file.path, mimeType: 'image/png')],
        sharePositionOrigin: origin,
      ),
    );
  }

  static String _slug(String title) {
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'studio3' : slug;
  }
}
