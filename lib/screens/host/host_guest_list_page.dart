import 'package:flutter/material.dart';

import '../../models/studio_event.dart';
import '../../services/event_service.dart';
import '../../utils/profile_navigation.dart';
import '../../widgets/post_picker_search_field.dart';
import '../../widgets/studio/studio.dart';

/// Guest list (from Manage event; `HostScanner` lists it): the people going, searchable by name,
/// as rows (40 avatar, name 15/500, handle 13), with the Mono count. Checking in by hand needs
/// tickets (BACKEND_CHANGES B22).
class HostGuestListPage extends StatefulWidget {
  const HostGuestListPage({super.key, required this.event, this.debugGuests});

  final StudioEvent event;

  @visibleForTesting
  final List<EventPerson>? debugGuests;

  static Future<void> open(BuildContext context, StudioEvent event) {
    return Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => HostGuestListPage(event: event)));
  }

  @override
  State<HostGuestListPage> createState() => _HostGuestListPageState();
}

class _HostGuestListPageState extends State<HostGuestListPage> {
  final _search = TextEditingController();
  List<EventPerson>? _guests;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _guests = widget.debugGuests;
    if (_guests == null) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final guests = await EventService.instance.attendees(widget.event.id);
      if (!mounted) return;
      setState(() {
        _guests = guests;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final guests = _guests;
    final q = _search.text.trim().toLowerCase();
    final shown = guests
        ?.where((g) => q.isEmpty || g.displayName.toLowerCase().contains(q) || g.username.toLowerCase().contains(q))
        .toList();
    Widget body;
    if (guests == null) {
      body = Center(
        child: _failed
            ? StudioEmptyState(title: "The guest list didn't load", actionLabel: 'Try again', onAction: _load)
            : SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
              ),
      );
    } else if (guests.isEmpty) {
      body = const Center(
        child: StudioEmptyState(title: 'No one yet', message: 'People who reserve a spot show up here.'),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(StudioSpace.marginPage, 6, StudioSpace.marginPage, 40),
        children: [
          PostPickerSearchField(
            controller: _search,
            hintText: 'Search guests',
            height: 44,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text('${guests.length} going', style: StudioType.mono(12, color: c.textSecondary)),
          const SizedBox(height: 4),
          for (final g in shown!)
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: () => openUserProfile(context, g.username),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                  child: Row(
                    children: [
                      StudioAvatar(url: g.avatarUrl, size: 40, semanticLabel: g.displayName),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.displayName,
                              style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                            ),
                            Text(g.handle, style: StudioType.label13(color: c.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
