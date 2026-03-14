import '../models/cycle_summary.dart';

class PhaseReminder {
  const PhaseReminder({required this.phase, required this.tips});
  final CyclePhase phase;
  final List<String> tips;
}

const _reminders = [
  PhaseReminder(phase: CyclePhase.period, tips: [
    'Offer a hot water bottle or heating pad',
    'Ask if they want company or space today',
    'Have their favourite snack ready',
    'Skip energy-heavy plans today',
    'A gentle back rub goes a long way',
    'Make a warm cup of tea without being asked',
    'Take care of extra chores quietly',
  ]),
  PhaseReminder(phase: CyclePhase.fertile, tips: [
    'Energy is usually high — great time for a date night',
    'Be emotionally present and connected',
    'Plan something fun together this week',
    'Small romantic gestures land well right now',
  ]),
  PhaseReminder(phase: CyclePhase.ovulation, tips: [
    'They may feel confident and social today — match that energy',
    'Compliments and connection mean a lot now',
    'Great day for quality time together',
  ]),
  PhaseReminder(phase: CyclePhase.follicular, tips: [
    'Energy is returning — good time for fun activities together',
    'New ideas and conversations flow easily now',
    'Plan ahead for something exciting',
    'A light-hearted outing sounds perfect',
  ]),
  PhaseReminder(phase: CyclePhase.luteal, tips: [
    'Emotions can run higher — listen more, talk less',
    'Patience is a love language right now',
    'Small gestures mean a lot this week',
    'Check in gently — "how are you feeling?" goes far',
    'Avoid big disagreements if possible — timing matters',
  ]),
];

const _generalTips = [
  'A surprise act of kindness never needs a reason',
  'Ask how they are — and really listen',
  'Make their favourite meal tonight',
  'Send a sweet message out of the blue',
];

/// Returns a single tip for [phase], rotating daily via [dayOfYearValue].
String getTipForPhase(CyclePhase phase, int dayOfYearValue) {
  final reminder = _reminders.firstWhere(
    (r) => r.phase == phase,
    orElse: () => PhaseReminder(phase: phase, tips: _generalTips),
  );
  final tips = reminder.tips.isNotEmpty ? reminder.tips : _generalTips;
  return tips[dayOfYearValue % tips.length];
}

/// Returns all tips for a phase (used in SettingsPanel preview).
List<String> getAllTipsForPhase(CyclePhase phase) {
  return _reminders
      .firstWhere(
        (r) => r.phase == phase,
        orElse: () => PhaseReminder(phase: phase, tips: _generalTips),
      )
      .tips;
}
