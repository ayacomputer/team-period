import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/cycle_summary.dart';
import '../models/mood_entry.dart';
import '../models/period_log.dart';
import '../utils/cycle_calculations.dart';
import '../utils/kindness_reminders.dart';
import '../utils/phase_theme.dart';

/// Always-visible card showing phase-aware kindness tips for the partner.
/// Also surfaces today's logged mood/conditions if one exists.
class KindnessCard extends StatelessWidget {
  const KindnessCard({
    super.key,
    required this.summary,
    required this.activePeriod,
    required this.partnerName,
  });

  final CycleSummary summary;
  final PeriodLog? activePeriod;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    final phase = summary.currentPhase;
    final primary = PhaseTheme.primaryColor(phase);
    final light = PhaseTheme.lightColor(phase);
    final accent = PhaseTheme.accentColor(phase);

    final tip = getTipForPhase(phase, dayOfYear(DateTime.now()));
    final todayMood = _todayMoodEntry();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: light,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.heart, size: 14, color: primary),
              const SizedBox(width: 8),
              Text(
                'For the partner',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primary.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Today's tip
          Text(
            tip,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: primary,
              height: 1.4,
            ),
          ),

          // Today's logged mood — only if partner logged one
          if (todayMood != null) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  FaIcon(
                    _moodIcon(todayMood.mood),
                    size: 14,
                    color: primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _moodSummary(todayMood),
                      style: TextStyle(
                        fontSize: 13,
                        color: primary.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  MoodEntry? _todayMoodEntry() {
    if (activePeriod == null) return null;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      return activePeriod!.moods.firstWhere((m) => m.date == today);
    } catch (_) {
      return null;
    }
  }

  String _moodSummary(MoodEntry entry) {
    final name = partnerName.isNotEmpty ? partnerName : 'They';
    final parts = ['$name logged: ${entry.mood.label}'];
    if (entry.conditions.isNotEmpty) {
      parts.add(entry.conditions.join(', '));
    }
    return parts.join(' · ');
  }

  IconData _moodIcon(Mood mood) {
    switch (mood) {
      case Mood.great:
        return FontAwesomeIcons.faceGrinStars;
      case Mood.good:
        return FontAwesomeIcons.faceSmile;
      case Mood.okay:
        return FontAwesomeIcons.faceMeh;
      case Mood.low:
        return FontAwesomeIcons.faceFrown;
      case Mood.rough:
        return FontAwesomeIcons.faceSadTear;
    }
  }
}
