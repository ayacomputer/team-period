enum CyclePhase { period, fertile, ovulation, luteal, follicular }

extension CyclePhaseLabel on CyclePhase {
  String get label {
    switch (this) {
      case CyclePhase.period:
        return 'Period';
      case CyclePhase.fertile:
        return 'Fertile Window';
      case CyclePhase.ovulation:
        return 'Ovulation';
      case CyclePhase.luteal:
        return 'Luteal Phase';
      case CyclePhase.follicular:
        return 'Follicular Phase';
    }
  }
}

class CycleSummary {
  const CycleSummary({
    required this.nextPeriodDate,
    required this.ovulationDate,
    required this.fertileWindowStart,
    required this.fertileWindowEnd,
    required this.currentPhase,
    required this.daysUntilNextPeriod,
    required this.averageCycleLength,
    required this.dayInCycle,
  });

  final DateTime nextPeriodDate;
  final DateTime ovulationDate;
  final DateTime fertileWindowStart;
  final DateTime fertileWindowEnd;
  final CyclePhase currentPhase;
  final int daysUntilNextPeriod;
  final int averageCycleLength;

  /// Which day of the current cycle we are on (1-based)
  final int dayInCycle;

  double get progressPercent =>
      (dayInCycle / averageCycleLength).clamp(0.0, 1.0);
}
