import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../models/post_image_transform.dart';
import 'crop_cover_math.dart' show CropFitMode;
import 'image_adjust_math.dart';

/// Bakes a [PostImageTransform] (crop box, rotation, flip, fit mode,
/// brightness/contrast/exposure) into real image bytes, matching exactly
/// what the edit screen's live preview shows — so the uploaded image is
/// what the user actually chose, not the original untouched file.
abstract final class PostImageRenderer {
  static const double maxOutputLongSide = 1920;

  static Future<Uint8List> render({
    required String imagePath,
    required PostImageTransform transform,
  }) async {
    final sourceBytes = await _loadSourceBytes(imagePath);
    final codec = await ui.instantiateImageCodec(sourceBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      return await _renderTransformed(image, transform);
    } finally {
      image.dispose();
    }
  }

  static Future<Uint8List> _loadSourceBytes(String path) async {
    if (path.startsWith('assets/')) {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    }
    return File(path).readAsBytes();
  }

  static Future<Uint8List> _renderTransformed(
    ui.Image image,
    PostImageTransform transform,
  ) async {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final imageAspect = imgW / imgH;
    final ratio = transform.aspectValue;

    double outW;
    double outH;
    if (ratio >= 1) {
      outW = maxOutputLongSide;
      outH = outW / ratio;
    } else {
      outH = maxOutputLongSide;
      outW = outH * ratio;
    }

    // Same coordinate contract as PostCropPreview: rect is normalized to
    // the image's own width/height fractions.
    final rect = transform.resolvedCropRect(imageAspect);
    final radians = transform.rotationDegrees * math.pi / 180;
    final flipX = transform.flipHorizontal ? -1.0 : 1.0;
    final flipY = transform.flipVertical ? -1.0 : 1.0;
    final rectCenterX = (rect.left + rect.right) / 2 * imgW;
    final rectCenterY = (rect.top + rect.bottom) / 2 * imgH;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, outW, outH),
    );

    final paint = ui.Paint();
    if (!ImageAdjustMath.isNeutral(
      brightness: transform.brightness,
      contrast: transform.contrast,
      exposure: transform.exposure,
      warmth: transform.warmth,
    )) {
      paint.colorFilter = ui.ColorFilter.matrix(
        ImageAdjustMath.combinedMatrix(
          brightness: transform.brightness,
          contrast: transform.contrast,
          exposure: transform.exposure,
          warmth: transform.warmth,
        ),
      );
    }

    if (transform.fitMode == CropFitMode.fill) {
      // The box's fraction-space aspect already matches `ratio` (Fill
      // locks it), so mapping it straight onto the full output canvas
      // fills edge-to-edge with no gaps.
      canvas.clipRect(ui.Rect.fromLTWH(0, 0, outW, outH));
      final scale = outW / (rect.width * imgW);
      canvas.translate(outW / 2, outH / 2);
      canvas.rotate(radians);
      canvas.scale(flipX * scale, flipY * scale);
      canvas.translate(-rectCenterX, -rectCenterY);
      canvas.drawImage(image, ui.Offset.zero, paint);
    } else {
      // Fit: the box can be any shape, so letterbox its own aspect ratio
      // into the output canvas — black bars fill whatever's left over.
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, outW, outH),
        ui.Paint()..color = const ui.Color(0xFF000000),
      );
      final subimageAspect = (rect.width / rect.height) * imageAspect;
      double windowW;
      double windowH;
      if (subimageAspect >= ratio) {
        windowW = outW;
        windowH = outW / subimageAspect;
      } else {
        windowH = outH;
        windowW = outH * subimageAspect;
      }
      final windowLeft = (outW - windowW) / 2;
      final windowTop = (outH - windowH) / 2;
      final scale = windowW / (rect.width * imgW);

      canvas.save();
      canvas.clipRect(ui.Rect.fromLTWH(windowLeft, windowTop, windowW, windowH));
      canvas.translate(windowLeft + windowW / 2, windowTop + windowH / 2);
      canvas.rotate(radians);
      canvas.scale(flipX * scale, flipY * scale);
      canvas.translate(-rectCenterX, -rectCenterY);
      canvas.drawImage(image, ui.Offset.zero, paint);
      canvas.restore();
    }

    final picture = recorder.endRecording();
    try {
      final rendered = await picture.toImage(outW.round(), outH.round());
      try {
        final byteData =
            await rendered.toByteData(format: ui.ImageByteFormat.png);
        return byteData!.buffer.asUint8List();
      } finally {
        rendered.dispose();
      }
    } finally {
      picture.dispose();
    }
  }
}
