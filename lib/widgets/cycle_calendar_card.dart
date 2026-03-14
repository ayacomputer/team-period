import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../models/cycle_summary.dart';
import '../utils/phase_theme.dart';

/// Hero card showing current phase, progress bar, and key upcoming dates.
class CycleCalendarCard extends StatelessWidget {
  const CycleCalendarCard({super.key, required this.summary});

  final CycleSummary summary;

  @override
  Widget build(BuildContext context) {
    final phase = summary.currentPhase;
    final primary = PhaseTheme.primaryColor(phase);
    final light = PhaseTheme.lightColor(phase);
    final accent = PhaseTheme.accentColor(phase);

    return Container(
      decoration: BoxDecoration(
        color: light,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent, width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase chip + day counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PhaseBadge(phase: phase, primary: primary),
              Text(
                'Day ${summary.dayInCycle}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Days until next period
          _HeadlineCountdown(
            days: summary.daysUntilNextPeriod,
            primary: primary,
          ),
          const SizedBox(height: 16),

          // Progress bar
          _CycleProgressBar(
            progress: summary.progressPercent,
            primary: primary,
            accent: accent,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Day 1',
                style: TextStyle(fontSize: 11, color: primary.withValues(alpha: 0.7)),
              ),
              Text(
                'Day ${summary.averageCycleLength}',
                style: TextStyle(fontSize: 11, color: primary.withValues(alpha: 0.7)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Date pills row
          Row(
            children: [
              _DatePill(
                icon: FontAwesomeIcons.droplet,
                label: 'Next period',
                date: summary.nextPeriodDate,
                color: PhaseTheme.primaryColor(CyclePhase.period),
                light: PhaseTheme.lightColor(CyclePhase.period),
              ),
              const SizedBox(width: 8),
              _DatePill(
                icon: FontAwesomeIcons.seedling,
                label: 'Fertile start',
                date: summary.fertileWindowStart,
                color: PhaseTheme.primaryColor(CyclePhase.fertile),
                light: PhaseTheme.lightColor(CyclePhase.fertile),
              ),
              const SizedBox(width: 8),
              _DatePill(
                icon: FontAwesomeIcons.egg,
                label: 'Ovulation',
                date: summary.ovulationDate,
                color: PhaseTheme.primaryColor(CyclePhase.ovulation),
                light: PhaseTheme.lightColor(CyclePhase.ovulation),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({required this.phase, required this.primary});
  final CyclePhase phase;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(_phaseIcon(phase), size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            phase.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _phaseIcon(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.period:
        return FontAwesomeIcons.droplet;
      case CyclePhase.fertile:
        return FontAwesomeIcons.seedling;
      case CyclePhase.ovulation:
        return FontAwesomeIcons.egg;
      case CyclePhase.follicular:
        return FontAwesomeIcons.sun;
      case CyclePhase.luteal:
        return FontAwesomeIcons.moon;
    }
  }
}

class _HeadlineCountdown extends StatelessWidget {
  const _HeadlineCountdown({required this.days, required this.primary});
  final int days;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final label = days == 0
        ? 'Period due today'
        : days < 0
            ? 'Period ${-days}d overdue'
            : 'Next period in $days day${days == 1 ? '' : 's'}';

    return Text(
      label,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.2,
      ),
    );
  }
}

class _CycleProgressBar extends StatelessWidget {
  const _CycleProgressBar({
    required this.progress,
    required this.primary,
    required this.accent,
  });
  final double progress;
  final Color primary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 10,
        backgroundColor: accent.withValues(alpha: 0.3),
        valueColor: AlwaysStoppedAnimation<Color>(primary),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({
    required this.icon,
    required this.label,
    required this.date,
    required this.color,
    required this.light,
  });
  final IconData icon;
  final String label;
  final DateTime date;
  final Color color;
  final Color light;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: light,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            FaIcon(icon, size: 14, color: color),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d').format(date),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
