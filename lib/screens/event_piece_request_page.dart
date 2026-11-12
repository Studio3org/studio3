import 'package:flutter/material.dart';

import '../models/studio_event.dart';
import '../services/api_exception.dart';
import '../services/event_service.dart';
import '../utils/money_format.dart';
import '../widgets/host/host_widgets.dart';
import '../widgets/studio/studio.dart';
import 'event_detail_page.dart';
import 'host/host_event_page.dart' show HostPriceSheet;

/// A host asking to show, sell or auction one of the viewer's pieces (Phase 5.2), laid out like
/// Cancel event: the piece and the event, how it will appear, delivery, the price (the artist
/// can set their own), what approving ends, then Approve and Decline. Pops true once answered.
///
/// Opened from the event page's "Review request" and from Event invites › Piece requests. The
/// server's messages (the onboarding 403, the 409s) show as they are.
class EventPieceRequestPage extends StatefulWidget {
  const EventPieceRequestPage({super.key, required this.request, this.debugSkipLoad = false});

  final EventPieceRequest request;

  /// For tests: don't look up the listing-conflict preview.
  @visibleForTesting
  final bool debugSkipLoad;

  static Future<bool> open(BuildContext context, EventPieceRequest request) async {
    final answered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EventPieceRequestPage(request: request)),
    );
    return answered == true;
  }

  @override
  State<EventPieceRequestPage> createState() => _EventPieceRequestPageState();
}

class _EventPieceRequestPageState extends State<EventPieceRequestPage> {
  late EventTaggingPreview? _preview = widget.request.preview;
  late int? _cents = widget.request.item.priceCents;
  bool _busy = false;

  EventLineupItem get _item => widget.request.item;
  StudioEvent get _event => widget.request.event;

  @override
  void initState() {
    super.initState();
    if (_preview == null && !widget.debugSkipLoad) _loadPreview();
  }

  /// From the event page the request comes without its preview; `/me/piece-requests` has it.
  Future<void> _loadPreview() async {
    try {
      final requests = await EventService.instance.myPieceRequests();
      final match = requests.where((r) => r.event.id == _event.id && r.item.pieceId == _item.pieceId);
      if (mounted && match.isNotEmpty) setState(() => _preview = match.first.preview);
    } catch (_) {
      // No warning to show; the server still ends the listing as it says.
    }
  }

  String get _shownAs => switch (_item.mode) {
    'sale' => 'For sale',
    'bid' => 'Auction',
    _ => 'On show',
  };

  bool get _selling => _item.isSelling;

  Future<void> _editPrice() async {
    final price = await showStudioSheet<String>(
      context: context,
      builder: (_) => HostPriceSheet(
        title: _item.title ?? 'Untitled',
        auction: _item.isAuction,
        initial: _cents == null ? '' : (_cents! / 100).toStringAsFixed(2),
      ),
    );
    final v = double.tryParse(price ?? '');
    if (v != null && mounted) setState(() => _cents = (v * 100).round());
  }

  Future<void> _approve() async {
    final preview = _preview;
    final title = _item.title ?? 'This piece';
    if (_selling && preview != null && preview.endsSomething) {
      final auction = preview.endsAuction;
      final bids = preview.activeBidCount;
      final go = await showHostConflictDialog(
        context,
        title: auction ? 'This will end its current auction' : 'This will end its current listing',
        message: auction
            ? '$title is in an auction on its own${bids > 0 ? ' with ${bids == 1 ? '1 bid' : '$bids bids'}' : ''}. '
                  'Approving ends that auction, and every bidder is told it was withdrawn.'
            : '$title is already for sale on its own. Approving closes that listing and starts a new '
                  'one tied to the event.',
      );
      if (!go || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await EventService.instance.approvePiece(
        _event.id,
        _item.pieceId,
        priceCents: _selling && _cents != _item.priceCents ? _cents : null,
      );
      if (!mounted) return;
      showStudioToast(context, 'Approved');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, 'Could not approve the request. Try again.', icon: null);
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      await EventService.instance.declinePiece(_event.id, _item.pieceId);
      if (!mounted) return;
      showStudioToast(context, 'Declined');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, 'Could not decline the request. Try again.', icon: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    final preview = _preview;
    final url = _item.mediaUrl ?? '';
    final host = _event.hostName ?? (_event.hostUsername == null ? null : '@${_event.hostUsername}');
    Widget fact(String label, String value) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Expanded(child: Text(label, style: StudioType.body15(color: c.textPrimary))),
          Text(value, style: StudioType.body15(color: c.textPrimary)),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Piece request'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(StudioSpace.marginForm, 16, StudioSpace.marginForm, 40),
        children: [
          Text(
            '${host ?? 'A host'} wants ${_item.title ?? 'your piece'} at ${_event.title}',
            style: StudioType.sans(24, weight: StudioType.medium, letterSpacing: -0.3, color: c.textPrimary),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 48,
                  height: 64,
                  child: url.isEmpty
                      ? ColoredBox(color: c.surface)
                      : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: c.surface)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _item.title ?? 'Untitled',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                    ),
                    Text(_event.scheduleLine, style: StudioType.caption12(color: c.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          HostNavRow(
            label: 'Event',
            value: _event.title,
            onTap: () => openEventDetail(context, _event),
          ),
          fact('Shown as', _shownAs),
          if (_selling) fact('Delivery', _item.isPickup ? 'Pickup at the event' : 'Ships after the event'),
          if (_selling)
            HostNavRow(
              label: _item.isAuction ? 'Starting bid' : 'Price',
              value: _cents == null ? null : formatMoney(_cents!),
              mono: true,
              enabled: !_busy,
              onTap: _editPrice,
            ),
          const SizedBox(height: 18),
          Text(
            _selling && preview != null && preview.endsAuction
                ? 'Approving ends its current auction${preview.activeBidCount > 0 ? ', and its ${preview.activeBidCount == 1 ? 'bidder is' : '${preview.activeBidCount} bidders are'} told it was withdrawn' : ''}. '
                      'It is then sold at the event.'
                : _selling && preview != null && preview.endsFixedListing
                ? 'Approving closes its current listing. It is then sold at the event.'
                : _selling
                ? 'Approving lists it for the event. Nothing changes until you approve.'
                : 'Approving shows it at the event. Its own listing stays as it is.',
            style: StudioType.label13(color: c.textSecondary).copyWith(height: 1.5),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(StudioSpace.marginForm, 8, StudioSpace.marginForm, safe > 0 ? safe : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StudioButton(
              label: 'Approve',
              loading: _busy,
              onPressed: _busy || (_selling && _cents == null) ? null : _approve,
            ),
            const SizedBox(height: 4),
            StudioButton(
              label: 'Decline',
              variant: StudioButtonVariant.text,
              onPressed: _busy ? null : _decline,
            ),
          ],
        ),
      ),
    );
  }
}
