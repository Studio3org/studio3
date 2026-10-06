import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/event_qr_code.dart';

/// The sheet of cards a host prints and puts beside the work.
///
/// This exists because the alternative was asking a host to screenshot twenty codes off a
/// screen, or paste links into somebody else's QR generator — which is telling them to leave
/// the app to do the one thing the feature is for.
///
/// The codes are **vector**, drawn by the PDF itself rather than rasterised from the screen.
/// That matters more than it sounds: a bitmap sized for a phone turns to mush enlarged onto
/// a card, and a QR that a camera has to work at is a QR nobody scans in a gallery with
/// indifferent lighting.
///
/// Laid out six to a page with cut lines, because the output is meant to be guillotined into
/// cards rather than admired as a document.
abstract final class EventQrPdf {
  EventQrPdf._();

  /// Cards per page. Two columns of three gives a card big enough that the code reads from
  /// arm's length while someone is holding a drink.
  static const _columns = 2;
  static const _rows = 3;
  static const _perPage = _columns * _rows;

  static Future<Uint8List> build({
    required String eventTitle,
    required EventQrCodes codes,
  }) async {
    final doc = pw.Document(title: '$eventTitle — codes', theme: await _theme());
    final cards = <_Card>[
      // The event's own code first: somewhere by the door, so people arriving can see the
      // whole bill rather than only whatever they happen to be standing in front of.
      _Card(
        title: eventTitle,
        subtitle: 'The whole event',
        url: codes.eventUrl,
        prompt: 'Scan to see everything on show',
      ),
      for (final piece in codes.pieces)
        _Card(
          title: piece.title ?? 'Untitled',
          subtitle: [
            if (piece.artistName != null) piece.artistName!,
            piece.modeLabel,
          ].join(' · '),
          url: piece.url,
          prompt: piece.mode == 'bid'
              ? 'Scan to bid'
              : piece.mode == 'sale'
                  ? 'Scan to buy'
                  : 'Scan to see this piece',
        ),
    ];

    for (var start = 0; start < cards.length; start += _perPage) {
      final page = cards.skip(start).take(_perPage).toList();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => _pageBody(page, eventTitle),
        ),
      );
    }

    return doc.save();
  }

  /// A typeface that can actually spell the artists' names.
  ///
  /// The PDF default is Helvetica, which is Latin-1 only — so an artist called Ø, Ł, 李 or
  /// अनु comes out as a box or nothing at all, on a card printed and put beside their work.
  /// That is a bad way to introduce somebody.
  ///
  /// Fetched the same way the app gets its screen fonts. If the fetch fails the document
  /// still builds with the default face: a host preparing cards on gallery wifi should get a
  /// sheet with an imperfect name on it rather than no sheet at all.
  static Future<pw.ThemeData?> _theme() async {
    try {
      return pw.ThemeData.withFont(
        base: await PdfGoogleFonts.notoSansRegular(),
        bold: await PdfGoogleFonts.notoSansBold(),
      );
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _pageBody(List<_Card> cards, String eventTitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          eventTitle,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 8),
        pw.Expanded(
          child: pw.GridView(
            crossAxisCount: _columns,
            childAspectRatio: 0.78,
            children: [
              for (final card in cards) _cardWidget(card),
              // Pad the last page so a half-full sheet keeps the same card size rather than
              // stretching two cards across the whole page.
              for (var i = cards.length; i < _perPage; i++) pw.SizedBox(),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _cardWidget(_Card card) {
    return pw.Container(
      margin: const pw.EdgeInsets.all(6),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        // A cut line, not decoration: whoever trims these needs to see where.
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            card.title,
            maxLines: 2,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          if (card.subtitle.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              card.subtitle,
              maxLines: 1,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
          pw.SizedBox(height: 10),
          pw.Expanded(
            child: pw.BarcodeWidget(
              // Vector, drawn at print resolution rather than scaled up from a screenshot.
              barcode: pw.Barcode.qrCode(
                // Medium recovery: survives a thumbprint or a scuff on a card that will be
                // handled all evening, without making the code dense enough to defeat a
                // phone camera across a room.
                errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium,
              ),
              data: card.url,
              drawText: false,
              // White margin around the code. A QR printed flush to an edge is measurably
              // harder for a camera to lock onto.
              padding: const pw.EdgeInsets.all(6),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            card.prompt,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _Card {
  const _Card({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.prompt,
  });

  final String title;
  final String subtitle;
  final String url;
  final String prompt;
}
