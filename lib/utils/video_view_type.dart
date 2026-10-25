import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Android Impeller + texture-backed video often produces green macroblock
/// tearing on MediaTek/Mali devices. Platform views avoid that path.
VideoViewType resolveVideoViewType() {
  if (kIsWeb) return VideoViewType.textureView;
  return Platform.isAndroid
      ? VideoViewType.platformView
      : VideoViewType.textureView;
}
