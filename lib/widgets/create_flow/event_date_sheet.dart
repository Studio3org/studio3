import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../screens/profile/profile_constants.dart';
import '../../theme/home_feed_tokens.dart';
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

  Future<DateTime?> _pickDate(DateTime? current) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
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

  Future<TimeOfDay?> _pickTime(TimeOfDay? current) {
    return showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
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
                    final picked = await _pickDate(_endDate ?? _startDate);
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
                        final picked = await _pickTime(_startTime);
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
                        final picked = await _pickTime(_endTime);
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
