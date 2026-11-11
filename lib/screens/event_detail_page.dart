import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_link_config.dart';
import '../models/studio_event.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/event_service.dart';
import '../services/saved_content_store.dart';
import '../services/user_service.dart';
import '../utils/app_destination.dart';
import '../utils/profile_navigation.dart';
import '../utils/require_login.dart';
import '../widgets/save_flow.dart';
import '../widgets/events/event_detail_widgets.dart';
import '../widgets/events/event_tickets_sheet.dart';
import '../widgets/events/event_waitlist_sheets.dart';
import '../widgets/accept_decline_buttons.dart';
import '../widgets/follow_button.dart';
import '../widgets/piece_detail/detail_follow_state.dart';
import '../widgets/share/share_sheet.dart';
import '../widgets/studio/studio.dart';
import 'event_checkout_page.dart';
import 'event_confirmed_page.dart';
import 'event_piece_request_page.dart';
import 'host/host_manage_page.dart';

/// Returns the pushed route's future, so a caller that wants to know when the viewer is
/// back — to refresh a list something on this page could have changed, an RSVP or a
/// delete — can await it instead of guessing when to re-fetch.
/// [openTickets] opens Choose tickets as soon as the page is up (the feed card's Get tickets).
Future<void> openEventDetail(BuildContext context, StudioEvent event, {bool openTickets = false}) {
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => EventDetailPage(event: event, openTickets: openTickets)));
}

/// The event page (`EvDetail`): the flyer with back, save, share and more over it; Hosted by
/// with Follow; Details; Featured artists; Pieces at this event; Location with a map that
/// opens directions; the host's FAQs; and the bar at the bottom with From, When and Get
/// tickets.
///
/// Get tickets opens Choose tickets (`EvChooseTickets`). An event with no ticket types offers
/// one free place and Reserve saves the RSVP; free ticket types are ordered at once, and paid
/// tickets go through checkout (`EvCheckout`, BACKEND_CHANGES B22).
/// The host's FAQs and whether the viewer follows the host come with the detail
/// (BACKEND_CHANGES B24); without the follow flags the page asks the host's profile.
class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key, required this.event, this.debugDetail, this.openTickets = false});

  final StudioEvent event;

  /// Open Choose tickets once the page is up.
  final bool openTickets;

  /// For tests: the full event, so the page neither fetches it nor the host's profile.
  @visibleForTesting
  final StudioEvent? debugDetail;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> with DetailFollowState<EventDetailPage> {
  final _store = SavedContentStore.instance;

  /// The full event, once fetched.
  ///
  /// The card that opened this page carries no bill, no cohosts and no description — those
  /// only come with the detail payload. Rendering the card first and filling in behind it
  /// means the header, title and time are on screen immediately instead of behind a spinner.
  StudioEvent? _detail;

  StudioEvent get _event => _detail ?? widget.event;

  bool _rsvping = false;
  bool _waitlistBusy = false;
  bool _answering = false;

  /// The held sheet opens by itself once per visit (from the notification or the page).
  bool _heldShown = false;

  /// Re-fetches while a piece on the bill is up for auction, so the bid under it stays
  /// current for someone standing in the room.
  Timer? _poll;
  static const _pollInterval = Duration(seconds: 12);

  bool get _debug => widget.debugDetail != null;

  /// Follow has its answer (from the detail, the host's profile, or a tap), so a later
  /// refresh doesn't overwrite it.
  bool _followKnown = false;

  @override
  String get followUsername => _event.hostUsername ?? '';

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    if (_debug) {
      _detail = widget.debugDetail;
      _applyHostFollow(widget.debugDetail!);
      return;
    }
    _loadDetail();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.openTickets && !_ticketsOpened) {
      _ticketsOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final e = _event;
        final soldOut = e.isFull || e.ticketOptions.every((t) => t.isSoldOut);
        if (mounted && e.canRsvp && !soldOut && !e.viewerIsGoing) _getTickets();
      });
    }
  }

  bool _ticketsOpened = false;

  @override
  void dispose() {
    _poll?.cancel();
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDetail() async {
    try {
      final full = await EventService.instance.getById(widget.event.id);
      if (!mounted) return;
      setState(() => _detail = full);
      if (!_followKnown && !_applyHostFollow(full)) _loadFollow();
      _syncPolling();
      if (!_heldShown && full.waitlist?.isHeld(DateTime.now()) == true) {
        _heldShown = true;
        _openHeld();
      }
    } catch (_) {
      // The card's own fields still render. A failed refresh is not worth an error screen
      // over content that is already on the page.
      if (!_followKnown) _loadFollow();
    }
  }

  /// Follow from the detail's flags (B24); false when the detail doesn't carry them.
  bool _applyHostFollow(StudioEvent e) {
    final following = e.hostIsFollowing;
    if (following == null) return false;
    _followKnown = true;
    followState = following
        ? FollowState.following
        : (e.hostFollowRequested == true ? FollowState.pending : FollowState.none);
    return true;
  }

  @override
  Future<void> toggleFollow() {
    _followKnown = true;
    return super.toggleFollow();
  }

  void _syncPolling() {
    final live = _event.liveLineup.any((item) => item.isBiddingOpen);
    if (live && _poll == null) {
      _poll = Timer.periodic(_pollInterval, (_) => _loadDetail());
    } else if (!live) {
      _poll?.cancel();
      _poll = null;
    }
  }

  /// When the detail doesn't say whether the viewer follows the host (a server without B24, or
  /// the detail failed), it comes from the host's profile.
  Future<void> _loadFollow() async {
    final host = widget.event.hostUsername;
    if (host == null || host.isEmpty || widget.event.isHost || !AuthSession.instance.isLoggedIn) {
      return;
    }
    try {
      final profile = await UserService.instance.getPublicProfile(host);
      if (!mounted || _followKnown) return;
      _followKnown = true;
      setState(() {
        followState = profile.isFollowing
            ? FollowState.following
            : (profile.followRequestPending ? FollowState.pending : FollowState.none);
      });
    } catch (_) {
      // Follow stays as Follow; tapping it still works.
    }
  }

  /// Save on the server, then mirror locally so the Saved tab updates without a round trip.
  Future<void> _toggleSaved() async {
    if (!await requireLogin(
      context,
      title: 'Sign in to save events',
      message: 'Log in or create a free account to save events.',
    )) {
      return;
    }
    final wasSaved = _store.isSaved(_event.id);
    try {
      await EventService.instance.setSaved(_event.id, saved: !wasSaved);
      if (!mounted) return;
      _store.toggleEvent(_event);
      announceEventSave(context, _event, saved: !wasSaved);
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not save that event.', icon: null);
    }
  }

  /// Say you're coming, or take it back.
  ///
  /// The response carries the fresh counts, so the bar updates from what the server actually
  /// recorded rather than from an optimistic guess that a full event would get wrong. True
  /// when the server took it.
  Future<bool> _setGoing(bool going) async {
    if (!await requireLogin(
      context,
      title: 'Sign in to get tickets',
      message: 'Log in or create a free account to go to events.',
    )) {
      return false;
    }
    if (!mounted) return false;
    setState(() => _rsvping = true);
    try {
      final result = await EventService.instance.setRsvp(_event.id, going: going);
      if (!mounted) return false;
      setState(() {
        _rsvping = false;
        _detail = _event.copyWith(
          viewerIsGoing: result.going,
          rsvpCount: result.rsvpCount,
          spotsLeft: result.spotsLeft,
          isFull: result.isFull,
        );
      });
      // Going opens the confirmation (`EvConfirmed`) from the caller.
      if (!result.going) showStudioToast(context, 'Your place is cancelled');
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      setState(() => _rsvping = false);
      showStudioToast(context, e.message, icon: null);
      // A 409 means somebody took the last place while this screen was open, so the counts
      // on it are already wrong.
      await _loadDetail();
      return false;
    } catch (_) {
      if (!mounted) return false;
      setState(() => _rsvping = false);
      showStudioToast(context, 'Could not update your place.', icon: null);
      return false;
    }
  }

  /// Reserve the free tickets in [choice], then You're going.
  ///
  /// An event with no ticket types offers one made-up General Admission place
  /// ([StudioEvent.ticketOptions], id `rsvp`): that is an RSVP. Free ticket types are ordered
  /// (B22), which issues them at once; `rsvp` is never sent as an order item.
  Future<void> _reserve(EventTicketChoice choice) async {
    final rsvpOnly = choice.counts.entries
        .where((e) => e.value > 0)
        .every((e) => e.key.id == EventService.rsvpTypeId);
    if (rsvpOnly) {
      if (await _setGoing(true) && mounted) {
        // A B22 server issues a ticket for the RSVP; the refreshed event says so.
        if (!_debug) await _loadDetail();
        if (!mounted) return;
        if (await EventConfirmedPage.open(context, event: _event, choice: choice)) await _loadDetail();
      }
      return;
    }
    if (!await requireLogin(
      context,
      title: 'Sign in to get tickets',
      message: 'Log in or create a free account to go to events.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _rsvping = true);
    try {
      final order = await EventService.instance.placeOrder(_event.id, choice.counts);
      if (!_debug) await _loadDetail();
      if (!mounted) return;
      setState(() => _rsvping = false);
      // A refund from View tickets changes what the page shows.
      if (await EventConfirmedPage.open(
        context,
        event: _event,
        choice: choice,
        orderId: order.id.isEmpty ? null : order.id,
      )) {
        await _loadDetail();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _rsvping = false);
      showStudioToast(context, e.message, icon: null);
      // A type may have sold out while the sheet was open.
      if (!_debug) await _loadDetail();
    } catch (_) {
      if (!mounted) return;
      setState(() => _rsvping = false);
      showStudioToast(context, 'Could not reserve your tickets.', icon: null);
    }
  }

  /// Choose tickets, then Reserve for free tickets. Signing in is asked at Reserve, so anyone
  /// can look at the ticket types first.
  Future<void> _getTickets() async {
    final choice = await EventTicketsSheet.show(context, _event);
    if (choice == null || !mounted) return;
    await _continueWith(choice);
  }

  /// Reserve free tickets, or go on to checkout for paid ones.
  Future<void> _continueWith(EventTicketChoice choice) async {
    if (choice.isFree) {
      await _reserve(choice);
      return;
    }
    // Paid tickets: checkout signs in first, like Reserve.
    if (!await requireLogin(
      context,
      title: 'Sign in to get tickets',
      message: 'Log in or create a free account to go to events.',
    )) {
      return;
    }
    if (!mounted) return;
    final result = await EventCheckoutPage.open(context, event: _event, choice: choice);
    if (!mounted || result == null) return;
    if (result.outcome == EventCheckoutOutcome.reserveInstead) {
      await _reserve(result.choice);
      return;
    }
    await _loadDetail();
    if (!mounted) return;
    if (await EventConfirmedPage.open(
      context,
      event: _event,
      choice: result.choice,
      email: UserService.instance.peekMeCached()?.email,
      orderId: result.orderId,
      order: result.order,
      pending: result.pending,
    )) {
      await _loadDetail();
    }
  }

  /// Join waitlist (`EvSoldOut`, `EvWaitlistJoin`): pick how many of each type, then save
  /// their place. Free, no card.
  Future<void> _joinWaitlist() async {
    if (!await requireLogin(
      context,
      title: 'Sign in to join the waitlist',
      message: 'Log in or create a free account to go to events.',
    )) {
      return;
    }
    if (!mounted) return;
    final wanted = await EventWaitlistJoinSheet.show(context, _event);
    if (wanted == null || wanted.isEmpty || !mounted) return;
    setState(() => _waitlistBusy = true);
    try {
      final waitlist = await EventService.instance.joinWaitlist(_event.id, wanted);
      if (!mounted) return;
      setState(() => _detail = _event.copyWith(waitlist: waitlist));
      showStudioToast(context, "You're on the waitlist");
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not join the waitlist.', icon: null);
    } finally {
      if (mounted) setState(() => _waitlistBusy = false);
    }
  }

  /// You're on the waitlist: tap to leave.
  Future<void> _leaveWaitlist() async {
    final leave = await showStudioConfirm(
      context,
      title: 'Leave the waitlist?',
      message: "You'll lose your place in line.",
      confirmLabel: 'Leave',
      cancelLabel: 'Stay on it',
    );
    if (!leave || !mounted) return;
    setState(() => _waitlistBusy = true);
    try {
      await EventService.instance.leaveWaitlist(_event.id);
      if (!mounted) return;
      setState(() => _detail = _event.copyWith(waitlist: EventWaitlist(open: _event.waitlist?.open ?? true)));
      showStudioToast(context, 'You left the waitlist');
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not leave the waitlist.', icon: null);
    } finally {
      if (mounted) setState(() => _waitlistBusy = false);
    }
  }

  /// Tickets held for you (`EvWaitlistHeld`).
  Future<void> _openHeld() async {
    final result = await EventWaitlistHeldSheet.show(context, _event);
    if (result == null || !mounted) return;
    switch (result.action) {
      case WaitlistHeldAction.buy:
        await _continueWith(result.choice!);
      case WaitlistHeldAction.expired:
        showStudioToast(context, 'Your hold ended, so the tickets went to the next person.', icon: null);
        await _loadDetail();
      case WaitlistHeldAction.keepWaiting:
        try {
          final waitlist = await EventService.instance.releaseHold(_event.id);
          if (!mounted) return;
          setState(() => _detail = _event.copyWith(waitlist: waitlist));
          showStudioToast(context, "You're still on the waitlist");
        } catch (_) {
          if (mounted) showStudioToast(context, 'Could not update the waitlist.', icon: null);
        }
    }
  }

  Future<void> _share() {
    // A real https:// link: the backend's /share/event page opens the app when it is
    // installed and shows the event on the web otherwise.
    return ShareSheet.show(
      context,
      shareText:
          '${_event.title} · ${_event.venue}\n${_event.scheduleLine}\n'
          '${AppLinkConfig.eventUrl(_event.id)}',
      copyLabel: 'Copy',
      copiedMessage: 'Copied',
    );
  }

  Future<void> _manage() async {
    await HostManagePage.open(context, _event);
    _loadDetail();
  }

  /// Answer the viewer's invite to be on the bill (Phase 5.1), then show the event as it now is.
  Future<void> _answerInvite({required bool accept}) async {
    setState(() => _answering = true);
    try {
      if (accept) {
        await EventService.instance.acceptInvite(_event.id);
      } else {
        await EventService.instance.declineInvite(_event.id);
      }
      if (!mounted) return;
      showStudioToast(context, accept ? "You're on the event" : 'Invite declined');
      await _loadDetail();
    } on ApiException catch (e) {
      if (!mounted) return;
      showStudioToast(context, e.message, icon: null);
      await _loadDetail();
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not answer the invite. Try again.', icon: null);
    } finally {
      if (mounted) setState(() => _answering = false);
    }
  }

  /// The viewer's own piece waiting for their answer (Phase 5.2), if any.
  EventLineupItem? _myWaitingPiece(StudioEvent e) {
    final me = AuthSession.instance.user?.username;
    if (me == null || me.isEmpty) return null;
    for (final item in e.lineup) {
      if (item.isWaiting && item.artistUsername == me) return item;
    }
    return null;
  }

  Future<void> _reviewRequest(EventLineupItem item) async {
    final answered = await EventPieceRequestPage.open(context, EventPieceRequest(item: item, event: _event));
    if (answered && mounted) await _loadDetail();
  }

  /// The ··· menu: the host's QR codes, "Can't make it" once going, and Copy link.
  void _openMore() {
    final event = _event;
    showStudioSheet<void>(
      context: context,
      builder: (sheetContext) => StudioSheet(
        horizontalPadding: 24,
        gap: 6,
        children: [
          if (event.canManage)
            StudioActionRow(
              icon: StudioIcons.ticket,
              title: 'Manage event',
              subtitle: 'Guests, piece QR codes, edit or cancel',
              onTap: () {
                Navigator.pop(sheetContext);
                _manage();
              },
            ),
          if (event.viewerIsGoing && !event.isHost)
            StudioActionRow(
              icon: StudioIcons.close,
              title: "Can't make it",
              subtitle: 'Gives your place back',
              onTap: () {
                Navigator.pop(sheetContext);
                _setGoing(false);
              },
            ),
          StudioActionRow(
            icon: StudioIcons.link,
            title: 'Copy link',
            onTap: () {
              Navigator.pop(sheetContext);
              Clipboard.setData(ClipboardData(text: AppLinkConfig.eventUrl(event.id)));
              showStudioToast(context, 'Link copied');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openDirections() => openEventDirections(context, _event);

  Widget? _bottomBar(StudioEvent e) {
    if (e.isOver && !e.isCancelled) return null;
    final when = StudioBottomBarInfo(label: 'When', value: eventDayLabel(e), mono: true);
    final options = e.ticketOptions;
    final from = StudioBottomBarInfo(label: 'Tickets', value: eventTicketRange(options));
    final soldOut = e.isFull || options.every((t) => t.isSoldOut);
    if (e.isCancelled) {
      return const StudioBottomBar(button: StudioButton(label: 'Event cancelled', onPressed: null));
    }
    // Phase 5.1: asked onto the bill and not answered yet.
    if (e.hasPendingInvite) {
      return StudioBottomBar(
        left: StudioBottomBarInfo(
          label: 'Invited as',
          value: e.viewerInvite!.isCohost ? 'Co-host' : 'Featured artist',
        ),
        right: when,
        button: Align(
          alignment: Alignment.centerRight,
          child: AcceptDeclineButtons(
            busy: _answering,
            onAccept: () => _answerInvite(accept: true),
            onDecline: () => _answerInvite(accept: false),
          ),
        ),
      );
    }
    // Phase 5.2: a host wants the viewer's piece at this event.
    final waiting = _myWaitingPiece(e);
    if (waiting != null) {
      return StudioBottomBar(
        left: const StudioBottomBarInfo(label: 'Your piece', value: 'Waiting for you'),
        right: when,
        button: StudioButton(label: 'Review request', onPressed: () => _reviewRequest(waiting)),
      );
    }
    if (e.canManage) {
      return StudioBottomBar(
        left: StudioBottomBarInfo(label: 'Going', value: '${e.rsvpCount}'),
        right: when,
        button: StudioButton(
          label: 'Manage event',
          variant: StudioButtonVariant.outline,
          height: 52,
          onPressed: _manage,
        ),
      );
    }
    if (e.viewerIsGoing) {
      return StudioBottomBar(
        left: from,
        right: when,
        button: StudioButton(
          label: "You're going",
          variant: StudioButtonVariant.outline,
          height: 52,
          loading: _rsvping,
          onPressed: _rsvping ? null : _openMore,
        ),
      );
    }
    final waitlist = e.waitlist;
    // `EvWaitlistHeld`: tickets held for the viewer.
    if (waitlist != null && waitlist.isHeld(DateTime.now())) {
      return StudioBottomBar(
        left: const StudioBottomBarInfo(label: 'Tickets', value: 'Held for you'),
        right: when,
        button: StudioButton(label: 'Get your tickets', onPressed: _openHeld),
      );
    }
    // `EvSoldOut`: Tickets Sold out, and Join waitlist, or You're on the waitlist (tap to
    // leave), when the server runs a waitlist (BACKEND_CHANGES B22).
    if (soldOut && waitlist != null && (waitlist.open || waitlist.joined)) {
      return StudioBottomBar(
        left: const StudioBottomBarInfo(label: 'Tickets', value: 'Sold out'),
        right: when,
        button: waitlist.joined
            ? StudioButton(
                label: "You're on the waitlist",
                variant: StudioButtonVariant.outline,
                height: 52,
                loading: _waitlistBusy,
                onPressed: _waitlistBusy ? null : _leaveWaitlist,
              )
            : StudioButton(
                label: 'Join waitlist',
                loading: _waitlistBusy,
                onPressed: _waitlistBusy ? null : _joinWaitlist,
              ),
      );
    }
    // Until then: the grey bar, where Save is how to hear if tickets open up.
    if (soldOut) return EventSoldOutBar(saved: _store.isSaved(e.id), onSave: _toggleSaved);
    return StudioBottomBar(
      left: from,
      right: when,
      button: StudioButton(
        label: 'Get tickets',
        loading: _rsvping,
        onPressed: e.canRsvp && !_rsvping ? _getTickets : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final e = _event;
    final bar = _bottomBar(e);
    // Approved pieces only: waiting and declined entries reach the host, co-hosts and the
    // artist, but aren't on the event yet (Phase 5.2).
    final pieces = e.liveLineup.where((item) => item.pieceId.isNotEmpty).toList();
    final address = e.address?.trim() ?? '';

    Widget padded(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status bar icons over the flyer, like the top icons.
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: c.background,
        body: Stack(
          children: [
            ListView(
              padding: EdgeInsets.only(bottom: bar == null ? MediaQuery.paddingOf(context).bottom + 40 : 200),
              children: [
                EventHero(
                  event: e,
                  saved: _store.isSaved(e.id),
                  onBack: () => Navigator.of(context).maybePop(),
                  onSave: _toggleSaved,
                  onShare: _share,
                  onMore: _openMore,
                ),
                padded(
                  EventHostRow(
                    event: e,
                    followLabel: followState.actionLabel,
                    followIcon: followState.icon,
                    followFilled: followState.filled,
                    followBusy: followBusy,
                    onFollow: toggleFollow,
                    onHost: () => openUserProfile(context, e.hostUsername),
                  ),
                ),
                // `EvPast`: the ended note, and the work from the show right under it so people
                // can still buy it. A cancelled event says so in the same box.
                if (e.isCancelled || e.isOver)
                  padded(
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: EventEndedNote(
                        e.isCancelled
                            ? (e.cancellationReason?.trim().isNotEmpty == true
                                  ? 'This event was cancelled. ${e.cancellationReason!.trim()}'
                                  : 'This event was cancelled.')
                            : pieces.isEmpty
                            ? 'This event has ended.'
                            : 'This event has ended. The pieces shown here are still on Studio 3.',
                      ),
                    ),
                  ),
                // Phase 4.4: the host moved it; their message, when they left one.
                if (e.rescheduledAt != null && !e.isCancelled && !e.isOver)
                  padded(
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: EventEndedNote(rescheduledNote(e)),
                    ),
                  ),
                if (e.isOver && !e.isCancelled && pieces.isNotEmpty)
                  EventShowWorkRow(
                    items: pieces,
                    onPiece: (item) =>
                        openDestination(context, AppDestination(AppDestinationType.piece, item.pieceId)),
                  ),
                if (e.details.trim().isNotEmpty) ...[
                  padded(const EventDetailHeading('Details', top: 22, bottom: 8)),
                  padded(EventDetailsText(e.details.trim())),
                ],
                if (e.artists.isNotEmpty) ...[
                  padded(const EventDetailHeading('Featured artists')),
                  EventArtistsRow(
                    artists: e.artists,
                    onArtist: (artist) => openUserProfile(context, artist.username),
                  ),
                ],
                if (pieces.isNotEmpty && !(e.isOver && !e.isCancelled)) ...[
                  padded(const EventDetailHeading('Pieces at this event')),
                  EventPiecesRow(
                    items: pieces,
                    onPiece: (item) =>
                        openDestination(context, AppDestination(AppDestinationType.piece, item.pieceId)),
                  ),
                ],
                if (address.isNotEmpty) ...[
                  padded(const EventDetailHeading('Location', bottom: 8)),
                  padded(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(address, style: StudioType.body15(color: c.textPrimary)),
                    ),
                  ),
                  padded(EventMapCard(onTap: _openDirections)),
                ],
                if (e.faqs.isNotEmpty) ...[
                  padded(const EventDetailHeading('FAQs', bottom: 0)),
                  for (final faq in e.faqs) padded(EventFaqRow(question: faq.question, answer: faq.answer)),
                ],
              ],
            ),
            if (bar != null) Positioned(left: 0, right: 0, bottom: 0, child: bar),
          ],
        ),
      ),
    );
  }
}
