import 'package:flutter/material.dart';

import '../models/studio_event.dart';
import '../services/event_service.dart';
import '../services/saved_content_store.dart';
import '../utils/require_login.dart';
import '../widgets/events/event_tab_widgets.dart';
import '../widgets/studio/studio.dart';
import 'event_detail_page.dart';

/// "See all" and a category from the Events tab: the events as `EvTab` list rows under the
/// shared top bar. No board of its own (plan section 17: See-all pages).
class EventListPage extends StatefulWidget {
  const EventListPage({super.key, required this.title, required this.load, this.debugNow});

  final String title;
  final Future<List<StudioEvent>> Function() load;

  @visibleForTesting
  final DateTime? debugNow;

  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  final _store = SavedContentStore.instance;
  List<StudioEvent>? _events;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    _load();
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final events = await widget.load();
      if (!mounted) return;
      setState(() {
        _events = events..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _toggleSaved(StudioEvent event) async {
    if (!await requireLogin(context, title: 'Sign in to save events')) return;
    final wasSaved = _store.isSaved(event.id);
    try {
      await EventService.instance.setSaved(event.id, saved: !wasSaved);
      if (mounted) _store.toggleEvent(event);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not save that event.', icon: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final events = _events;
    final now = widget.debugNow ?? DateTime.now();
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: widget.title),
      body: events == null
          ? (_failed
                ? Center(
                    child: StudioEmptyState(
                      title: "Events didn't load",
                      actionLabel: 'Try again',
                      onAction: _load,
                    ),
                  )
                : Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
                    ),
                  ))
          : events.isEmpty
          ? const Center(
              child: StudioEmptyState(
                title: 'Nothing here yet',
                message: 'Events show up here as they are posted.',
              ),
            )
          : RefreshIndicator(
              color: c.textPrimary,
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  final e = events[i];
                  return EventListRow(
                    event: e,
                    saved: _store.isSaved(e.id),
                    onTap: () => openEventDetail(context, e),
                    onSave: () => _toggleSaved(e),
                    now: now,
                  );
                },
              ),
            ),
    );
  }
}
