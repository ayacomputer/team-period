import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/cycle_settings.dart';
import '../models/period_log.dart';
import '../models/sleep_entry.dart';
import '../utils/cycle_calculations.dart';

/// Displays a summary of all logged cycles with sleep correlation and CSV export.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.logs,
    required this.settings,
    required this.sleep,
  });

  final List<PeriodLog> logs;
  final CycleSettings settings;
  final List<SleepEntry> sleep;

  // Build a date→quality map for quick look-ups.
  Map<String, int> _sleepMap() =>
      {for (final s in sleep) s.date: s.quality};

  /// Generates a CSV string from cycle logs + sleep data.
  String _buildCsv(AppLocalizations t) {
    final sleepMap = _sleepMap();
    final sorted = [...logs]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    final header = [
      t.startDate,
      t.endDate,
      t.duration,
      t.cycleGap,
      t.sleepCol,
    ].join(',');

    final rows = <String>[];
    for (var i = 0; i < sorted.length; i++) {
      final log = sorted[i];
      final prevLog = i < sorted.length - 1 ? sorted[i + 1] : null;

      final start = fromIsoDate(log.startDate);
      final end = log.endDate != null ? fromIsoDate(log.endDate!) : null;
      final duration = end != null ? daysBetween(start, end) + 1 : null;
      final cycleGap = prevLog != null
          ? daysBetween(fromIsoDate(prevLog.startDate), start)
          : null;

      // Average sleep quality during this cycle window
      final sleepQuality = _avgSleepQuality(log, sleepMap);

      rows.add([
        log.startDate,
        log.endDate ?? '',
        duration != null ? '$duration' : '',
        cycleGap != null ? '$cycleGap' : '',
        sleepQuality != null ? sleepQuality.toStringAsFixed(1) : '',
      ].join(','));
    }

    return '$header\n${rows.join('\n')}';
  }

  double? _avgSleepQuality(PeriodLog log, Map<String, int> sleepMap) {
    final start = fromIsoDate(log.startDate);
    final end = log.endDate != null ? fromIsoDate(log.endDate!) : DateTime.now();

    final qualities = <int>[];
    for (var d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      final key = toIsoDate(d);
      if (sleepMap.containsKey(key)) qualities.add(sleepMap[key]!);
    }

    if (qualities.isEmpty) return null;
    return qualities.reduce((a, b) => a + b) / qualities.length;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final sleepMap = _sleepMap();

    // Newest first
    final sorted = [...logs]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    final avgCycle = computeAverageCycleLength(logs, settings);
    final avgPeriod = computeAveragePeriodLength(logs);
    final completed = logs.where((l) => l.endDate != null).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(t.historyTitle),
        actions: [
          if (logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: t.exportCsv,
              onPressed: () {
                final csv = _buildCsv(t);
                Clipboard.setData(ClipboardData(text: csv));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t.exportCsv),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Summary stats
          _HistorySummaryWidget(
            avgCycleLength: avgCycle,
            avgPeriodLength: avgPeriod,
            totalCycles: completed,
            t: t,
          ),
          const Divider(height: 1),

          // Cycle rows
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      t.noCyclesYet,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 15),
                    ),
                  )
                : _CycleTable(logs: sorted, sleepMap: sleepMap, t: t),
          ),
        ],
      ),
    );
  }
}

// ── Summary chips ─────────────────────────────────────────────────────────────

class _HistorySummaryWidget extends StatelessWidget {
  const _HistorySummaryWidget({
    required this.avgCycleLength,
    required this.avgPeriodLength,
    required this.totalCycles,
    required this.t,
  });

  final int avgCycleLength;
  final int? avgPeriodLength;
  final int totalCycles;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          _SummaryChip(
            label: t.avgCycle,
            value: '$avgCycleLength${t.days}',
            icon: Icons.loop,
            color: const Color(0xFFE11D48),
          ),
          const SizedBox(width: 8),
          if (avgPeriodLength != null)
            _SummaryChip(
              label: t.avgPeriod,
              value: '$avgPeriodLength${t.days}',
              icon: Icons.water_drop_outlined,
              color: const Color(0xFF7C3AED),
            ),
          if (avgPeriodLength != null) const SizedBox(width: 8),
          _SummaryChip(
            label: t.totalCycles,
            value: '$totalCycles',
            icon: Icons.refresh,
            color: const Color(0xFF0891B2),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cycle table ───────────────────────────────────────────────────────────────

class _CycleTable extends StatelessWidget {
  const _CycleTable({
    required this.logs,
    required this.sleepMap,
    required this.t,
  });

  final List<PeriodLog> logs;
  final Map<String, int> sleepMap;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: logs.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (_, i) {
        final log = logs[i];
        final prevLog = i < logs.length - 1 ? logs[i + 1] : null;
        return _CycleRowWidget(
            log: log, prevLog: prevLog, sleepMap: sleepMap, t: t);
      },
    );
  }
}

class _CycleRowWidget extends StatelessWidget {
  const _CycleRowWidget({
    required this.log,
    required this.prevLog,
    required this.sleepMap,
    required this.t,
  });

  final PeriodLog log;
  final PeriodLog? prevLog;
  final Map<String, int> sleepMap;
  final AppLocalizations t;

  /// Average sleep quality over the cycle's duration, or null if no data.
  double? _avgSleep() {
    final start = fromIsoDate(log.startDate);
    final end = log.endDate != null ? fromIsoDate(log.endDate!) : DateTime.now();

    final qualities = <int>[];
    for (var d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      final q = sleepMap[toIsoDate(d)];
      if (q != null) qualities.add(q);
    }
    if (qualities.isEmpty) return null;
    return qualities.reduce((a, b) => a + b) / qualities.length;
  }

  @override
  Widget build(BuildContext context) {
    final start = fromIsoDate(log.startDate);
    final end = log.endDate != null ? fromIsoDate(log.endDate!) : null;
    final duration = end != null ? daysBetween(start, end) + 1 : null;
    final cycleGap = prevLog != null
        ? daysBetween(fromIsoDate(prevLog!.startDate), start)
        : null;

    final month = t.monthsShort[start.month - 1];
    final avgSleep = _avgSleep();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Month badge
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  month,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFE11D48),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${start.year}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFE11D48),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Date details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _DateChip(
                      label: t.startDate,
                      date: _formatDate(start, t),
                    ),
                    const SizedBox(width: 8),
                    _DateChip(
                      label: t.endDate,
                      date: end != null ? _formatDate(end, t) : t.ongoing,
                      dimmed: end == null,
                    ),
                  ],
                ),
                if (avgSleep != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.bedtime_outlined,
                          size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        '${t.sleepCol}: ${_sleepStars(avgSleep)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (duration != null)
                _Stat(
                  value: '$duration${t.days}',
                  label: t.duration,
                  color: const Color(0xFFE11D48),
                )
              else
                _Stat(
                  value: t.ongoing,
                  label: t.duration,
                  color: Colors.grey,
                ),
              const SizedBox(height: 4),
              _Stat(
                value: cycleGap != null
                    ? '$cycleGap${t.days}'
                    : t.noCycleGap,
                label: t.cycleGap,
                color: const Color(0xFF0891B2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d, AppLocalizations t) {
    final m = t.monthsShort[d.month - 1];
    return '$m ${d.day}';
  }

  /// Converts a 1–5 float average into a compact star string, e.g. "★★★☆☆".
  String _sleepStars(double avg) {
    final rounded = avg.round().clamp(1, 5);
    return '${'★' * rounded}${'☆' * (5 - rounded)}';
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip(
      {required this.label, required this.date, this.dimmed = false});
  final String label;
  final String date;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        Text(
          date,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: dimmed ? Colors.grey.shade400 : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
