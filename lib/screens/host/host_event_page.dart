import 'package:flutter/material.dart';

import '../../config/app_link_config.dart';
import '../../data/post_location_options.dart';
import '../../data/post_picker_options.dart';
import '../../models/piece_summary.dart';
import '../../models/studio_event.dart';
import '../../services/api_exception.dart';
import '../../services/auth_session.dart';
import '../../services/event_service.dart';
import '../../services/media_service.dart';
import '../../utils/money_format.dart';
import '../../utils/post_image_renderer.dart';
import '../../utils/qr_image_share.dart';
import '../../widgets/choose_location_sheet.dart';
import '../../widgets/create_flow/event_lineup_models.dart';
import '../../widgets/host/host_date_sheet.dart';
import '../../widgets/host/host_piece_qr_sheet.dart';
import '../../widgets/host/host_widgets.dart';
import '../../widgets/studio/studio.dart';
import 'host_flyer_page.dart';
import 'host_live_page.dart';
import 'host_people_picker_page.dart';
import 'host_tag_pieces_page.dart';
import 'host_ticket_page.dart';

/// What the event does with the art on show (`HostArtMode`). Never a mix of selling and auction.
enum HostArtMode {
  none('No art'),
  showing('Showing only'),
  selling('Selling'),
  auction('Auction');

  const HostArtMode(this.label);
  final String label;

  bool get sells => this == selling || this == auction;
}

/// How sold pieces reach the buyer, for the whole event (`HostArtMode` delivery).
enum HostDelivery {
  pickup('Pickup at the event'),
  ship('Ships after the event');

  const HostDelivery(this.label);
  final String label;
}

/// Hosting (`HostDetails` … `HostReview`, Flow 10): one page with four steps as tabs —
/// Details, Tickets, Lineup, Review — and Save and continue at the bottom; Publish event on the
/// last. Opened from + on the Events tab (a new event) or from Manage event (an existing one,
/// [editing]).
///
/// What the server has today (BACKEND_CHANGES B22, B28): free RSVP events with an optional cap,
/// the lineup (show, sale or auction per piece, pickup or ship), co-hosts and featured artists.
/// So Tickets offers Free (RSVP) only; the age limit, Public switch and refund policy are left
/// out until they can be saved (section 0.3). A published event's date can't move (B28).
class HostEventPage extends StatefulWidget {
  const HostEventPage({super.key, this.editing, this.debugNow, this.debugStep = 0, this.debugFlyer});

  final StudioEvent? editing;

  /// For tests.
  @visibleForTesting
  final DateTime? debugNow;
  @visibleForTesting
  final int debugStep;

  /// For tests: a cover already framed, in place of picking one from the photo library.
  @visibleForTesting
  final HostFlyer? debugFlyer;

  /// A new event. Returns when the host leaves the flow.
  static Future<void> open(BuildContext context, {StudioEvent? editing}) {
    return Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => HostEventPage(editing: editing)));
  }

  @override
  State<HostEventPage> createState() => _HostEventPageState();
}

class _HostEventPageState extends State<HostEventPage> {
  late int _step = widget.debugStep;
  late int _reached = widget.debugStep;
  final _scroll = ScrollController();

  final _title = TextEditingController();
  final _description = TextEditingController();
  late HostFlyer? _flyer = widget.debugFlyer;
  String? _coverUrl;
  PostLocationOption? _location;
  HostDateSelection? _date;
  String? _category;
  HostArtMode _art = HostArtMode.none;
  HostDelivery _delivery = HostDelivery.pickup;
  int? _capacity;
  final _cohosts = <EventLineupPerson>[];
  final _artists = <EventLineupPerson>[];
  final _pieces = <EventTaggedPiece>[];

  /// What the event has on the server: as opened for editing, then kept up to date while
  /// saving, so only what changed is sent and a retry doesn't add a piece twice.
  final _originalPieces = <String, EventLineupItem>{};

  /// The event a failed publish already created, so trying again updates it instead of
  /// making a second one; and the cover already uploaded for [_uploadedFlyer].
  StudioEvent? _created;
  HostFlyer? _uploadedFlyer;
  String? _uploadedCover;

  bool _saving = false;

  StudioEvent? get _editing => widget.editing;
  bool get _published => _editing?.isPublished ?? false;

  @override
  void initState() {
    super.initState();
    _title.addListener(_changed);
    _description.addListener(_changed);
    final e = _editing;
    if (e != null) _loadFrom(e);
    _initial = _signature();
  }

  /// Everything the host can change, to tell whether leaving would lose anything.
  late String _initial;
  String _signature() => [
    _title.text.trim(),
    _description.text.trim(),
    _flyer?.path,
    _coverUrl,
    _location?.displayName,
    _date?.startsAt,
    _date?.endsAt,
    _category,
    _art,
    _delivery,
    _capacity,
    _cohosts.map((p) => p.username).join(','),
    _artists.map((p) => p.username).join(','),
    _pieces.map((p) => '${p.piece.id}:${p.mode}:${p.price}').join(','),
  ].join('|');

  bool get _dirty => _signature() != _initial;

  /// Back from Details: asks before dropping a new event or unsaved edits.
  Future<void> _leave() async {
    if (_dirty) {
      final discard = await showStudioConfirm(
        context,
        title: _editing == null ? 'Discard this event?' : 'Discard your changes?',
        message: _editing == null ? 'Nothing you added is saved yet.' : 'Your edits to this event are not saved yet.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
      );
      if (!discard || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  void _changed() => setState(() {});

  void _loadFrom(StudioEvent e) {
    _title.text = e.title;
    _description.text = e.details;
    _coverUrl = e.imageUrl.isEmpty ? null : e.imageUrl;
    if (e.venue.isNotEmpty || (e.address ?? '').isNotEmpty) {
      _location = PostLocationOption(
        id: 'event',
        name: e.venue.isNotEmpty ? e.venue : (e.address ?? ''),
        subtitle: e.address ?? '',
        displayName: e.address ?? e.venue,
        lat: e.latitude,
        lng: e.longitude,
      );
    }
    _date = HostDateSelection.fromEvent(e);
    _category = e.category;
    _capacity = e.capacity;
    _cohosts.addAll(e.cohosts.map((p) => EventLineupPerson(username: p.username, name: p.name ?? '', avatarUrl: p.avatarUrl)));
    _artists.addAll(e.artists.map((p) => EventLineupPerson(username: p.username, name: p.name ?? '', avatarUrl: p.avatarUrl)));
    final modes = e.lineup.map((i) => i.mode).toSet();
    _art = e.lineup.isEmpty
        ? HostArtMode.none
        : modes.contains('bid')
        ? HostArtMode.auction
        : modes.contains('sale')
        ? HostArtMode.selling
        : HostArtMode.showing;
    if (e.lineup.any((i) => i.deliveryMode == 'ship')) _delivery = HostDelivery.ship;
    for (final item in e.lineup) {
      _originalPieces[item.pieceId] = item;
      _pieces.add(
        EventTaggedPiece(
          piece: PieceSummary(
            id: item.pieceId,
            title: item.title ?? 'Untitled',
            mediaUrl: item.mediaUrl,
            priceCents: item.priceCents,
            authorName: item.artistName,
            authorUsername: item.artistUsername,
          ),
          mode: switch (item.mode) {
            'sale' => EventPieceMode.sale,
            'bid' => EventPieceMode.bid,
            _ => EventPieceMode.featured,
          },
          price: item.priceCents == null ? '' : (item.priceCents! / 100).toStringAsFixed(2),
          fulfillment: item.deliveryMode == 'ship' ? EventFulfillment.ship : EventFulfillment.pickup,
        ),
      );
    }
    _reached = kHostSteps.length - 1;
  }

  @override
  void dispose() {
    _title.removeListener(_changed);
    _description.removeListener(_changed);
    _title.dispose();
    _description.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // --- steps -------------------------------------------------------------------------------

  /// A draft whose start has gone by (a published event's date can't move, so it isn't asked).
  bool get _datePassed => !_published && _date != null && _date!.startsAt.isBefore(widget.debugNow ?? DateTime.now());

  bool get _detailsReady =>
      _title.text.trim().isNotEmpty &&
      (_flyer != null || (_coverUrl ?? '').isNotEmpty) &&
      _location != null &&
      _date != null &&
      !_datePassed &&
      _category != null;

  /// What Details still needs, for the Review step.
  List<String> get _missing => [
    if (_title.text.trim().isEmpty) 'a title',
    if (_flyer == null && (_coverUrl ?? '').isEmpty) 'a cover',
    if (_location == null) 'a location',
    if (_date == null || _datePassed) 'a date',
    if (_category == null) 'a category',
  ];

  /// Every step needs Details complete: the tabs can jump back to Details and empty a field.
  bool get _canContinue => _detailsReady && !_saving;

  void _goTo(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _step = step;
      if (step > _reached) _reached = step;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  Future<void> _continue() async {
    if (!_canContinue) return;
    if (_step < kHostSteps.length - 1) {
      _goTo(_step + 1);
      return;
    }
    await _save();
  }

  void _back() {
    if (_step > 0) {
      _goTo(_step - 1);
    } else {
      _leave();
    }
  }

  // --- Details -------------------------------------------------------------------------------

  Future<void> _pickFlyer() async {
    final picked = await HostFlyerPage.open(context, initial: _flyer);
    if (picked != null && mounted) setState(() => _flyer = picked);
  }

  void _pickLocation() {
    ChooseLocationSheet.show(
      context,
      selected: _location,
      subtitle: 'Where the event happens.',
      searchHint: 'Search a venue or address',
      currentLabel: 'Use where I am now',
      footnote: 'Guests see the venue and its address on the event page.',
      onLocationSelected: (l) => setState(() => _location = l),
    );
  }

  Future<void> _pickDate() async {
    final picked = await HostDateSheet.show(context, initial: _date, now: widget.debugNow);
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickCategory() async {
    final picked = await showHostOptionSheet<String?>(
      context,
      title: 'Category',
      options: [for (final o in EventCategoryOptions.all) HostOption<String?>(o.id, o.name)],
      initial: _category,
      scrollable: true,
    );
    if (picked != null && mounted) setState(() => _category = picked);
  }

  Future<void> _pickArt() async {
    final picked = await showStudioSheet<(HostArtMode, HostDelivery)>(
      context: context,
      builder: (_) => _ArtModeSheet(art: _art, delivery: _delivery),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final (art, delivery) = picked;
      if (art != _art) {
        // A new mode starts every piece at Not for sale, so nothing goes on sale unasked.
        for (var i = 0; i < _pieces.length; i++) {
          _pieces[i] = _pieces[i].copyWith(mode: EventPieceMode.featured);
        }
      }
      _art = art;
      _delivery = delivery;
      for (var i = 0; i < _pieces.length; i++) {
        _pieces[i] = _pieces[i].copyWith(
          fulfillment: delivery == HostDelivery.ship ? EventFulfillment.ship : EventFulfillment.pickup,
        );
      }
    });
  }

  Future<void> _pickDelivery() async {
    final picked = await showHostOptionSheet<HostDelivery>(
      context,
      title: 'Delivery',
      subtitle: 'For every piece sold at this event. Buyers do not choose.',
      options: const [
        HostOption(HostDelivery.pickup, 'Pickup at the event', subtitle: 'Buyers take it home that night'),
        HostOption(HostDelivery.ship, 'Ships after the event'),
      ],
      initial: _delivery,
    );
    if (picked != null && mounted) {
      setState(() {
        _delivery = picked;
        for (var i = 0; i < _pieces.length; i++) {
          _pieces[i] = _pieces[i].copyWith(
            fulfillment: picked == HostDelivery.ship ? EventFulfillment.ship : EventFulfillment.pickup,
          );
        }
      });
    }
  }

  Widget _details(StudioColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HostFlyerBox(
          onTap: _pickFlyer,
          imagePath: _flyer?.path,
          transform: _flyer?.transform,
          imageUrl: _coverUrl,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(StudioSpace.marginForm, 4, StudioSpace.marginForm, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StudioUnderlineField(
                label: 'Title',
                controller: _title,
                hint: 'Give the event a name',
                valueSize: 16,
                required: true,
              ),
              const SizedBox(height: 18),
              StudioUnderlineField(
                label: 'Description',
                controller: _description,
                hint: 'What happens, who it is for',
                valueSize: 16,
                maxLines: 5,
                minLines: 1,
              ),
              const SizedBox(height: 18),
              HostNavRow(label: 'Location', value: _location?.name, onTap: _pickLocation, required: true),
              HostNavRow(
                label: 'Date and time',
                value: _date?.rowLabel,
                mono: true,
                enabled: !_published,
                onTap: _pickDate,
                required: true,
              ),
              if (_published || _datePassed)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _published ? "A published event's date can't be changed yet." : 'That date has passed. Pick a new one.',
                    style: StudioType.caption12(color: _published ? c.textTertiary : c.textPrimary),
                  ),
                ),
              HostNavRow(
                label: 'Category',
                value: _category == null ? null : EventCategoryOptions.byId(_category!)?.name,
                onTap: _pickCategory,
                required: true,
              ),
              HostNavRow(label: 'Event art', value: _art.label, onTap: _pickArt),
              if (_art.sells) HostNavRow(label: 'Delivery', value: _delivery.label, onTap: _pickDelivery),
            ],
          ),
        ),
      ],
    );
  }

  // --- Tickets -------------------------------------------------------------------------------

  String get _ticketLine => _capacity == null ? 'Free · no limit' : 'Free · $_capacity available';

  Future<void> _editTicket() async {
    final result = await HostTicketPage.open(context, capacity: _capacity);
    if (result != null && mounted) setState(() => _capacity = result.capacity);
  }

  Widget _tickets(StudioColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StudioSpace.marginForm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HostLabel('Is this a paid event?'),
          HostOptionRows<bool>(
            options: const [
              HostOption(true, 'Paid tickets', subtitle: 'Coming soon. Every event is free for now.', enabled: false),
              HostOption(false, 'Free (RSVP)', subtitle: 'People reserve a spot. No payment.'),
            ],
            value: false,
            onChanged: (_) {},
          ),
          const HostLabel('Ticket types'),
          // The whole card opens the ticket, so Edit can sit level with the name.
          GestureDetector(
            onTap: _editTicket,
            behavior: HitTestBehavior.opaque,
            child: HostCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('General Admission', style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary)),
                      const SizedBox(height: 3),
                      Text(_ticketLine, style: StudioType.label13(color: c.textPrimary)),
                      const SizedBox(height: 3),
                      Text('One per person', style: StudioType.caption12(color: c.textSecondary)),
                    ],
                  ),
                ),
                HostTextAction(label: 'Edit', size: 13, inline: true, onTap: _editTicket),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Lineup --------------------------------------------------------------------------------

  Future<void> _addPerson({required bool cohost}) async {
    final person = await HostPeoplePickerPage.open(
      context,
      title: cohost ? 'Add a co-host' : 'Add a featured artist',
      excludeUsernames: {..._cohosts.map((p) => p.username), ..._artists.map((p) => p.username)},
    );
    if (person == null || !mounted) return;
    setState(() => (cohost ? _cohosts : _artists).add(person));
  }

  Future<void> _removePerson(EventLineupPerson person, {required bool cohost}) async {
    final ok = await showStudioConfirm(
      context,
      title: 'Remove ${person.displayName}?',
      message: cohost ? 'They will no longer be a co-host.' : 'They will no longer be featured on the event.',
      confirmLabel: 'Remove',
    );
    if (ok && mounted) setState(() => (cohost ? _cohosts : _artists).remove(person));
  }

  Future<void> _tagPieces() async {
    final picked = await HostTagPiecesPage.open(
      context,
      artists: _artists,
      selectedIds: _pieces.map((p) => p.piece.id).toSet(),
      knownPieces: _pieces.map((p) => p.piece).toList(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final existing = {for (final p in _pieces) p.piece.id: p};
      _pieces
        ..clear()
        ..addAll(
          picked.map(
            (piece) =>
                existing[piece.id] ??
                EventTaggedPiece(
                  piece: piece,
                  price: (piece.priceCents ?? 0) > 0 ? (piece.priceCents! / 100).toStringAsFixed(2) : '',
                  fulfillment: _delivery == HostDelivery.ship ? EventFulfillment.ship : EventFulfillment.pickup,
                ),
          ),
        );
    });
  }

  /// For sale / Auction on a piece already listed or in an auction asks first (`HostConflict`).
  Future<void> _setMode(int index, EventPieceMode mode) async {
    final tagged = _pieces[index];
    if (mode == tagged.mode) return;
    if (mode != EventPieceMode.featured && !_originalPieces.containsKey(tagged.piece.id)) {
      final auction = tagged.needsRelistForBid;
      if (auction || tagged.needsRelistForSale) {
        final go = await showHostConflictDialog(
          context,
          title: auction ? 'This will end its current auction' : 'This will end its current listing',
          message: auction
              ? '${tagged.piece.title} is in an auction on its own. Selling it at this event ends that auction, '
                    'and every bidder is told it was withdrawn.'
              : '${tagged.piece.title} is already for sale on its own. Selling it at this event closes that '
                    'listing and starts a new one tied to the event.',
        );
        if (!go || !mounted) return;
      }
    }
    if (mode != EventPieceMode.featured && tagged.price.trim().isEmpty) {
      final price = await _askPrice(tagged.piece.title, auction: mode == EventPieceMode.bid);
      if (price == null || !mounted) return;
      setState(() => _pieces[index] = _pieces[index].copyWith(mode: mode, price: price));
      return;
    }
    setState(() => _pieces[index] = tagged.copyWith(mode: mode));
  }

  Future<void> _editPrice(int index) async {
    final tagged = _pieces[index];
    final price = await _askPrice(tagged.piece.title, auction: tagged.mode == EventPieceMode.bid, initial: tagged.price);
    if (price != null && mounted) setState(() => _pieces[index] = tagged.copyWith(price: price));
  }

  Future<String?> _askPrice(String title, {required bool auction, String initial = ''}) {
    return showStudioSheet<String>(
      context: context,
      builder: (_) => _PriceSheet(title: title, auction: auction, initial: initial),
    );
  }

  /// Only a piece's own artist can sell or auction it at an event (the server answers 403
  /// otherwise); anyone else's piece is shown, not sold, until artists can approve it (B28).
  static bool _owns(PieceSummary piece) {
    final by = piece.authorUsername ?? '';
    return by.isEmpty || by == AuthSession.instance.user?.username;
  }

  /// Every tagged piece's code at once ("Download all", `HostPieceQR`).
  Future<void> _downloadAllCodes() async {
    try {
      await QrImageShare.shareAll([
        for (final p in _pieces) (title: p.piece.title, url: AppLinkConfig.pieceUrl(p.piece.id)),
      ]);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not save those codes.', icon: null);
    }
  }

  /// "a title, a cover and a date".
  static String _listJoin(List<String> items) =>
      items.length < 2 ? items.join() : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';

  static int? _cents(String price) {
    final v = double.tryParse(price.replaceAll(',', '').replaceAll(r'$', '').trim());
    return v == null ? null : (v * 100).round();
  }

  String _priceLine(EventTaggedPiece p) {
    if (p.mode == EventPieceMode.featured) return _art == HostArtMode.showing ? 'On show' : 'Not for sale';
    final cents = _cents(p.price);
    final money = cents == null ? 'Add a price' : formatMoney(cents);
    if (p.mode == EventPieceMode.bid) {
      final ends = _date?.endsAt.subtract(const Duration(minutes: 30));
      final end = ends == null ? '' : ' · Ends at ${hostTime(TimeOfDay.fromDateTime(ends))}${_date!.zone.isEmpty ? '' : ' ${_date!.zone}'}';
      return 'Starting bid $money$end';
    }
    return money;
  }

  Widget _lineup(StudioColors c) {
    Widget people(List<EventLineupPerson> list, {required bool cohost}) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in list) ...[
            HostPersonTile(
              name: p.displayName,
              avatarUrl: p.avatarUrl,
              onTap: () => _removePerson(p, cohost: cohost),
            ),
            const SizedBox(width: 8),
          ],
          HostAddTile(
            onTap: () => _addPerson(cohost: cohost),
            semanticLabel: cohost ? 'Add a co-host' : 'Add a featured artist',
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StudioSpace.marginForm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HostLabel('Co-hosts'),
          people(_cohosts, cohost: true),
          const HostLabel('Featured artists'),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Artists you feature show on the event page.', style: StudioType.caption12(color: c.textSecondary)),
          ),
          people(_artists, cohost: false),
          const HostLabel('Pieces'),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _art == HostArtMode.none
                  ? 'No art at this event (set in Details).'
                  : _art.sells
                  ? '${_art.label} · ${_delivery.label} (set in Details)'
                  : '${_art.label} (set in Details)',
              style: StudioType.caption12(color: c.textSecondary),
            ),
          ),
          if (_art != HostArtMode.none) ...[
            for (var i = 0; i < _pieces.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _PieceCard(
                tagged: _pieces[i],
                art: _art,
                owned: _owns(_pieces[i].piece),
                priceLine: _priceLine(_pieces[i]),
                onMode: (m) => _setMode(i, m),
                onPrice: _pieces[i].mode == EventPieceMode.featured ? null : () => _editPrice(i),
                onRemove: () => setState(() => _pieces.removeAt(i)),
                onQr: () => showHostPieceQrSheet(
                  context,
                  pieceId: _pieces[i].piece.id,
                  title: _pieces[i].piece.title,
                  artistName: _pieces[i].piece.authorName,
                  priceLabel: _pieces[i].mode == EventPieceMode.featured ? null : _priceLine(_pieces[i]),
                  imageUrl: eventPieceCoverUrl(_pieces[i].piece),
                  allCount: _pieces.length,
                  onDownloadAll: _downloadAllCodes,
                ),
              ),
            ],
            HostTextAction(label: '+ Tag a piece', underline: true, onTap: _tagPieces),
          ],
        ],
      ),
    );
  }

  // --- Review --------------------------------------------------------------------------------

  Widget _review(StudioColors c) {
    Widget card(String label, int step, List<Widget> lines) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // The whole card opens its step, so Edit can sit level with the label at its own size.
      child: GestureDetector(
        onTap: () => _goTo(step),
        behavior: HitTestBehavior.opaque,
        child: HostCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(label, style: StudioType.label13(color: c.textSecondary))),
                  HostTextAction(label: 'Edit', size: 13, inline: true, underline: true, onTap: () => _goTo(step)),
                ],
              ),
              for (final l in lines) ...[const SizedBox(height: 6), l],
            ],
          ),
        ),
      ),
    );
    final small = StudioType.label13(color: c.textPrimary);
    final muted = StudioType.label13(color: c.textSecondary);
    final where = [_location?.name ?? '', _location?.displayName ?? ''].where((p) => p.isNotEmpty).toSet().join(', ');
    final selling = _pieces.where((p) => p.mode != EventPieceMode.featured).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(StudioSpace.marginForm, 18, StudioSpace.marginForm, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          card('Details', 0, [
            Text(_title.text.trim(), style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary)),
            Text(EventCategoryOptions.byId(_category ?? '')?.name ?? '', style: small),
            Text(
              _art.sells ? 'Event art: ${_art.label} · ${_delivery.label}' : 'Event art: ${_art.label}',
              style: small,
            ),
            if (where.isNotEmpty) Text(where, style: muted),
            if (_date != null) Text(_date!.rangeLabel, style: StudioType.mono(12, color: c.textPrimary)),
          ]),
          card('Tickets', 1, [Text('General Admission · $_ticketLine', style: small)]),
          card('Lineup', 2, [
            if (_cohosts.isNotEmpty)
              Text('${_cohosts.length == 1 ? 'Co-host' : 'Co-hosts'}: ${_cohosts.map((p) => p.displayName).join(', ')}', style: small),
            if (_artists.isNotEmpty)
              Text(
                '${_artists.length == 1 ? 'Featured artist' : 'Featured artists'}: ${_artists.map((p) => p.displayName).join(', ')}',
                style: small,
              ),
            if (_pieces.isNotEmpty && _art != HostArtMode.none)
              Text(
                '${_pieces.length} ${_pieces.length == 1 ? 'piece' : 'pieces'}: '
                '${_pieces.map((p) => '${p.piece.title} (${p.mode == EventPieceMode.featured ? (_art.sells ? 'not for sale' : 'on show') : (p.mode == EventPieceMode.bid ? 'auction' : 'for sale')})').join(', ')}',
                style: muted,
              ),
            if (_cohosts.isEmpty && _artists.isEmpty && (_pieces.isEmpty || _art == HostArtMode.none))
              Text('Just you, no art tagged.', style: muted),
            if (selling > 0 && _pieces.any((p) => p.mode != EventPieceMode.featured && _cents(p.price) == null))
              Text('Add a price to every piece for sale.', style: StudioType.label13(weight: StudioType.medium, color: c.textPrimary)),
          ]),
          if (_missing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'To publish, add ${_listJoin(_missing)} in Details.',
                style: StudioType.label13(color: c.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  // --- saving --------------------------------------------------------------------------------

  Future<String?> _uploadCover() async {
    final flyer = _flyer;
    if (flyer == null) return _coverUrl;
    if (flyer == _uploadedFlyer) return _uploadedCover;
    final bytes = await PostImageRenderer.render(imagePath: flyer.path, transform: flyer.transform);
    final url = await MediaService.instance.uploadBytes(
      purpose: MediaPurpose.event,
      bytes: bytes,
      contentType: 'image/png',
    );
    _uploadedFlyer = flyer;
    _uploadedCover = url;
    return url;
  }

  Future<void> _save() async {
    if (_pieces.any((p) => _art != HostArtMode.none && p.mode != EventPieceMode.featured && _cents(p.price) == null)) {
      showStudioToast(context, 'Add a price to every piece for sale.', icon: null);
      return;
    }
    final date = _date;
    if (date == null) return;
    setState(() => _saving = true);
    try {
      final cover = await _uploadCover();
      final location = _location;
      final fields = <String, dynamic>{
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'coverMediaUrl': ?cover,
        'category': _category,
        'venueName': location?.name,
        'address': location?.displayName,
        'latitude': location?.lat,
        'longitude': location?.lng,
        'capacity': _capacity,
      };
      final existing = _created ?? _editing;
      late StudioEvent event;
      if (existing == null) {
        event = await EventService.instance.create(
          title: _title.text.trim(),
          startsAt: date.startsAt,
          endsAt: date.endsAt,
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
          coverMediaUrl: cover,
          category: _category,
          timezoneName: date.zone.isEmpty ? null : date.zone,
          venueName: location?.name,
          address: location?.displayName,
          latitude: location?.lat,
          longitude: location?.lng,
          capacity: _capacity,
        );
        _created = event;
      } else {
        event = await EventService.instance.update(existing.id, {
          ...fields,
          if (!_published) ...{
            'startsAt': date.startsAt.toUtc().toIso8601String(),
            'endsAt': date.endsAt.toUtc().toIso8601String(),
            if (date.zone.isNotEmpty) 'timezone': date.zone,
          },
        });
      }
      await EventService.instance.setPeople(
        event.id,
        cohostUsernames: _cohosts.map((p) => p.username).toList(),
        artistUsernames: _artists.map((p) => p.username).toList(),
      );
      final wanted = _art == HostArtMode.none ? <EventTaggedPiece>[] : _pieces;
      final wantedIds = {for (final p in wanted) p.piece.id};
      for (final id in _originalPieces.keys.toList()) {
        if (wantedIds.contains(id)) continue;
        await EventService.instance.removePiece(event.id, id);
        _originalPieces.remove(id);
      }
      for (final (i, p) in wanted.indexed) {
        // One way of selling per event: a piece for sale follows Event art (sale or auction).
        final mode = !_art.sells || p.mode == EventPieceMode.featured || !_owns(p.piece)
            ? 'featured'
            : (_art == HostArtMode.auction ? 'bid' : 'sale');
        final cents = mode == 'featured' ? null : _cents(p.price);
        final delivery = _delivery == HostDelivery.ship ? 'ship' : 'pickup';
        final before = _originalPieces[p.piece.id];
        if (before != null) {
          if (before.mode == mode && before.priceCents == cents && before.deliveryMode == delivery) continue;
          await EventService.instance.removePiece(event.id, p.piece.id);
          _originalPieces.remove(p.piece.id);
        }
        final added = await EventService.instance.addPiece(
          event.id,
          pieceId: p.piece.id,
          mode: mode,
          priceCents: cents,
          deliveryMode: delivery,
          sortOrder: i,
        );
        _originalPieces[p.piece.id] = EventLineupItem(
          id: added.id,
          pieceId: p.piece.id,
          mode: mode,
          priceCents: cents,
          deliveryMode: delivery,
        );
      }
      if (!event.isPublished) event = await EventService.instance.publish(event.id);
      if (!mounted) return;
      if (_published) {
        showStudioToast(context, 'Event saved');
        Navigator.of(context).pop();
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HostLivePage(
            event: event,
            flyer: _flyer,
            whenLabel: date.rowLabel,
            ticketsLabel: _capacity == null ? 'Free · no limit' : 'Free · $_capacity total',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showStudioToast(context, 'Could not publish your event. Please try again.', icon: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final last = _step == kHostSteps.length - 1;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return PopScope(
      canPop: _step == 0 && !_saving && !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _back();
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: StudioTopBar(context: context, title: 'Event', onBack: _back),
        body: Column(
          children: [
            HostStepTabs(step: _step, reached: _reached, onStep: _goTo),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  switch (_step) {
                    0 => _details(c),
                    1 => _tickets(c),
                    2 => _lineup(c),
                    _ => _review(c),
                  },
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(StudioSpace.marginForm, 8, StudioSpace.marginForm, safe > 0 ? safe : 24),
              child: StudioButton(
                label: last ? (_editing?.isPublished ?? false ? 'Save changes' : 'Publish event') : 'Save and continue',
                loading: _saving,
                onPressed: _canContinue ? _continue : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Event art (`HostArtMode`): No art, Showing only, Selling, Auction; then, for Selling and
/// Auction, DELIVERY FOR SOLD PIECES (Pickup at the event, Ships after the event); Done.
class _ArtModeSheet extends StatefulWidget {
  const _ArtModeSheet({required this.art, required this.delivery});

  final HostArtMode art;
  final HostDelivery delivery;

  @override
  State<_ArtModeSheet> createState() => _ArtModeSheetState();
}

class _ArtModeSheetState extends State<_ArtModeSheet> {
  late HostArtMode _art = widget.art;
  late HostDelivery _delivery = widget.delivery;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 10,
      scrollable: true,
      children: [
        Text('Event art', style: StudioType.title22(color: c.textPrimary)),
        Text(
          'Every tagged piece is on display. Choose whether people can buy them.',
          style: StudioType.body14(color: c.textSecondary),
        ),
        HostOptionRows<HostArtMode>(
          options: const [
            HostOption(HostArtMode.none, 'No art'),
            HostOption(HostArtMode.showing, 'Showing only', subtitle: 'Pieces are on display, nothing is sold'),
            HostOption(HostArtMode.selling, 'Selling', subtitle: 'Pieces can be bought at a set price'),
            HostOption(HostArtMode.auction, 'Auction', subtitle: 'Pieces are auctioned during the event'),
          ],
          value: _art,
          onChanged: (v) => setState(() => _art = v),
        ),
        if (_art == HostArtMode.auction)
          Text(
            'Bidding ends 30 minutes before the event ends.',
            style: StudioType.caption12(color: c.textSecondary),
          ),
        if (_art.sells) ...[
          const HostLabel('Delivery for sold pieces', top: 14),
          HostOptionRows<HostDelivery>(
            options: const [
              HostOption(HostDelivery.pickup, 'Pickup at the event', subtitle: 'Buyers take it home that night'),
              HostOption(HostDelivery.ship, 'Ships after the event'),
            ],
            value: _delivery,
            onChanged: (v) => setState(() => _delivery = v),
          ),
        ],
        StudioButton(label: 'Done', onPressed: () => Navigator.pop(context, (_art, _delivery))),
      ],
    );
  }
}

/// A tagged piece (`HostLineup`): a card with the 48 × 64 image, the title 15/500 and the
/// artist 12; × removes it. On a Selling or Auction event two chips follow Event art (For sale /
/// Auction, Not for sale); a collected piece can only be Not for sale. Then the price line 13
/// and "Link and QR code".
class _PieceCard extends StatelessWidget {
  const _PieceCard({
    required this.tagged,
    required this.art,
    required this.owned,
    required this.priceLine,
    required this.onMode,
    required this.onRemove,
    required this.onQr,
    this.onPrice,
  });

  final EventTaggedPiece tagged;
  final HostArtMode art;

  /// The host's own piece; anyone else's can only be shown.
  final bool owned;
  final String priceLine;
  final ValueChanged<EventPieceMode> onMode;
  final VoidCallback onRemove;
  final VoidCallback onQr;
  final VoidCallback? onPrice;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final piece = tagged.piece;
    final url = eventPieceCoverUrl(piece);
    final selling = art == HostArtMode.auction ? EventPieceMode.bid : EventPieceMode.sale;
    final collected = piece.isCollectedListing;
    return HostCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      piece.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                    ),
                    if ((piece.authorName ?? '').isNotEmpty)
                      Text(piece.authorName!, style: StudioType.caption12(color: c.textSecondary)),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Remove ${piece.title}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox.square(
                    dimension: 44,
                    child: Center(child: StudioIcon(StudioIcons.close, size: 16, color: c.textTertiary)),
                  ),
                ),
              ),
            ],
          ),
          if (art.sells) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (!collected && owned)
                  StudioChip(
                    label: art == HostArtMode.auction ? 'Auction' : 'For sale',
                    selected: tagged.mode != EventPieceMode.featured,
                    dense: true,
                    onTap: () => onMode(selling),
                  ),
                StudioChip(
                  label: 'Not for sale',
                  selected: tagged.mode == EventPieceMode.featured,
                  dense: true,
                  onTap: () => onMode(EventPieceMode.featured),
                ),
              ],
            ),
            if (!owned && !collected)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Only ${(piece.authorName ?? '').isNotEmpty ? piece.authorName : 'its artist'} can sell this piece.',
                  style: StudioType.caption12(color: c.textSecondary),
                ),
              ),
          ],
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onPrice,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 32,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(priceLine, style: StudioType.label13(color: c.textBody)),
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: onQr,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 32,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StudioIcon(StudioIcons.qrCode, size: 14, color: c.textPrimary),
                        const SizedBox(width: 6),
                        Text('Link and QR code', style: StudioType.label13(weight: StudioType.medium, color: c.textPrimary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Price (or starting bid) for a piece sold at the event: an underline field with "$" and Done.
class _PriceSheet extends StatefulWidget {
  const _PriceSheet({required this.title, required this.auction, required this.initial});

  final String title;
  final bool auction;
  final String initial;

  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  late final _price = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  bool get _valid => (double.tryParse(_price.text.replaceAll(',', '').trim()) ?? 0) >= 1;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 14,
      children: [
        Text(widget.auction ? 'Starting bid' : 'Price', style: StudioType.title22(color: c.textPrimary)),
        Text(widget.title, style: StudioType.body14(color: c.textSecondary)),
        StudioUnderlineField(
          label: widget.auction ? 'Starting bid (USD)' : 'Price (USD)',
          controller: _price,
          hint: '0.00',
          mono: true,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        StudioButton(
          label: 'Done',
          onPressed: _valid ? () => Navigator.pop(context, _price.text.replaceAll(',', '').trim()) : null,
        ),
      ],
    );
  }
}
