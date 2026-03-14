import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/mood_entry.dart';
import '../models/period_log.dart';
import '../utils/phase_theme.dart';
import '../models/cycle_summary.dart';

/// Mood selector + condition chips shown while a period is active.
class PeriodLoggerCard extends StatefulWidget {
  const PeriodLoggerCard({
    super.key,
    required this.activePeriod,
    required this.onPeriodStart,
    required this.onPeriodEnd,
    required this.onMoodSaved,
  });

  final PeriodLog? activePeriod;
  final VoidCallback onPeriodStart;
  final VoidCallback onPeriodEnd;
  final void Function(MoodEntry entry) onMoodSaved;

  @override
  State<PeriodLoggerCard> createState() => _PeriodLoggerCardState();
}

class _PeriodLoggerCardState extends State<PeriodLoggerCard> {
  Mood? _selectedMood;
  final Set<String> _selectedConditions = {};
  final _noteController = TextEditingController();
  bool _showMoodLogger = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _saveMood() {
    if (_selectedMood == null) return;
    final entry = MoodEntry(
      date: _todayIso(),
      mood: _selectedMood!,
      conditions: _selectedConditions.toList(),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    widget.onMoodSaved(entry);
    setState(() {
      _showMoodLogger = false;
      _selectedMood = null;
      _selectedConditions.clear();
      _noteController.clear();
    });
  }

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.activePeriod != null;
    final roseLight = PhaseTheme.lightColor(CyclePhase.period);
    final rose = PhaseTheme.primaryColor(CyclePhase.period);

    return Column(
      children: [
        // Action buttons row
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Period Started',
                icon: FontAwesomeIcons.droplet,
                color: rose,
                light: roseLight,
                enabled: !isActive,
                onTap: widget.onPeriodStart,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                label: 'Period Ended',
                icon: FontAwesomeIcons.circleCheck,
                color: const Color(0xFF16A34A),
                light: const Color(0xFFF0FDF4),
                enabled: isActive,
                onTap: () {
                  widget.onPeriodEnd();
                  setState(() => _showMoodLogger = false);
                },
              ),
            ),
          ],
        ),

        // Log today's mood button — only while period is active
        if (isActive) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const FaIcon(FontAwesomeIcons.faceSmile, size: 16),
            label: Text(
              _todayMoodEntry() != null
                  ? 'Update today\'s mood'
                  : 'Log today\'s mood',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: rose,
              side: BorderSide(color: rose.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: () => setState(() => _showMoodLogger = !_showMoodLogger),
          ),
        ],

        // Mood logger panel
        if (_showMoodLogger) ...[
          const SizedBox(height: 16),
          _MoodLoggerPanel(
            initialMood: _selectedMood,
            selectedConditions: _selectedConditions,
            noteController: _noteController,
            onMoodSelected: (m) => setState(() => _selectedMood = m),
            onConditionToggled: (c) => setState(() {
              if (_selectedConditions.contains(c)) {
                _selectedConditions.remove(c);
              } else {
                _selectedConditions.add(c);
              }
            }),
            onSave: _selectedMood != null ? _saveMood : null,
          ),
        ],
      ],
    );
  }

  MoodEntry? _todayMoodEntry() {
    if (widget.activePeriod == null) return null;
    final today = _todayIso();
    try {
      return widget.activePeriod!.moods.firstWhere((m) => m.date == today);
    } catch (_) {
      return null;
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.light,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final Color light;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: enabled ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            FaIcon(
              icon,
              size: 28,
              color: enabled ? Colors.white : Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.white : Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodLoggerPanel extends StatelessWidget {
  const _MoodLoggerPanel({
    required this.initialMood,
    required this.selectedConditions,
    required this.noteController,
    required this.onMoodSelected,
    required this.onConditionToggled,
    required this.onSave,
  });

  final Mood? initialMood;
  final Set<String> selectedConditions;
  final TextEditingController noteController;
  final void Function(Mood) onMoodSelected;
  final void Function(String) onConditionToggled;
  final VoidCallback? onSave;

  static const _moods = [
    (Mood.great, FontAwesomeIcons.faceGrinStars, 'Great'),
    (Mood.good, FontAwesomeIcons.faceSmile, 'Good'),
    (Mood.okay, FontAwesomeIcons.faceMeh, 'Okay'),
    (Mood.low, FontAwesomeIcons.faceFrown, 'Low'),
    (Mood.rough, FontAwesomeIcons.faceSadTear, 'Rough'),
  ];

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
          const Text(
            'How are you feeling?',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 12),

          // Mood row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _moods.map((m) {
              final (mood, icon, label) = m;
              final selected = initialMood == mood;
              return GestureDetector(
                onTap: () => onMoodSelected(mood),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected
                            ? PhaseTheme.primaryColor(CyclePhase.period)
                                .withValues(alpha: 0.15)
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(
                                color:
                                    PhaseTheme.primaryColor(CyclePhase.period),
                                width: 2,
                              )
                            : null,
                      ),
                      child: FaIcon(
                        icon,
                        size: 22,
                        color: selected
                            ? PhaseTheme.primaryColor(CyclePhase.period)
                            : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? PhaseTheme.primaryColor(CyclePhase.period)
                            : Colors.grey.shade500,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          const Text(
            'Symptoms',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),

          // Condition chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kConditionOptions.map((c) {
              final selected = selectedConditions.contains(c);
              return FilterChip(
                label: Text(c),
                selected: selected,
                onSelected: (_) => onConditionToggled(c),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: selected
                      ? PhaseTheme.primaryColor(CyclePhase.period)
                      : Colors.grey.shade700,
                ),
                selectedColor:
                    PhaseTheme.accentColor(CyclePhase.period).withValues(alpha: 0.4),
                checkmarkColor: PhaseTheme.primaryColor(CyclePhase.period),
                side: BorderSide(
                  color: selected
                      ? PhaseTheme.primaryColor(CyclePhase.period)
                      : Colors.grey.shade300,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Optional note
          TextField(
            controller: noteController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add a note (optional)',
              hintStyle:
                  TextStyle(color: Colors.grey.shade400, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const FaIcon(FontAwesomeIcons.floppyDisk, size: 14),
              label: const Text('Save mood'),
              onPressed: onSave,
              style: FilledButton.styleFrom(
                backgroundColor:
                    PhaseTheme.primaryColor(CyclePhase.period),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
