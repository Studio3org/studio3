import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../screens/profile/profile_constants.dart';
import '../../theme/home_feed_tokens.dart';
import '../studio_message.dart';
import 'create_flow_widgets.dart';

class EventDateSelection {
  const EventDateSelection({
    required this.multiDay,
    required this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
  });

  final bool multiDay;
  final DateTime startDate;
  final DateTime? endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  /// When the event actually starts, as a single timestamp.
  ///
  /// Null until a start time has been chosen. The sheet lets someone pick a date alone,
  /// which is fine while drafting, but an event cannot be published without one: its whole
  /// clock — and, for an event auction, when bidding opens and closes — is derived from it.
  DateTime? get startsAt {
    final time = startTime;
    if (time == null) return null;
    return DateTime(
      startDate.year, startDate.month, startDate.day, time.hour, time.minute,
    );
  }

  /// When it ends.
  ///
  /// Falls back to two hours after the start when no end time was given. A default is used
  /// rather than leaving it null because the server requires an end — an event auction
  /// closes thirty minutes before it, so there is no such thing as an open-ended one — and
  /// two hours is both the common case and long enough for that window to exist.
  DateTime? get endsAt {
    final start = startsAt;
    if (start == null) return null;
    final date = multiDay && endDate != null ? endDate! : startDate;
    final time = endTime;
    if (time == null) return start.add(const Duration(hours: 2));
    final end = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    // A finish time earlier than the start means it runs past midnight.
    return end.isAfter(start) ? end : end.add(const Duration(days: 1));
  }

  String get summary {
    final dateText = multiDay && endDate != null
        ? '${formatEventDate(startDate, includeWeekday: false)} – ${formatEventDate(endDate!, includeWeekday: false)}'
        : formatEventDate(startDate);
    final start = startTime == null ? null : formatEventTime(startTime!);
    final end = endTime == null ? null : formatEventTime(endTime!);
    if (start != null && end != null) return '$dateText · $start–$end';
    if (start != null) return '$dateText · $start';
    return dateText;
  }

  /// Review card: `Sat Jul 25 · 8:00 PM – 10:00 PM CST`
  String get reviewLine {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateText = multiDay && endDate != null
        ? '${months[startDate.month - 1]} ${startDate.day} – ${months[endDate!.month - 1]} ${endDate!.day}'
        : '${weekdays[startDate.weekday - 1]} ${months[startDate.month - 1]} ${startDate.day}';
    return _withTimes(dateText, compactAmPm: false);
  }

  /// Success poster: `Sat, July 25th · 8:00PM – 10:00PM CST`
  String get posterLine {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateText =
        '${weekdays[startDate.weekday - 1]}, ${months[startDate.month - 1]} ${startDate.day}${_dayOrdinal(startDate.day)}';
    return _withTimes(dateText, compactAmPm: true);
  }

  String _withTimes(String dateText, {required bool compactAmPm}) {
    String? fmt(TimeOfDay? time) {
      if (time == null) return null;
      final text = formatEventTime(time);
      return compactAmPm ? text.replaceAll(' ', '') : text;
    }

    final start = fmt(startTime);
    final end = fmt(endTime);
    final tz = _shortTimeZone();
    if (start != null && end != null) return '$dateText · $start – $end$tz';
    if (start != null) return '$dateText · $start$tz';
    return dateText;
  }
}

String formatEventDate(DateTime date, {bool includeWeekday = true}) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final month = months[date.month - 1];
  final weekday = weekdays[date.weekday - 1];
  return includeWeekday
      ? '$weekday, $month ${date.day}'
      : '$month ${date.day}';
}

String formatEventDateShort(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String formatEventTime(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String _dayOrdinal(int day) {
  if (day >= 11 && day <= 13) return 'th';
  return switch (day % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };
}

String _shortTimeZone() {
  final name = DateTime.now().timeZoneName;
  if (name.length <= 5) return ' $name';
  return '';
}

/// Date / time sheet for event posting (Figma Event Posting — Details).
class EventDateSheet extends StatefulWidget {
  const EventDateSheet({super.key, this.initial});

  final EventDateSelection? initial;

  static Future<EventDateSelection?> show(
    BuildContext context, {
    EventDateSelection? initial,
  }) {
    return showModalBottomSheet<EventDateSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => EventDateSheet(initial: initial),
    );
  }

  @override
  State<EventDateSheet> createState() => _EventDateSheetState();
}

class _EventDateSheetState extends State<EventDateSheet> {
  static const _sheetBg = HomeFeedTokens.background;
  static const _handleColor = Color(0xFFC8C5BC);
  static const _disabledFill = Color(0xFFC8C5BC);

  late bool _multiDay;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _multiDay = initial?.multiDay ?? false;
    _startDate = initial?.startDate;
    _endDate = initial?.endDate;
    _startTime = initial?.startTime;
    _endTime = initial?.endTime;
  }

  bool get _canSubmit {
    if (_startDate == null) return false;
    if (_multiDay && _endDate == null) return false;
    return true;
  }

  /// [minDate] floors how far back the calendar allows picking — an event
  /// can't be scheduled in the past. Defaults to today; the end-date field
  /// passes the chosen start date instead, so it can't land before it.
  Future<DateTime?> _pickDate(DateTime? current, {DateTime? minDate}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final floor = minDate ?? today;
    // A value already set earlier than the floor (e.g. the start date moved
    // forward after an end date was picked) must not trip showDatePicker's
    // firstDate <= initialDate assertion.
    final first = (current != null && current.isBefore(floor))
        ? current
        : floor;
    final initial = current ?? today;
    return showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: HomeFeedTokens.neutral800,
              onPrimary: HomeFeedTokens.textInverse,
              surface: HomeFeedTokens.background,
              onSurface: HomeFeedTokens.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isPastTimeOfDay(TimeOfDay time) {
    final now = TimeOfDay.now();
    return time.hour < now.hour ||
        (time.hour == now.hour && time.minute < now.minute);
  }

  /// [forDate] is the date this time belongs to (start or end) — when it's
  /// today, a time earlier than right now is rejected rather than silently
  /// accepted, since that date/time combination would already be in the past.
  Future<TimeOfDay?> _pickTime(TimeOfDay? current, {DateTime? forDate}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
      // The default round-clock dial is fussy to tap precisely on a phone —
      // a plain hour/minute text entry is faster and matches the rest of
      // this sheet's simple field-based UI.
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (context, child) {
        // TimePickerEntryMode.input(Only)'s dialog has a fixed minimum
        // content height. On a device with a larger system text-scale
        // setting, the hour/minute fields render tall enough to exceed
        // that fixed height by a couple of pixels, which throws
        // "BoxConstraints has non-normalized height constraints" — clamping
        // text scale here is Flutter's own documented workaround.
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: HomeFeedTokens.neutral800,
                onPrimary: HomeFeedTokens.textInverse,
                surface: HomeFeedTokens.background,
                onSurface: HomeFeedTokens.textPrimary,
              ),
            ),
            child: child!,
          ),
        );
      },
    );
    if (picked == null) return null;
    if (forDate != null && _isToday(forDate) && _isPastTimeOfDay(picked)) {
      if (mounted) {
        StudioMessage.show(context, "Pick a time later than now for today's date.");
      }
      return null;
    }
    return picked;
  }

  void _onDone() {
    final start = _startDate;
    if (start == null) return;
    Navigator.pop(
      context,
      EventDateSelection(
        multiDay: _multiDay,
        startDate: start,
        endDate: _multiDay ? _endDate : null,
        startTime: _startTime,
        endTime: _endTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _sheetBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, safeBottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Date',
                style: kProfileGeist(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Multi-day event',
                      style: kProfileGeist(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: _multiDay,
                    onChanged: (value) => setState(() {
                      _multiDay = value;
                      if (!value) _endDate = null;
                    }),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeThumbColor: Colors.white,
                    activeTrackColor: HomeFeedTokens.neutral800,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: _handleColor,
                    trackOutlineColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _LabeledTapField(
                label: _multiDay ? 'Start date' : 'Date',
                hint: 'Select a date',
                value: _startDate == null ? null : formatEventDate(_startDate!),
                onTap: () async {
                  final picked = await _pickDate(_startDate);
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
              if (_multiDay) ...[
                const SizedBox(height: 16),
                _LabeledTapField(
                  label: 'End date',
                  hint: 'Select a date',
                  value: _endDate == null ? null : formatEventDate(_endDate!),
                  onTap: () async {
                    final picked = await _pickDate(
                      _endDate ?? _startDate,
                      minDate: _startDate,
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _LabeledTapField(
                      label: 'Start time',
                      hint: '--:-- --',
                      value: _startTime == null
                          ? null
                          : formatEventTime(_startTime!),
                      onTap: () async {
                        final picked = await _pickTime(
                          _startTime,
                          forDate: _startDate,
                        );
                        if (picked != null) {
                          setState(() => _startTime = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LabeledTapField(
                      label: 'End time',
                      hint: '--:-- --',
                      value: _endTime == null
                          ? null
                          : formatEventTime(_endTime!),
                      onTap: () async {
                        final picked = await _pickTime(
                          _endTime,
                          forDate: _multiDay ? (_endDate ?? _startDate) : _startDate,
                        );
                        if (picked != null) setState(() => _endTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              CreateFlowBottomButton(
                label: 'Done',
                height: 40,
                backgroundColor: _canSubmit
                    ? HomeFeedTokens.neutral800
                    : _disabledFill,
                textColor: _canSubmit
                    ? HomeFeedTokens.textInverse
                    : HomeFeedTokens.textPrimary,
                onTap: _canSubmit ? _onDone : null,
                child: Text(
                  'Done',
                  style: GoogleFonts.geist(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: _canSubmit
                        ? HomeFeedTokens.textInverse
                        : HomeFeedTokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledTapField extends StatelessWidget {
  const _LabeledTapField({
    required this.label,
    required this.hint,
    required this.onTap,
    this.value,
  });

  final String label;
  final String hint;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: kProfileGeist(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: HomeFeedTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 40,
            width: double.infinity,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HomeFeedTokens.textPrimary),
            ),
            child: Text(
              filled ? value! : hint,
              style: GoogleFonts.geist(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: filled
                    ? HomeFeedTokens.textPrimary
                    : HomeFeedTokens.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
