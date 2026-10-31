import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/studio_event.dart';
import '../../utils/money_format.dart' show formatMoney;
import '../studio/studio.dart';
import 'event_tickets_sheet.dart';

/// Opens [child] the way Choose tickets opens: up from the bottom over the event page, which
/// blurs (14) behind it; tapping outside closes it.
Future<T?> _showEventSheet<T>(BuildContext context, Widget child) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, _, _) => child,
    transitionBuilder: (context, animation, _, child) {
      final t = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return AnimatedBuilder(
        animation: t,
        builder: (context, _) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                // The route's own barrier carries "Close" for VoiceOver / TalkBack.
                excludeFromSemantics: true,
                onTap: () => Navigator.of(context).maybePop(),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 14 * t.value, sigmaY: 14 * t.value),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionalTranslation(translation: Offset(0, 1 - t.value), child: child),
            ),
          ],
        ),
      );
    },
  );
}

/// The sheet body both waitlist sheets share: Paper, 24 top corners, 10 20 padding, grabber.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).maybePop();
        },
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * StudioSize.sheetMaxHeightFactor),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(StudioRadius.sheet)),
          ),
          padding: EdgeInsets.fromLTRB(20, 10, 20, safe > 0 ? safe : 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: c.lineStrong, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Join the waitlist (`EvWaitlistJoin`). Works like Choose tickets but is made to look
/// different so nobody thinks they are buying: grey cards with "Sold out" on each, no prices,
/// − / + labelled Want, no total, and "Nothing is charged now". Each type up to the host's
/// per-order limit. Returns how many of each type they want, or null.
class EventWaitlistJoinSheet extends StatefulWidget {
  const EventWaitlistJoinSheet({super.key, required this.event});

  final StudioEvent event;

  static Future<Map<EventTicketType, int>?> show(BuildContext context, StudioEvent event) =>
      _showEventSheet<Map<EventTicketType, int>>(context, EventWaitlistJoinSheet(event: event));

  @override
  State<EventWaitlistJoinSheet> createState() => _EventWaitlistJoinSheetState();
}

class _EventWaitlistJoinSheetState extends State<EventWaitlistJoinSheet> {
  late final List<EventTicketType> _types = widget.event.ticketOptions;

  /// The first type starts at 1, so Join waitlist is one tap for most people.
  late final Map<EventTicketType, int> _wanted = {
    for (var i = 0; i < _types.length; i++) _types[i]: i == 0 ? 1 : 0,
  };

  int get _count => _wanted.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return _SheetFrame(
      children: [
        Text('Join the waitlist', style: StudioType.title22(color: c.textPrimary)),
        const SizedBox(height: 4),
        Text(
          'These are sold out. Nothing is charged now.',
          style: StudioType.sans(14, height: 1.5, color: c.textSecondary),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final type in _types) ...[
                  const SizedBox(height: 12),
                  WaitlistTypeCard(
                    type: type,
                    count: _wanted[type] ?? 0,
                    onAdd: () => setState(() => _wanted[type] = (_wanted[type] ?? 0) + 1),
                    onRemove: () => setState(() => _wanted[type] = (_wanted[type] ?? 0) - 1),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          "We'll hold them for you if any open up, and let you know.",
          style: StudioType.label13(color: c.textSecondary).copyWith(height: 1.5),
        ),
        const SizedBox(height: 12),
        StudioButton(
          label: 'Join waitlist',
          onPressed: _count == 0
              ? null
              : () => Navigator.of(context).pop({
                    for (final e in _wanted.entries)
                      if (e.value > 0) e.key: e.value,
                  }),
        ),
        const SizedBox(height: 12),
        Text(
          'You can leave the waitlist any time.',
          textAlign: TextAlign.center,
          style: StudioType.caption12(color: c.textTertiary),
        ),
      ],
    );
  }
}

/// A sold-out type on the waitlist sheet: Surface card, radius 14, 14 14 12 padding; name
/// 16/500 with Mono 11 "Sold out" on the right; what it includes 13 Graphite; then "Want" 12
/// Graphite and the − count + stepper on Paper, up to the per-order limit. No price.
class WaitlistTypeCard extends StatelessWidget {
  const WaitlistTypeCard({
    super.key,
    required this.type,
    required this.count,
    required this.onAdd,
    required this.onRemove,
  });

  final EventTicketType type;
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final limit = type.perOrderLimit;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(StudioRadius.panel)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(type.name, style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary)),
              ),
              Text('Sold out', style: StudioType.mono(11, color: c.textTertiary)),
            ],
          ),
          if (type.includes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(type.includes!.trim(), style: StudioType.label13(color: c.textSecondary)),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Want', style: StudioType.caption12(color: c.textSecondary)),
              const SizedBox(width: 8),
              TicketStepper(
                name: type.name,
                count: count,
                fill: c.background,
                onAdd: limit == null || count < limit ? onAdd : null,
                onRemove: count > 0 ? onRemove : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The − count + stepper: 34 tall, Line border, radius 10, Mono 14 count.
class TicketStepper extends StatelessWidget {
  const TicketStepper({
    super.key,
    required this.name,
    required this.count,
    required this.onAdd,
    required this.onRemove,
    this.fill,
    this.borderColor,
  });

  final String name;
  final int count;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final Color? fill;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    Widget step(String label, String semantic, VoidCallback? onTap) => Semantics(
          button: true,
          enabled: onTap != null,
          label: semantic,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 34,
              height: 32,
              child: Center(
                child: Text(
                  label,
                  style: StudioType.sans(17, color: onTap == null ? c.textPlaceholder : c.textPrimary),
                ),
              ),
            ),
          ),
        );
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: borderColor ?? c.lineStrong),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          step('−', 'One less $name', onRemove),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 16),
            child: Text('$count', textAlign: TextAlign.center, style: StudioType.mono(14, color: c.textPrimary)),
          ),
          step('+', 'One more $name', onAdd),
        ],
      ),
    );
  }
}

/// The hold's time left: `1:42:10`, or `9:05` under an hour.
String waitlistCountdown(Duration left) {
  final h = left.inHours;
  final m = (left.inMinutes % 60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = (left.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// What happened on the held sheet.
enum WaitlistHeldAction { buy, keepWaiting, expired }

class WaitlistHeldResult {
  const WaitlistHeldResult(this.action, {this.choice});

  final WaitlistHeldAction action;

  /// The tickets to buy (or reserve), for [WaitlistHeldAction.buy].
  final EventTicketChoice? choice;
}

/// Tickets held for you (`EvWaitlistHeld`), opened from the "Waitlist ticket open" notification
/// or the event page. The held tickets are already picked; a Surface bar counts down the hold in
/// red Mono, and when it reaches zero the sheet closes (the tickets go to the next person). Other
/// types still show Sold out. Continue to payment (Reserve when free) goes on to the normal
/// checkout. "Keep waiting for [type]" shows when they also wait for another type.
class EventWaitlistHeldSheet extends StatefulWidget {
  const EventWaitlistHeldSheet({super.key, required this.event, this.now});

  final StudioEvent event;

  /// For tests: the clock.
  final DateTime Function()? now;

  static Future<WaitlistHeldResult?> show(BuildContext context, StudioEvent event, {DateTime Function()? now}) =>
      _showEventSheet<WaitlistHeldResult>(context, EventWaitlistHeldSheet(event: event, now: now));

  @override
  State<EventWaitlistHeldSheet> createState() => _EventWaitlistHeldSheetState();
}

class _EventWaitlistHeldSheetState extends State<EventWaitlistHeldSheet> {
  late final List<EventTicketType> _types = widget.event.ticketOptions;
  late final Map<String, int> _held = widget.event.waitlist?.held ?? const {};
  late final Map<EventTicketType, int> _counts = {for (final t in _types) t: _held[t.id] ?? 0};
  Timer? _timer;
  bool _closed = false;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  Duration get _left {
    final until = widget.event.waitlist?.heldUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  /// The other types they still wait for: "Keep waiting for General Admission".
  List<EventTicketType> get _stillWaiting {
    final wanted = widget.event.waitlist?.wanted ?? const {};
    return [
      for (final t in _types)
        if ((wanted[t.id] ?? 0) > 0 && (_held[t.id] ?? 0) == 0) t,
    ];
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  void _tick() {
    if (!mounted || _closed) return;
    if (_left == Duration.zero) {
      _closed = true;
      _timer?.cancel();
      Navigator.of(context).pop(const WaitlistHeldResult(WaitlistHeldAction.expired));
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String countdown(Duration left) => waitlistCountdown(left);

  EventTicketChoice get _choice => EventTicketChoice({
        for (final e in _counts.entries)
          if (e.value > 0) e.key: e.value,
      });

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final e = widget.event;
    final choice = _choice;
    final waiting = _stillWaiting;
    return _SheetFrame(
      children: [
        Text(e.title, style: StudioType.sans(20, weight: StudioType.medium, color: c.textPrimary)),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: eventStartLabel(e), style: StudioType.mono(13, color: c.textSecondary)),
              if (e.venue.isNotEmpty) TextSpan(text: ' · ${e.venue}'),
            ],
          ),
          style: StudioType.label13(color: c.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(child: Text('Your tickets are held', style: StudioType.body14(color: c.textPrimary))),
              Semantics(
                label: 'Time left ${countdown(_left)}',
                excludeSemantics: true,
                child: Text(countdown(_left), style: StudioType.mono(15, color: c.alert)),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final type in _types) ...[
                  const SizedBox(height: 12),
                  EventTicketCard(
                    type: type,
                    count: _counts[type] ?? 0,
                    heldCount: _held[type.id] ?? 0,
                    onAdd: () => setState(() => _counts[type] = (_counts[type] ?? 0) + 1),
                    onRemove: () => setState(() => _counts[type] = (_counts[type] ?? 0) - 1),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${choice.count}', style: StudioType.mono(13, color: c.textSecondary)),
                    TextSpan(text: choice.count == 1 ? ' ticket' : ' tickets'),
                    if (!choice.isFree) const TextSpan(text: ' · tax added at checkout'),
                  ],
                ),
                style: StudioType.label13(color: c.textSecondary),
              ),
            ),
            Text(
              choice.isFree ? 'Free' : formatMoney(choice.totalCents),
              style: StudioType.sans(18, color: c.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StudioButton(
          label: choice.count > 0 && !choice.isFree ? 'Continue to payment' : 'Reserve',
          onPressed: choice.count == 0
              ? null
              : () {
                  _closed = true;
                  Navigator.of(context).pop(WaitlistHeldResult(WaitlistHeldAction.buy, choice: choice));
                },
        ),
        if (waiting.isNotEmpty)
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: () {
                _closed = true;
                Navigator.of(context).pop(const WaitlistHeldResult(WaitlistHeldAction.keepWaiting));
              },
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: StudioSize.tapTarget,
                child: Center(
                  child: Text(
                    'Keep waiting for ${waiting.map((t) => t.name).join(' and ')}',
                    style: StudioType.body14(weight: StudioType.medium, color: c.textSecondary),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
