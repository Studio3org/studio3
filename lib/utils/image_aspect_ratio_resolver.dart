import 'dart:async';

import 'package:flutter/material.dart';

/// Detects a posted image's real (baked-in) aspect ratio and snaps it to
/// whichever of the two posting sizes — 3:4 or 16:9 — it actually is.
/// Posting always bakes to exactly one of those two ratios (see
/// `PostImageRenderer`), so this is a reliable source of truth, unlike
/// heuristics based on unrelated metadata (listing "dimensions" strings,
/// media type, etc.).
abstract final class ImageAspectRatioResolver {
  static const double portrait3x4 = 3 / 4;
  static const double landscape16x9 = 16 / 9;

  static final Map<String, double> _cache = {};

  /// Returns a cached ratio if already resolved, otherwise null.
  static double? cached(String url) => _cache[url];

  static Future<double> resolve(String url) async {
    final cached = _cache[url];
    if (cached != null) return cached;

    final raw = await _decode(url);
    final snapped = snap(raw ?? portrait3x4);
    _cache[url] = snapped;
    return snapped;
  }

  static Future<double?> _decode(String url) {
    final completer = Completer<double?>();
    final stream = NetworkImage(url).resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, synchronousCall) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (!completer.isCompleted) {
          completer.complete(h == 0 ? null : w / h);
        }
        stream.removeListener(listener);
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) completer.complete(null);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// Snaps any raw width/height ratio to whichever of the two posting
  /// ratios (3:4 or 16:9) it's closer to — shared by the image feed and the
  /// video player so both agree on the same boundary.
  static double snap(double raw) {
    final portraitDiff = (raw - portrait3x4).abs();
    final landscapeDiff = (raw - landscape16x9).abs();
    return portraitDiff <= landscapeDiff ? portrait3x4 : landscape16x9;
  }
}
