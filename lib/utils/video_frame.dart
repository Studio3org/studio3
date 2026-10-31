import 'dart:io';
import 'dart:typed_data';

import 'package:easy_video_editor/easy_video_editor.dart';

/// A JPEG of the frame [atMs] into the video at [path], [width] wide (keeping its shape), or
/// null if it can't be read. Used for video covers and chat posters.
///
/// Uses `easy_video_editor`, already here for trimming: `video_thumbnail` (0.5.6, no longer
/// maintained) stopped building on Android once Gradle dropped `jcenter()`.
Future<Uint8List?> videoFrameJpeg(
  String path, {
  int atMs = 0,
  int width = 720,
  int quality = 80,
}) async {
  final out = await VideoEditorBuilder(videoPath: path).generateThumbnail(
    positionMs: atMs,
    quality: quality,
    width: width,
  );
  if (out == null) return null;
  final file = File(out);
  try {
    return await file.readAsBytes();
  } finally {
    try {
      await file.delete();
    } catch (_) {}
  }
}
