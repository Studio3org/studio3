import 'package:flutter/material.dart';

import '../../models/studio_event.dart';
import '../../services/api_exception.dart';
import '../../services/event_service.dart';
import '../../widgets/host/host_date_sheet.dart';
import '../../widgets/host/host_widgets.dart';
import '../../widgets/studio/studio.dart';

/// Reschedule (`HostReschedule`, Phase 4.4), laid out like Cancel event: the title 24/500, the
/// new date and time (the same date sheet as creating the event), what happens to guests, an
/// optional message to them, then "Reschedule and tell guests" and Keep the date. Pops the
/// moved event once the server takes it; its 400 / 409 messages show as they are.
class HostReschedulePage extends StatefulWidget {
  const HostReschedulePage({super.key, required this.event, this.debugNow});

  final StudioEvent event;

  @visibleForTesting
  final DateTime? debugNow;

  static Future<StudioEvent?> open(BuildContext context, StudioEvent event) {
    return Navigator.of(context).push<StudioEvent>(MaterialPageRoute(builder: (_) => HostReschedulePage(event: event)));
  }

  @override
  State<HostReschedulePage> createState() => _HostReschedulePageState();
}

class _HostReschedulePageState extends State<HostReschedulePage> {
  final _message = TextEditingController();
  late final HostDateSelection _was = HostDateSelection.fromEvent(widget.event);
  late HostDateSelection _date = _was;
  bool _busy = false;

  bool get _changed => _date.startsAt != _was.startsAt || _date.endsAt != _was.endsAt;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await HostDateSheet.show(context, initial: _date, now: widget.debugNow);
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final moved = await EventService.instance.reschedule(
        widget.event.id,
        startsAt: _date.startsAt,
        endsAt: _date.endsAt,
        message: _message.text,
      );
      if (!mounted) return;
      showStudioToast(context, 'Event rescheduled');
      Navigator.of(context).pop(moved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, 'Could not reschedule the event. Try again.', icon: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final e = widget.event;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Reschedule'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(StudioSpace.marginForm, 16, StudioSpace.marginForm, 40),
        children: [
          Text(
            'Reschedule ${e.title}',
            style: StudioType.sans(24, weight: StudioType.medium, letterSpacing: -0.3, color: c.textPrimary),
          ),
          const SizedBox(height: 18),
          HostNavRow(label: 'Date and time', value: _date.rowLabel, mono: true, enabled: !_busy, onTap: _pickDate),
          const SizedBox(height: 18),
          Text(
            "Everyone with a ticket is told once. Their tickets still work, and they can get a full "
            'refund until the new start. An auction at the event moves with it.',
            style: StudioType.label13(color: c.textSecondary).copyWith(height: 1.5),
          ),
          const SizedBox(height: 18),
          StudioUnderlineField(
            label: 'Message to guests (optional)',
            controller: _message,
            hint: 'Let guests know why it moved…',
            maxLength: 500,
            maxLines: 3,
            minLines: 1,
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
              label: 'Reschedule and tell guests',
              loading: _busy,
              onPressed: _busy || !_changed ? null : _save,
            ),
            const SizedBox(height: 4),
            StudioButton(
              label: 'Keep the date',
              variant: StudioButtonVariant.text,
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
