import '../models/cycle_settings.dart';
import '../models/cycle_summary.dart';
import '../models/period_log.dart';

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
