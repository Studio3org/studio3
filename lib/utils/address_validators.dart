/// Client-side validation for the address form — UI feedback only, the
/// backend is the actual source of truth.
abstract final class AddressValidators {
  static String? zip(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Zip code is required';
    // US 5-digit, or ZIP+4 — matches this app's US-only state list.
    if (!RegExp(r'^\d{5}(-\d{4})?$').hasMatch(v)) {
      return 'Enter a valid US zip code';
    }
    return null;
  }
}
