import 'dart:async';

import 'package:flutter/material.dart';

/// Detects a posted image's real (baked-in) aspect ratio and snaps it to
/// whichever of the four posting sizes — 1:1, 3:4, 9:16 or 16:9 — it
/// actually is. A scene (image or video) is always cropped to exactly one
/// of those four at posting time (see `PostImageRenderer` and
/// `SceneVideoEditPage`'s own crop step), so this is a reliable source of
/// truth, unlike heuristics based on unrelated metadata (listing
/// "dimensions" strings, media type, etc.). A piece's own images are
/// narrower — still only ever 3:4 or 16:9 — but snapping against all four
/// is harmless for those too, since a piece never produces 1:1 or 9:16 to
/// begin with.
abstract final class ImageAspectRatioResolver {
  static const double portrait3x4 = 3 / 4;
  static const double landscape16x9 = 16 / 9;
  static const double square1x1 = 1;
  static const double portrait9x16 = 9 / 16;

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

  /// Snaps any raw width/height ratio to whichever of the four posting
  /// ratios it's closer to — shared by the image feed and the video player
  /// so both agree on the same boundaries.
  static double snap(double raw) {
    const ratios = [portrait9x16, portrait3x4, square1x1, landscape16x9];
    return ratios.reduce(
      (closest, candidate) =>
          (raw - candidate).abs() < (raw - closest).abs() ? candidate : closest,
    );
  }
}
