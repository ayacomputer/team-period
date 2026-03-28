import 'dart:math';
import '../models/cycle_settings.dart';
import '../models/cycle_summary.dart';
import '../models/period_log.dart';
import '../models/temperature_entry.dart';

/// All pure functions — no side effects, no Flutter dependencies.
/// Dates are always normalised to midnight (start of day) to avoid
/// timezone-drift bugs.

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Returns `date` formatted as "YYYY-MM-DD".
String toIsoDate(DateTime date) {
  final d = _startOfDay(date);
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Parses "YYYY-MM-DD" → midnight DateTime.
DateTime fromIsoDate(String iso) {
  final parts = iso.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// Number of whole days between two dates (normalised to midnight).
int daysBetween(DateTime a, DateTime b) {
  final da = _startOfDay(a);
  final db = _startOfDay(b);
  return db.difference(da).inDays;
}

/// Computes average cycle length from logs.
/// Falls back to [settings.averageCycleLength] when fewer than 2 logs exist.
int computeAverageCycleLength(List<PeriodLog> logs, CycleSettings settings) {
  if (logs.length < 2) return settings.averageCycleLength;

  final sorted = [...logs]
    ..sort((a, b) => a.startDate.compareTo(b.startDate));

  final gaps = <int>[];
  for (var i = 1; i < sorted.length; i++) {
    final gap = daysBetween(
      fromIsoDate(sorted[i - 1].startDate),
      fromIsoDate(sorted[i].startDate),
    );
    if (gap > 0) gaps.add(gap);
  }
  if (gaps.isEmpty) return settings.averageCycleLength;

  final sum = gaps.fold(0, (a, b) => a + b);
  return (sum / gaps.length).round();
}

/// Mean duration of completed period logs.
/// Returns null if there are no completed logs.
int? computeAveragePeriodLength(List<PeriodLog> logs) {
  final completed = logs.where((l) => l.endDate != null).toList();
  if (completed.isEmpty) return null;

  final durations = completed.map((l) {
    final start = fromIsoDate(l.startDate);
    final end = fromIsoDate(l.endDate!);
    return daysBetween(start, end) + 1; // inclusive
  }).toList();

  final sum = durations.fold(0, (a, b) => a + b);
  return (sum / durations.length).round();
}

/// Computes the full [CycleSummary] for today.
CycleSummary computeCycleSummary(List<PeriodLog> logs, CycleSettings settings) {
  final avgCycle = computeAverageCycleLength(logs, settings);
  final today = _startOfDay(DateTime.now());

  // Most recent log
  final sorted = [...logs]
    ..sort((a, b) => b.startDate.compareTo(a.startDate));
  final lastLog = sorted.isNotEmpty ? sorted.first : null;

  final lastStart =
      lastLog != null ? fromIsoDate(lastLog.startDate) : today;

  final nextPeriod = lastStart.add(Duration(days: avgCycle));
  final ovulation = nextPeriod.subtract(const Duration(days: 14));
  final fertileStart = ovulation.subtract(const Duration(days: 3));
  final fertileEnd = ovulation.add(const Duration(days: 3));

  final dayInCycle = daysBetween(lastStart, today) + 1; // 1-based
  final daysUntil = daysBetween(today, nextPeriod);

  final phase = _computePhase(
    today: today,
    lastLog: lastLog,
    settings: settings,
    ovulation: ovulation,
    fertileStart: fertileStart,
    fertileEnd: fertileEnd,
  );

  return CycleSummary(
    nextPeriodDate: nextPeriod,
    ovulationDate: ovulation,
    fertileWindowStart: fertileStart,
    fertileWindowEnd: fertileEnd,
    currentPhase: phase,
    daysUntilNextPeriod: daysUntil,
    averageCycleLength: avgCycle,
    dayInCycle: dayInCycle.clamp(1, avgCycle),
  );
}

CyclePhase _computePhase({
  required DateTime today,
  required PeriodLog? lastLog,
  required CycleSettings settings,
  required DateTime ovulation,
  required DateTime fertileStart,
  required DateTime fertileEnd,
}) {
  // 1. Period — highest priority
  if (lastLog != null) {
    final start = fromIsoDate(lastLog.startDate);
    final end = lastLog.endDate != null
        ? fromIsoDate(lastLog.endDate!)
        : start.add(Duration(days: settings.averagePeriodLength - 1));

    if (!today.isBefore(start) && !today.isAfter(end)) {
      return CyclePhase.period;
    }
  }

  // 2. Ovulation
  if (today == ovulation) return CyclePhase.ovulation;

  // 3. Fertile window
  if (!today.isBefore(fertileStart) && !today.isAfter(fertileEnd)) {
    return CyclePhase.fertile;
  }

  // 4. Follicular (before fertile window)
  if (today.isBefore(fertileStart)) return CyclePhase.follicular;

  // 5. Luteal (after fertile window)
  return CyclePhase.luteal;
}

/// Returns the day-of-year (1–366) — used for rotating daily tips.
int dayOfYear(DateTime date) {
  final start = DateTime(date.year, 1, 1);
  return date.difference(start).inDays + 1;
}

// ── Calendar helpers ───────────────────────────────────────────────────────

/// The role a calendar day plays relative to logged / predicted cycle data.
enum DayRole {
  /// Falls within a completed period log (startDate..endDate).
  actualPeriod,

  /// Ongoing period with no endDate, up to today.
  activePeriod,

  /// Predicted future period window (dashed rose border).
  predictedPeriod,

  /// Predicted ovulation day (violet dot).
  predictedOvulation,

  /// Predicted fertile window (green tint).
  predictedFertile,

  /// No special role.
  none,
}

/// Returns 35 or 42 [DateTime] values covering [month].
/// The grid always starts on the Sunday of the week containing the 1st.
List<DateTime> generateCalendarDays(DateTime month) {
  final firstOfMonth = DateTime(month.year, month.month, 1);
  // weekday: Mon=1 … Sun=7; we want Sunday=0 offset
  final sundayOffset = firstOfMonth.weekday % 7;
  final gridStart = firstOfMonth.subtract(Duration(days: sundayOffset));

  // Use 35 cells unless the last day of the month falls in the 6th row.
  final lastOfMonth = DateTime(month.year, month.month + 1, 0);
  final lastSundayOffset = lastOfMonth.weekday % 7;
  final lastCell = lastOfMonth.add(Duration(days: 6 - lastSundayOffset));
  final totalDays = lastCell.difference(gridStart).inDays + 1;
  final cellCount = totalDays > 35 ? 42 : 35;

  return List.generate(cellCount, (i) => gridStart.add(Duration(days: i)));
}

/// Builds a map from each date within [monthStart]..[monthEnd] to its
/// [DayRole]. Actual log data always takes priority over predictions.
Map<DateTime, DayRole> buildDayRoleMap({
  required List<PeriodLog> logs,
  required CycleSettings settings,
  required DateTime monthStart,
  required DateTime monthEnd,
  required DateTime today,
}) {
  final map = <DateTime, DayRole>{};

  void setIfEmpty(DateTime day, DayRole role) {
    final key = _startOfDay(day);
    map[key] ??= DayRole.none;
    if (map[key] == DayRole.none) map[key] = role;
  }

  // ── Step 1: mark actual / active logs ─────────────────────────────────

  for (final log in logs) {
    final start = fromIsoDate(log.startDate);
    final end = log.endDate != null ? fromIsoDate(log.endDate!) : today;
    final role = log.isActive ? DayRole.activePeriod : DayRole.actualPeriod;

    for (var d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      final key = _startOfDay(d);
      // Always overwrite with actual data.
      map[key] = role;
    }
  }

  // ── Step 2: predictions ───────────────────────────────────────────────

  if (logs.isEmpty) return map;

  final avgCycle = computeAverageCycleLength(logs, settings);
  final avgPeriod =
      computeAveragePeriodLength(logs) ?? settings.averagePeriodLength;

  // Start from the most-recent log's start date and project forward one
  // cycle at a time.  We begin one cycle *before* monthStart so that
  // fertile/ovulation windows whose period anchor is just before the view
  // still get drawn inside the visible month.
  final sorted = [...logs]
    ..sort((a, b) => b.startDate.compareTo(a.startDate));
  var projected = fromIsoDate(sorted.first.startDate);

  // Walk forward until the projected start is close enough to monthStart
  // that its fertile/ovulation tail could overlap with the visible month.
  // "Close enough" = within one full cycle before monthStart.
  while (projected.add(Duration(days: avgCycle)).isBefore(monthStart)) {
    projected = projected.add(Duration(days: avgCycle));
  }

  // Paint predictions for every projected cycle that overlaps the month.
  // Actual data already occupies those keys (Step 1), so setIfEmpty
  // guarantees real logs always win — no extra suppression needed.
  while (!projected.isAfter(monthEnd)) {
    final periodEnd = projected.add(Duration(days: avgPeriod - 1));
    final ovulation = projected.add(Duration(days: avgCycle - 14));
    final fertileStart = ovulation.subtract(const Duration(days: 5));
    final fertileEnd = ovulation.add(const Duration(days: 1));

    // Only paint predictions for days that are today or in the future.
    // Past predictions are noise and conflict with "no data logged" months.
    if (!periodEnd.isBefore(today)) {
      for (var d = projected;
          !d.isAfter(periodEnd);
          d = d.add(const Duration(days: 1))) {
        if (!d.isBefore(today)) setIfEmpty(d, DayRole.predictedPeriod);
      }
    }

    if (!ovulation.isBefore(today)) {
      setIfEmpty(ovulation, DayRole.predictedOvulation);
    }

    for (var d = fertileStart;
        !d.isAfter(fertileEnd);
        d = d.add(const Duration(days: 1))) {
      if (d != ovulation && !d.isBefore(today)) {
        setIfEmpty(d, DayRole.predictedFertile);
      }
    }

    projected = projected.add(Duration(days: avgCycle));
  }

  return map;
}

// ── Health insights ────────────────────────────────────────────────────────

enum InsightSeverity { info, warning }

class HealthInsight {
  const HealthInsight({
    required this.type,
    required this.severity,
    required this.message,
  });

  final String type;
  final InsightSeverity severity;
  final String message;
}

/// Analyses [logs], [settings], and [temperatures] and returns a list of
/// relevant [HealthInsight] items. All checks are purely functional.
List<HealthInsight> computeHealthInsights(
  List<PeriodLog> logs,
  CycleSettings settings,
  List<TemperatureEntry> temperatures,
) {
  final insights = <HealthInsight>[];
  final completed = logs.where((l) => l.endDate != null).toList();

  // ── Not enough data ────────────────────────────────────────────────────
  if (completed.length < 3) {
    insights.add(const HealthInsight(
      type: 'insufficient_data',
      severity: InsightSeverity.info,
      message:
          'Log at least 3 complete cycles for personalised health insights.',
    ));
    return insights; // early return — most checks need 3+ cycles
  }

  // ── Cycle length stats ────────────────────────────────────────────────
  final sorted = [...logs]
    ..sort((a, b) => a.startDate.compareTo(b.startDate));

  final cycleLengths = <int>[];
  for (var i = 1; i < sorted.length; i++) {
    final gap = daysBetween(
      fromIsoDate(sorted[i - 1].startDate),
      fromIsoDate(sorted[i].startDate),
    );
    if (gap > 0) cycleLengths.add(gap);
  }

  if (cycleLengths.isNotEmpty) {
    final avgCycle = cycleLengths.fold(0, (a, b) => a + b) / cycleLengths.length;

    if (avgCycle > 35) {
      insights.add(HealthInsight(
        type: 'long_cycle',
        severity: InsightSeverity.warning,
        message:
            'Your average cycle is ${avgCycle.round()} days — longer than the typical range (21–35 days). Consider speaking with a healthcare provider.',
      ));
    } else if (avgCycle < 21) {
      insights.add(HealthInsight(
        type: 'short_cycle',
        severity: InsightSeverity.warning,
        message:
            'Your average cycle is ${avgCycle.round()} days — shorter than the typical range (21–35 days). Consider speaking with a healthcare provider.',
      ));
    }

    // Irregular cycles (std dev > 7 days)
    final mean = avgCycle;
    final variance = cycleLengths
            .map((c) => pow(c - mean, 2))
            .fold(0.0, (a, b) => a + b) /
        cycleLengths.length;
    final stdDev = sqrt(variance);

    if (stdDev > 7) {
      insights.add(HealthInsight(
        type: 'irregular_cycles',
        severity: InsightSeverity.info,
        message:
            'Your cycle lengths vary significantly (±${stdDev.round()} days), which may indicate hormonal irregularity.',
      ));
    }
  }

  // ── Period duration checks ────────────────────────────────────────────
  for (final log in completed) {
    final start = fromIsoDate(log.startDate);
    final end = fromIsoDate(log.endDate!);
    final duration = daysBetween(start, end) + 1;

    if (duration > 8) {
      insights.add(HealthInsight(
        type: 'long_period',
        severity: InsightSeverity.warning,
        message:
            'A period starting ${log.startDate} lasted $duration days, which is longer than usual (>8 days).',
      ));
    } else if (duration < 2) {
      insights.add(HealthInsight(
        type: 'very_short_period',
        severity: InsightSeverity.info,
        message:
            'A period starting ${log.startDate} lasted only $duration day — shorter than typical.',
      ));
    }
  }

  // ── Cycle overdue ─────────────────────────────────────────────────────
  final avgCycleLength = computeAverageCycleLength(logs, settings);
  final recentLog = (sorted..sort((a, b) => b.startDate.compareTo(a.startDate))).first;
  final lastStart = fromIsoDate(recentLog.startDate);
  final today = _startOfDay(DateTime.now());
  final daysSinceLast = daysBetween(lastStart, today);

  if (recentLog.isActive == false && daysSinceLast > avgCycleLength + 7) {
    insights.add(HealthInsight(
      type: 'cycle_overdue',
      severity: InsightSeverity.warning,
      message:
          'Your period is ${daysSinceLast - avgCycleLength} days overdue. If this is unexpected, consider taking a pregnancy test or consulting a doctor.',
    ));
  }

  // ── BBT checks ────────────────────────────────────────────────────────
  if (temperatures.isNotEmpty) {
    final recentTemps = temperatures
        .where((t) {
          final d = fromIsoDate(t.dateOnly);
          return daysBetween(d, today) <= 18;
        })
        .toList()
      ..sort((a, b) => a.datetime.compareTo(b.datetime));

    // BBT consistently elevated (all readings in last 18 days > 37.5°C)
    if (recentTemps.length >= 3 &&
        recentTemps.every((t) => t.celsius > 37.5)) {
      insights.add(const HealthInsight(
        type: 'bbt_consistently_elevated',
        severity: InsightSeverity.warning,
        message:
            'All temperature readings over the last 18 days are above 37.5°C. This may indicate illness or hormonal changes — seek medical advice if persistent.',
      ));
    }

    // No post-ovulation BBT rise
    final summary = computeCycleSummary(logs, settings);
    final ovulationDate = summary.ovulationDate;
    final postOvTemps = temperatures
        .where((t) {
          final d = fromIsoDate(t.dateOnly);
          return !d.isBefore(ovulationDate) &&
              daysBetween(ovulationDate, d) <= 10;
        })
        .toList()
      ..sort((a, b) => a.datetime.compareTo(b.datetime));

    if (postOvTemps.length >= 3) {
      // Check for a sustained rise of ≥ 0.2°C over 3 consecutive readings
      final baselineTemp = temperatures
          .where((t) {
            final d = fromIsoDate(t.dateOnly);
            return d.isBefore(ovulationDate);
          })
          .map((t) => t.celsius)
          .fold<double>(0.0, (a, b) => a + b);

      final beforeOvCount = temperatures
          .where((t) => fromIsoDate(t.dateOnly).isBefore(ovulationDate))
          .length;

      if (beforeOvCount > 0) {
        final baseline = baselineTemp / beforeOvCount;
        final hasRise = _hasSustainedRise(postOvTemps, baseline, 0.2, 3);
        if (!hasRise) {
          insights.add(const HealthInsight(
            type: 'bbt_no_post_ovulation_rise',
            severity: InsightSeverity.info,
            message:
                'No clear temperature rise detected after predicted ovulation. BBT should rise ≥0.2°C and stay elevated for 3+ days after ovulation.',
          ));
        }
      }
    }
  }

  return insights;
}

/// Returns true if [temps] contains a run of at least [minDays] consecutive
/// readings that are all at least [riseThreshold] above [baseline].
bool _hasSustainedRise(
  List<TemperatureEntry> temps,
  double baseline,
  double riseThreshold,
  int minDays,
) {
  var streak = 0;
  for (final t in temps) {
    if (t.celsius >= baseline + riseThreshold) {
      streak++;
      if (streak >= minDays) return true;
    } else {
      streak = 0;
    }
  }
  return false;
}
