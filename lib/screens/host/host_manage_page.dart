import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/app_link_config.dart';
import '../../models/studio_event.dart';
import '../../services/event_service.dart';
import '../../utils/money_format.dart';
import '../../widgets/events/your_events_widgets.dart' show eventHowSoon;
import '../../widgets/settings_tile.dart';
import '../../widgets/share/share_sheet.dart';
import '../../widgets/studio/studio.dart';
import '../event_qr_codes_page.dart';
import 'host_cancel_page.dart';
import 'host_event_page.dart';
import 'host_reschedule_page.dart';
import 'host_scanner_page.dart';

/// Manage event (`HostManage`): the host's tools. The cover full width at 3:4 (radius 14) with
/// how soon it is; the name 24/500 and the Mono date, time and venue; the numbers side by side
/// (Mono 18 over 11 Graphite labels); Ticket types with how many are taken (Sold out in red); rows
/// for piece links and QR codes and Edit event; Cancel event as a grey link; the bar at the
/// bottom with Going and Doors open.
///
/// Ticket types list the event's own (B22), or General Admission for a free RSVP event.
/// Earned comes later (the waitlist count shows once the server sends it). The bar's button is
/// Check in guests (B28, Phase 4.3), for a published or archived event; Reschedule sits under
/// Edit event while a published event hasn't ended (Phase 4.4).
class HostManagePage extends StatefulWidget {
  const HostManagePage({super.key, required this.event, this.debugEvent, this.debugNow});

  final StudioEvent event;

  /// For tests: the full event, instead of fetching it.
  @visibleForTesting
  final StudioEvent? debugEvent;
  @visibleForTesting
  final DateTime? debugNow;

  static Future<void> open(BuildContext context, StudioEvent event) {
    return Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => HostManagePage(event: event)));
  }

  @override
  State<HostManagePage> createState() => _HostManagePageState();
}

class _HostManagePageState extends State<HostManagePage> {
  late StudioEvent _event = widget.debugEvent ?? widget.event;

  @override
  void initState() {
    super.initState();
    if (widget.debugEvent == null) _load();
  }

  Future<void> _load() async {
    try {
      final full = await EventService.instance.getById(widget.event.id);
      if (mounted) setState(() => _event = full);
    } catch (_) {
      // The card's own fields still render.
    }
  }

  void _share() {
    final e = _event;
    ShareSheet.show(
      context,
      shareText: '${e.title} · ${e.venue}\n${e.scheduleLine}\n${AppLinkConfig.eventUrl(e.id)}',
      copyLabel: 'Copy',
      copiedMessage: 'Copied',
    );
  }

  Future<void> _edit() async {
    await HostEventPage.open(context, editing: _event);
    _load();
  }

  Future<void> _cancel() async {
    final cancelled = await HostCancelPage.open(context, _event);
    if (cancelled == true) _load();
  }

  Future<void> _checkIn() async {
    await HostScannerPage.open(context, _event);
    _load();
  }

  Future<void> _reschedule() async {
    final moved = await HostReschedulePage.open(context, _event);
    if (moved != null && mounted) {
      setState(() => _event = moved);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final e = _event;
    final now = widget.debugNow ?? DateTime.now();
    final width = MediaQuery.sizeOf(context).width - 48;
    final zone = e.zoneLabel.isEmpty ? '' : ' ${e.zoneLabel}';
    final when = '${_day(e.startsAt)} · ${_time(e.startsAt)}$zone';
    final active = e.isPublished && !e.isOver;
    final scanning = e.isPublished || e.status == 'archived';
    final going = e.capacity == null ? '${e.rsvpCount}' : '${e.rsvpCount} of ${e.capacity}';
    // Pieces on the event: approved ones (waiting and declined entries aren't on it yet).
    final pieces = e.liveLineup.length;
    // An accepted co-host (Phase 5.1): only the host reschedules or cancels.
    final coHost = !e.isHost && e.viewerCanEdit;
    Widget typeRow(String name, String taken, {required bool soldOut}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(child: Text(name, style: StudioType.body14(color: c.textSecondary))),
          Text(taken, style: StudioType.mono(14, color: soldOut ? c.alert : c.textPrimary)),
        ],
      ),
    );
    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(value, style: StudioType.mono(18, color: c.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: StudioType.sans(11, color: c.textSecondary)),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(
        context: context,
        title: 'Manage event',
        actions: [
          IconButton(
            onPressed: _share,
            tooltip: 'Share event',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: StudioIcon(StudioIcons.share, size: 22, color: c.textPrimary),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: c.textPrimary,
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(StudioSpace.marginForm, 12, StudioSpace.marginForm, 190),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(StudioRadius.panel),
                  child: SizedBox(
                    width: width,
                    height: width * 4 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        e.imageUrl.isEmpty
                            ? ColoredBox(color: c.surface)
                            : CachedNetworkImage(
                                imageUrl: e.imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => ColoredBox(color: c.surface),
                              ),
                        Positioned(
                          left: 14,
                          top: 12,
                          child: StudioImageLabel(
                            e.isCancelled
                                ? 'Cancelled'
                                : e.isOver
                                ? 'Ended'
                                : e.isDraft
                                ? 'Draft'
                                : eventHowSoon(e, now),
                            size: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  e.title,
                  style: StudioType.sans(24, weight: StudioType.medium, letterSpacing: -0.4, color: c.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  [when, if (e.venue.isNotEmpty) e.venue].join(' · '),
                  style: StudioType.mono(12, color: c.textSecondary),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.line), bottom: BorderSide(color: c.line)),
                  ),
                  child: Row(
                    children: [
                      stat('${e.rsvpCount}', e.capacity == null ? 'going' : 'going of ${e.capacity}'),
                      stat('${e.saveCount}', 'saved'),
                      stat('$pieces', pieces == 1 ? 'piece' : 'pieces'),
                      // The waitlist's size, once the server runs one (BACKEND_CHANGES B22).
                      if (e.waitlist?.waitingCount != null) stat('${e.waitlist!.waitingCount}', 'waiting'),
                    ],
                  ),
                ),
                const HostManageLabel('Ticket types'),
                // The event's ticket types (B22), or its one free RSVP place when it has none.
                if (e.ticketTypes.isEmpty)
                  typeRow(
                    'General Admission',
                    e.isFull ? 'Sold out' : (e.capacity == null ? '${e.rsvpCount} going' : '${e.rsvpCount} of ${e.capacity}'),
                    soldOut: e.isFull,
                  )
                else
                  for (final t in e.ticketTypes) typeRow(t.closed ? '${t.name} (closed)' : t.name, _taken(t), soldOut: t.isSoldOut),
                // Who was asked onto the bill and where they stand (Phase 5.1), host and co-hosts.
                if (e.invites.isNotEmpty) ...[
                  const HostManageLabel('People'),
                  for (final i in e.invites)
                    typeRow(
                      '${i.person.displayName} · ${i.isCohost ? 'Co-host' : 'Featured artist'}',
                      i.statusLabel,
                      soldOut: false,
                    ),
                ],
                const SizedBox(height: 8),
                if (pieces > 0)
                  SettingsTile(
                    label: 'Piece links and QR codes',
                    subtitle: 'Copy or download for printing',
                    onTap: () => EventQrCodesPage.open(context, eventId: e.id, eventTitle: e.title),
                  ),
                if (!e.isCancelled && !e.isOver) SettingsTile(label: 'Edit event', onTap: _edit),
                if (active && e.isHost && !coHost) SettingsTile(label: 'Reschedule', onTap: _reschedule),
                if (e.isCancelled)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      e.cancellationReason?.isNotEmpty == true
                          ? 'This event was cancelled. ${e.cancellationReason}'
                          : 'This event was cancelled.',
                      style: StudioType.body14(color: c.textSecondary),
                    ),
                  ),
                if (active && !coHost)
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: _cancel,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: SizedBox(
                          height: 44,
                          child: Center(
                            child: Text(
                              'Cancel event',
                              style: StudioType.body14(color: c.textSecondary).copyWith(
                                decoration: TextDecoration.underline,
                                decorationColor: c.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: StudioBottomBar(
              left: StudioBottomBarInfo(label: 'Going', value: going, mono: true, monoSize: 17),
              right: StudioBottomBarInfo(label: 'Doors open', value: '${_time(e.startsAt)}$zone', mono: true, monoSize: 17),
              button: StudioButton(label: 'Check in guests', onPressed: scanning ? _checkIn : null),
            ),
          ),
        ],
      ),
    );
  }

  /// How many of a ticket type are taken: `12 of 40` (sold or held, the host's view), `8 left`
  /// (a co-host's view), or its price when nothing says.
  static String _taken(EventTicketType t) {
    if (t.isSoldOut) return 'Sold out';
    final sold = t.sold;
    if (sold != null) return t.quantity == null ? '$sold sold' : '$sold of ${t.quantity}';
    if (t.left != null) return '${t.left} left';
    return t.isFree ? 'Free' : formatMoney(t.priceCents);
  }

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _day(DateTime d) => '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
  static String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
  }
}

/// A section label on Manage event: Mono 11/500 Tertiary caps, 24 above, 2 below.
class HostManageLabel extends StatelessWidget {
  const HostManageLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: StudioType.mono(11, weight: StudioType.medium, color: context.studio.textTertiary)
            .copyWith(letterSpacing: 0.5),
      ),
    );
  }
}
