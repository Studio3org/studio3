import 'dart:io';
import 'dart:typed_data';

import '../data/post_material_options.dart';
import '../models/listing_details.dart';
import '../models/post_image_transform.dart';
import '../services/api_exception.dart';
import '../utils/crop_cover_math.dart' show CropAspectRatio;
import '../services/media_service.dart';
import '../services/piece_service.dart';
import '../services/post_service.dart';
import '../services/series_service.dart';
import '../utils/post_image_renderer.dart';

/// Draft state carried through the posting flow.
class PostDraft {
  const PostDraft({
    required this.postType,
    required this.imagePaths,
    this.mediaKind = 'image',
    this.videoPath,
    this.videoThumbnailBytes,
    this.title = '',
    this.description = '',
    this.mediumId,
    this.styleTags = const [],
    this.location,
    this.materials = const [],
    this.listingDetails,
    this.selectedSeriesId,
    this.newSeriesName,
    this.transforms = const [],
    this.previewImageIndex = 0,
    this.aiDisclosed = false,
    this.altText,
    this.linkedPieceId,
    this.isProcess = false,
    this.isForSale = false,
    this.status = 'live',
  });

  final String postType;
  final List<String> imagePaths;
  final String mediaKind;
  final String? videoPath;
  final Uint8List? videoThumbnailBytes;
  final String title;
  final String description;
  final String? mediumId;
  final List<String> styleTags;
  final String? location;
  final List<PostMaterialOption> materials;
  final ListingDetails? listingDetails;
  final String? selectedSeriesId;
  final String? newSeriesName;
  final List<PostImageTransform> transforms;
  final int previewImageIndex;
  final bool aiDisclosed;
  final String? altText;
  final String? linkedPieceId;
  final bool isProcess;
  final bool isForSale;

  /// `'live'` (default) or `'draft'` — a draft is created immediately but
  /// hidden from public feeds until later published (see profile grid's
  /// "Publish" action).
  final String status;

  bool get isVideo => mediaKind == 'video';

  PostDraft copyWith({
    String? postType,
    List<String>? imagePaths,
    String? mediaKind,
    String? videoPath,
    String? title,
    String? description,
    String? mediumId,
    List<String>? styleTags,
    String? location,
    List<PostMaterialOption>? materials,
    ListingDetails? listingDetails,
    String? selectedSeriesId,
    String? newSeriesName,
    List<PostImageTransform>? transforms,
    int? previewImageIndex,
    bool? aiDisclosed,
    String? altText,
    String? linkedPieceId,
    bool? isProcess,
    bool? isForSale,
    String? status,
  }) {
    return PostDraft(
      postType: postType ?? this.postType,
      imagePaths: imagePaths ?? this.imagePaths,
      mediaKind: mediaKind ?? this.mediaKind,
      videoPath: videoPath ?? this.videoPath,
      title: title ?? this.title,
      description: description ?? this.description,
      mediumId: mediumId ?? this.mediumId,
      styleTags: styleTags ?? this.styleTags,
      location: location ?? this.location,
      materials: materials ?? this.materials,
      listingDetails: listingDetails ?? this.listingDetails,
      selectedSeriesId: selectedSeriesId ?? this.selectedSeriesId,
      newSeriesName: newSeriesName ?? this.newSeriesName,
      transforms: transforms ?? this.transforms,
      previewImageIndex: previewImageIndex ?? this.previewImageIndex,
      aiDisclosed: aiDisclosed ?? this.aiDisclosed,
      altText: altText ?? this.altText,
      linkedPieceId: linkedPieceId ?? this.linkedPieceId,
      isProcess: isProcess ?? this.isProcess,
      isForSale: isForSale ?? this.isForSale,
      status: status ?? this.status,
    );
  }
}

class PostPublishService {
  PostPublishService._();
  static final PostPublishService instance = PostPublishService._();

  final _media = MediaService.instance;
  final _pieces = PieceService.instance;
  final _posts = PostService.instance;
  final _series = SeriesService.instance;

  Future<void> publish(PostDraft draft) async {
    final isScene = draft.postType == 'scene';
    final isVideo = draft.isVideo;
    final isListing = draft.isForSale;
    final purpose = isScene ? 'post' : 'piece';

    if (isVideo) {
      if (draft.videoPath == null || draft.videoPath!.isEmpty) {
        throw Exception('No video selected');
      }
      if (!isScene) {
        throw Exception('Video upload is only supported for scenes');
      }
      final mediaUrl = await _media.uploadFile(
        purpose: purpose,
        file: File(draft.videoPath!),
        // Always declare video — gallery temp paths may lack a .mp4 extension,
        // and contentTypeForPath would otherwise fall back to image/jpeg.
        contentType: 'video/mp4',
      );
      final thumbnailUrl = await _uploadVideoThumbnail(
        draft.videoThumbnailBytes,
        purpose,
      );
      await _posts.create({
        'mediaUrl': mediaUrl,
        'mediaType': 'video',
        if (draft.description.trim().isNotEmpty)
          'caption': draft.description.trim(),
        if (draft.linkedPieceId != null && draft.linkedPieceId!.isNotEmpty)
          'linkedPieceId': draft.linkedPieceId,
        if (draft.location != null && draft.location!.isNotEmpty)
          'location': draft.location,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        'isProcess': draft.isProcess,
        'status': draft.status,
      });
      return;
    }

    if (draft.imagePaths.isEmpty) {
      throw Exception('No image selected');
    }
    final imageIndex = draft.previewImageIndex.clamp(
      0,
      draft.imagePaths.length - 1,
    );
    final imagePath = draft.imagePaths[imageIndex];
    final transform = imageIndex < draft.transforms.length
        ? draft.transforms[imageIndex]
        : PostImageTransform();
    final bytes = await PostImageRenderer.render(
      imagePath: imagePath,
      transform: transform,
    );
    final mediaUrl = await _media.uploadBytes(
      purpose: purpose,
      bytes: bytes,
      contentType: 'image/png',
    );
    final mediaAspectRatio = transform.aspectRatio == CropAspectRatio.ratio16x9
        ? '16:9'
        : '3:4';

    if (isScene) {
      await _posts.create({
        'mediaUrl': mediaUrl,
        'mediaType': 'image',
        if (draft.description.trim().isNotEmpty)
          'caption': draft.description.trim(),
        if (draft.linkedPieceId != null && draft.linkedPieceId!.isNotEmpty)
          'linkedPieceId': draft.linkedPieceId,
        if (draft.location != null && draft.location!.isNotEmpty)
          'location': draft.location,
        'mediaAspectRatio': mediaAspectRatio,
        'isProcess': draft.isProcess,
        'status': draft.status,
      });
      return;
    }

    final caption = draft.description.trim();
    final materials = draft.materials.map((m) => m.name).toList();

    final body = <String, dynamic>{
      'title': draft.title.trim().isNotEmpty ? draft.title.trim() : 'Untitled',
      'mediaUrl': mediaUrl,
      'mediaType': 'image',
      if (caption.isNotEmpty) 'caption': caption,
      if (draft.mediumId != null) 'medium': draft.mediumId,
      if (draft.listingDetails?.yearCreated != null)
        'yearCreated': draft.listingDetails!.yearCreated,
      if (draft.listingDetails?.framingMounting?.trim().isNotEmpty == true)
        'framingMounting': draft.listingDetails!.framingMounting!.trim(),
      if (draft.listingDetails?.provenance?.trim().isNotEmpty == true)
        'provenance': draft.listingDetails!.provenance!.trim(),
      if (draft.listingDetails?.handlingNotes?.trim().isNotEmpty == true)
        'handlingNotes': draft.listingDetails!.handlingNotes!.trim(),
      if (materials.isNotEmpty) 'materials': materials,
      if (draft.styleTags.isNotEmpty) 'styleTags': draft.styleTags,
      if (draft.location != null && draft.location!.isNotEmpty)
        'location': draft.location,
      'mediaAspectRatio': mediaAspectRatio,
      'status': draft.status,
      'aiDisclosed': draft.aiDisclosed,
      if (draft.altText != null && draft.altText!.trim().isNotEmpty)
        'altText': draft.altText!.trim(),
      if (isListing) ...{
        'isForSale': true,
        if (draft.listingDetails?.priceCents != null)
          'priceCents': draft.listingDetails!.priceCents,
        if (draft.listingDetails?.dimensionsString != null)
          'dimensions': draft.listingDetails!.dimensionsString,
        if (draft.listingDetails?.location != null)
          'shippingRegion': draft.listingDetails!.location,
      },
    };

    final piece = await _pieces.create(body);
    await _assignPieceToSeries(draft, piece.id);
  }

  /// Uploads the poster-frame bytes captured at pick-time (via
  /// `AssetEntity.thumbnailDataWithSize`, the same proven mechanism the
  /// gallery grid itself uses — see `post_page.dart`) as a still image
  /// (same presign/S3 path as any other image), so Explore can show a real
  /// thumbnail instead of trying to decode the video file itself.
  /// Best-effort — a failure here shouldn't block the video post.
  Future<String?> _uploadVideoThumbnail(
    Uint8List? thumbnailBytes,
    String purpose,
  ) async {
    if (thumbnailBytes == null) return null;
    try {
      return await _media.uploadBytes(
        purpose: purpose,
        bytes: thumbnailBytes,
        contentType: 'image/jpeg',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _assignPieceToSeries(PostDraft draft, String pieceId) async {
    final newName = draft.newSeriesName?.trim();
    if (newName != null && newName.isNotEmpty) {
      await _series.create(name: newName, pieceIds: [pieceId]);
      return;
    }

    final seriesId = draft.selectedSeriesId;
    if (seriesId == null || seriesId.isEmpty) return;

    try {
      await _series.addPiece(seriesId, pieceId);
    } on ApiException catch (e) {
      if (e.statusCode == 400) {
        throw ApiException(
          e.message.isNotEmpty
              ? e.message
              : 'This piece is already in another series.',
        );
      }
      rethrow;
    }
  }
}
