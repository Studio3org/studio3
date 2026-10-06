/// The printable links for an event — one per work on the bill, plus the event itself.
///
/// The URLs come from the server rather than being assembled client-side, so the code on the
/// wall and the link the app resolves cannot become two different opinions about what a
/// share URL looks like.
class EventQrCodes {
  const EventQrCodes({
    required this.eventId,
    required this.eventUrl,
    this.pieces = const [],
  });

  final String eventId;
  final String eventUrl;
  final List<EventQrCode> pieces;

  factory EventQrCodes.fromJson(Map<String, dynamic> json) => EventQrCodes(
        eventId: json['eventId'] as String? ?? '',
        eventUrl: json['eventUrl'] as String? ?? '',
        pieces: (json['pieces'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(EventQrCode.fromJson)
                .toList() ??
            const [],
      );
}

/// One work and the link its code carries.
class EventQrCode {
  const EventQrCode({
    required this.pieceId,
    required this.url,
    this.title,
    this.mode = 'featured',
    this.priceCents,
    this.mediaUrl,
    this.artistName,
    this.artistUsername,
  });

  final String pieceId;

  /// What the QR encodes: a link, not a token. It navigates; it admits nobody.
  final String url;

  final String? title;
  final String mode;
  final int? priceCents;
  final String? mediaUrl;

  /// Printed on the card. A gallery label without the artist's name is missing the point.
  final String? artistName;
  final String? artistUsername;

  /// What to print under the title, so whoever is placing the cards knows which is which.
  String get modeLabel {
    final price = priceCents == null ? null : '\$${(priceCents! / 100).toStringAsFixed(0)}';
    return switch (mode) {
      'bid' => price == null ? 'Auction' : 'Auction · from $price',
      'sale' => price == null ? 'For sale' : 'For sale · $price',
      _ => 'On show',
    };
  }

  factory EventQrCode.fromJson(Map<String, dynamic> json) => EventQrCode(
        pieceId: json['pieceId'] as String? ?? '',
        url: json['url'] as String? ?? '',
        title: json['title'] as String?,
        mode: json['mode'] as String? ?? 'featured',
        priceCents: (json['priceCents'] as num?)?.toInt(),
        mediaUrl: json['mediaUrl'] as String?,
        artistName: json['artistName'] as String?,
        artistUsername: json['artistUsername'] as String?,
      );
}
