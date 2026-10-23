import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/post_location_options.dart';
import '../data/post_material_options.dart';
import '../data/post_picker_options.dart';
import '../models/feed_item.dart';
import '../models/feed_preview_item.dart';
import '../models/piece_summary.dart';
import '../models/post_image_transform.dart';
import '../models/post_summary.dart';
import '../models/user_profile.dart' show CommissionQuote;
import '../services/auth_session.dart';
import '../services/piece_service.dart';
import '../services/post_publish_service.dart';
import '../services/user_service.dart';
import '../theme/studio_colors.dart';
import '../utils/explore_detail_route.dart';
import '../widgets/choose_location_sheet.dart';
import '../widgets/create_flow/link_piece_sheet.dart';
import '../widgets/create_flow/listing_details_form.dart';
import '../widgets/create_flow/post_availability_step.dart';
import '../widgets/create_flow/post_flow_widgets.dart';
import '../widgets/create_flow/post_result_views.dart';
import '../widgets/create_flow/post_review_step.dart';
import '../widgets/create_flow/scene_details_step.dart';
import '../widgets/create_flow/series_picker_sheet.dart';
import '../widgets/piece_detail/piece_share_sheet.dart';
import '../widgets/post_create_option_sheet.dart';
import '../widgets/post_crop_preview.dart';
import '../widgets/seller_mode_required_dialog.dart';
import '../widgets/studio/studio_toast.dart';
import 'add_materials_page.dart';

/// Steps after the photos. Pieces: availability (`PostAvailFixed`) → details
/// (`PostDetailsForSale`) → review (`PostReview`) → published (`PostSuccess`) or failed
/// (`PostError`). Scenes: details (`ScenePhotoDetails`) → posted (`ScenePhotoPosted`) or
/// failed — no review (Flow 5).
enum _CreateStep { availability, details, review, done, failed }

/// Opens the posting flow on a Scene already linked to a piece ("Add a Scene from the
/// studio" on the published screen).
class ScenePostArgs {
  const ScenePostArgs({required this.pieceId, required this.pieceTitle, this.pieceImageUrl});

  final String pieceId;
  final String pieceTitle;
  final String? pieceImageUrl;
}

/// The calls the posting flow makes to save and publish.
class PostPublisher {
  const PostPublisher({
    required this.saveDraft,
    required this.goLive,
    required this.postScene,
  });

  factory PostPublisher.api() {
    final s = PostPublishService.instance;
    return PostPublisher(saveDraft: s.saveDraft, goLive: s.goLive, postScene: s.postScene);
  }

  final Future<PieceSummary> Function(PostDraft draft) saveDraft;
  final Future<PieceSummary> Function(String pieceId) goLive;
  final Future<PostSummary> Function(PostDraft draft) postScene;
}

/// Details, review and result steps of posting (D11: the board's steps).
///
/// The editing steps stay mounted (off stage when not shown) so what was entered survives
/// going back. Back moves one step at a time; from the first step it returns to the photo
/// step ([onEdit]).
class PostCreatePage extends StatefulWidget {
  const PostCreatePage({
    super.key,
    required this.postType,
    required this.imagePaths,
    required this.transforms,
    required this.previewImageIndex,
    required this.onClose,
    this.onEdit,
    this.mediaKind = 'image',
    this.videoPath,
    this.videoThumbnailBytes,
    this.videoLength,
    this.initialLinkedPiece,
    this.commissionQuote,
    this.publisher,
    this.active = true,
    this.debugLocation,
    this.debugMediumIds = const [],
  });

  final String postType;

  /// Pieces: every photo in order (the first is the cover). Scenes: the photo at
  /// [previewImageIndex] is posted.
  final List<String> imagePaths;
  final List<PostImageTransform> transforms;
  final int previewImageIndex;
  final VoidCallback onClose;
  final VoidCallback? onEdit;
  final String mediaKind;
  final String? videoPath;
  final Uint8List? videoThumbnailBytes;
  final Duration? videoLength;
  final ScenePostArgs? initialLinkedPiece;

  /// False while the photo steps are on screen: the page stays mounted (keeping what was
  /// typed) but leaves the back button to them.
  final bool active;

  /// Seller's earnings for a price; defaults to the API. Tests pass their own.
  @visibleForTesting
  final Future<CommissionQuote?> Function(int priceCents)? commissionQuote;

  /// Saving and publishing; defaults to [PostPublishService]. Tests pass their own.
  @visibleForTesting
  final PostPublisher? publisher;

  /// Starting location and mediums, for tests (the pickers need the network).
  @visibleForTesting
  final PostLocationOption? debugLocation;
  @visibleForTesting
  final List<String> debugMediumIds;

  @override
  State<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends State<PostCreatePage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _detailsKey = GlobalKey<PieceDetailsStepState>();
  late final PostPublisher _publisher = widget.publisher ?? PostPublisher.api();

  late _CreateStep _step;
  bool _listForSale = false;
  bool _publishing = false;
  late PostLocationOption? _location = widget.debugLocation;
  late final List<String> _mediumIds = List.of(widget.debugMediumIds);
  final Set<String> _styleIds = {};
  final List<PostMaterialOption> _materials = [];
  String? _seriesId;
  String? _newSeriesName;
  String? _seriesLabel;
  final List<SceneLinkedPiece> _linkedPieces = [];
  CommissionQuote? _reviewQuote;

  /// The piece once saved as a draft; publishing again only takes it live.
  PieceSummary? _draftPiece;
  DateTime? _savedAt;
  PieceSummary? _publishedPiece;
  PostSummary? _postedScene;

  bool get _isPiece => widget.postType == 'piece';
  double? get _price => PostAvailabilityStep.parsePrice(_priceController.text);

  @override
  void initState() {
    super.initState();
    _step = _isPiece ? _CreateStep.availability : _CreateStep.details;
    _listForSale = _isPiece && AuthSession.instance.sellerEnabled;
    final linked = widget.initialLinkedPiece;
    if (linked != null) {
      _linkedPieces.add(
        SceneLinkedPiece(
          id: linked.pieceId,
          title: linked.pieceTitle,
          imageUrl: linked.pieceImageUrl,
        ),
      );
    }
    AuthSession.instance.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    AuthSession.instance.removeListener(_onSessionChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    if (_isPiece && AuthSession.instance.sellerEnabled && !_listForSale) {
      setState(() => _listForSale = true);
    }
  }

  Future<void> _onListForSaleChanged(bool value) async {
    if (!value) {
      // The price stays typed in case they switch back; it is only sent for a sale.
      setState(() => _listForSale = false);
      return;
    }
    if (AuthSession.instance.sellerEnabled) {
      setState(() => _listForSale = true);
      return;
    }
    final switchToSeller = await showSellerModeRequiredDialog(context);
    if (!mounted || switchToSeller != true) return;
    await Navigator.pushNamed(context, '/profile-settings');
    if (mounted && AuthSession.instance.sellerEnabled) {
      setState(() => _listForSale = true);
    }
  }

  // ---------------------------------------------------------------- pickers

  void _openLocationPicker() {
    ChooseLocationSheet.show(
      context,
      selected: _location,
      subtitle: _isPiece ? 'Where the piece is now.' : 'Optional. Only a city is ever shown.',
      onLocationSelected: (location) => setState(() => _location = location),
    );
  }

  /// Multi-select (`PostMedium`): the first picked is the one shown and filtered on.
  void _openMediumPicker() {
    PostCreateOptionSheet.show(
      context,
      title: 'Medium',
      searchHint: 'Search mediums',
      options: PostMediumOptions.all,
      selectedIds: {..._mediumIds},
      mode: PostPickerSelectionMode.multiCheckbox,
      onSelectionChanged: (ids) => setState(() {
        _mediumIds
          ..removeWhere((id) => !ids.contains(id))
          ..addAll(ids.where((id) => !_mediumIds.contains(id)));
      }),
    );
  }

  void _openStylePicker() {
    PostCreateOptionSheet.show(
      context,
      title: 'Style',
      searchHint: 'Search styles',
      options: PostStyleOptions.all,
      selectedIds: {..._styleIds},
      mode: PostPickerSelectionMode.multiCheckbox,
      maxSelections: PostStyleOptions.maxSelections,
      onSelectionChanged: (ids) => setState(() {
        _styleIds
          ..clear()
          ..addAll(ids);
      }),
    );
  }

  Future<void> _openMaterialsPage() async {
    final result = await Navigator.push<List<PostMaterialOption>>(
      context,
      MaterialPageRoute<List<PostMaterialOption>>(
        builder: (_) => AddMaterialsPage(
          initialMaterials: List<PostMaterialOption>.from(_materials),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _materials
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _openSeriesPicker() async {
    final result = await SeriesPickerSheet.show(
      context,
      selectedSeriesId: _seriesId,
      newSeriesName: _newSeriesName,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (!result.hasSelection) {
        _seriesId = null;
        _newSeriesName = null;
        _seriesLabel = null;
      } else {
        _seriesId = result.selectedSeriesId;
        _newSeriesName = result.newSeriesName;
        _seriesLabel = result.displayLabel;
      }
    });
  }

  Future<void> _openLinkPieces() async {
    final username = AuthSession.instance.user?.username;
    if (username == null || username.isEmpty) return;
    List<PieceSummary> pieces;
    try {
      pieces = await PieceService.instance.getUserPieces(username);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not load your pieces', icon: null);
      return;
    }
    if (!mounted) return;
    final picked = await LinkPieceSheet.show(
      context,
      pieces: pieces,
      selectedIds: _linkedPieces.map((p) => p.id).toList(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _linkedPieces
        ..clear()
        ..addAll(
          picked.map((p) => SceneLinkedPiece(id: p.id, title: p.title, imageUrl: p.mediaUrl)),
        );
    });
  }

  // ---------------------------------------------------------------- labels

  /// Pieces: the cover is the first photo. Scenes: the photo being posted.
  int get _coverIndex => _isPiece
      ? 0
      : widget.previewImageIndex.clamp(0, widget.imagePaths.isEmpty ? 0 : widget.imagePaths.length - 1);

  String? get _mediumLabel {
    if (_mediumIds.isEmpty) return null;
    return _mediumIds.map((id) => PostMediumOptions.byId(id)?.name ?? id).join(', ');
  }

  String? get _styleLabel {
    if (_styleIds.isEmpty) return null;
    return _styleIds.map((id) => PostStyleOptions.byId(id)?.name ?? id).join(', ');
  }

  String get _titleText {
    final t = _titleController.text.trim();
    return t.isEmpty ? 'Your piece' : t;
  }

  /// Width / height of [_cover]: the photo's crop, or 9:16 for a video's frame.
  double get _coverAspect {
    if (widget.mediaKind == 'video' || widget.imagePaths.isEmpty) return 9 / 16;
    return widget.transforms[_coverIndex].aspectRatio.value;
  }

  Widget _cover() {
    if (widget.mediaKind == 'video' || widget.imagePaths.isEmpty) {
      final bytes = widget.videoThumbnailBytes;
      return bytes == null
          ? ColoredBox(color: context.studio.surface)
          : Image.memory(bytes, fit: BoxFit.cover);
    }
    return PostCropPreview(
      imagePath: widget.imagePaths[_coverIndex],
      transform: widget.transforms[_coverIndex],
    );
  }

  PostDraft _buildDraft() {
    final details = _isPiece
        ? _detailsKey.currentState?.buildListingDetails(priceUsd: _listForSale ? _price : null)
        : null;
    return PostDraft(
      postType: widget.postType,
      imagePaths: widget.imagePaths,
      mediaKind: widget.mediaKind,
      videoPath: widget.videoPath,
      videoThumbnailBytes: widget.videoThumbnailBytes,
      title: _titleController.text,
      description: _descriptionController.text,
      mediumIds: List.of(_mediumIds),
      styleTags: _styleIds.toList(),
      location: _location?.displayName,
      materials: List.of(_materials),
      listingDetails: details,
      selectedSeriesId: _seriesId,
      newSeriesName: _newSeriesName,
      transforms: widget.transforms,
      previewImageIndex: widget.previewImageIndex,
      aiDisclosed: _detailsKey.currentState?.aiDisclosed ?? false,
      linkedPieceIds: _linkedPieces.map((p) => p.id).toList(),
      isForSale: _isPiece && _listForSale,
    );
  }

  // ---------------------------------------------------------------- navigation

  void _goBack() {
    switch (_step) {
      case _CreateStep.review:
        setState(() => _step = _CreateStep.details);
      case _CreateStep.details when _isPiece:
        setState(() => _step = _CreateStep.availability);
      case _CreateStep.details:
      case _CreateStep.availability:
        widget.onEdit?.call();
      case _CreateStep.done:
      case _CreateStep.failed:
        widget.onClose();
    }
  }

  Future<CommissionQuote?> _quote(int priceCents) =>
      (widget.commissionQuote ?? UserService.instance.getCommissionQuote)(priceCents);

  void _toReview() {
    setState(() => _step = _CreateStep.review);
    final price = _price;
    if (_listForSale && price != null) {
      _quote((price * 100).round()).then(
        (q) {
          if (mounted) setState(() => _reviewQuote = q);
        },
        onError: (Object _) {},
      );
    }
  }

  // ---------------------------------------------------------------- publishing

  Future<void> _publishPiece() async {
    setState(() => _publishing = true);
    try {
      var piece = _draftPiece;
      if (piece == null) {
        piece = await _publisher.saveDraft(_buildDraft());
        _draftPiece = piece;
        _savedAt = DateTime.now();
      }
      final live = await _publisher.goLive(piece.id);
      if (!mounted) return;
      setState(() {
        _publishedPiece = live;
        _step = _CreateStep.done;
      });
    } catch (_) {
      if (mounted) setState(() => _step = _CreateStep.failed);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _postScene() async {
    setState(() => _publishing = true);
    try {
      final post = await _publisher.postScene(_buildDraft());
      if (!mounted) return;
      setState(() {
        _postedScene = post;
        _step = _CreateStep.done;
      });
    } catch (_) {
      if (mounted) setState(() => _step = _CreateStep.failed);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  /// Leaves the flow, then runs [then] with a context that outlives it.
  void _closeThen(void Function(BuildContext context) then) {
    final navigator = Navigator.of(context);
    widget.onClose();
    then(navigator.context);
  }

  void _addSceneForPiece(PieceSummary piece) {
    _closeThen(
      (context) => Navigator.of(context).pushNamed(
        '/post',
        arguments: ScenePostArgs(
          pieceId: piece.id,
          pieceTitle: piece.title,
          pieceImageUrl: piece.mediaUrl,
        ),
      ),
    );
  }

  /// Drafts show on the artist's own profile.
  void _goToDrafts() {
    final username = AuthSession.instance.user?.username;
    _closeThen((context) {
      if (username != null) Navigator.of(context).pushNamed('/profile', arguments: username);
    });
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final finished = _step == _CreateStep.done || _step == _CreateStep.failed;
    final steps = _isPiece
        ? const [_CreateStep.availability, _CreateStep.details, _CreateStep.review]
        : const [_CreateStep.details];
    return PopScope(
      canPop: !widget.active,
      onPopInvokedWithResult: (didPop, _) {
        if (widget.active && !didPop && !_publishing) _goBack();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final step in steps)
            Offstage(
              offstage: _step != step,
              child: TickerMode(enabled: _step == step, child: _buildStep(step)),
            ),
          if (finished) _buildResult(),
        ],
      ),
    );
  }

  Widget _buildStep(_CreateStep step) {
    switch (step) {
      case _CreateStep.availability:
        return PostAvailabilityStep(
          cover: _cover(),
          photoCount: widget.imagePaths.length,
          forSale: _listForSale,
          onForSaleChanged: _onListForSaleChanged,
          priceController: _priceController,
          onBack: _goBack,
          onEdit: () => widget.onEdit?.call(),
          onContinue: () => setState(() => _step = _CreateStep.details),
          quote: _quote,
        );
      case _CreateStep.details when _isPiece:
        return PieceDetailsStep(
          key: _detailsKey,
          forSale: _listForSale,
          titleController: _titleController,
          descriptionController: _descriptionController,
          location: _location?.name,
          medium: _mediumLabel,
          style: _styleLabel,
          materialsCount: _materials.length,
          series: _seriesLabel,
          onLocation: _openLocationPicker,
          onMedium: _openMediumPicker,
          onStyle: _openStylePicker,
          onMaterials: _openMaterialsPage,
          onSeries: _openSeriesPicker,
          onBack: _goBack,
          onContinue: _toReview,
        );
      case _CreateStep.details:
        final length = widget.videoLength;
        return SceneDetailsStep(
          preview: _cover(),
          previewAspect: _coverAspect,
          videoLength: length == null
              ? null
              : '${length.inMinutes}:${(length.inSeconds % 60).toString().padLeft(2, '0')}',
          captionController: _descriptionController,
          linkedPieces: _linkedPieces,
          location: _location?.name,
          onBack: _goBack,
          onLinkPiece: _openLinkPieces,
          onUnlink: (p) => setState(() => _linkedPieces.removeWhere((l) => l.id == p.id)),
          onLocation: _openLocationPicker,
          onPost: _postScene,
          posting: _publishing,
        );
      case _CreateStep.review:
        return _buildReview();
      case _CreateStep.done:
      case _CreateStep.failed:
        return const SizedBox.shrink();
    }
  }

  Widget _buildReview() {
    final details = _detailsKey.currentState?.buildListingDetails(
      priceUsd: _listForSale ? _price : null,
    );
    final price = _price;
    final quote = _reviewQuote;
    final weight = details?.weight;
    return PostReviewStep(
      cover: _cover(),
      title: _titleText,
      photoCount: widget.imagePaths.length,
      forSale: _listForSale,
      availabilityRows: [
        PostReviewRow('Selling', _listForSale ? 'Fixed price' : 'Not for sale'),
        if (_listForSale && price != null)
          PostReviewRow('Price', formatUsd((price * 100).round()), small: true),
        if (_listForSale && quote != null)
          PostReviewRow('You receive', formatUsd(quote.netCents), small: true),
      ],
      detailRows: [
        if (details?.dimensionsLabel != null)
          PostReviewRow('Size', details!.dimensionsLabel!, mono: true),
        if (_listForSale && weight != null)
          PostReviewRow(
            'Weight',
            '${PieceDetailsFormat.number(weight)} ${details!.weightUnit}',
            mono: true,
          ),
        if (_listForSale && details?.framingMounting != null)
          PostReviewRow('Framing', details!.framingMounting!),
        if (_location != null) PostReviewRow('Location', _location!.name),
        if (_mediumLabel != null) PostReviewRow('Medium', _mediumLabel!),
        if (_seriesLabel != null) PostReviewRow('Series', _seriesLabel!),
      ],
      onBack: _goBack,
      onEditPhotos: () => widget.onEdit?.call(),
      onEditAvailability: () => setState(() => _step = _CreateStep.availability),
      onEditDetails: () => setState(() => _step = _CreateStep.details),
      onPublish: _publishPiece,
      publishing: _publishing,
    );
  }

  Widget _buildResult() {
    final user = AuthSession.instance.user;
    final authorName = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name
        : (user?.username ?? '');
    if (_step == _CreateStep.failed) {
      return PostErrorView(
        isScene: !_isPiece,
        savedAt: _isPiece ? _savedAt : null,
        retrying: _publishing,
        onClose: widget.onClose,
        onRetry: _isPiece ? _publishPiece : _postScene,
        onDrafts: _goToDrafts,
      );
    }
    final piece = _publishedPiece;
    if (piece != null) {
      final item = FeedPreviewItem.fromPieceSummary(piece);
      final price = _price;
      return PostPublishedView(
        title: piece.title,
        cover: _cover(),
        coverAspect: _coverAspect,
        photoCount: widget.imagePaths.length,
        authorName: authorName,
        avatarUrl: user?.profilePhotoUrl,
        priceLabel: _listForSale && price != null ? formatUsd((price * 100).round()) : null,
        onClose: widget.onClose,
        onAddScene: () => _addSceneForPiece(piece),
        onShare: () => PieceShareSheet.show(context, item),
        onView: () => _closeThen((context) => openPieceDetailPreview(context, item)),
      );
    }
    final scene = _postedScene!;
    return SceneLiveView(
      preview: _cover(),
      previewAspect: _coverAspect,
      isVideo: widget.mediaKind == 'video',
      authorName: authorName,
      avatarUrl: user?.profilePhotoUrl,
      linkedPieces: [
        for (final p in _linkedPieces) LinkedPieceThumb(title: p.title, imageUrl: p.imageUrl),
      ],
      onClose: widget.onClose,
      onShare: () =>
          PieceShareSheet.show(context, FeedPreviewItem.fromFeedItem(FeedItem.post(scene))),
      onView: () => _closeThen((context) => openExploreDetail(context, FeedItem.post(scene))),
    );
  }
}

/// Number formatting for the review rows.
abstract final class PieceDetailsFormat {
  /// 8 → "8", 1.5 → "1.5".
  static String number(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();
}
