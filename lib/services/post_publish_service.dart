import 'dart:io';
import 'dart:typed_data';

import '../data/post_material_options.dart';
import '../models/listing_details.dart';
import '../models/piece_summary.dart';
import '../models/auction.dart';
import '../models/post_image_transform.dart';
import '../models/post_summary.dart';
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
    this.mediumIds = const [],
    this.styleTags = const [],
    this.location,
    this.materials = const [],
    this.listingDetails,
    this.selectedSeriesId,
    this.newSeriesName,
    this.newSeriesDescription,
    this.auction,
    this.relatedScenes = const [],
    this.transforms = const [],
    this.previewImageIndex = 0,
    this.aiDisclosed = false,
    this.altText,
    this.linkedPieceIds = const [],
    this.linkedPieceId,
    this.isProcess = false,
    this.isForSale = false,
  });

  final String postType;

  /// Pieces: every photo in order, the first is the cover. Scenes: the photo at
  /// [previewImageIndex] is posted.
  final List<String> imagePaths;
  final String mediaKind;
  final String? videoPath;
  final Uint8List? videoThumbnailBytes;
  final String title;
  final String description;

  /// Every medium picked, in order; the first is the one shown and filtered on.
  final List<String> mediumIds;
  final List<String> styleTags;
  final String? location;
  final List<PostMaterialOption> materials;
  final ListingDetails? listingDetails;
  final String? selectedSeriesId;
  final String? newSeriesName;
  final String? newSeriesDescription;
  final List<PostImageTransform> transforms;
  final int previewImageIndex;
  final bool aiDisclosed;
  final String? altText;

  /// Scenes: the pieces it shows on, in order.
  final List<String> linkedPieceIds;

  /// The single linked piece of the earlier Scene flow (restored `SceneCreatePage`); used
  /// when [linkedPieceIds] is empty.
  final String? linkedPieceId;

  List<String> get _linkedIds => linkedPieceIds.isNotEmpty
      ? linkedPieceIds
      : [if (linkedPieceId != null && linkedPieceId!.isNotEmpty) linkedPieceId!];
  final bool isProcess;
  final bool isForSale;

  /// Set when the piece is posted for auction (`PostAvailAuction`).
  final AuctionTerms? auction;

  /// Pieces: Scenes to link to it once it exists (`PostRelatedScenes`).
  final List<PostSummary> relatedScenes;

  bool get isVideo => mediaKind == 'video';
}

class PostPublishService {
  PostPublishService._();
  static final PostPublishService instance = PostPublishService._();

  final _media = MediaService.instance;
  final _pieces = PieceService.instance;
  final _posts = PostService.instance;
  final _series = SeriesService.instance;

  /// Uploads a piece's photos and saves it as a **draft** (with its series), so a failure
  /// after this point loses nothing (`PostError`). [goLive] then publishes it.
  ///
  /// An auction is created **live** instead: the server opens an auction only when its
  /// piece is created live, and a draft auction taken live later never opens
  /// (BACKEND_CHANGES B16). Its series is then best-effort, so a failure there doesn't
  /// leave a live auction behind an error screen.
  Future<PieceSummary> saveDraft(PostDraft draft) async {
    if (draft.imagePaths.isEmpty) throw Exception('No image selected');
    final images = <Map<String, dynamic>>[];
    for (var i = 0; i < draft.imagePaths.length; i++) {
      final transform = i < draft.transforms.length ? draft.transforms[i] : PostImageTransform();
      final url = await _uploadImage(draft.imagePaths[i], transform, 'piece');
      images.add({
        'mediaUrl': url,
        'mediaType': 'image',
        'mediaAspectRatio': _aspect(transform),
      });
    }

    final details = draft.listingDetails;
    final caption = draft.description.trim();
    final materials = draft.materials.map((m) => m.name).toList();
    final body = <String, dynamic>{
      'title': draft.title.trim().isNotEmpty ? draft.title.trim() : 'Untitled',
      'images': images,
      'mediaUrl': images.first['mediaUrl'],
      'mediaType': 'image',
      'mediaAspectRatio': images.first['mediaAspectRatio'],
      if (caption.isNotEmpty) 'caption': caption,
      if (draft.mediumIds.isNotEmpty) ...{
        'medium': draft.mediumIds.first,
        'mediums': draft.mediumIds,
      },
      if (details?.yearCreated != null) 'yearCreated': details!.yearCreated,
      if (details?.framingMounting?.trim().isNotEmpty == true)
        'framingMounting': details!.framingMounting!.trim(),
      if (details?.provenance?.trim().isNotEmpty == true)
        'provenance': details!.provenance!.trim(),
      if (details?.handlingNotes?.trim().isNotEmpty == true)
        'handlingNotes': details!.handlingNotes!.trim(),
      if (details?.edition != null) 'edition': details!.edition,
      if (details?.signed != null) 'signed': details!.signed,
      if (details?.dimensionsString != null) 'dimensions': details!.dimensionsString,
      if (materials.isNotEmpty) 'materials': materials,
      if (draft.styleTags.isNotEmpty) 'styleTags': draft.styleTags,
      if (draft.location != null && draft.location!.isNotEmpty) 'location': draft.location,
      'status': draft.auction != null ? 'live' : 'draft',
      'aiDisclosed': draft.aiDisclosed,
      if (draft.altText != null && draft.altText!.trim().isNotEmpty)
        'altText': draft.altText!.trim(),
      if (draft.isForSale) ...{
        'isForSale': true,
        if (draft.auction != null)
          ...draft.auction!.toJson()
        else if (details?.priceCents != null)
          'priceCents': details!.priceCents,
        if (details?.weightKg != null) 'weightKg': details!.weightKg,
        // The city the piece is in is where it ships from.
        if (draft.location != null && draft.location!.isNotEmpty)
          'shippingRegion': draft.location,
      },
    };

    final piece = await _pieces.create(body);
    await _linkScenes(draft.relatedScenes, piece.id);
    if (draft.auction != null) {
      try {
        await _assignPieceToSeries(draft, piece.id);
      } catch (_) {}
      return piece;
    }
    await _assignPieceToSeries(draft, piece.id);
    return piece;
  }

  /// One call for the earlier screens (restored from before commit 76f4ef9): a Scene posts
  /// straight to live; a piece is saved as a draft and taken live.
  Future<void> publish(PostDraft draft) async {
    if (draft.postType == 'scene') {
      await postScene(draft);
      return;
    }
    final piece = await saveDraft(draft);
    if (!piece.isLive || draft.auction == null) await goLive(piece.id);
  }

  /// Draft → live.
  Future<PieceSummary> goLive(String pieceId) => _pieces.update(pieceId, {'status': 'live'});

  /// Posts a Scene (photo or video) straight to live — Scenes have no draft or review.
  Future<PostSummary> postScene(PostDraft draft) async {
    final linked = {
      if (draft._linkedIds.isNotEmpty) ...{
        'linkedPieceId': draft._linkedIds.first,
        'linkedPieceIds': draft._linkedIds,
      },
    };
    final caption = draft.description.trim();
    final location = draft.location;
    if (draft.isVideo) {
      if (draft.videoPath == null || draft.videoPath!.isEmpty) {
        throw Exception('No video selected');
      }
      final mediaUrl = await _media.uploadFile(
        purpose: 'post',
        file: File(draft.videoPath!),
        // Always declare video — gallery temp paths may lack a .mp4 extension,
        // and contentTypeForPath would otherwise fall back to image/jpeg.
        contentType: 'video/mp4',
      );
      final thumbnailUrl = await _uploadVideoThumbnail(draft.videoThumbnailBytes, 'post');
      return _posts.create({
        'mediaUrl': mediaUrl,
        'mediaType': 'video',
        if (caption.isNotEmpty) 'caption': caption,
        ...linked,
        if (location != null && location.isNotEmpty) 'location': location,
        'thumbnailUrl': ?thumbnailUrl,
        'isProcess': draft.isProcess,
        'status': 'live',
      });
    }

    if (draft.imagePaths.isEmpty) throw Exception('No image selected');
    final index = draft.previewImageIndex.clamp(0, draft.imagePaths.length - 1);
    final transform = index < draft.transforms.length
        ? draft.transforms[index]
        : PostImageTransform();
    final mediaUrl = await _uploadImage(draft.imagePaths[index], transform, 'post');
    return _posts.create({
      'mediaUrl': mediaUrl,
      'mediaType': 'image',
      if (caption.isNotEmpty) 'caption': caption,
      ...linked,
      if (location != null && location.isNotEmpty) 'location': location,
      'mediaAspectRatio': _aspect(transform),
      'isProcess': draft.isProcess,
      'status': 'live',
    });
  }

  Future<String> _uploadImage(String path, PostImageTransform transform, String purpose) async {
    final bytes = await PostImageRenderer.render(imagePath: path, transform: transform);
    return _media.uploadBytes(purpose: purpose, bytes: bytes, contentType: 'image/png');
  }

  /// The nearest of the ratios the feed knows, for the posted media.
  static String _aspect(PostImageTransform t) {
    final v = t.aspectValue;
    var best = CropAspectRatio.ratio3x4;
    for (final r in CropAspectRatio.values) {
      if ((r.value - v).abs() < (best.value - v).abs()) best = r;
    }
    return best.label;
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

  /// Adds [pieceId] to each Scene's linked pieces. Best-effort: a Scene that can't be
  /// updated doesn't stop the piece being saved.
  Future<void> _linkScenes(List<PostSummary> scenes, String pieceId) async {
    for (final scene in scenes) {
      if (scene.linkedPieceIds.contains(pieceId)) continue;
      try {
        await _posts.update(scene.id, {
          'linkedPieceIds': [...scene.linkedPieceIds, pieceId],
        });
      } catch (_) {}
    }
  }

  Future<void> _assignPieceToSeries(PostDraft draft, String pieceId) async {
    final newName = draft.newSeriesName?.trim();
    if (newName != null && newName.isNotEmpty) {
      await _series.create(
        name: newName,
        description: draft.newSeriesDescription,
        pieceIds: [pieceId],
      );
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
