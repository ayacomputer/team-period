import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/cycle_settings.dart';
import '../models/flow_entry.dart';
import '../models/mood_entry.dart';
import '../models/period_log.dart';
import '../models/sleep_entry.dart';
import '../utils/cycle_calculations.dart';

/// Full-month calendar showing actual and predicted cycle phases.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.logs,
    required this.settings,
    required this.sleep,
  });

  final List<PeriodLog> logs;
  final CycleSettings settings;
  final List<SleepEntry> sleep;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);

    final monthStart = _focusedMonth;
    final monthEnd = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final calDays = generateCalendarDays(_focusedMonth);
    final roleMap = buildDayRoleMap(
      logs: widget.logs,
      settings: widget.settings,
      monthStart: monthStart,
      monthEnd: monthEnd,
      today: today,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(title: Text(t.calendarTitle)),
      body: Column(
        children: [
          // Month navigator
          _MonthNavigator(
            focusedMonth: _focusedMonth,
            onPrevious: _previousMonth,
            onNext: _nextMonth,
            t: t,
          ),

          // Weekday header
          _WeekdayHeader(t: t),
          const Divider(height: 1),

          // Month grid
          Expanded(
            child: _MonthGrid(
              calDays: calDays,
              focusedMonth: _focusedMonth,
              roleMap: roleMap,
              today: today,
              logs: widget.logs,
              sleep: widget.sleep,
              t: t,
            ),
          ),

          // Legend
          _Legend(t: t),
        ],
      ),
    );
  }
}

// ── Month navigator ───────────────────────────────────────────────────────────

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.focusedMonth,
    required this.onPrevious,
    required this.onNext,
    required this.t,
  });

  final DateTime focusedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final monthName = t.monthsFull[focusedMonth.month - 1];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
            tooltip: 'Previous month',
          ),
          Text(
            '$monthName ${focusedMonth.year}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            tooltip: 'Next month',
          ),
        ],
      ),
    );
  }
}

// ── Weekday header ────────────────────────────────────────────────────────────

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.t});
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: t.weekdaysShort
            .map(
              (d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Month grid ────────────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.calDays,
    required this.focusedMonth,
    required this.roleMap,
    required this.today,
    required this.logs,
    required this.sleep,
    required this.t,
  });

  final List<DateTime> calDays;
  final DateTime focusedMonth;
  final Map<DateTime, DayRole> roleMap;
  final DateTime today;
  final List<PeriodLog> logs;
  final List<SleepEntry> sleep;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.9,
      ),
      itemCount: calDays.length,
      itemBuilder: (_, i) {
        final day = calDays[i];
        final role = roleMap[day] ?? DayRole.none;
        final isCurrentMonth = day.month == focusedMonth.month;
        final isToday = day == today;

        return _DayCellWidget(
          day: day,
          role: role,
          isCurrentMonth: isCurrentMonth,
          isToday: isToday,
          // Use the outer build context so the bottom sheet inherits the
          // correct Localizations and Navigator.
          onTap: () => _showDayDetail(context, day, role),
        );
      },
    );
  }

  void _showDayDetail(BuildContext context, DateTime day, DayRole role) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DayDetailSheet(
        day: day,
        role: role,
        logs: logs,
        sleep: sleep,
        t: t,
      ),
    );
  }
}

// ── Day cell ──────────────────────────────────────────────────────────────────

class _DayCellWidget extends StatelessWidget {
  const _DayCellWidget({
    required this.day,
    required this.role,
    required this.isCurrentMonth,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final DayRole role;
  final bool isCurrentMonth;
  final bool isToday;
  final VoidCallback onTap;

  static const _rose = Color(0xFFE11D48);
  static const _rose50 = Color(0xFFFFF1F2);
  static const _violet600 = Color(0xFF7C3AED);
  static const _green50 = Color(0xFFF0FDF4);
  static const _green600 = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background fill / border
            _buildBackground(),

            // Day number
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                color: _textColor(),
              ),
            ),

            // Today ring overlay
            if (isToday)
              Positioned.fill(
                child: CustomPaint(
                  painter: _TodayRingPainter(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    switch (role) {
      case DayRole.actualPeriod:
      case DayRole.activePeriod:
        return Container(
          decoration: const BoxDecoration(
            color: _rose,
            shape: BoxShape.circle,
          ),
        );
      case DayRole.predictedPeriod:
        return CustomPaint(
          painter: const _DashedCirclePainter(_rose),
          child: Container(color: _rose50),
        );
      case DayRole.predictedOvulation:
        return Container(
          decoration: const BoxDecoration(
            color: _violet600,
            shape: BoxShape.circle,
          ),
        );
      case DayRole.predictedFertile:
        return Container(
          decoration: BoxDecoration(
            color: _green50,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      case DayRole.none:
        return const SizedBox.shrink();
    }
  }

  Color _textColor() {
    if (!isCurrentMonth) return Colors.black26;
    switch (role) {
      case DayRole.actualPeriod:
      case DayRole.activePeriod:
      case DayRole.predictedOvulation:
        return Colors.white;
      case DayRole.predictedPeriod:
        return _rose;
      case DayRole.predictedFertile:
        return _green600;
      case DayRole.none:
        return Colors.black87;
    }
  }
}

// ── Dashed circle painter ─────────────────────────────────────────────────────

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter(this.color);
  final Color color;

  static const _segments = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) - 2;
    const totalAngle = 2 * pi;
    const segmentAngle = totalAngle / _segments;
    const gapFraction = 0.35;
    const arcAngle = segmentAngle * (1 - gapFraction);

    for (var i = 0; i < _segments; i++) {
      final startAngle = i * segmentAngle - pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}

// ── Today ring painter ────────────────────────────────────────────────────────

class _TodayRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE11D48)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) - 1.5;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_TodayRingPainter old) => false;
}

// ── Day detail sheet ──────────────────────────────────────────────────────────

class _DayDetailSheet extends StatelessWidget {
  const _DayDetailSheet({
    required this.day,
    required this.role,
    required this.logs,
    required this.sleep,
    required this.t,
  });

  final DateTime day;
  final DayRole role;
  final List<PeriodLog> logs;
  final List<SleepEntry> sleep;
  final AppLocalizations t;

  String get _dayIso =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final monthName = t.monthsFull[day.month - 1];
    final roleLabel = _roleLabel();
    final roleColor = _roleColor();

    final moods = logs
        .expand((l) => l.moods)
        .where((m) => m.date == _dayIso)
        .toList();

    final flows = logs
        .expand((l) => l.flows)
        .where((f) => f.date == _dayIso)
        .toList();

    final sleepEntry = sleep.where((s) => s.date == _dayIso).firstOrNull;

    final hasData =
        role != DayRole.none || moods.isNotEmpty || flows.isNotEmpty || sleepEntry != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),

            // Date heading
            Text(
              '${day.day} $monthName ${day.year}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            // Cycle phase chip
            if (role != DayRole.none)
              _PhaseChip(label: roleLabel, color: roleColor)
            else if (!hasData)
              Text(t.noDayInfo, style: TextStyle(color: Colors.grey.shade500)),

            // ── Flow ──────────────────────────────────────────────────────
            if (flows.isNotEmpty) ...[
              const SizedBox(height: 16),
              const _SectionLabel(text: 'Flow'),
              const SizedBox(height: 6),
              ...flows.map((f) => _DetailRow(
                    leading: f.intensity.emoji,
                    label: f.intensity.label,
                  )),
            ],

            // ── Mood ──────────────────────────────────────────────────────
            if (moods.isNotEmpty) ...[
              const SizedBox(height: 16),
              const _SectionLabel(text: 'Mood'),
              const SizedBox(height: 6),
              ...moods.map((m) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                        leading: _moodEmoji(m.mood),
                        label: _moodLabel(m.mood),
                      ),
                      if (m.conditions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 28, top: 4),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: m.conditions
                                .map((c) => _SmallChip(label: c))
                                .toList(),
                          ),
                        ),
                      if (m.note != null && m.note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 28, top: 4),
                          child: Text(
                            m.note!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  )),
            ],

            // ── Sleep ─────────────────────────────────────────────────────
            if (sleepEntry != null) ...[
              const SizedBox(height: 16),
              const _SectionLabel(text: 'Sleep'),
              const SizedBox(height: 6),
              _DetailRow(
                leading: _sleepEmoji(sleepEntry.quality),
                label: _sleepQualityLabel(sleepEntry.quality) +
                    (sleepEntry.hoursSlept != null
                        ? '  ·  ${sleepEntry.hoursSlept}h'
                        : ''),
              ),
              if (sleepEntry.note != null && sleepEntry.note!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 28, top: 4),
                  child: Text(
                    sleepEntry.note!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _roleLabel() {
    switch (role) {
      case DayRole.actualPeriod:
      case DayRole.activePeriod:
        return t.periodDay;
      case DayRole.predictedPeriod:
        return t.predictedPeriod;
      case DayRole.predictedOvulation:
        return t.predictedOvulation;
      case DayRole.predictedFertile:
        return t.fertilWindow;
      case DayRole.none:
        return '';
    }
  }

  Color _roleColor() {
    switch (role) {
      case DayRole.actualPeriod:
      case DayRole.activePeriod:
      case DayRole.predictedPeriod:
        return const Color(0xFFE11D48);
      case DayRole.predictedOvulation:
        return const Color(0xFF7C3AED);
      case DayRole.predictedFertile:
        return const Color(0xFF16A34A);
      case DayRole.none:
        return Colors.grey;
    }
  }

  String _moodEmoji(Mood mood) {
    return switch (mood) {
      Mood.great => '😁',
      Mood.good => '🙂',
      Mood.okay => '😐',
      Mood.low => '😟',
      Mood.rough => '😢',
    };
  }

  String _moodLabel(Mood mood) {
    return switch (mood) {
      Mood.great => 'Great',
      Mood.good => 'Good',
      Mood.okay => 'Okay',
      Mood.low => 'Low',
      Mood.rough => 'Rough',
    };
  }

  String _sleepEmoji(int quality) {
    return switch (quality) {
      5 => '😴',
      4 => '🌙',
      3 => '💤',
      2 => '😪',
      _ => '😩',
    };
  }

  String _sleepQualityLabel(int quality) {
    return switch (quality) {
      5 => 'Excellent',
      4 => 'Good',
      3 => 'Fair',
      2 => 'Poor',
      _ => 'Very poor',
    };
  }
}

// ── Day detail sub-widgets ────────────────────────────────────────────────────

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B7280),
        letterSpacing: 0.4,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.leading, required this.label});
  final String leading;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text(leading, style: const TextStyle(fontSize: 15))),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend({required this.t});
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          _LegendItem(
            color: const Color(0xFFE11D48),
            label: t.periodDay,
            filled: true,
          ),
          _LegendItem(
            color: const Color(0xFFE11D48),
            label: t.predictedPeriod,
            filled: false,
            dashed: true,
          ),
          _LegendItem(
            color: const Color(0xFF7C3AED),
            label: t.predictedOvulation,
            filled: true,
          ),
          _LegendItem(
            color: const Color(0xFF16A34A),
            label: t.fertilWindow,
            filled: false,
            rounded: true,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.filled,
    this.dashed = false,
    this.rounded = false,
  });

  final Color color;
  final String label;
  final bool filled;
  final bool dashed;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.1),
            shape: rounded ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: rounded ? BorderRadius.circular(3) : null,
            border: !filled
                ? Border.all(
                    color: color,
                    width: 1.5,
                    style: dashed ? BorderStyle.none : BorderStyle.solid,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}
