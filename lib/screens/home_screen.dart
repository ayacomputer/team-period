import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../l10n/app_localizations.dart';
import '../models/cycle_settings.dart';
import '../models/flow_entry.dart';
import '../models/mood_entry.dart';
import '../models/period_log.dart';
import '../models/sleep_entry.dart';
import '../models/temperature_entry.dart';
import '../utils/cycle_calculations.dart';
import '../widgets/cycle_calendar_card.dart';
import '../widgets/cycle_history_list.dart';
import '../widgets/empty_state.dart';
import '../widgets/kindness_card.dart';
import '../widgets/period_logger_card.dart';
import '../widgets/settings_panel.dart';

/// Home tab — stateless. All data is owned by [MainShell].
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.logs,
    required this.settings,
    required this.temperatures,
    required this.sleep,
    required this.waterIntake,
    required this.coupleId,
    required this.activePeriod,
    required this.onPeriodStart,
    required this.onPeriodEnd,
    required this.onMoodSaved,
    required this.onFlowSaved,
    required this.onDeleteLog,
    required this.onSaveSettings,
    required this.onSaveSleep,
    required this.onWaterIntakeChanged,
  });

  final List<PeriodLog> logs;
  final CycleSettings settings;
  final List<TemperatureEntry> temperatures;
  final List<SleepEntry> sleep;
  final Map<String, int> waterIntake;
  final String coupleId;
  final PeriodLog? activePeriod;
  final VoidCallback onPeriodStart;
  final VoidCallback onPeriodEnd;
  final void Function(MoodEntry) onMoodSaved;
  final void Function(FlowEntry) onFlowSaved;
  final void Function(String) onDeleteLog;
  final void Function(CycleSettings) onSaveSettings;
  final void Function(SleepEntry) onSaveSleep;
  final void Function(String date, int ml) onWaterIntakeChanged;

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SettingsPanel(
        settings: settings,
        coupleId: coupleId,
        onSave: onSaveSettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final summary = computeCycleSummary(logs, settings);
    final avgPeriodLength = computeAveragePeriodLength(logs);
    final insights = computeHealthInsights(logs, settings, temperatures);
    final confidence = _predictionConfidence(logs);
    final todayIso = toIsoDate(DateTime.now());
    final todayWaterMl = waterIntake[todayIso] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: const Color(0xFFF9FAFB),
              floating: true,
              pinned: false,
              elevation: 0,
              title: Row(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.heartPulse,
                    size: 18,
                    color: Color(0xFFE11D48),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t.appTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.gear, size: 18),
                  onPressed: () => _openSettings(context),
                  tooltip: t.settingsTitle,
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Hero calendar card
                  CycleCalendarCard(summary: summary),
                  const SizedBox(height: 12),

                  // Stat chips + prediction confidence
                  _StatChipRow(
                    avgCycleLength: summary.averageCycleLength,
                    avgPeriodLength: avgPeriodLength,
                    confidence: confidence,
                    t: t,
                  ),
                  const SizedBox(height: 12),

                  // Health insights card
                  if (insights.isNotEmpty)
                    _HealthInsightsCard(insights: insights, t: t),
                  if (insights.isNotEmpty) const SizedBox(height: 16),

                  // Kindness card for partner
                  KindnessCard(
                    summary: summary,
                    activePeriod: activePeriod,
                    partnerName: settings.partnerName,
                  ),
                  const SizedBox(height: 16),

                  // Period logger (start/end + mood + flow)
                  PeriodLoggerCard(
                    activePeriod: activePeriod,
                    onPeriodStart: onPeriodStart,
                    onPeriodEnd: onPeriodEnd,
                    onMoodSaved: onMoodSaved,
                    onFlowSaved: onFlowSaved,
                  ),
                  const SizedBox(height: 16),

                  // Water intake tracker
                  _WaterTrackerCard(
                    currentMl: todayWaterMl,
                    goalMl: settings.dailyWaterGoalMl,
                    isOnPeriod: activePeriod != null,
                    onChanged: (ml) => onWaterIntakeChanged(todayIso, ml),
                    t: t,
                  ),
                  const SizedBox(height: 16),

                  // Sleep quality logger
                  _SleepLogCard(
                    todayEntry: sleep.where((s) => s.date == todayIso).firstOrNull,
                    onSave: onSaveSleep,
                    t: t,
                  ),
                  const SizedBox(height: 24),

                  // History list
                  if (logs.isEmpty)
                    EmptyState(
                      icon: Icons.calendar_month_outlined,
                      title: t.noCyclesYet,
                      subtitle: t.noCyclesSubtitle,
                    )
                  else
                    CycleHistoryList(
                      logs: logs,
                      onDelete: onDeleteLog,
                    ),

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Prediction confidence ─────────────────────────────────────────────────────

enum _Confidence { low, medium, high }

_Confidence _predictionConfidence(List<PeriodLog> logs) {
  final completed = logs.where((l) => l.endDate != null).length;
  if (completed >= 5) return _Confidence.high;
  if (completed >= 2) return _Confidence.medium;
  return _Confidence.low;
}

// ── Stat chips ────────────────────────────────────────────────────────────────

class _StatChipRow extends StatelessWidget {
  const _StatChipRow({
    required this.avgCycleLength,
    required this.avgPeriodLength,
    required this.confidence,
    required this.t,
  });

  final int avgCycleLength;
  final int? avgPeriodLength;
  final _Confidence confidence;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(
          label: '${t.avgCycle}: $avgCycleLength${t.days}',
          icon: Icons.loop,
          color: const Color(0xFFE11D48),
        ),
        if (avgPeriodLength != null)
          _StatChip(
            label: '${t.avgPeriod}: $avgPeriodLength${t.days}',
            icon: Icons.water_drop_outlined,
            color: const Color(0xFF7C3AED),
          ),
        _ConfidenceChip(confidence: confidence, t: t),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.confidence, required this.t});

  final _Confidence confidence;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (confidence) {
      _Confidence.high => (
          const Color(0xFF16A34A),
          t.confidenceHigh,
          Icons.signal_cellular_alt,
        ),
      _Confidence.medium => (
          const Color(0xFFD97706),
          t.confidenceMedium,
          Icons.signal_cellular_alt_2_bar,
        ),
      _Confidence.low => (
          const Color(0xFF6B7280),
          t.confidenceLow,
          Icons.signal_cellular_alt_1_bar,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '${t.prediction}: $label',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Health insights card ──────────────────────────────────────────────────────

class _HealthInsightsCard extends StatelessWidget {
  const _HealthInsightsCard({
    required this.insights,
    required this.t,
  });

  final List<HealthInsight> insights;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    // Show up to 3 items inline; offer "see all" to expand the rest.
    final preview = insights.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.health_and_safety_outlined,
                    size: 18, color: Color(0xFFE11D48)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.healthInsights,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                if (insights.length > 3)
                  TextButton(
                    onPressed: () => _showAll(context),
                    child: Text(t.seeAll,
                        style: const TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...preview.map((ins) => _InsightRow(insight: ins)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showAll(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              t.healthInsights,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 12),
            ...insights.map((ins) => _InsightRow(insight: ins)),
          ],
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});
  final HealthInsight insight;

  @override
  Widget build(BuildContext context) {
    final isWarning = insight.severity == InsightSeverity.warning;
    final color =
        isWarning ? const Color(0xFFD97706) : const Color(0xFF0891B2);
    final bgColor =
        isWarning ? const Color(0xFFFFFBEB) : const Color(0xFFECFEFF);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              insight.message,
              style: TextStyle(
                fontSize: 13,
                color: color.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Water tracker card ────────────────────────────────────────────────────────

class _WaterTrackerCard extends StatelessWidget {
  const _WaterTrackerCard({
    required this.currentMl,
    required this.goalMl,
    required this.isOnPeriod,
    required this.onChanged,
    required this.t,
  });

  final int currentMl;
  final int goalMl;
  final bool isOnPeriod;
  final void Function(int ml) onChanged;
  final AppLocalizations t;

  static const _stepMl = 250;

  @override
  Widget build(BuildContext context) {
    final progress = (currentMl / goalMl).clamp(0.0, 1.0);
    const water = Color(0xFF0EA5E9);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, size: 18, color: water),
              const SizedBox(width: 8),
              Text(
                t.waterTracker,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const Spacer(),
              Text(
                '$currentMl / $goalMl ml',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          if (isOnPeriod) ...[
            const SizedBox(height: 4),
            Text(
              t.waterPeriodReminder,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF0EA5E9)),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(water),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _WaterButton(
                icon: Icons.remove,
                onTap: currentMl >= _stepMl
                    ? () => onChanged(currentMl - _stepMl)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentMl >= goalMl ? t.waterGoalMet : t.addWater,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: currentMl >= goalMl
                        ? const Color(0xFF16A34A)
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _WaterButton(
                icon: Icons.add,
                onTap: () => onChanged(currentMl + _stepMl),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaterButton extends StatelessWidget {
  const _WaterButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null
              ? const Color(0xFF0EA5E9).withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap != null
              ? const Color(0xFF0EA5E9)
              : Colors.grey.shade400,
        ),
      ),
    );
  }
}

// ── Sleep log card ────────────────────────────────────────────────────────────

class _SleepLogCard extends StatefulWidget {
  const _SleepLogCard({
    required this.todayEntry,
    required this.onSave,
    required this.t,
  });

  final SleepEntry? todayEntry;
  final void Function(SleepEntry) onSave;
  final AppLocalizations t;

  @override
  State<_SleepLogCard> createState() => _SleepLogCardState();
}

class _SleepLogCardState extends State<_SleepLogCard> {
  int _selectedQuality = 0;

  @override
  void initState() {
    super.initState();
    _selectedQuality = widget.todayEntry?.quality ?? 0;
  }

  @override
  void didUpdateWidget(_SleepLogCard old) {
    super.didUpdateWidget(old);
    if (widget.todayEntry != old.todayEntry) {
      _selectedQuality = widget.todayEntry?.quality ?? 0;
    }
  }

  void _selectQuality(int q) {
    setState(() => _selectedQuality = q);
    final today = toIsoDate(DateTime.now());
    widget.onSave(SleepEntry(date: today, quality: q));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bedtime_outlined,
                  size: 18, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                widget.t.sleepQuality,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const Spacer(),
              if (_selectedQuality > 0)
                Text(
                  _qualityLabel(_selectedQuality, widget.t),
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6366F1)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final q = i + 1;
              final selected = _selectedQuality == q;
              return GestureDetector(
                onTap: () => _selectQuality(q),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF6366F1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _starEmoji(q),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  static String _starEmoji(int q) {
    const emojis = ['😴', '😪', '🙂', '😊', '🌟'];
    return emojis[q - 1];
  }

  static String _qualityLabel(int q, AppLocalizations t) {
    return switch (q) {
      1 => t.sleepPoor,
      2 => t.sleepFair,
      3 => t.sleepOkay,
      4 => t.sleepGood,
      5 => t.sleepExcellent,
      _ => '',
    };
  }
}
