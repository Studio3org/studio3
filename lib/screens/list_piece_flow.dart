import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/auction.dart';
import '../models/feed_preview_item.dart';
import '../models/piece_summary.dart';
import '../models/user_profile.dart' show CommissionQuote;
import '../services/api_exception.dart';
import '../services/auction_service.dart';
import '../services/auth_session.dart';
import '../services/piece_service.dart';
import '../services/user_service.dart';
import '../utils/explore_detail_route.dart';
import '../widgets/create_flow/listing_details_form.dart' show showFramingSheet, kFramingOptions;
import '../widgets/create_flow/post_availability_step.dart';
import '../widgets/create_flow/post_flow_widgets.dart';
import '../widgets/create_flow/post_result_views.dart';
import '../widgets/piece_detail/piece_share_sheet.dart';
import '../widgets/studio/studio.dart';
import 'post_create_page.dart' show ScenePostArgs;
import 'seller/seller_setup_flow.dart';

/// "12 people", "1 person": how many saved a piece (BACKEND_CHANGES B17).
String savedPeople(int count) => count == 1 ? '1 person' : '$count people';

/// `ListDone`'s line: "We let the 12 people who saved it know." when anyone saved it (B12 told
/// them, B17 counts them); otherwise what collectors can do now.
String listedSubheading(PieceSummary piece) {
  final saved = piece.savesCount ?? 0;
  if (saved == 1) return 'We let the person who saved it know.';
  if (saved > 1) return 'We let the $saved people who saved it know.';
  return piece.isAuction ? 'Collectors can bid on it now.' : 'Collectors can collect it now.';
}

/// Listing an auction from a posted piece: the server opens its auction on PATCH
/// (BACKEND_CHANGES B16, 2026-11-05), so List later offers Fixed price or Auction.
const kListLaterAuction = true;

/// "List it later" (`ListOwnerPiece` → `PostListLater` → `ListPricing` → `ListDone`): turns
/// the owner's not-for-sale piece into a sale. Seller mode first; then the details only a
/// sale needs (depth, weight, framing); then fixed price (or auction); then the listed
/// screen. [onListed] runs once it is for sale.
Future<void> startListingLater(BuildContext context, {required String pieceId, VoidCallback? onListed}) async {
  if (!AuthSession.instance.sellerEnabled) {
    final seller = await SellerSetupPage.prompt(context, secondaryLabel: 'Not now', returnLabel: 'Continue listing');
    if (!context.mounted || !seller) return;
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
    MaterialPageRoute(
      builder: (_) => ListPricingPage(piece: piece, details: details),
    ),
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
  final match = RegExp(r'([\d.?]+)\s*[x×]\s*([\d.?]+)(?:\s*[x×]\s*([\d.?]+))?\s*(in|cm)?').firstMatch(raw ?? '');
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
    text: widget.piece.weightKg == null ? '' : ListingDetailsWeight.lb(widget.piece.weightKg!),
  )..addListener(_changed);
  late String? _framing = kFramingOptions.contains(widget.piece.framingMounting) ? widget.piece.framingMounting : null;

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

/// "Relist as an auction" (`ArtistAuctionUnsold`): the auction settings, filled in from the
/// run that ended, then a fresh auction (`/auction/relist`, which keeps the old one as the
/// record) and the listed screen. [onListed] runs once it is up.
Future<void> startRelistAuction(
  BuildContext context, {
  required String pieceId,
  required EndedAuction last,
  VoidCallback? onListed,
}) async {
  PieceSummary piece;
  try {
    piece = await PieceService.instance.getById(pieceId);
  } catch (_) {
    if (context.mounted) showStudioToast(context, 'Could not load the piece', icon: null);
    return;
  }
  if (!context.mounted) return;
  final listed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => ListPricingPage(piece: piece, relist: last)),
  );
  if (listed == true) onListed?.call();
}

/// "How do you want to sell it?" (`ListPricing`): Fixed price or Auction, the earnings line,
/// 2 of 2 in the progress bar, and "List it" (no review step). Listing replaces this page
/// with the listed screen. With [relist], the auction settings of a run that ended without a
/// sale, filled in (`ArtistAuctionUnsold`).
class ListPricingPage extends StatefulWidget {
  const ListPricingPage({
    super.key,
    required this.piece,
    this.details,
    this.relist,
    this.quote,
    this.update,
    this.relistAuction,
  });

  final PieceSummary piece;

  /// What List later collected; not asked again when relisting an auction.
  final ListLaterDetails? details;
  final EndedAuction? relist;

  /// For tests: the commission quote and the PATCH.
  @visibleForTesting
  final Future<CommissionQuote?> Function(int priceCents)? quote;
  @visibleForTesting
  final Future<PieceSummary> Function(String id, Map<String, dynamic> body)? update;

  /// For tests: the relist call, answering the piece as it is after.
  @visibleForTesting
  final Future<PieceSummary> Function(String id, AuctionTerms terms)? relistAuction;

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
  void initState() {
    super.initState();
    final last = widget.relist;
    if (last != null) {
      _mode = SaleMode.auction;
      if (last.startingBidCents != null) _start.text = formatUsd(last.startingBidCents!);
      if (last.reserveCents != null) _reserve.text = formatUsd(last.reserveCents!);
    }
  }

  /// A fresh auction on the piece, then the piece as it is now.
  Future<PieceSummary> _relist(String id, AuctionTerms terms) async {
    await AuctionService.instance.relist(
      id,
      durationDays: terms.durationDays,
      startingBidCents: terms.startingBidCents,
      reserveCents: terms.reserveCents,
    );
    return PieceService.instance.getById(id);
  }

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
    if (widget.relist != null) {
      final terms = AuctionTerms(
        startingBidCents: PostAvailabilityStep.parseCents(_start.text)!,
        durationDays: _days,
        reserveCents: PostAvailabilityStep.parseCents(_reserve.text),
      );
      await _finish(() => (widget.relistAuction ?? _relist)(piece.id, terms));
      return;
    }
    final body = <String, dynamic>{
      'isForSale': true,
      // An auction that ended without a sale left the piece delisted (`ArtistAuctionUnsold`
      // "Sell at a fixed price"): listing it puts it back up.
      if (piece.status == 'delisted') 'status': 'live',
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
      if (details != null) ...{
        'dimensions': details.dimensions,
        'weightKg': details.weightKg,
        'framingMounting': details.framing,
      },
      if (piece.location != null && piece.location!.isNotEmpty) 'shippingRegion': piece.location,
    };
    await _finish(() => (widget.update ?? PieceService.instance.update)(piece.id, body));
  }

  /// Runs the listing call, then the listed screen; a failure keeps the page with the
  /// server's reason.
  Future<void> _finish(Future<PieceSummary> Function() call) async {
    try {
      final listed = await call();
      if (!mounted) return;
      await Navigator.of(
        context,
      ).pushReplacement<bool, bool>(MaterialPageRoute(builder: (_) => ListDonePage(piece: listed)), result: true);
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
      modes: widget.relist != null
          ? const [SaleMode.auction]
          : const [SaleMode.fixed, if (kListLaterAuction) SaleMode.auction],
      onModeChanged: (m) => setState(() => _mode = m),
      priceController: _price,
      startingBidController: _start,
      reserveController: _reserve,
      durationDays: _days,
      onDurationChanged: (d) => setState(() => _days = d),
      onBack: () => Navigator.pop(context),
      onContinue: _list,
      quote: widget.quote ?? UserService.instance.getCommissionQuote,
      heading: widget.relist != null ? 'Relist as an auction' : 'How do you want to sell it?',
      subheading: widget.relist != null
          ? 'Your last terms are filled in. Change anything you like.'
          : 'Pick how collectors can buy ${piece.title}.',
      step: 2,
      steps: 2,
      actionLabel: 'List it',
      busy: _busy,
    );
  }
}

/// "[Title] is listed" (`ListDone`): the published screen with its feed preview, "Add a
/// Scene from the studio", Share and View piece, under "We let the [N] people who saved it
/// know" ([listedSubheading]; BACKEND_CHANGES B12, B17).
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
      subheading: listedSubheading(piece),
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
          arguments: ScenePostArgs(pieceId: piece.id, pieceTitle: piece.title, pieceImageUrl: piece.mediaUrl),
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
