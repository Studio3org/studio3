/// Piece details collected on the posting flow's details step (`PostDetailsForSale`).
class ListingDetails {
  const ListingDetails({
    this.priceUsd,
    this.width,
    this.height,
    this.depth,
    this.dimensionUnit = 'in',
    this.weight,
    this.weightUnit = 'lb',
    this.framingMounting,
    this.location,
    this.provenance,
    this.yearCreated,
    this.edition,
    this.signed,
    this.handlingNotes,
  });

  final double? priceUsd;
  final double? width;
  final double? height;
  final double? depth;
  final String dimensionUnit;

  /// For shipping quotes only; never shown on the piece.
  final double? weight;
  final String weightUnit;
  final String? framingMounting;

  /// The city a sale ships from (sent as the shipping region).
  final String? location;
  final String? provenance;
  final int? yearCreated;
  final String? edition;
  final bool? signed;
  final String? handlingNotes;

  int? get priceCents => priceUsd == null ? null : (priceUsd! * 100).round();

  double? get weightKg {
    final w = weight;
    if (w == null) return null;
    return weightUnit == 'kg' ? w : double.parse((w * 0.45359237).toStringAsFixed(3));
  }

  /// "24x36x1.5 in", or "24x36 in" without a depth.
  String? get dimensionsString {
    if (width == null && height == null && depth == null) return null;
    final parts = [width, height, if (depth != null) depth].map((v) => v == null ? '?' : _num(v));
    return '${parts.join('x')} $dimensionUnit';
  }

  /// "24 × 36 × 1.5 in" for the review.
  String? get dimensionsLabel => dimensionsString?.replaceAll('x', ' × ');

  static String _num(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  static String formatNumber(double v) => _num(v);
}
