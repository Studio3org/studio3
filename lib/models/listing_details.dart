/// Piece details collected on the posting flow's details step (`PostDetailsForSale`).
///
/// Also carries the fields the earlier listing forms collected (packaged size, declared
/// value, listing type; restored from before commit 76f4ef9).
class ListingDetails {
  const ListingDetails({
    this.priceUsd,
    this.width,
    this.height,
    this.depth,
    this.dimensionUnit = 'in',
    this.nonStandardFormat = false,
    this.nonStandardDescription,
    this.weight,
    this.weightUnit = 'lb',
    double? weightKg,
    this.framingMounting,
    this.location,
    this.provenance,
    this.yearCreated,
    this.edition,
    this.signed,
    this.handlingNotes,
    this.packageLength,
    this.packageWidth,
    this.packageHeight,
    this.packageUnit = 'in',
    this.declaredValueUsd,
    this.listingType,
    this.auctionDurationDays,
  }) : _weightKg = weightKg;

  final double? priceUsd;
  final double? width;
  final double? height;
  final double? depth;
  final String dimensionUnit;
  final bool nonStandardFormat;
  final String? nonStandardDescription;

  /// For shipping quotes only; never shown on the piece.
  final double? weight;
  final String weightUnit;

  /// A weight already in kilograms (the earlier forms); [weight] / [weightUnit] otherwise.
  final double? _weightKg;
  final String? framingMounting;

  /// The city a sale ships from (sent as the shipping region).
  final String? location;
  final String? provenance;
  final int? yearCreated;
  final String? edition;
  final bool? signed;
  final String? handlingNotes;

  /// Shipping attributes the courier prices on. Packaged size is deliberately separate from
  /// the artwork's own dimensions above — crating and framing add bulk, and a courier quotes
  /// on the box, not the canvas.
  final double? packageLength;
  final double? packageWidth;
  final double? packageHeight;
  final String packageUnit;
  final double? declaredValueUsd;

  /// `'fixed'` or `'auction'` when the piece is listed for sale.
  final String? listingType;
  final int? auctionDurationDays;

  int? get priceCents => priceUsd == null ? null : (priceUsd! * 100).round();

  int? get declaredValueCents =>
      declaredValueUsd == null ? null : (declaredValueUsd! * 100).round();

  double? get weightKg {
    if (_weightKg != null) return _weightKg;
    final w = weight;
    if (w == null) return null;
    return weightUnit == 'kg' ? w : double.parse((w * 0.45359237).toStringAsFixed(3));
  }

  static const _cmPerInch = 2.54;

  /// The API stores packaged dimensions in centimetres, so convert here rather than sending
  /// a unit the backend would have to interpret.
  double? _toCm(double? value) {
    if (value == null) return null;
    return packageUnit == 'cm' ? value : value * _cmPerInch;
  }

  double? get packageLengthCm => _toCm(packageLength);
  double? get packageWidthCm => _toCm(packageWidth);
  double? get packageHeightCm => _toCm(packageHeight);

  /// "24x36x1.5 in", or "24x36 in" without a depth.
  String? get dimensionsString {
    if (width == null && height == null && depth == null) return null;
    final parts = [width, height, if (depth != null) depth].map((v) => v == null ? '?' : _num(v));
    return '${parts.join('x')} $dimensionUnit';
  }

  /// "24 × 36 × 1.5 in" for the review.
  String? get dimensionsLabel => dimensionsString?.replaceAll('x', ' × ');

  ListingDetails copyWith({
    double? priceUsd,
    double? width,
    double? height,
    double? depth,
    String? dimensionUnit,
    bool? nonStandardFormat,
    String? nonStandardDescription,
    String? framingMounting,
    String? location,
    String? provenance,
    int? yearCreated,
    String? handlingNotes,
    double? weightKg,
    double? packageLength,
    double? packageWidth,
    double? packageHeight,
    String? packageUnit,
    double? declaredValueUsd,
    String? listingType,
    int? auctionDurationDays,
  }) {
    return ListingDetails(
      priceUsd: priceUsd ?? this.priceUsd,
      width: width ?? this.width,
      height: height ?? this.height,
      depth: depth ?? this.depth,
      dimensionUnit: dimensionUnit ?? this.dimensionUnit,
      nonStandardFormat: nonStandardFormat ?? this.nonStandardFormat,
      nonStandardDescription: nonStandardDescription ?? this.nonStandardDescription,
      weight: weight,
      weightUnit: weightUnit,
      weightKg: weightKg ?? _weightKg,
      framingMounting: framingMounting ?? this.framingMounting,
      location: location ?? this.location,
      provenance: provenance ?? this.provenance,
      yearCreated: yearCreated ?? this.yearCreated,
      edition: edition,
      signed: signed,
      handlingNotes: handlingNotes ?? this.handlingNotes,
      packageLength: packageLength ?? this.packageLength,
      packageWidth: packageWidth ?? this.packageWidth,
      packageHeight: packageHeight ?? this.packageHeight,
      packageUnit: packageUnit ?? this.packageUnit,
      declaredValueUsd: declaredValueUsd ?? this.declaredValueUsd,
      listingType: listingType ?? this.listingType,
      auctionDurationDays: auctionDurationDays ?? this.auctionDurationDays,
    );
  }

  static String _num(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  static String formatNumber(double v) => _num(v);
}
