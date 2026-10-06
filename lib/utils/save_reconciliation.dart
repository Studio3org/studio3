import '../services/api_exception.dart';

/// Attempts to tell whether a write that failed with an ambiguous network
/// error (see [ApiException.ambiguous]) actually succeeded server-side, by
/// refetching the authoritative list and checking for a just-submitted
/// match. Only meaningful for create operations — a failed update is
/// idempotent to retry regardless, since it just overwrites the same row.
///
/// Returns true if a match was found (the caller should treat the write as
/// successful); false if the error wasn't ambiguous, wasn't an
/// [ApiException], the refetch itself failed, or no match was found (the
/// caller should show the error and allow a normal retry).
Future<bool> reconcileAmbiguousWrite<T>({
  required Object error,
  required Future<List<T>> Function() fetchCurrent,
  required bool Function(T candidate) matches,
}) async {
  if (error is! ApiException || !error.ambiguous) return false;
  try {
    final current = await fetchCurrent();
    return current.any(matches);
  } catch (_) {
    // Don't let a failed reconciliation attempt mask the original error.
    return false;
  }
}
