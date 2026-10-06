import 'dart:io';
import 'dart:typed_data';

import 'api_client.dart';
import 'api_exception.dart';

/// Presign `purpose` values — see docs/api/flows/media.md.
abstract final class MediaPurpose {
  static const profile = 'profile';
  static const cover = 'cover';
  static const piece = 'piece';
  static const post = 'post';
  static const chat = 'chat';
}

class PresignResult {
  const PresignResult({
    this.presignedPutUrl,
    required this.url,
    required this.key,
    this.devMode = false,
  });

  final String? presignedPutUrl;
  final String url;
  final String key;
  final bool devMode;

  factory PresignResult.fromJson(Map<String, dynamic> json) {
    return PresignResult(
      presignedPutUrl: json['presignedPutUrl'] as String?,
      url: json['url'] as String? ?? '',
      key: json['key'] as String? ?? '',
      devMode: json['devMode'] as bool? ?? false,
    );
  }
}

class MediaService {
  MediaService._();
  static final MediaService instance = MediaService._();

  static const int maxImageBytes = 20 * 1024 * 1024;
  static const int maxVideoBytes = 100 * 1024 * 1024;

  final _api = ApiClient.instance;

  static String contentTypeForPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' || 'm4v' || 'mov' => 'video/mp4',
      _ => 'image/jpeg',
    };
  }

  static bool isVideoContentType(String contentType) =>
      contentType.startsWith('video/');

  static void _validateSize(int byteLength, String contentType) {
    final isVideo = isVideoContentType(contentType);
    final maxBytes = isVideo ? maxVideoBytes : maxImageBytes;
    if (byteLength > maxBytes) {
      final maxMb = maxBytes ~/ (1024 * 1024);
      throw ApiException(
        isVideo
            ? 'Video must be ${maxMb}MB or smaller'
            : 'Image must be ${maxMb}MB or smaller',
      );
    }
  }

  Future<PresignResult> presign({
    required String purpose,
    required String contentType,
    String? pieceId,
    String? postId,
  }) async {
    final body = <String, dynamic>{
      'purpose': purpose,
      'contentType': contentType,
    };
    if (pieceId != null) body['pieceId'] = pieceId;
    if (postId != null) body['postId'] = postId;
    final json = await _api.post('/api/media/presign', body: body, auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    return PresignResult.fromJson(data);
  }

  Future<String> uploadBytes({
    required String purpose,
    required Uint8List bytes,
    required String contentType,
    String? pieceId,
    String? postId,
  }) async {
    _validateSize(bytes.length, contentType);
    final presign = await this.presign(
      purpose: purpose,
      contentType: contentType,
      pieceId: pieceId,
      postId: postId,
    );
    if (presign.url.isEmpty) {
      throw ApiException('Upload failed: server did not return a media URL');
    }
    final putUrl = presign.presignedPutUrl;
    if (!presign.devMode && putUrl != null && putUrl.isNotEmpty) {
      await _api.uploadToPresignedUrl(
        presignedPutUrl: putUrl,
        bytes: bytes,
        contentType: contentType,
      );
    }
    return presign.url;
  }

  Future<String> uploadFile({
    required String purpose,
    required File file,
    String? contentType,
    String? pieceId,
    String? postId,
  }) async {
    final bytes = await file.readAsBytes();
    return uploadBytes(
      purpose: purpose,
      bytes: bytes,
      contentType: contentType ?? contentTypeForPath(file.path),
      pieceId: pieceId,
      postId: postId,
    );
  }
}
