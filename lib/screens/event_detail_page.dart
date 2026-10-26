import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../theme/collect_detail_tokens.dart' show formatMoney;
import '../widgets/events/event_detail_widgets.dart';
import '../widgets/events/event_tickets_sheet.dart';
import '../widgets/follow_button.dart';
import '../widgets/piece_detail/detail_follow_state.dart';
import '../widgets/share/share_sheet.dart';
import '../widgets/studio/studio.dart';
import 'event_checkout_page.dart';
import 'event_qr_codes_page.dart';

/// Returns the pushed route's future, so a caller that wants to know when the viewer is
/// back — to refresh a list something on this page could have changed, an RSVP or a
/// delete — can await it instead of guessing when to re-fetch.
Future<void> openEventDetail(BuildContext context, StudioEvent event) {
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => EventDetailPage(event: event)));
}

/// The event page (`EvDetail`): the flyer with back, save, share and more over it; Hosted by
/// with Follow; Details; Featured artists; Pieces at this event; Location with a map that
/// opens directions; the host's FAQs; and the bar at the bottom with From, When and Get
/// tickets.
///
/// Get tickets opens Choose tickets (`EvChooseTickets`). Every event is free on the server and
/// an RSVP is a headcount (BACKEND_CHANGES B22), so the sheet offers one free place and Reserve
/// saves the RSVP; paid tickets go through checkout (`EvCheckout`) once the server sells them.
/// FAQs and the host's follow state are BACKEND_CHANGES B24.
class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key, required this.event, this.debugDetail});

  final StudioEvent event;

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

  /// Re-fetches while a piece on the bill is up for auction, so the bid under it stays
  /// current for someone standing in the room.
  Timer? _poll;
  static const _pollInterval = Duration(seconds: 12);

  bool get _debug => widget.debugDetail != null;

  @override
  String get followUsername => _event.hostUsername ?? '';

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    if (_debug) {
      _detail = widget.debugDetail;
      return;
    }
    _loadDetail();
    _loadFollow();
  }

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
      _syncPolling();
    } catch (_) {
      // The card's own fields still render. A failed refresh is not worth an error screen
      // over content that is already on the page.
    }
  }

  void _syncPolling() {
    final live = _event.lineup.any((item) => item.isBiddingOpen);
    if (live && _poll == null) {
      _poll = Timer.periodic(_pollInterval, (_) => _loadDetail());
    } else if (!live) {
      _poll?.cancel();
      _poll = null;
    }
  }

  /// The event payload does not say whether the viewer follows the host (B24), so it comes
  /// from the host's profile.
  Future<void> _loadFollow() async {
    final host = widget.event.hostUsername;
    if (host == null || host.isEmpty || widget.event.isHost || !AuthSession.instance.isLoggedIn) {
      return;
    }
    try {
      final profile = await UserService.instance.getPublicProfile(host);
      if (!mounted) return;
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
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not save that event.', icon: null);
    }
  }

  /// Say you're coming, or take it back.
  ///
  /// The response carries the fresh counts, so the bar updates from what the server actually
  /// recorded rather than from an optimistic guess that a full event would get wrong.
  Future<void> _setGoing(bool going) async {
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
      final result = await EventService.instance.setRsvp(_event.id, going: going);
      if (!mounted) return;
      setState(() {
        _rsvping = false;
        _detail = _event.copyWith(
          viewerIsGoing: result.going,
          rsvpCount: result.rsvpCount,
          spotsLeft: result.spotsLeft,
          isFull: result.isFull,
        );
      });
      showStudioToast(context, result.going ? "You're going" : 'Your place is cancelled');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _rsvping = false);
      showStudioToast(context, e.message, icon: null);
      // A 409 means somebody took the last place while this screen was open, so the counts
      // on it are already wrong.
      await _loadDetail();
    } catch (_) {
      if (!mounted) return;
      setState(() => _rsvping = false);
      showStudioToast(context, 'Could not update your place.', icon: null);
    }
  }

  /// Choose tickets, then Reserve for free tickets. Signing in is asked at Reserve, so anyone
  /// can look at the ticket types first.
  Future<void> _getTickets() async {
    final choice = await EventTicketsSheet.show(context, _event);
    if (choice == null || !mounted) return;
    if (choice.isFree) {
      await _setGoing(true);
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
    final outcome = await EventCheckoutPage.open(context, event: _event, choice: choice);
    if (!mounted || outcome == null) return;
    if (outcome == EventCheckoutOutcome.reserveInstead) {
      await _setGoing(true);
      return;
    }
    showStudioToast(context, "You're going");
    await _loadDetail();
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

  void _openQrCodes() => EventQrCodesPage.open(context, eventId: _event.id, eventTitle: _event.title);

  /// The ··· menu: the host's QR codes, "Can't make it" once going, and Copy link.
  void _openMore() {
    final event = _event;
    showStudioSheet<void>(
      context: context,
      builder: (sheetContext) => StudioSheet(
        horizontalPadding: 24,
        gap: 6,
        children: [
          if (event.isHost)
            StudioActionRow(
              icon: StudioIcons.ticket,
              title: 'QR codes for pieces',
              subtitle: 'Print them to hang beside each work',
              onTap: () {
                Navigator.pop(sheetContext);
                _openQrCodes();
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

  /// Directions in the phone's maps app, to the pin when there is one, else the address.
  Future<void> _openDirections() async {
    final event = _event;
    final target = event.hasLocation
        ? '${event.latitude},${event.longitude}'
        : (event.address ?? event.venue);
    if (target.trim().isEmpty) return;
    final q = Uri.encodeComponent(target);
    final apple = !kIsWeb && Platform.isIOS;
    final uri = Uri.parse(
      apple ? 'https://maps.apple.com/?daddr=$q' : 'https://www.google.com/maps/dir/?api=1&destination=$q',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!opened && mounted) showStudioToast(context, 'Could not open maps.', icon: null);
  }

  Widget? _bottomBar(StudioEvent e) {
    if (e.isOver && !e.isCancelled) return null;
    final when = StudioBottomBarInfo(label: 'When', value: eventDayLabel(e), mono: true);
    final options = e.ticketOptions;
    final lowest = options.map((t) => t.priceCents).reduce((a, b) => a < b ? a : b);
    final from = StudioBottomBarInfo(label: 'From', value: lowest == 0 ? 'Free' : formatMoney(lowest));
    final soldOut = e.isFull || options.every((t) => t.isSoldOut);
    if (e.isCancelled) {
      return const StudioBottomBar(button: StudioButton(label: 'Event cancelled', onPressed: null));
    }
    if (e.isHost) {
      return StudioBottomBar(
        left: StudioBottomBarInfo(label: 'Going', value: '${e.rsvpCount}'),
        right: when,
        button: StudioButton(
          label: 'QR codes for pieces',
          variant: StudioButtonVariant.outline,
          height: 52,
          onPressed: _openQrCodes,
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
    return StudioBottomBar(
      left: from,
      right: when,
      button: StudioButton(
        label: soldOut ? 'Sold out' : 'Get tickets',
        loading: _rsvping,
        onPressed: e.canRsvp && !soldOut && !_rsvping ? _getTickets : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final e = _event;
    final bar = _bottomBar(e);
    final pieces = e.lineup.where((item) => item.pieceId.isNotEmpty).toList();
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
                    followFilled: followState.filled,
                    followBusy: followBusy,
                    onFollow: toggleFollow,
                    onHost: () => openUserProfile(context, e.hostUsername),
                  ),
                ),
                if (e.isCancelled || e.isOver)
                  padded(
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: Text(
                        e.isCancelled
                            ? (e.cancellationReason?.trim().isNotEmpty == true
                                  ? 'This event was cancelled. ${e.cancellationReason!.trim()}'
                                  : 'This event was cancelled.')
                            : 'This event has ended.',
                        style: StudioType.body15(height: 1.5, color: c.textSecondary),
                      ),
                    ),
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
                if (pieces.isNotEmpty) ...[
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
