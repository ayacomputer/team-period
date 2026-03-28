import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../l10n/app_localizations.dart';
import '../models/flow_entry.dart';
import '../models/mood_entry.dart';
import '../models/period_log.dart';
import '../utils/cycle_calculations.dart';
import '../utils/phase_theme.dart';
import '../models/cycle_summary.dart';

/// Period start/end buttons, mood logger, and flow intensity logger.
///
/// Flow and mood logging panels are only visible while a period is active.
class PeriodLoggerCard extends StatefulWidget {
  const PeriodLoggerCard({
    super.key,
    required this.activePeriod,
    required this.onPeriodStart,
    required this.onPeriodEnd,
    required this.onMoodSaved,
    required this.onFlowSaved,
  });

  final PeriodLog? activePeriod;
  final VoidCallback onPeriodStart;
  final VoidCallback onPeriodEnd;
  final void Function(MoodEntry entry) onMoodSaved;
  final void Function(FlowEntry entry) onFlowSaved;

  @override
  State<PeriodLoggerCard> createState() => _PeriodLoggerCardState();
}

class _PeriodLoggerCardState extends State<PeriodLoggerCard> {
  Mood? _selectedMood;
  final Set<String> _selectedConditions = {};
  final _noteController = TextEditingController();
  bool _showMoodLogger = false;
  bool _showFlowLogger = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _todayIso() => toIsoDate(DateTime.now());

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

  void _saveFlow(FlowIntensity intensity) {
    widget.onFlowSaved(FlowEntry(date: _todayIso(), intensity: intensity));
    setState(() => _showFlowLogger = false);
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

  FlowEntry? _todayFlowEntry() {
    if (widget.activePeriod == null) return null;
    final today = _todayIso();
    try {
      return widget.activePeriod!.flows.firstWhere((f) => f.date == today);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isActive = widget.activePeriod != null;
    final rose = PhaseTheme.primaryColor(CyclePhase.period);
    final roseLight = PhaseTheme.lightColor(CyclePhase.period);

    return Column(
      children: [
        // Start / End buttons
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: t.periodStarted,
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
                label: t.periodEnded,
                icon: FontAwesomeIcons.circleCheck,
                color: const Color(0xFF16A34A),
                light: const Color(0xFFF0FDF4),
                enabled: isActive,
                onTap: () {
                  widget.onPeriodEnd();
                  setState(() {
                    _showMoodLogger = false;
                    _showFlowLogger = false;
                  });
                },
              ),
            ),
          ],
        ),

        // Mood + flow logger buttons — only while active
        if (isActive) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const FaIcon(FontAwesomeIcons.faceSmile, size: 15),
                  label: Text(
                    _todayMoodEntry() != null ? t.logMood : t.logMood,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: rose,
                    side: BorderSide(color: rose.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => setState(() {
                    _showMoodLogger = !_showMoodLogger;
                    _showFlowLogger = false;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const FaIcon(FontAwesomeIcons.droplet, size: 15),
                  label: Text(
                    t.logFlow,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7C3AED),
                    side: const BorderSide(
                        color: Color(0xFF7C3AED), width: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => setState(() {
                    _showFlowLogger = !_showFlowLogger;
                    _showMoodLogger = false;
                  }),
                ),
              ),
            ],
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
            t: t,
          ),
        ],

        // Flow logger panel
        if (_showFlowLogger) ...[
          const SizedBox(height: 16),
          _FlowLoggerPanel(
            currentEntry: _todayFlowEntry(),
            onSave: _saveFlow,
            t: t,
          ),
        ],
      ],
    );
  }
}

// ── Flow logger panel ─────────────────────────────────────────────────────────

class _FlowLoggerPanel extends StatelessWidget {
  const _FlowLoggerPanel({
    required this.currentEntry,
    required this.onSave,
    required this.t,
  });

  final FlowEntry? currentEntry;
  final void Function(FlowIntensity) onSave;
  final AppLocalizations t;

  static const _options = [
    (FlowIntensity.spotting, '💧'),
    (FlowIntensity.light, '🩸'),
    (FlowIntensity.medium, '🩸🩸'),
    (FlowIntensity.heavy, '🩸🩸🩸'),
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
          Text(
            t.logFlow,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Row(
            children: _options.map((opt) {
              final (intensity, emoji) = opt;
              final label = _intensityLabel(intensity, t);
              final selected = currentEntry?.intensity == intensity;
              const violet = Color(0xFF7C3AED);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => onSave(intensity),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? violet.withValues(alpha: 0.12)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? violet : Colors.grey.shade200,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(emoji,
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: selected ? violet : Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _intensityLabel(FlowIntensity intensity, AppLocalizations t) {
    return switch (intensity) {
      FlowIntensity.spotting => t.flowSpotting,
      FlowIntensity.light => t.flowLight,
      FlowIntensity.medium => t.flowMedium,
      FlowIntensity.heavy => t.flowHeavy,
    };
  }
}

// ── Action buttons ────────────────────────────────────────────────────────────

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

// ── Mood logger panel ─────────────────────────────────────────────────────────

class _MoodLoggerPanel extends StatelessWidget {
  const _MoodLoggerPanel({
    required this.initialMood,
    required this.selectedConditions,
    required this.noteController,
    required this.onMoodSelected,
    required this.onConditionToggled,
    required this.onSave,
    required this.t,
  });

  final Mood? initialMood;
  final Set<String> selectedConditions;
  final TextEditingController noteController;
  final void Function(Mood) onMoodSelected;
  final void Function(String) onConditionToggled;
  final VoidCallback? onSave;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final moods = [
      (Mood.great, FontAwesomeIcons.faceGrinStars, t.moodGreat),
      (Mood.good, FontAwesomeIcons.faceSmile, t.moodGood),
      (Mood.okay, FontAwesomeIcons.faceMeh, t.moodOkay),
      (Mood.low, FontAwesomeIcons.faceFrown, t.moodLow),
      (Mood.rough, FontAwesomeIcons.faceSadTear, t.moodRough),
    ];

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
          Text(
            t.logMood,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 12),

          // Mood row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: moods.map((m) {
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
                selectedColor: PhaseTheme.accentColor(CyclePhase.period)
                    .withValues(alpha: 0.4),
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
              label: Text(t.saveButton),
              onPressed: onSave,
              style: FilledButton.styleFrom(
                backgroundColor: PhaseTheme.primaryColor(CyclePhase.period),
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
