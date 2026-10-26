import 'package:flutter/material.dart';

import '../../models/studio_event.dart';
import '../../services/api_exception.dart';
import '../../services/event_service.dart';
import '../../widgets/studio/studio.dart';

/// Cancel event (`HostCancel`): exactly what happens before confirming — the title "Cancel
/// [name]?" 24/500, how many guests are told (Mono), what happens to them and to tagged pieces,
/// an optional message to guests, then "Cancel event and tell guests" and Keep event. Free
/// events have nothing to refund; refunds and card fees come with paid tickets (B22). The
/// message goes to guests with the cancellation notification. Pops true once cancelled.
class HostCancelPage extends StatefulWidget {
  const HostCancelPage({super.key, required this.event});

  final StudioEvent event;

  static Future<bool?> open(BuildContext context, StudioEvent event) {
    return Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => HostCancelPage(event: event)));
  }

  @override
  State<HostCancelPage> createState() => _HostCancelPageState();
}

class _HostCancelPageState extends State<HostCancelPage> {
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      final text = _message.text.trim();
      await EventService.instance.cancel(widget.event.id, reason: text.isEmpty ? null : text);
      if (!mounted) return;
      showStudioToast(context, 'Event cancelled');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, 'Could not cancel the event. Try again.', icon: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final e = widget.event;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    final going = e.rsvpCount;
    Widget fact(String label, String value) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Expanded(child: Text(label, style: StudioType.body15(color: c.textPrimary))),
          Text(value, style: StudioType.mono(15, color: c.textPrimary)),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Cancel event'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(StudioSpace.marginForm, 16, StudioSpace.marginForm, 40),
        children: [
          Text(
            'Cancel ${e.title}?',
            style: StudioType.sans(24, weight: StudioType.medium, letterSpacing: -0.3, color: c.textPrimary),
          ),
          const SizedBox(height: 18),
          fact('Guests told', going == 1 ? '1 person' : '$going people'),
          fact('Pieces taken off the event', '${e.lineup.length}'),
          const SizedBox(height: 18),
          Text(
            'Everyone who reserved a spot gets a notification. Tagged pieces go back to their normal '
            'listings, and any auction at the event is cancelled with bidders told.',
            style: StudioType.label13(color: c.textSecondary).copyWith(height: 1.5),
          ),
          const SizedBox(height: 18),
          StudioUnderlineField(
            label: 'Message to guests (optional)',
            controller: _message,
            hint: 'Let guests know what happened…',
            maxLength: 200,
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
            StudioButton(label: 'Cancel event and tell guests', loading: _busy, onPressed: _busy ? null : _cancel),
            const SizedBox(height: 4),
            StudioButton(
              label: 'Keep event',
              variant: StudioButtonVariant.text,
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
