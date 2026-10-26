import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/host/host_widgets.dart';
import '../../widgets/studio/studio.dart';

/// Ticket type (`HostEditTicket`) for a free event: the name (General Admission, fixed until
/// paid tickets), "Limit how many" with Tickets available in Mono under it when on, and Save
/// ticket type. Price, what is included, the per-order limit and sale dates come with paid
/// tickets (BACKEND_CHANGES B22). Pops `(capacity: …)`, null capacity for no limit.
class HostTicketPage extends StatefulWidget {
  const HostTicketPage({super.key, this.capacity});

  final int? capacity;

  static Future<({int? capacity})?> open(BuildContext context, {int? capacity}) {
    return Navigator.of(context).push<({int? capacity})>(
      MaterialPageRoute(builder: (_) => HostTicketPage(capacity: capacity)),
    );
  }

  @override
  State<HostTicketPage> createState() => _HostTicketPageState();
}

class _HostTicketPageState extends State<HostTicketPage> {
  late bool _limit = widget.capacity != null;
  late final _count = TextEditingController(text: widget.capacity?.toString() ?? '');
  final _name = TextEditingController(text: 'General Admission');

  @override
  void dispose() {
    _count.dispose();
    _name.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_count.text.trim());
  bool get _valid => !_limit || (_value ?? 0) >= 1;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Ticket type'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(StudioSpace.marginForm, 14, StudioSpace.marginForm, 40),
        children: [
          StudioUnderlineField(
            label: 'Name',
            controller: _name,
            enabled: false,
            valueSize: 16,
            helper: 'Names and prices come with paid tickets.',
          ),
          const SizedBox(height: 8),
          HostSwitchRow(
            label: 'Limit how many',
            subtitle: 'Off: anyone can reserve a spot',
            value: _limit,
            divider: !_limit,
            onChanged: (v) => setState(() => _limit = v),
          ),
          if (_limit)
            Container(
              padding: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
              child: StudioUnderlineField(
                label: 'Tickets available',
                controller: _count,
                mono: true,
                valueSize: 16,
                autofocus: widget.capacity == null,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(StudioSpace.marginForm, 8, StudioSpace.marginForm, safe > 0 ? safe : 24),
        child: StudioButton(
          label: 'Save ticket type',
          onPressed: _valid ? () => Navigator.pop(context, (capacity: _limit ? _value : null)) : null,
        ),
      ),
    );
  }
}
