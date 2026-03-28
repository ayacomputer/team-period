import 'package:shared_preferences/shared_preferences.dart';

/// Writes cycle summary data to [SharedPreferences] so a native home-screen
/// widget (iOS WidgetKit / Android Glance) can read it via the shared app group
/// or SharedPreferences on the platform side.
///
/// Keys are intentionally simple strings so native code can reference them
/// without importing any Dart layer.
///
/// Call [update] whenever logs or settings change — typically from [MainShell]
/// after any Firestore write.
class WidgetDataService {
  WidgetDataService._();
  static final instance = WidgetDataService._();

  // ── SharedPreferences key constants ──────────────────────────────────────

  /// ISO date string of the predicted next period start, e.g. "2026-04-14".
  static const keyNextPeriodDate = 'widget_next_period_date';

  /// Number of days until the next period (int). Negative = overdue.
  static const keyDaysUntilPeriod = 'widget_days_until_period';

  /// Whether a period is currently active (bool).
  static const keyPeriodActive = 'widget_period_active';

  /// Current cycle day number when a period is active (int), else 0.
  static const keyCurrentCycleDay = 'widget_current_cycle_day';

  /// Average cycle length in days (int).
  static const keyAvgCycleLength = 'widget_avg_cycle_length';

  /// Average period length in days (int), or 0 if unknown.
  static const keyAvgPeriodLength = 'widget_avg_period_length';

  /// Timestamp (milliseconds since epoch) of the last update (int).
  static const keyLastUpdated = 'widget_last_updated';

  // ── Public API ────────────────────────────────────────────────────────────

  /// Persists cycle summary data for the native widget layer.
  ///
  /// [nextPeriodDate] — predicted start date of the next period.
  /// [periodActive]   — whether a period is in progress right now.
  /// [currentCycleDay] — day-of-cycle counter (1 = today on day 1 of period).
  /// [avgCycleLength]  — average cycle length in days.
  /// [avgPeriodLength] — average period length in days, null if not enough data.
  Future<void> update({
    required DateTime nextPeriodDate,
    required bool periodActive,
    required int currentCycleDay,
    required int avgCycleLength,
    required int? avgPeriodLength,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final daysUntil = nextPeriodDate
        .toLocal()
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;

    await Future.wait([
      prefs.setString(
          keyNextPeriodDate, _toIso(nextPeriodDate)),
      prefs.setInt(keyDaysUntilPeriod, daysUntil),
      prefs.setBool(keyPeriodActive, periodActive),
      prefs.setInt(keyCurrentCycleDay, currentCycleDay),
      prefs.setInt(keyAvgCycleLength, avgCycleLength),
      prefs.setInt(keyAvgPeriodLength, avgPeriodLength ?? 0),
      prefs.setInt(
          keyLastUpdated, DateTime.now().millisecondsSinceEpoch),
    ]);
  }

  /// Reads the last persisted widget snapshot.  Returns null if no data has
  /// been written yet (e.g. first launch before any Firestore data arrives).
  Future<WidgetSnapshot?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(keyNextPeriodDate);
    if (dateStr == null) return null;

    return WidgetSnapshot(
      nextPeriodDate: DateTime.parse(dateStr),
      daysUntilPeriod: prefs.getInt(keyDaysUntilPeriod) ?? 0,
      periodActive: prefs.getBool(keyPeriodActive) ?? false,
      currentCycleDay: prefs.getInt(keyCurrentCycleDay) ?? 0,
      avgCycleLength: prefs.getInt(keyAvgCycleLength) ?? 28,
      avgPeriodLength: prefs.getInt(keyAvgPeriodLength) ?? 0,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
          prefs.getInt(keyLastUpdated) ?? 0),
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  String _toIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Immutable snapshot of the data written to SharedPreferences.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.nextPeriodDate,
    required this.daysUntilPeriod,
    required this.periodActive,
    required this.currentCycleDay,
    required this.avgCycleLength,
    required this.avgPeriodLength,
    required this.lastUpdated,
  });

  final DateTime nextPeriodDate;

  /// Positive = days until period. 0 = today. Negative = overdue.
  final int daysUntilPeriod;
  final bool periodActive;

  /// Day-of-cycle count (1-based). 0 when no active period.
  final int currentCycleDay;
  final int avgCycleLength;

  /// 0 when unknown (fewer than 2 completed cycles).
  final int avgPeriodLength;
  final DateTime lastUpdated;
}
