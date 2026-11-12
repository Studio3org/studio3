import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/event_check_in.dart';
import '../../models/studio_event.dart';
import '../../services/api_exception.dart';
import '../../services/event_service.dart';
import '../../services/offline_check_in.dart';
import '../../utils/profile_navigation.dart';
import '../../widgets/host/host_widgets.dart';
import '../../widgets/post_picker_search_field.dart';
import '../../widgets/studio/studio.dart';

/// Guest list (`HostScanner` lists it, Phase 4.3): every ticket that still admits someone,
/// searched on the server by name, username or ticket number, as rows (40 avatar, name
/// 15/500, the type and Mono number 13) with Check in by hand, the Mono count and the age limit.
class HostGuestListPage extends StatefulWidget {
  const HostGuestListPage({super.key, required this.event, this.debugGuests});

  final StudioEvent event;

  @visibleForTesting
  final EventGuestList? debugGuests;

  static Future<void> open(BuildContext context, StudioEvent event) {
    return Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => HostGuestListPage(event: event)));
  }

  @override
  State<HostGuestListPage> createState() => _HostGuestListPageState();
}

class _HostGuestListPageState extends State<HostGuestListPage> {
  static const _limit = 500;

  final _search = TextEditingController();
  Timer? _debounce;
  EventGuestList? _list;
  bool _failed = false;
  String? _error;
  final _busy = <String>{};
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _list = widget.debugGuests;
    if (_list == null) _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final list = await EventService.instance.guests(widget.event.id, q: _search.text, limit: _limit);
      if (!mounted || request != _request) return;
      setState(() {
        _list = list;
        _failed = false;
      });
    } on ApiException catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _failed = true;
        _error = e.statusCode == null ? null : e.message;
      });
    } catch (_) {
      if (mounted && request == _request) setState(() => _failed = true);
    }
  }

  void _onSearch(String _) {
    setState(() {});
    if (widget.debugGuests != null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _checkIn(CheckInTicket guest) async {
    setState(() => _busy.add(guest.id));
    CheckInResult? result;
    try {
      result = await EventService.instance.checkIn(widget.event.id, guest.id);
      final ticket = result.ticket;
      if (ticket != null && !result.isInvalid) await OfflineCheckIn.instance.noteCheckedIn(widget.event.id, ticket);
    } on ApiException catch (e) {
      if (e.statusCode == null) {
        result = await OfflineCheckIn.instance.scan(widget.event.id, guest.id);
      } else if (mounted) {
        showStudioToast(context, e.message, icon: null);
      }
    } catch (_) {
      result = await OfflineCheckIn.instance.scan(widget.event.id, guest.id);
    }
    if (!mounted) return;
    setState(() {
      _busy.remove(guest.id);
      final list = _list;
      if (result != null && list != null) {
        final updated =
            result.ticket ??
            (result.isInvalid ? null : guest.copyWith(status: 'checked_in', checkedInAt: DateTime.now()));
        _list = EventGuestList(
          guests: [for (final g in list.guests) g.id == guest.id && updated != null ? updated : g],
          checkedIn: result.checkedIn ?? (result.isCheckedIn ? list.checkedIn + 1 : list.checkedIn),
          total: result.total ?? list.total,
          ageLimit: list.ageLimit,
        );
      }
    });
    if (result != null) showStudioToast(context, result.message, icon: null);
  }

  static String? _age(String? age) => switch (age) {
    '18' => '18+ event: check ID at the door.',
    '21' => '21+ event: check ID at the door.',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final list = _list;
    final q = _search.text.trim().toLowerCase();
    // Tests (and the moment between typing and the server answering) filter what is here.
    final shown = list?.guests
        .where(
          (g) =>
              widget.debugGuests == null ||
              q.isEmpty ||
              g.displayName.toLowerCase().contains(q) ||
              (g.holderUsername?.toLowerCase().contains(q) ?? false) ||
              (g.number?.toLowerCase().contains(q) ?? false),
        )
        .toList();
    final age = _age(list?.ageLimit ?? widget.event.ageLimit);
    Widget body;
    if (list == null) {
      body = Center(
        child: _failed
            ? StudioEmptyState(
                title: "The guest list didn't load",
                message: _error,
                actionLabel: 'Try again',
                onAction: _load,
              )
            : SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary)),
      );
    } else if (list.guests.isEmpty && q.isEmpty) {
      body = const Center(
        child: StudioEmptyState(title: 'No one yet', message: 'People with tickets show up here.'),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(StudioSpace.marginPage, 6, StudioSpace.marginPage, 40),
        children: [
          PostPickerSearchField(
            controller: _search,
            hintText: 'Search guests or ticket numbers',
            height: 44,
            onChanged: _onSearch,
          ),
          const SizedBox(height: 12),
          Text('${list.checkedIn} of ${list.total} checked in', style: StudioType.mono(12, color: c.textSecondary)),
          if (age != null) ...[const SizedBox(height: 2), Text(age, style: StudioType.label13(color: c.textSecondary))],
          const SizedBox(height: 4),
          for (final g in shown!)
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: g.holderUsername?.isNotEmpty == true ? () => openUserProfile(context, g.holderUsername) : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.line)),
                  ),
                  child: Row(
                    children: [
                      StudioAvatar(url: g.holderAvatarUrl, size: 40, semanticLabel: g.displayName),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.displayName,
                              style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                            ),
                            Text(
                              [?g.ticketTypeName, ?g.number].join(' · '),
                              style: StudioType.label13(color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (g.isCheckedIn)
                        Text('Checked in', style: StudioType.mono(12, color: c.textSecondary))
                      else
                        HostTextAction(
                          key: ValueKey('check-in-${g.id}'),
                          label: 'Check in',
                          onTap: _busy.contains(g.id) ? null : () => _checkIn(g),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'No guests match "${_search.text.trim()}".',
                textAlign: TextAlign.center,
                style: StudioType.body14(color: c.textSecondary),
              ),
            ),
        ],
      );
    }
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Guest list'),
      body: body,
    );
  }
}
