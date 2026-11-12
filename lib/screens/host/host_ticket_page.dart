import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/studio_event.dart';
import '../../services/auth_session.dart';
import '../../utils/money_format.dart';
import '../../widgets/host/host_date_sheet.dart';
import '../../widgets/host/host_widgets.dart';
import '../../widgets/studio/studio.dart';
import '../seller/seller_setup_flow.dart';

/// What [HostTicketPage.openType] pops: the edited ticket type, or [removed] when the host
/// took it off the event.
typedef HostTicketEdit = ({EventTicketType? type, bool removed});

/// Ticket type (`HostEditTicket`).
///
/// Two uses:
/// - An event with no ticket types (a free RSVP, [HostTicketPage.new]): the name (General
///   Admission, fixed), "Limit how many" with Tickets available in Mono under it when on, and
///   Save ticket type. Pops `(capacity: …)`, null capacity for no limit.
/// - One of the event's ticket types (BACKEND_CHANGES B22, [HostTicketPage.type]): the name,
///   Free or Paid with its price, what's included, Limit how many, Max per order, and when the
///   sale starts and ends. "You receive $X per ticket" shows when the server sent the host's
///   share. Pops a [HostTicketEdit].
class HostTicketPage extends StatefulWidget {
  const HostTicketPage({super.key, this.capacity}) : type = null, editsType = false, isNew = false, canRemove = false, checkSeller = true, startPaid = false, debugNow = null;

  const HostTicketPage.type({
    super.key,
    this.type,
    this.isNew = false,
    this.canRemove = false,
    this.checkSeller = true,
    this.startPaid = false,
    @visibleForTesting this.debugNow,
  }) : capacity = null,
       editsType = true;

  final int? capacity;

  /// The type being edited; null for a new one.
  final EventTicketType? type;
  final bool editsType;
  final bool isNew;

  /// Offer Remove ticket type.
  final bool canRemove;

  /// Ask for a seller profile before Paid (the host's own event; a co-host isn't asked, the
  /// server answers for the host's profile).
  final bool checkSeller;

  /// A new type that starts as Paid ("Paid tickets" chosen on the Tickets step).
  final bool startPaid;

  /// For tests: the sale date sheet's today.
  final DateTime? debugNow;

  static Future<({int? capacity})?> open(BuildContext context, {int? capacity}) {
    return Navigator.of(context).push<({int? capacity})>(
      MaterialPageRoute(builder: (_) => HostTicketPage(capacity: capacity)),
    );
  }

  static Future<HostTicketEdit?> openType(
    BuildContext context, {
    EventTicketType? type,
    bool isNew = false,
    bool canRemove = false,
    bool checkSeller = true,
    bool startPaid = false,
    DateTime? debugNow,
  }) {
    return Navigator.of(context).push<HostTicketEdit>(
      MaterialPageRoute(
        builder: (_) => HostTicketPage.type(
          type: type,
          isNew: isNew,
          canRemove: canRemove,
          checkSeller: checkSeller,
          startPaid: startPaid,
          debugNow: debugNow,
        ),
      ),
    );
  }

  @override
  State<HostTicketPage> createState() => _HostTicketPageState();
}

class _HostTicketPageState extends State<HostTicketPage> {
  EventTicketType? get _type => widget.type;

  late bool _limit = widget.editsType ? _type?.quantity != null : widget.capacity != null;
  late final _count = TextEditingController(
    text: (widget.editsType ? _type?.quantity : widget.capacity)?.toString() ?? '',
  );
  late final _name = TextEditingController(text: widget.editsType ? (_type?.name ?? '') : 'General Admission');
  late bool _paid = widget.startPaid || (_type?.priceCents ?? 0) > 0;
  late final _price = TextEditingController(
    text: (_type?.priceCents ?? 0) > 0 ? (_type!.priceCents / 100).toStringAsFixed(2) : '',
  );
  late final _includes = TextEditingController(text: _type?.includes ?? '');
  late final _perOrder = TextEditingController(text: _type?.perOrderLimit?.toString() ?? '');
  late DateTime? _saleStarts = _type?.saleStartsAt;
  late DateTime? _saleEnds = _type?.saleEndsAt;

  /// Sold or held already: the server won't change its price (409).
  bool get _priceLocked => (_type?.sold ?? 0) > 0;

  @override
  void dispose() {
    _count.dispose();
    _name.dispose();
    _price.dispose();
    _includes.dispose();
    _perOrder.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_count.text.trim());

  int? get _priceCents {
    final v = double.tryParse(_price.text.replaceAll(',', '').replaceAll(r'$', '').trim());
    return v == null ? null : (v * 100).round();
  }

  int? get _perOrderValue => int.tryParse(_perOrder.text.trim());

  bool get _valid {
    if (_limit && (_value ?? 0) < 1) return false;
    if (!widget.editsType) return true;
    if (_name.text.trim().isEmpty) return false;
    if (_paid && (_priceCents ?? 0) < 50) return false;
    if (_perOrder.text.trim().isNotEmpty && (_perOrderValue ?? 0) < 1) return false;
    final starts = _saleStarts;
    final ends = _saleEnds;
    if (starts != null && ends != null && !ends.isAfter(starts)) return false;
    return true;
  }

  /// Paid needs a seller profile (`SellerPrompt`, as for selling a piece at the event).
  Future<void> _setPaid(bool paid) async {
    if (paid == _paid || _priceLocked) return;
    if (paid && widget.checkSeller && !AuthSession.instance.sellerEnabled) {
      final seller = await SellerSetupPage.prompt(
        context,
        secondaryLabel: 'Keep it free',
        returnLabel: 'Back to your event',
      );
      if (!seller || !mounted) return;
    }
    setState(() => _paid = paid);
  }

  Future<void> _pickSale({required bool start}) async {
    final picked = await HostDateSheet.showOne(
      context,
      title: start ? 'Sale starts' : 'Sale ends',
      initial: start ? _saleStarts : _saleEnds,
      now: widget.debugNow,
    );
    if (picked == null || !mounted) return;
    setState(() => start ? _saleStarts = picked.at : _saleEnds = picked.at);
  }

  static String _when(DateTime d) => '${hostDay(d)} · ${hostTime(TimeOfDay.fromDateTime(d))}';

  void _save() {
    if (!widget.editsType) {
      Navigator.pop(context, (capacity: _limit ? _value : null));
      return;
    }
    final before = _type;
    final includes = _includes.text.trim();
    final edited = EventTicketType(
      id: before?.id ?? '',
      name: _name.text.trim(),
      priceCents: _paid ? (_priceCents ?? 0) : 0,
      includes: includes.isEmpty ? null : includes,
      left: before?.left,
      perOrderLimit: _perOrder.text.trim().isEmpty ? null : _perOrderValue,
      quantity: _limit ? _value : null,
      sold: before?.sold,
      hostNetCents: before?.hostNetCents,
      closed: before?.closed ?? false,
      waiting: before?.waiting,
      saleStartsAt: _saleStarts,
      saleEndsAt: _saleEnds,
      onSale: before?.onSale,
      soldOut: before?.soldOut,
      sortOrder: before?.sortOrder,
    );
    Navigator.pop<HostTicketEdit>(context, (type: edited, removed: false));
  }

  Future<void> _remove() async {
    final sold = (_type?.sold ?? 0) > 0;
    final ok = await showStudioConfirm(
      context,
      title: 'Remove ${_type?.name.isNotEmpty == true ? _type!.name : 'this ticket type'}?',
      message: sold
          ? 'It stops selling. Tickets already sold stay valid.'
          : 'It comes off the event when you save.',
      confirmLabel: 'Remove',
    );
    if (ok && mounted) Navigator.pop<HostTicketEdit>(context, (type: null, removed: true));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    final net = _type?.hostNetCents;
    // The host's share is for the saved price; once the price changes it waits for the save.
    final showNet = widget.editsType && _paid && net != null && _priceCents == _type?.priceCents;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Ticket type'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(StudioSpace.marginForm, 14, StudioSpace.marginForm, 40),
        children: [
          if (widget.editsType)
            StudioUnderlineField(
              label: 'Name',
              controller: _name,
              hint: 'General Admission, VIP…',
              valueSize: 16,
              required: true,
              autofocus: widget.isNew,
              onChanged: (_) => setState(() {}),
            )
          else
            StudioUnderlineField(
              label: 'Name',
              controller: _name,
              enabled: false,
              valueSize: 16,
              helper: 'Add ticket types to name them or charge for them.',
            ),
          if (widget.editsType) ...[
            const HostLabel('Price'),
            HostOptionRows<bool>(
              options: [
                HostOption(false, 'Free', enabled: !_priceLocked),
                HostOption(true, 'Paid', enabled: !_priceLocked),
              ],
              value: _paid,
              onChanged: _setPaid,
            ),
            if (_paid)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: StudioUnderlineField(
                  label: 'Price (USD)',
                  controller: _price,
                  hint: '0.00',
                  mono: true,
                  valueSize: 16,
                  enabled: !_priceLocked,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            if (showNet)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'You receive ${formatMoney(net)} per ticket',
                  style: StudioType.caption12(color: c.textSecondary),
                ),
              ),
            if (_priceLocked)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  "This ticket has sold, so its price can't change. Add a new ticket type instead.",
                  style: StudioType.caption12(color: c.textSecondary),
                ),
              ),
            const SizedBox(height: 18),
            StudioUnderlineField(
              label: "What's included",
              controller: _includes,
              hint: 'Entry, a drink, early access…',
              valueSize: 16,
              maxLines: 4,
              minLines: 1,
            ),
          ],
          const SizedBox(height: 8),
          HostSwitchRow(
            label: 'Limit how many',
            value: _limit,
            verticalPadding: 10,
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
                autofocus: widget.editsType ? false : widget.capacity == null,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
              ),
            ),
          if (widget.editsType && _limit && (_type?.sold ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${_type!.sold} sold or held',
                style: StudioType.caption12(color: c.textSecondary),
              ),
            ),
          if (widget.editsType) ...[
            const SizedBox(height: 18),
            StudioUnderlineField(
              label: 'Max per order',
              controller: _perOrder,
              hint: 'No limit',
              mono: true,
              valueSize: 16,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            HostNavRow(
              label: 'Sale starts',
              value: _saleStarts == null ? 'When published' : _when(_saleStarts!),
              mono: _saleStarts != null,
              onTap: () => _pickSale(start: true),
            ),
            HostNavRow(
              label: 'Sale ends',
              value: _saleEnds == null ? 'When the event ends' : _when(_saleEnds!),
              mono: _saleEnds != null,
              onTap: () => _pickSale(start: false),
            ),
            if (_saleStarts != null && _saleEnds != null && !_saleEnds!.isAfter(_saleStarts!))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('A sale has to end after it starts.', style: StudioType.caption12(color: c.textPrimary)),
              ),
            if (widget.canRemove)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: HostTextAction(label: 'Remove ticket type', underline: true, onTap: _remove),
              ),
          ],
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(StudioSpace.marginForm, 8, StudioSpace.marginForm, safe > 0 ? safe : 24),
        child: StudioButton(label: 'Save ticket type', onPressed: _valid ? _save : null),
      ),
    );
  }
}
