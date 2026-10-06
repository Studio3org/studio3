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

  int? get priceCents =>
      priceUsd == null ? null : (priceUsd! * 100).round();

  String? get dimensionsString {
    if (nonStandardFormat) {
      return nonStandardDescription?.trim().isNotEmpty == true
          ? 'non-standard: ${nonStandardDescription!.trim()}'
          : 'non-standard';
    }
    if (width == null && height == null && depth == null) return null;
    final w = width?.toString() ?? '?';
    final h = height?.toString() ?? '?';
    final d = depth?.toString() ?? '?';
    return '${w}x${h}x$d $dimensionUnit';
  }
}
