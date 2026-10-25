import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/auction.dart';
import '../models/feed_preview_item.dart';
import '../models/piece_summary.dart';
import '../models/user_profile.dart' show CommissionQuote;
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/piece_service.dart';
import '../services/user_service.dart';
import '../utils/explore_detail_route.dart';
import '../widgets/create_flow/listing_details_form.dart' show showFramingSheet, kFramingOptions;
import '../widgets/create_flow/post_availability_step.dart';
import '../widgets/create_flow/post_flow_widgets.dart';
import '../widgets/create_flow/post_result_views.dart';
import '../widgets/piece_detail/piece_share_sheet.dart';
import '../widgets/seller_mode_required_dialog.dart';
import '../widgets/studio/studio.dart';
import 'post_create_page.dart' show ScenePostArgs;

/// Listing an auction from a posted piece needs the server to open its auction on PATCH
/// (BACKEND_CHANGES B16). Until then List later offers Fixed price only.
const kListLaterAuction = false;

/// "List it later" (`ListOwnerPiece` → `PostListLater` → `ListPricing` → `ListDone`): turns
/// the owner's not-for-sale piece into a sale. Seller mode first; then the details only a
/// sale needs (depth, weight, framing); then fixed price (or auction); then the listed
/// screen. [onListed] runs once it is for sale.
Future<void> startListingLater(
  BuildContext context, {
  required String pieceId,
  VoidCallback? onListed,
}) async {
  if (!AuthSession.instance.sellerEnabled) {
    final switchToSeller = await showSellerModeRequiredDialog(context);
    if (!context.mounted || switchToSeller != true) return;
    await Navigator.pushNamed(context, '/profile-settings');
    if (!context.mounted || !AuthSession.instance.sellerEnabled) return;
  }
  PieceSummary piece;
  try {
    piece = await PieceService.instance.getById(pieceId);
  } catch (_) {
    if (context.mounted) showStudioToast(context, 'Could not load the piece', icon: null);
    return;
  }
  if (!context.mounted) return;
  final details = await ListLaterDetailsSheet.show(context, piece: piece);
  if (details == null || !context.mounted) return;
  final listed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => ListPricingPage(piece: piece, details: details)),
  );
  if (listed == true) onListed?.call();
}

/// What `PostListLater` collects.
class ListLaterDetails {
  const ListLaterDetails({required this.dimensions, required this.weightKg, required this.framing});

  /// "24x36x1.5 in": the piece's size with the depth added.
  final String dimensions;
  final double weightKg;
  final String framing;
}

/// Width, height, depth and unit from "24x36x1.5 in" (depth may be missing).
({String? width, String? height, String? depth, String unit}) parseDimensions(String? raw) {
  final match = RegExp(
    r'([\d.?]+)\s*[x×]\s*([\d.?]+)(?:\s*[x×]\s*([\d.?]+))?\s*(in|cm)?',
  ).firstMatch(raw ?? '');
  if (match == null) return (width: null, height: null, depth: null, unit: 'in');
  String? clean(String? v) => v == null || v == '?' ? null : v;
  return (
    width: clean(match.group(1)),
    height: clean(match.group(2)),
    depth: clean(match.group(3)),
    unit: match.group(4) ?? 'in',
  );
}

/// "Before you list it" (`PostListLater`): a sheet over the piece with the details only
/// needed to sell (Depth in Mono with its unit, Weight in lb with its tooltip, Framing), and
/// "Continue to pricing", off until all three are filled.
class ListLaterDetailsSheet extends StatefulWidget {
  const ListLaterDetailsSheet({super.key, required this.piece});

  final PieceSummary piece;

  static Future<ListLaterDetails?> show(BuildContext context, {required PieceSummary piece}) {
    return showStudioSheet<ListLaterDetails>(
      context: context,
      useRootNavigator: true,
      builder: (_) => ListLaterDetailsSheet(piece: piece),
    );
  }

  @override
  State<ListLaterDetailsSheet> createState() => _ListLaterDetailsSheetState();
}

class _ListLaterDetailsSheetState extends State<ListLaterDetailsSheet> {
  late final _dims = parseDimensions(widget.piece.dimensions);
  late final _depth = TextEditingController(text: _dims.depth ?? '')..addListener(_changed);
  late final _weight = TextEditingController(
    text: widget.piece.weightKg == null
        ? ''
        : ListingDetailsWeight.lb(widget.piece.weightKg!),
  )..addListener(_changed);
  late String? _framing = kFramingOptions.contains(widget.piece.framingMounting)
      ? widget.piece.framingMounting
      : null;

  void _changed() => setState(() {});

  @override
  void dispose() {
    _depth.dispose();
    _weight.dispose();
    super.dispose();
  }

  double? _num(String text) {
    final v = double.tryParse(text.trim());
    return v != null && v > 0 ? v : null;
  }

  bool get _complete => _num(_depth.text) != null && _num(_weight.text) != null && _framing != null;

  void _continue() {
    if (!_complete) return;
    final d = _dims;
    final dimensions = '${d.width ?? '?'}x${d.height ?? '?'}x${_depth.text.trim()} ${d.unit}';
    Navigator.pop(
      context,
      ListLaterDetails(
        dimensions: dimensions,
        weightKg: double.parse((_num(_weight.text)! * 0.45359237).toStringAsFixed(3)),
        framing: _framing!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decimal = FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));
    return StudioSheet(
      horizontalPadding: 24,
      gap: 22,
      scrollable: true,
      children: [
        PostHeading(
          title: 'Before you list it',
          subtitle: 'We need three more details to quote shipping for collectors.',
        ),
        StudioUnderlineField(
          label: 'Depth',
          controller: _depth,
          hint: 'Add depth',
          mono: true,
          sansHint: true,
          valueSize: 18,
          strongUnderline: true,
          unit: _dims.unit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [decimal],
        ),
        StudioTooltip(
          message: 'Used only to get shipping quotes. It never shows on your piece.',
          builder: (context, toggle) => StudioUnderlineField(
            label: 'Weight',
            controller: _weight,
            hint: 'Add weight',
            mono: true,
            sansHint: true,
            valueSize: 18,
            unit: 'lb',
            labelTrailing: StudioInfoButton(onTap: toggle, semanticLabel: 'What is weight?'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [decimal],
          ),
        ),
        PostChevronRow(
          label: 'Framing',
          value: _framing,
          placeholder: 'Add',
          info: 'Tell collectors how it arrives: unframed, framed, or ready to hang.',
          onTap: () async {
            final picked = await showFramingSheet(context, selected: _framing);
            if (picked != null && mounted) setState(() => _framing = picked);
          },
        ),
        StudioButton(
          label: 'Continue to pricing',
          height: StudioSize.buttonPrimaryTall,
          onPressed: _complete ? _continue : null,
        ),
      ],
    );
  }
}

/// Pounds for the weight field, from the stored kilograms.
abstract final class ListingDetailsWeight {
  static String lb(double kg) {
    final lb = kg / 0.45359237;
    final rounded = double.parse(lb.toStringAsFixed(1));
    return rounded == rounded.roundToDouble() ? '${rounded.round()}' : '$rounded';
  }
}

/// "How do you want to sell it?" (`ListPricing`): Fixed price or Auction, the earnings line,
/// 2 of 2 in the progress bar, and "List it" (no review step). Listing replaces this page
/// with the listed screen.
class ListPricingPage extends StatefulWidget {
  const ListPricingPage({
    super.key,
    required this.piece,
    required this.details,
    this.quote,
    this.update,
  });

  final PieceSummary piece;
  final ListLaterDetails details;

  /// For tests: the commission quote and the PATCH.
  @visibleForTesting
  final Future<CommissionQuote?> Function(int priceCents)? quote;
  @visibleForTesting
  final Future<PieceSummary> Function(String id, Map<String, dynamic> body)? update;

  @override
  State<ListPricingPage> createState() => _ListPricingPageState();
}

class _ListPricingPageState extends State<ListPricingPage> {
  final _price = TextEditingController();
  final _start = TextEditingController();
  final _reserve = TextEditingController();
  SaleMode _mode = SaleMode.fixed;
  int _days = AuctionTerms.defaultDays;
  bool _busy = false;

  @override
  void dispose() {
    _price.dispose();
    _start.dispose();
    _reserve.dispose();
    super.dispose();
  }

  Future<void> _list() async {
    setState(() => _busy = true);
    final piece = widget.piece;
    final details = widget.details;
    final body = <String, dynamic>{
      'isForSale': true,
      if (_mode == SaleMode.auction)
        ...AuctionTerms(
          startingBidCents: PostAvailabilityStep.parseCents(_start.text)!,
          durationDays: _days,
          reserveCents: PostAvailabilityStep.parseCents(_reserve.text),
        ).toJson()
      else ...{
        'listingType': 'fixed',
        'priceCents': PostAvailabilityStep.parseCents(_price.text),
      },
      'dimensions': details.dimensions,
      'weightKg': details.weightKg,
      'framingMounting': details.framing,
      if (piece.location != null && piece.location!.isNotEmpty) 'shippingRegion': piece.location,
    };
    try {
      final listed = await (widget.update ?? PieceService.instance.update)(piece.id, body);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement<bool, bool>(
        MaterialPageRoute(builder: (_) => ListDonePage(piece: listed)),
        result: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(
        context,
        e is ApiException && e.message.isNotEmpty ? e.message : 'Could not list it. Try again.',
        icon: null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final piece = widget.piece;
    final cover = piece.mediaUrl;
    return PostAvailabilityStep(
      cover: cover == null || cover.isEmpty
          ? ColoredBox(color: context.studio.surface)
          : CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover),
      photoCount: piece.imageUrls.isEmpty ? 1 : piece.imageUrls.length,
      pieceTitle: piece.title,
      mode: _mode,
      modes: const [SaleMode.fixed, if (kListLaterAuction) SaleMode.auction],
      onModeChanged: (m) => setState(() => _mode = m),
      priceController: _price,
      startingBidController: _start,
      reserveController: _reserve,
      durationDays: _days,
      onDurationChanged: (d) => setState(() => _days = d),
      onBack: () => Navigator.pop(context),
      onContinue: _list,
      quote: widget.quote ?? UserService.instance.getCommissionQuote,
      heading: 'How do you want to sell it?',
      subheading: 'Pick how collectors can buy ${piece.title}.',
      step: 2,
      steps: 2,
      actionLabel: 'List it',
      busy: _busy,
    );
  }
}

/// "[Title] is listed" (`ListDone`): the published screen with its feed preview, "Add a
/// Scene from the studio", Share and View piece. The board's "We let the [N] people who saved
/// it know" needs the save count and the listing notice (BACKEND_CHANGES B12, B17).
class ListDonePage extends StatelessWidget {
  const ListDonePage({super.key, required this.piece});

  final PieceSummary piece;

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.user;
    final item = FeedPreviewItem.fromPieceSummary(piece);
    final cover = piece.mediaUrl;
    final price = piece.priceCents;
    final name = (user?.name.trim().isNotEmpty ?? false) ? user!.name : (user?.username ?? '');
    void close() => Navigator.of(context).pop();
    return PostPublishedView(
      title: piece.title,
      heading: '${piece.title} is listed',
      subheading: 'Collectors can collect it now.',
      cover: cover == null || cover.isEmpty
          ? ColoredBox(color: context.studio.surface)
          : CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover),
      coverAspect: _aspect(piece.mediaAspectRatio),
      photoCount: piece.imageUrls.isEmpty ? 1 : piece.imageUrls.length,
      authorName: name,
      avatarUrl: user?.profilePhotoUrl,
      priceLabel: price == null ? null : formatUsd(price),
      onClose: close,
      onAddScene: () {
        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.pushNamed(
          '/post',
          arguments: ScenePostArgs(
            pieceId: piece.id,
            pieceTitle: piece.title,
            pieceImageUrl: piece.mediaUrl,
          ),
        );
      },
      onShare: () => PieceShareSheet.show(context, item),
      onView: () {
        final navigator = Navigator.of(context);
        navigator.pop();
        openPieceDetailPreview(navigator.context, item);
      },
    );
  }

  /// "3:4" → 0.75; 3:4 when unknown.
  static double _aspect(String? label) {
    final parts = label?.split(':');
    if (parts == null || parts.length != 2) return 3 / 4;
    final w = double.tryParse(parts[0]);
    final h = double.tryParse(parts[1]);
    return w == null || h == null || h == 0 ? 3 / 4 : w / h;
  }
}
