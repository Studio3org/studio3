/// Listing-specific fields collected in the listing details step.
class ListingDetails {
  const ListingDetails({
    this.priceUsd,
    this.width,
    this.height,
    this.depth,
    this.dimensionUnit = 'in',
    this.nonStandardFormat = false,
    this.nonStandardDescription,
    this.framingMounting,
    this.location,
    this.provenance,
    this.yearCreated,
    this.handlingNotes,
    this.weightKg,
    this.packageLength,
    this.packageWidth,
    this.packageHeight,
    this.packageUnit = 'in',
    this.declaredValueUsd,
    this.listingType,
    this.auctionDurationDays,
  });

  final double? priceUsd;
  final double? width;
  final double? height;
  final double? depth;
  final String dimensionUnit;
  final bool nonStandardFormat;
  final String? nonStandardDescription;
  final String? framingMounting;
  final String? location;
  final String? provenance;
  final int? yearCreated;
  final String? handlingNotes;

  /// Shipping attributes the courier prices on. Packaged size is deliberately
  /// separate from the artwork's own dimensions above — crating and framing add
  /// bulk, and a courier quotes on the box, not the canvas.
  final double? weightKg;
  final double? packageLength;
  final double? packageWidth;
  final double? packageHeight;
  final String packageUnit;
  final double? declaredValueUsd;

  /// `'fixed'` or `'auction'` when the piece is listed for sale.
  final String? listingType;
  final int? auctionDurationDays;

  int? get priceCents =>
      priceUsd == null ? null : (priceUsd! * 100).round();

  int? get declaredValueCents =>
      declaredValueUsd == null ? null : (declaredValueUsd! * 100).round();

  static const _cmPerInch = 2.54;

  /// The API stores packaged dimensions in centimetres, so convert here rather
  /// than sending a unit the backend would have to interpret.
  double? _toCm(double? value) {
    if (value == null) return null;
    return packageUnit == 'cm' ? value : value * _cmPerInch;
  }

  double? get packageLengthCm => _toCm(packageLength);
  double? get packageWidthCm => _toCm(packageWidth);
  double? get packageHeightCm => _toCm(packageHeight);

  String? get dimensionsString {
    if (nonStandardFormat) {
      return nonStandardDescription?.trim().isNotEmpty == true
          ? 'non-standard: ${nonStandardDescription!.trim()}'
          : 'non-standard';
    }
    if (width == null && height == null && depth == null) return null;
    final w = width?.toString() ?? '?';
    final h = height?.toString() ?? '?';
    if (depth == null) return '${w}x$h $dimensionUnit';
    return '${w}x${h}x$depth $dimensionUnit';
  }

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
      nonStandardDescription:
          nonStandardDescription ?? this.nonStandardDescription,
      framingMounting: framingMounting ?? this.framingMounting,
      location: location ?? this.location,
      provenance: provenance ?? this.provenance,
      yearCreated: yearCreated ?? this.yearCreated,
      handlingNotes: handlingNotes ?? this.handlingNotes,
      weightKg: weightKg ?? this.weightKg,
      packageLength: packageLength ?? this.packageLength,
      packageWidth: packageWidth ?? this.packageWidth,
      packageHeight: packageHeight ?? this.packageHeight,
      packageUnit: packageUnit ?? this.packageUnit,
      declaredValueUsd: declaredValueUsd ?? this.declaredValueUsd,
      listingType: listingType ?? this.listingType,
      auctionDurationDays: auctionDurationDays ?? this.auctionDurationDays,
    );
  }
}
