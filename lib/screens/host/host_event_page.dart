import 'package:flutter/cupertino.dart';
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
import '../../widgets/events/event_detail_widgets.dart' show eventTicketRange;
import '../../widgets/host/host_date_sheet.dart';
import '../../widgets/host/host_piece_qr_sheet.dart';
import '../../widgets/host/host_widgets.dart';
import '../../widgets/studio/studio.dart';
import '../seller/seller_setup_flow.dart';
import 'host_flyer_page.dart';
import 'host_live_page.dart';
import 'host_people_picker_page.dart';
import 'host_reschedule_page.dart';
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
/// Tickets (BACKEND_CHANGES B22): Free (RSVP), one General Admission place per person with an
/// optional cap, or ticket types the host names and prices (free or paid), with a refund policy
/// once any is paid. Details carries the age limit and the Public switch (off = link only).
/// The lineup: show, sale or auction per piece, pickup or ship; co-hosts and featured artists.
/// A published event's date can't move (B28).
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

  /// Ticket types (B22) rather than a free RSVP: [_types] is what the host has set up (open
  /// types only; closed ones stay on the server as they are).
  bool _ticketed = false;
  final _types = <EventTicketType>[];

  /// The ticket types on the server, by id: as opened, then kept up to date while saving, so
  /// only what changed is sent and a retry doesn't add a type twice.
  final _originalTypes = <String, EventTicketType>{};
  String _refundPolicy = 'none';
  String _ageLimit = 'all';
  bool _public = true;
  final _cohosts = <EventLineupPerson>[];
  final _artists = <EventLineupPerson>[];

  /// Where each person on the bill stands, by role and username, as the server last said
  /// (`invited` · `accepted` · `declined`, Phase 5.1). Empty on an older server, which has
  /// no invites: everyone listed is simply on the bill.
  final _peopleStatus = <String, String>{};

  /// The people as opened, so they are sent only when the host changed them: the server
  /// replaces the lists wholesale, and an unchanged save must not touch anyone's invite.
  String _originalPeople = '';

  /// When bidding ends, when the host picked a time; null for the default, 30 minutes before
  /// the event ends (Phase 5.3). [_originalAuctionEndsAt] is as opened, so it is sent only
  /// when it changed (a published event's running auctions can't move once bid on).
  DateTime? _auctionEndsAt;
  DateTime? _originalAuctionEndsAt;
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

  /// A published event's date moves only through Reschedule, which tells everyone with a
  /// ticket (Phase 4.4); the host's own, before it ends.
  bool get _canReschedule => _published && (_editing?.isHost ?? false) && !(_editing?.isOver ?? true);

  /// An accepted co-host editing someone else's event (Phase 5.1): they can edit it, but only
  /// the host publishes, moves the date and changes who is on the bill.
  bool get _coHost => _editing != null && !_editing!.isHost && _editing!.viewerCanEdit;

  @override
  void initState() {
    super.initState();
    _title.addListener(_changed);
    _description.addListener(_changed);
    final e = _editing;
    if (e != null) _loadFrom(e);
    _originalPeople = _peopleKey();
    _initial = _signature();
    // A card (a draft from Your events) carries no ticket types; the server has them.
    if (e != null && e.ticketTypes.isEmpty && widget.debugNow == null) _loadTypes(e.id);
  }

  Future<void> _loadTypes(String eventId) async {
    try {
      final types = await EventService.instance.listTicketTypes(eventId);
      if (!mounted || types.isEmpty || _originalTypes.isNotEmpty || _types.isNotEmpty) return;
      final untouched = !_dirty;
      setState(() => _takeTypes(types));
      if (untouched) _initial = _signature();
    } catch (_) {
      // Tickets show as a free RSVP; saving leaves the server's types alone.
    }
  }

  void _takeTypes(List<EventTicketType> types) {
    final open = types.where((t) => !t.closed && t.id.isNotEmpty).toList();
    _types
      ..clear()
      ..addAll(open);
    _originalTypes
      ..clear()
      ..addAll({for (final t in open) t.id: t});
    _ticketed = open.isNotEmpty;
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
    _ticketed,
    _types.map((t) => '${t.id}:${t.toJson()}').join(','),
    _refundPolicy,
    _ageLimit,
    _public,
    _cohosts.map((p) => p.username).join(','),
    _artists.map((p) => p.username).join(','),
    _peopleKey(),
    _auctionEndsAt,
    _pieces.map((p) => '${p.piece.id}:${p.mode}:${p.price}').join(','),
  ].join('|');

  static String _statusKey(String role, String username) => '$role:$username';

  String? _statusOf(EventLineupPerson p, {required bool cohost}) =>
      _peopleStatus[_statusKey(cohost ? 'cohost' : 'artist', p.username)];

  /// Who is on the bill and where they stand, to tell whether the people changed.
  String _peopleKey() => [
    for (final p in _cohosts) 'c:${p.username}:${_statusOf(p, cohost: true) ?? ''}',
    for (final p in _artists) 'a:${p.username}:${_statusOf(p, cohost: false) ?? ''}',
  ].join(',');

  /// The usernames sent for a role: everyone but those who declined (sending them again would
  /// ask them again).
  List<String> _sendable(List<EventLineupPerson> list, {required bool cohost}) => [
    for (final p in list)
      if (_statusOf(p, cohost: cohost) != 'declined') p.username,
  ];

  bool get _dirty => _signature() != _initial;

  /// Back from Details: asks before leaving a new event (always, the user's call 2026-11-08)
  /// or dropping unsaved edits to an existing one.
  Future<void> _leave() async {
    if (_editing == null && !_dirty) {
      final leave = await showStudioConfirm(
        context,
        title: 'Leave this event?',
        message: "You haven't added anything yet.",
        confirmLabel: 'Leave',
        cancelLabel: 'Keep editing',
      );
      if (!leave || !mounted) return;
      Navigator.of(context).pop();
      return;
    }
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
    _takeTypes(e.ticketTypes);
    _refundPolicy = e.refundPolicy ?? 'none';
    _ageLimit = e.ageLimit ?? 'all';
    _public = e.visibility != 'link';
    EventLineupPerson person(String username, String? name, String? avatarUrl) =>
        EventLineupPerson(username: username, name: name ?? '', avatarUrl: avatarUrl);
    if (e.invites.isNotEmpty) {
      // Phase 5.1: `cohosts` and `artists` are accepted people only, so the bill comes from
      // the invites, with where each person stands.
      for (final i in e.invites) {
        final list = i.isCohost ? _cohosts : _artists;
        final p = person(i.username, i.name, i.avatarUrl);
        if (list.contains(p)) continue;
        list.add(p);
        _peopleStatus[_statusKey(i.role, i.username)] = i.status;
      }
    } else {
      _cohosts.addAll(e.cohosts.map((p) => person(p.username, p.name, p.avatarUrl)));
      _artists.addAll(e.artists.map((p) => person(p.username, p.name, p.avatarUrl)));
    }
    final ends = e.auctionEndsAt;
    // The server sends the effective end; the default (30 minutes before the end) stays null.
    if (ends != null && !ends.isAtSameMomentAs(e.endsAt.subtract(_biddingGap))) {
      _auctionEndsAt = ends;
      _originalAuctionEndsAt = ends;
    }
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
      cityOnly: false,
      onLocationSelected: (l) => setState(() => _location = l),
    );
  }

  Future<void> _pickDate() async {
    final picked = await HostDateSheet.show(context, initial: _date, now: widget.debugNow);
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        // A bidding end the new date leaves outside its limits goes back to the default.
        final ends = _auctionEndsAt;
        if (ends != null && !_biddingEndFits(ends, picked)) _auctionEndsAt = null;
      });
    }
  }

  /// Bidding ends at least this long before the event does (Phase 5.3).
  static const _biddingGap = Duration(minutes: 30);

  static bool _biddingEndFits(DateTime at, HostDateSelection date) =>
      at.isAfter(date.startsAt) && !at.isAfter(date.endsAt.subtract(_biddingGap));

  /// When bidding ends as shown: the host's pick, or 30 minutes before the end.
  DateTime? get _biddingEnds => _auctionEndsAt ?? _date?.endsAt.subtract(_biddingGap);

  String get _biddingEndsLabel {
    final ends = _biddingEnds;
    if (ends == null) return '';
    final zone = _date!.zone.isEmpty ? '' : ' ${_date!.zone}';
    final day = _date!.multiDay ? '${hostDay(ends)} · ' : '';
    return '$day${hostTime(TimeOfDay.fromDateTime(ends))}$zone';
  }

  /// Bidding ends (Phase 5.3): any time after the start, up to 30 minutes before the end.
  Future<void> _pickBiddingEnd() async {
    final date = _date;
    if (date == null) return;
    final picked = await showStudioSheet<({DateTime? at})>(
      context: context,
      builder: (_) => _BiddingEndSheet(date: date, initial: _auctionEndsAt),
    );
    if (picked == null || !mounted) return;
    final at = picked.at;
    // The default time picked on the wheel is still the default.
    setState(() => _auctionEndsAt = at == null || at.isAtSameMomentAs(date.endsAt.subtract(_biddingGap)) ? null : at);
  }

  Future<void> _reschedule() async {
    final editing = _editing;
    if (editing == null) return;
    final moved = await HostReschedulePage.open(context, editing);
    if (moved == null || !mounted) return;
    // The move is saved already, so it isn't an unsaved change here.
    final untouched = !_dirty;
    setState(() => _date = HostDateSelection.fromEvent(moved));
    if (untouched) _initial = _signature();
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
        HostFlyerBox(onTap: _pickFlyer, imagePath: _flyer?.path, transform: _flyer?.transform, imageUrl: _coverUrl),
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
                enabled: (!_published || _canReschedule) && !_coHost,
                onTap: _published ? _reschedule : _pickDate,
                required: true,
              ),
              if (_coHost && !_published)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Only the host can change the date.', style: StudioType.caption12(color: c.textTertiary)),
                )
              else if (_published || _datePassed)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _canReschedule
                        ? 'A published event moves with Reschedule, which tells everyone with a ticket.'
                        : _published
                        ? "A published event's date can't be changed yet."
                        : 'That date has passed. Pick a new one.',
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
              if (_art == HostArtMode.auction)
                HostNavRow(
                  label: 'Bidding ends',
                  value: _biddingEndsLabel,
                  mono: true,
                  enabled: _date != null,
                  onTap: _pickBiddingEnd,
                ),
              HostNavRow(label: 'Age limit', value: _ageLabel(_ageLimit), onTap: _pickAge),
              HostSwitchRow(
                label: 'Public',
                subtitle: _public ? 'Shows in Events, search and profiles' : 'Only people with the link can find it',
                value: _public,
                onChanged: (v) => setState(() => _public = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _ageLabel(String age) => switch (age) {
    '18' => '18+',
    '21' => '21+',
    _ => 'All ages',
  };

  Future<void> _pickAge() async {
    final picked = await showHostOptionSheet<String>(
      context,
      title: 'Age limit',
      subtitle: 'Shown on the event page.',
      options: const [
        HostOption('all', 'All ages'),
        HostOption('18', '18+'),
        HostOption('21', '21+'),
      ],
      initial: _ageLimit,
    );
    if (picked != null && mounted) setState(() => _ageLimit = picked);
  }

  // --- Tickets -------------------------------------------------------------------------------

  String get _ticketLine => _capacity == null ? 'Free · no limit' : 'Free · $_capacity available';

  /// The host's own event: a co-host isn't asked about a seller profile (the server checks the
  /// host's, and a co-host just sees its message).
  bool get _isOwner => _editing == null || _editing!.isHost;

  bool get _anyPaid => _ticketed && _types.any((t) => !t.isFree);

  static String _refundLabel(String policy) => switch (policy) {
    '7d' => '7 days',
    '24h' => '24 hours',
    _ => 'No refunds',
  };

  /// `$25 · 40 available`, `Free · no limit`.
  static String _typeLine(EventTicketType t) {
    final price = t.isFree ? 'Free' : formatMoney(t.priceCents);
    final count = t.quantity == null ? 'no limit' : '${t.quantity} available';
    return '$price · $count';
  }

  Future<void> _editTicket() async {
    final result = await HostTicketPage.open(context, capacity: _capacity);
    if (result != null && mounted) setState(() => _capacity = result.capacity);
  }

  /// Paid tickets: ask for a seller profile first (the host's own event), then the first type.
  Future<void> _setTicketed(bool ticketed) async {
    if (ticketed == _ticketed) return;
    if (!ticketed) {
      if (_types.isNotEmpty) {
        final ok = await showStudioConfirm(
          context,
          title: 'Make it a free RSVP?',
          message: 'Your ticket types come off the event when you save. Tickets already sold stay valid.',
          confirmLabel: 'Make it free',
        );
        if (!ok || !mounted) return;
      }
      setState(() => _ticketed = false);
      return;
    }
    if (_types.isNotEmpty) {
      setState(() => _ticketed = true);
      return;
    }
    if (_isOwner && !AuthSession.instance.sellerEnabled) {
      final seller = await SellerSetupPage.prompt(
        context,
        secondaryLabel: 'Keep it free',
        returnLabel: 'Back to your event',
      );
      if (!seller || !mounted) return;
    }
    final result = await HostTicketPage.openType(
      context,
      type: const EventTicketType(id: '', name: 'General Admission'),
      isNew: true,
      checkSeller: _isOwner,
      startPaid: true,
      debugNow: widget.debugNow,
    );
    final type = result?.type;
    if (type == null || !mounted) return;
    setState(() {
      _types.add(type);
      _ticketed = true;
    });
  }

  Future<void> _addType() async {
    final result = await HostTicketPage.openType(
      context,
      isNew: true,
      checkSeller: _isOwner,
      debugNow: widget.debugNow,
    );
    final type = result?.type;
    if (type != null && mounted) setState(() => _types.add(type));
  }

  Future<void> _editType(int index) async {
    final result = await HostTicketPage.openType(
      context,
      type: _types[index],
      canRemove: true,
      checkSeller: _isOwner,
      debugNow: widget.debugNow,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.removed) {
        _types.removeAt(index);
      } else if (result.type != null) {
        _types[index] = result.type!;
      }
    });
  }

  Future<void> _pickRefund() async {
    final picked = await showHostOptionSheet<String>(
      context,
      title: 'Refund policy',
      subtitle: "Buyers see it before they pay. It can't change once a paid ticket has sold.",
      options: const [
        HostOption('7d', '7 days', subtitle: 'Refunds up to 7 days before the event'),
        HostOption('24h', '24 hours', subtitle: 'Refunds up to 24 hours before the event'),
        HostOption('none', 'No refunds'),
      ],
      initial: _refundPolicy,
    );
    if (picked != null && mounted) setState(() => _refundPolicy = picked);
  }

  Widget _typeCard(StudioColors c, int index) {
    final t = _types[index];
    final extra = [
      if ((t.includes ?? '').trim().isNotEmpty) t.includes!.trim(),
      if (t.perOrderLimit != null) 'Up to ${t.perOrderLimit} per order',
    ].join(' · ');
    return Padding(
      padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
      // The whole card opens the ticket, so Edit can sit level with the name.
      child: GestureDetector(
        onTap: () => _editType(index),
        behavior: HitTestBehavior.opaque,
        child: HostCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name, style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary)),
                    const SizedBox(height: 3),
                    Text(_typeLine(t), style: StudioType.label13(color: c.textPrimary)),
                    if (extra.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(extra, style: StudioType.caption12(color: c.textSecondary)),
                    ],
                    if (!t.isFree && t.hostNetCents != null && _originalTypes[t.id]?.priceCents == t.priceCents) ...[
                      const SizedBox(height: 3),
                      Text(
                        'You receive ${formatMoney(t.hostNetCents!)} per ticket',
                        style: StudioType.caption12(color: c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              HostTextAction(label: 'Edit', size: 13, inline: true, onTap: () => _editType(index)),
            ],
          ),
        ),
      ),
    );
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
              HostOption(true, 'Paid tickets', subtitle: 'Sell ticket types. Some can be free.'),
              HostOption(false, 'Free (RSVP)', subtitle: 'People reserve a spot. No payment.'),
            ],
            value: _ticketed,
            onChanged: _setTicketed,
          ),
          const HostLabel('Ticket types'),
          if (_ticketed) ...[
            for (var i = 0; i < _types.length; i++) _typeCard(c, i),
            HostTextAction(label: '+ Add ticket type', underline: true, onTap: _addType),
            if (_anyPaid) HostNavRow(label: 'Refund policy', value: _refundLabel(_refundPolicy), onTap: _pickRefund),
          ] else
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
                        Text(
                          'General Admission',
                          style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
                        ),
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

  /// A declined person: ask them again, or take them off.
  Future<void> _declinedPerson(EventLineupPerson person, {required bool cohost}) async {
    // Like showStudioConfirm, with Remove as a second action.
    final again = await showStudioSheet<bool>(
      context: context,
      builder: (sheetContext) {
        final c = sheetContext.studio;
        return StudioSheet(
          horizontalPadding: StudioSpace.marginForm,
          gap: 14,
          children: [
            Text('${person.displayName} declined', style: StudioType.title22(color: c.textPrimary)),
            Text(
              'Ask them again when you save, or take them off the event.',
              style: StudioType.body14(color: c.textSecondary),
            ),
            const SizedBox(height: 2),
            StudioButton(label: 'Ask again', onPressed: () => Navigator.pop(sheetContext, true)),
            StudioButton(
              label: 'Remove',
              variant: StudioButtonVariant.outline,
              onPressed: () => Navigator.pop(sheetContext, false),
            ),
            StudioButton(
              label: 'Cancel',
              variant: StudioButtonVariant.text,
              onPressed: () => Navigator.pop(sheetContext),
            ),
          ],
        );
      },
    );
    if (again == null || !mounted) return;
    setState(() {
      if (again) {
        _peopleStatus.remove(_statusKey(cohost ? 'cohost' : 'artist', person.username));
      } else {
        (cohost ? _cohosts : _artists).remove(person);
      }
    });
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
    // Selling your own piece needs a seller profile (`SellerPrompt`); the event stays open.
    // Someone else's piece is sold by its artist once they approve (Phase 5.2).
    if (mode != EventPieceMode.featured && _owns(tagged.piece) && !AuthSession.instance.sellerEnabled) {
      final seller = await SellerSetupPage.prompt(
        context,
        secondaryLabel: 'Keep it not for sale',
        returnLabel: 'Back to your event',
      );
      if (!seller || !mounted) return;
    }
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
    final price = await _askPrice(
      tagged.piece.title,
      auction: tagged.mode == EventPieceMode.bid,
      initial: tagged.price,
    );
    if (price != null && mounted) setState(() => _pieces[index] = tagged.copyWith(price: price));
  }

  Future<String?> _askPrice(String title, {required bool auction, String initial = ''}) {
    return showStudioSheet<String>(
      context: context,
      builder: (_) => HostPriceSheet(title: title, auction: auction, initial: initial),
    );
  }

  /// The viewer's own piece. Anyone else's can be shown, sold or auctioned too, but waits for
  /// its artist to approve (Phase 5.2).
  static bool _owns(PieceSummary piece) {
    final by = piece.authorUsername ?? '';
    return by.isEmpty || by == AuthSession.instance.user?.username;
  }

  /// A piece approved without asking: the viewer's own or the host's (Phase 5.2).
  bool _approvedAsIs(PieceSummary piece) =>
      _owns(piece) || (piece.authorUsername ?? '') == (_editing?.hostUsername ?? '');

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
      final ends = _biddingEnds;
      final end = ends == null
          ? ''
          : ' · Ends at ${hostTime(TimeOfDay.fromDateTime(ends))}${_date!.zone.isEmpty ? '' : ' ${_date!.zone}'}';
      return 'Starting bid $money$end';
    }
    return money;
  }

  static String? _statusLabel(String? status) => switch (status) {
    'invited' => 'Invited',
    'accepted' => 'Accepted',
    'declined' => 'Declined',
    _ => null,
  };

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
              status: _statusLabel(_statusOf(p, cohost: cohost)),
              // Only the host changes who is on the bill (Phase 5.1).
              onTap: _coHost
                  ? null
                  : _statusOf(p, cohost: cohost) == 'declined'
                  ? () => _declinedPerson(p, cohost: cohost)
                  : () => _removePerson(p, cohost: cohost),
            ),
            const SizedBox(width: 8),
          ],
          if (!_coHost)
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
            child: Text(
              'Artists you feature show on the event page.',
              style: StudioType.caption12(color: c.textSecondary),
            ),
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
                approval: _owns(_pieces[i].piece) ? null : _originalPieces[_pieces[i].piece.id]?.approvalLine,
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
                  Expanded(
                    child: Text(label, style: StudioType.label13(color: c.textSecondary)),
                  ),
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
            Text(
              _title.text.trim(),
              style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
            ),
            Text(EventCategoryOptions.byId(_category ?? '')?.name ?? '', style: small),
            Text('${_ageLabel(_ageLimit)} · ${_public ? 'Public' : 'Link only'}', style: small),
            Text(
              _art.sells ? 'Event art: ${_art.label} · ${_delivery.label}' : 'Event art: ${_art.label}',
              style: small,
            ),
            if (where.isNotEmpty) Text(where, style: muted),
            if (_date != null) Text(_date!.rangeLabel, style: StudioType.mono(12, color: c.textPrimary)),
          ]),
          card('Tickets', 1, [
            if (!_ticketed || _types.isEmpty)
              Text('General Admission · $_ticketLine', style: small)
            else
              for (final t in _types) Text('${t.name} · ${_typeLine(t)}', style: small),
            if (_anyPaid) Text('Refunds: ${_refundLabel(_refundPolicy)}', style: muted),
          ]),
          card('Lineup', 2, [
            if (_cohosts.isNotEmpty)
              Text(
                '${_cohosts.length == 1 ? 'Co-host' : 'Co-hosts'}: ${_cohosts.map((p) => p.displayName).join(', ')}',
                style: small,
              ),
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
              Text(
                'Add a price to every piece for sale.',
                style: StudioType.label13(weight: StudioType.medium, color: c.textPrimary),
              ),
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
    final plan = _piecePlan();
    // Changing someone else's piece sends it back to them (Phase 5.2).
    final askAgain = {
      for (final p in plan.changed)
        if (!_approvedAsIs(p.tagged.piece)) _originalPieces[p.tagged.piece.id]?.artistLabel ?? 'The artist',
    };
    if (askAgain.isNotEmpty) {
      final who = _listJoin(askAgain.toList());
      final go = await showStudioConfirm(
        context,
        title: '$who will be asked again',
        message: 'You changed how their work shows at this event, so it waits for them to approve it again.',
        confirmLabel: 'Save',
        cancelLabel: 'Keep editing',
      );
      if (!go || !mounted) return;
    }
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
        'ageLimit': _ageLimit,
        'visibility': _public ? 'public' : 'link',
        if (_anyPaid) 'refundPolicy': _refundPolicy,
        // Only when it changed: a published event's bidding end can't move once bid on.
        if (!_sameMoment(_auctionEndsAt, _originalAuctionEndsAt) && _art == HostArtMode.auction)
          'auctionEndsAt': _auctionEndsAt?.toUtc().toIso8601String(),
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
          ageLimit: _ageLimit,
          visibility: _public ? 'public' : 'link',
          refundPolicy: _anyPaid ? _refundPolicy : null,
          auctionEndsAt: _art == HostArtMode.auction ? _auctionEndsAt : null,
        );
        _created = event;
        _originalAuctionEndsAt = _art == HostArtMode.auction ? _auctionEndsAt : null;
      } else {
        event = await EventService.instance.update(existing.id, {
          ...fields,
          if (!_published && !_coHost) ...{
            'startsAt': date.startsAt.toUtc().toIso8601String(),
            'endsAt': date.endsAt.toUtc().toIso8601String(),
            if (date.zone.isNotEmpty) 'timezone': date.zone,
          },
        });
        if (fields.containsKey('auctionEndsAt')) _originalAuctionEndsAt = _auctionEndsAt;
      }
      // Only the host changes who is on the bill, and only when it changed: the lists are
      // replaced wholesale, so an untouched save must not reset anyone's invite (Phase 5.1).
      if (!_coHost && _peopleKey() != _originalPeople) {
        final saved = await EventService.instance.setPeople(
          event.id,
          cohostUsernames: _sendable(_cohosts, cohost: true),
          artistUsernames: _sendable(_artists, cohost: false),
        );
        _takePeopleStatus(saved);
      }
      await _savePieces(event.id, plan);
      await _saveTypes(event.id);
      // Only the host publishes; a co-host's edits to a draft are saved as they are.
      if (!event.isPublished && !_coHost) event = await EventService.instance.publish(event.id);
      if (!mounted) return;
      if (_published || _coHost) {
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
            ticketsLabel: !_ticketed || _types.isEmpty
                ? (_capacity == null ? 'Free · no limit' : 'Free · $_capacity total')
                : _types.length == 1
                ? _typeLine(_types.single)
                : '${_types.length} types · ${eventTicketRange(_types)}',
          ),
        ),
      );
    } on _SellerNeeded catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // The host sets up their seller profile; a co-host just sees why (it's the host's).
      if (_isOwner) {
        await SellerSetupPage.prompt(context, secondaryLabel: 'Not now', returnLabel: 'Back to your event');
      } else {
        showStudioToast(context, e.message, icon: null);
      }
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

  static bool _sameMoment(DateTime? a, DateTime? b) =>
      a == null ? b == null : (b != null && a.isAtSameMomentAs(b));

  /// Where each person stands after the host changed the bill, from the server's answer.
  void _takePeopleStatus(StudioEvent saved) {
    if (saved.invites.isNotEmpty) {
      _peopleStatus
        ..clear()
        ..addAll({for (final i in saved.invites) _statusKey(i.role, i.username): i.status});
      // Declined people the host left on the list were not sent, so they are off the event.
      _cohosts.removeWhere((p) => !_peopleStatus.containsKey(_statusKey('cohost', p.username)));
      _artists.removeWhere((p) => !_peopleStatus.containsKey(_statusKey('artist', p.username)));
    }
    _originalPeople = _peopleKey();
  }

  /// What each wanted piece should be on the server: its mode, price and delivery.
  ({String mode, int? cents, String delivery}) _wantedEntry(EventTaggedPiece p) {
    // One way of selling per event: a piece for sale follows Event art (sale or auction).
    final mode = !_art.sells || p.mode == EventPieceMode.featured
        ? 'featured'
        : (_art == HostArtMode.auction ? 'bid' : 'sale');
    return (
      mode: mode,
      cents: mode == 'featured' ? null : _cents(p.price),
      delivery: _delivery == HostDelivery.ship ? 'ship' : 'pickup',
    );
  }

  /// The bill's changes: pieces to take off, pieces already on it whose mode, price or delivery
  /// changed (taken off and added back), and new ones. Unchanged pieces are left alone, so an
  /// artist's approval isn't reset by a save that didn't touch their piece (Phase 5.2).
  ({List<String> removed, List<_PieceChange> changed, List<_PieceChange> added}) _piecePlan() {
    final wanted = _art == HostArtMode.none ? <EventTaggedPiece>[] : _pieces;
    final wantedIds = {for (final p in wanted) p.piece.id};
    final changed = <_PieceChange>[];
    final added = <_PieceChange>[];
    for (final (i, p) in wanted.indexed) {
      final entry = _wantedEntry(p);
      final change = _PieceChange(p, entry.mode, entry.cents, entry.delivery, i);
      final before = _originalPieces[p.piece.id];
      if (before == null) {
        added.add(change);
      } else if (before.mode != entry.mode ||
          (entry.mode != 'featured' && before.priceCents != entry.cents) ||
          (before.deliveryMode ?? entry.delivery) != entry.delivery) {
        changed.add(change);
      }
    }
    return (
      removed: [for (final id in _originalPieces.keys) if (!wantedIds.contains(id)) id],
      changed: changed,
      added: added,
    );
  }

  /// Takes off everything that goes or changed first, then adds back: an event either sells or
  /// auctions, so switching one piece at a time would meet the other mode still there (409).
  /// Each step is remembered in [_originalPieces], so a retry doesn't add a piece twice.
  Future<void> _savePieces(
    String eventId,
    ({List<String> removed, List<_PieceChange> changed, List<_PieceChange> added}) plan,
  ) async {
    final service = EventService.instance;
    for (final id in [...plan.removed, for (final c in plan.changed) c.tagged.piece.id]) {
      if (!_originalPieces.containsKey(id)) continue;
      await service.removePiece(eventId, id);
      _originalPieces.remove(id);
    }
    for (final c in [...plan.changed, ...plan.added]) {
      final id = c.tagged.piece.id;
      if (_originalPieces.containsKey(id)) continue;
      final added = await service.addPiece(
        eventId,
        pieceId: id,
        mode: c.mode,
        priceCents: c.cents,
        deliveryMode: c.delivery,
        sortOrder: c.sortOrder,
      );
      _originalPieces[id] = EventLineupItem(
        id: added.id,
        pieceId: id,
        mode: c.mode,
        priceCents: c.cents,
        deliveryMode: c.delivery,
        title: added.title ?? c.tagged.piece.title,
        artistUsername: added.artistUsername ?? c.tagged.piece.authorUsername,
        artistName: added.artistName ?? c.tagged.piece.authorName,
        approvalStatus: added.approvalStatus,
      );
    }
  }

  /// Sends the ticket types that changed: removed ones are deleted (or closed, once sold), new
  /// ones added and edited ones patched with only what changed. Each success is remembered in
  /// [_originalTypes], so a retry after a failure part way doesn't add a type twice.
  Future<void> _saveTypes(String eventId) async {
    final service = EventService.instance;
    final wanted = _ticketed ? _types : <EventTicketType>[];
    final wantedIds = {for (final t in wanted) t.id};
    for (final id in _originalTypes.keys.toList()) {
      if (wantedIds.contains(id)) continue;
      await service.deleteTicketType(eventId, id);
      _originalTypes.remove(id);
    }
    for (var i = 0; i < wanted.length; i++) {
      final t = wanted[i];
      try {
        if (t.id.isEmpty) {
          final created = await service.createTicketType(eventId, t);
          final saved = created.ticketTypes.firstWhere(
            (x) => x.id == created.id,
            orElse: () => _withId(t, created.id),
          );
          _originalTypes[saved.id] = saved;
          wanted[i] = saved;
        } else {
          final changes = _typeChanges(_originalTypes[t.id], t);
          if (changes.isEmpty) continue;
          final list = await service.updateTicketType(eventId, t.id, changes);
          final saved = list.firstWhere((x) => x.id == t.id, orElse: () => t);
          _originalTypes[t.id] = saved;
          wanted[i] = saved;
        }
      } on ApiException catch (e) {
        if (e.statusCode == 403) throw _SellerNeeded(e.message);
        rethrow;
      }
    }
  }

  /// What differs between the server's [before] and the host's [now], as a PATCH body. The price
  /// is sent only when it changed: a sold type's price can't (409).
  static Map<String, dynamic> _typeChanges(EventTicketType? before, EventTicketType now) {
    final next = now.toJson();
    if (before == null) return next;
    final was = before.toJson();
    return {
      for (final e in next.entries)
        if (e.key != 'sortOrder' && was[e.key] != e.value) e.key: e.value,
    };
  }

  static EventTicketType _withId(EventTicketType t, String id) => EventTicketType(
    id: id,
    name: t.name,
    priceCents: t.priceCents,
    includes: t.includes,
    perOrderLimit: t.perOrderLimit,
    quantity: t.quantity,
    saleStartsAt: t.saleStartsAt,
    saleEndsAt: t.saleEndsAt,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final last = _step == kHostSteps.length - 1;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return PopScope(
      // A new event always asks before back leaves it; an untouched edit just closes.
      canPop: _step == 0 && !_saving && !_dirty && _editing != null,
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
                label: last
                    ? (_editing?.isPublished ?? false) || _coHost
                          ? 'Save changes'
                          : 'Publish event'
                    : 'Save and continue',
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
            'Bidding ends 30 minutes before the event ends, or earlier if you pick a time in Details.',
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
    required this.priceLine,
    this.approval,
    required this.onMode,
    required this.onRemove,
    required this.onQr,
    this.onPrice,
  });

  final EventTaggedPiece tagged;
  final HostArtMode art;

  /// Someone else's piece: "Waiting for Mira" / "Approved by Mira" / "Declined by Mira"
  /// (Phase 5.2). Null for the viewer's own.
  final String? approval;
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
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(color: c.surface),
                        ),
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
                if (!collected)
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
          ],
          if (approval != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(approval!, style: StudioType.caption12(color: c.textSecondary)),
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: StudioTapArea(child: GestureDetector(
                  onTap: onPrice,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 32,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(priceLine, style: StudioType.label13(color: c.textBody)),
                    ),
                  ),
                )),
              ),
              StudioTapArea(child: Semantics(
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
                        Text(
                          'Link and QR code',
                          style: StudioType.label13(weight: StudioType.medium, color: c.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }
}

/// Price (or starting bid) for a piece sold at the event: an underline field with "$" and Done.
/// Also the artist's own price on a piece request (Phase 5.2).
class HostPriceSheet extends StatefulWidget {
  const HostPriceSheet({super.key, required this.title, required this.auction, required this.initial});

  final String title;
  final bool auction;
  final String initial;

  @override
  State<HostPriceSheet> createState() => HostPriceSheetState();
}

class HostPriceSheetState extends State<HostPriceSheet> {
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

/// One piece to add (again) to the bill, with what to send.
class _PieceChange {
  const _PieceChange(this.tagged, this.mode, this.cents, this.delivery, this.sortOrder);

  final EventTaggedPiece tagged;
  final String mode;
  final int? cents;
  final String delivery;
  final int sortOrder;
}

/// A paid ticket type was refused for want of the host's seller profile (403).
class _SellerNeeded implements Exception {
  const _SellerNeeded(this.message);

  final String message;
}

/// Bidding ends (Phase 5.3), laid out like the date sheet's time wheel: a date-and-time wheel
/// from just after the start to 30 minutes before the end, Done, and Use the default.
/// Returns `(at: null)` for the default.
class _BiddingEndSheet extends StatefulWidget {
  const _BiddingEndSheet({required this.date, this.initial});

  final HostDateSelection date;
  final DateTime? initial;

  @override
  State<_BiddingEndSheet> createState() => _BiddingEndSheetState();
}

class _BiddingEndSheetState extends State<_BiddingEndSheet> {
  static const _step = 5;

  static DateTime _floor(DateTime d) => DateTime(d.year, d.month, d.day, d.hour, d.minute - d.minute % _step);

  late final DateTime _max = _floor(widget.date.endsAt.subtract(const Duration(minutes: 30)));
  late final DateTime _min = _floor(widget.date.startsAt).add(const Duration(minutes: _step));
  late DateTime _picked = () {
    final at = widget.initial == null ? _max : _floor(widget.initial!);
    if (at.isBefore(_min)) return _min;
    if (at.isAfter(_max)) return _max;
    return at;
  }();

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final fits = !_max.isBefore(_min);
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 10,
      children: [
        Text('Bidding ends', style: StudioType.title22(color: c.textPrimary)),
        Text(
          'Any time after the event starts, up to 30 minutes before it ends.',
          style: StudioType.body14(color: c.textSecondary),
        ),
        if (fits)
          SizedBox(
            height: 200,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(context).brightness,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: StudioType.sans(20, color: c.textPrimary),
                ),
              ),
              child: CupertinoDatePicker(
                mode: widget.date.multiDay ? CupertinoDatePickerMode.dateAndTime : CupertinoDatePickerMode.time,
                minuteInterval: _step,
                initialDateTime: _picked,
                minimumDate: _min,
                maximumDate: _max,
                onDateTimeChanged: (d) => _picked = d,
              ),
            ),
          ),
        StudioButton(label: 'Done', onPressed: fits ? () => Navigator.pop(context, (at: _picked)) : null),
        StudioButton(
          label: 'Use the default',
          variant: StudioButtonVariant.text,
          onPressed: () => Navigator.pop(context, (at: null)),
        ),
      ],
    );
  }
}
