import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/studio_event.dart';
import '../studio/studio.dart';
import 'host_widgets.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// `8:00 PM`.
String hostTime(TimeOfDay t) {
  final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  return '$hour:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
}

/// `Sat, Nov 21`.
String hostDay(DateTime d) => '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

/// The zone the times are in: this phone's, as an abbreviation ("CST"); empty when the
/// phone only knows an offset name.
String hostZone() {
  final name = DateTime.now().timeZoneName;
  return name.contains('/') || name.length > 5 ? '' : name;
}

/// When the event runs (`HostDate`): one day or several, a start and an end time.
class HostDateSelection {
  const HostDateSelection({
    required this.multiDay,
    required this.startDate,
    this.endDate,
    required this.start,
    required this.end,
    this.zone = '',
  });

  final bool multiDay;
  final DateTime startDate;
  final DateTime? endDate;
  final TimeOfDay start;
  final TimeOfDay end;

  /// "CST" — shown after every time.
  final String zone;

  DateTime get startsAt => DateTime(startDate.year, startDate.month, startDate.day, start.hour, start.minute);

  /// The end; on a single day an end at or before the start runs past midnight.
  DateTime get endsAt {
    final day = multiDay && endDate != null ? endDate! : startDate;
    var end = DateTime(day.year, day.month, day.day, this.end.hour, this.end.minute);
    if (!end.isAfter(startsAt)) end = end.add(const Duration(days: 1));
    return end;
  }

  String get _z => zone.isEmpty ? '' : ' $zone';

  /// The Details row: `Sat, Nov 21 · 8:00 PM CST`.
  String get rowLabel => '${hostDay(startDate)} · ${hostTime(start)}$_z';

  /// Review and Live: `Sat, Nov 21 · 8:00 – 10:00 PM CST`, or both days for a run.
  String get rangeLabel {
    final e = endsAt;
    final sameDay = e.year == startDate.year && e.month == startDate.month && e.day == startDate.day;
    if (sameDay || !multiDay) {
      final s = hostTime(start);
      final en = hostTime(end);
      final samePeriod = s.endsWith(en.substring(en.length - 2));
      return '${hostDay(startDate)} · ${samePeriod ? s.substring(0, s.length - 3) : s} – $en$_z';
    }
    return '${hostDay(startDate)} ${hostTime(start)} – ${hostDay(e)} ${hostTime(end)}$_z';
  }

  factory HostDateSelection.fromEvent(StudioEvent e) {
    final multi = e.endsAt.difference(e.startsAt).inHours >= 24 ||
        e.endsAt.day != e.startsAt.day && e.endsAt.difference(e.startsAt).inHours > 12;
    return HostDateSelection(
      multiDay: multi,
      startDate: DateTime(e.startsAt.year, e.startsAt.month, e.startsAt.day),
      endDate: multi ? DateTime(e.endsAt.year, e.endsAt.month, e.endsAt.day) : null,
      start: TimeOfDay.fromDateTime(e.startsAt),
      end: TimeOfDay.fromDateTime(e.endsAt),
      zone: e.zoneLabel.isNotEmpty ? e.zoneLabel : hostZone(),
    );
  }
}

/// Date and time (`HostDate`): a sheet with Multi-day event, the month (15/500 with ‹ ›),
/// the week in Mono 11, days 34 (the chosen one in an Ink circle; past days grey), Starts and
/// Ends as Mono underline fields that open the time wheel, the zone line 12 and Done.
class HostDateSheet extends StatefulWidget {
  const HostDateSheet({super.key, this.initial, this.now});

  final HostDateSelection? initial;

  /// For tests.
  final DateTime? now;

  static Future<HostDateSelection?> show(BuildContext context, {HostDateSelection? initial, DateTime? now}) {
    return showStudioSheet<HostDateSelection>(
      context: context,
      builder: (_) => HostDateSheet(initial: initial, now: now),
    );
  }

  @override
  State<HostDateSheet> createState() => _HostDateSheetState();
}

class _HostDateSheetState extends State<HostDateSheet> {
  late DateTime _today;
  late bool _multi;
  DateTime? _startDate;
  DateTime? _endDate;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late DateTime _month;
  late final _startText = TextEditingController();
  late final _endText = TextEditingController();
  late final String _zone;

  @override
  void initState() {
    super.initState();
    final now = widget.now ?? DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    final i = widget.initial;
    _multi = i?.multiDay ?? false;
    _startDate = i?.startDate;
    _endDate = i?.endDate;
    _start = i?.start ?? const TimeOfDay(hour: 19, minute: 0);
    _end = i?.end ?? const TimeOfDay(hour: 21, minute: 0);
    _zone = i?.zone.isNotEmpty == true ? i!.zone : hostZone();
    final anchor = _startDate ?? _today;
    _month = DateTime(anchor.year, anchor.month);
    _syncTimes();
  }

  @override
  void dispose() {
    _startText.dispose();
    _endText.dispose();
    super.dispose();
  }

  void _syncTimes() {
    final z = _zone.isEmpty ? '' : ' $_zone';
    _startText.text = '${hostTime(_start)}$z';
    _endText.text = '${hostTime(_end)}$z';
  }

  void _pickDay(DateTime day) {
    setState(() {
      if (!_multi || _startDate == null || _endDate != null || day.isBefore(_startDate!)) {
        _startDate = day;
        _endDate = null;
      } else {
        _endDate = day.isAtSameMomentAs(_startDate!) ? null : day;
      }
    });
  }

  Future<void> _pickTime({required bool start}) async {
    var picked = start ? _start : _end;
    final c = context.studio;
    final done = await showStudioSheet<bool>(
      context: context,
      builder: (sheetContext) => StudioSheet(
        horizontalPadding: StudioSpace.marginForm,
        gap: 10,
        children: [
          Text(start ? 'Starts' : 'Ends', style: StudioType.title22(color: c.textPrimary)),
          SizedBox(
            height: 200,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(context).brightness,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: StudioType.sans(20, color: c.textPrimary),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                minuteInterval: 5,
                initialDateTime: DateTime(2000, 1, 1, picked.hour, picked.minute - picked.minute % 5),
                onDateTimeChanged: (d) => picked = TimeOfDay.fromDateTime(d),
              ),
            ),
          ),
          StudioButton(label: 'Done', onPressed: () => Navigator.pop(sheetContext, true)),
        ],
      ),
    );
    if (done != true || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
      _syncTimes();
    });
  }

  bool get _ready => _startDate != null && (!_multi || _endDate != null);

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 10,
      scrollable: true,
      children: [
        Text('Date and time', style: StudioType.title22(color: c.textPrimary)),
        HostSwitchRow(
          label: 'Multi-day event',
          subtitle: 'Runs across more than one day',
          value: _multi,
          onChanged: (v) => setState(() {
            _multi = v;
            if (!v) _endDate = null;
          }),
        ),
        _monthHeader(c),
        _grid(c),
        Row(
          children: [
            Expanded(
              child: StudioUnderlineField(
                label: 'Starts',
                controller: _startText,
                readOnly: true,
                mono: true,
                onTap: () => _pickTime(start: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StudioUnderlineField(
                label: 'Ends',
                controller: _endText,
                readOnly: true,
                mono: true,
                onTap: () => _pickTime(start: false),
              ),
            ),
          ],
        ),
        Text(
          _zone.isEmpty ? "Times are in this phone's time zone" : "Times are in $_zone, this phone's time zone",
          style: StudioType.caption12(color: c.textTertiary),
        ),
        StudioButton(
          label: 'Done',
          onPressed: _ready
              ? () => Navigator.pop(
                  context,
                  HostDateSelection(
                    multiDay: _multi,
                    startDate: _startDate!,
                    endDate: _endDate,
                    start: _start,
                    end: _end,
                    zone: _zone,
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Widget _monthHeader(StudioColors c) {
    final canGoBack = _month.isAfter(DateTime(_today.year, _today.month));
    Widget arrow(bool back) => Semantics(
      button: true,
      label: back ? 'Previous month' : 'Next month',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: back && !canGoBack
            ? null
            : () => setState(() => _month = DateTime(_month.year, _month.month + (back ? -1 : 1))),
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: 36,
          child: Center(
            child: Transform.flip(
              flipX: back,
              child: StudioIcon(
                StudioIcons.chevronRight,
                size: 18,
                color: back && !canGoBack ? c.textPlaceholder : c.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_monthNames[_month.month - 1]} ${_month.year}',
              style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
            ),
          ),
          arrow(true),
          arrow(false),
        ],
      ),
    );
  }

  Widget _grid(StudioColors c) {
    final first = DateTime(_month.year, _month.month);
    final lead = first.weekday % 7; // Sunday first
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <Widget>[
      for (final w in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
        Center(child: Text(w, style: StudioType.mono(11, color: c.textTertiary))),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++) _day(c, DateTime(_month.year, _month.month, d)),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      childAspectRatio: 50 / 36,
      children: cells,
    );
  }

  Widget _day(StudioColors c, DateTime day) {
    final past = day.isBefore(_today);
    final start = _startDate;
    final end = _endDate;
    final isEnd = end != null && day.isAtSameMomentAs(end);
    final picked = (start != null && day.isAtSameMomentAs(start)) || isEnd;
    final between = start != null && end != null && day.isAfter(start) && day.isBefore(end);
    return Semantics(
      button: !past,
      selected: picked,
      label: hostDay(day),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: past ? null : () => _pickDay(day),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: picked ? c.textPrimary : (between ? c.surface : null),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${day.day}',
              style: StudioType.body14(
                color: picked ? c.background : (past ? c.textPlaceholder : c.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
