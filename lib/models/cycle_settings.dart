class CycleSettings {
  const CycleSettings({
    this.averageCycleLength = 28,
    this.averagePeriodLength = 5,
    this.partnerName = '',
    this.notificationsEnabled = false,
  });

  final int averageCycleLength;
  final int averagePeriodLength;

  /// Display name for the person who has the period (shown in kindness card)
  final String partnerName;
  final bool notificationsEnabled;

  CycleSettings copyWith({
    int? averageCycleLength,
    int? averagePeriodLength,
    String? partnerName,
    bool? notificationsEnabled,
  }) {
    return CycleSettings(
      averageCycleLength: averageCycleLength ?? this.averageCycleLength,
      averagePeriodLength: averagePeriodLength ?? this.averagePeriodLength,
      partnerName: partnerName ?? this.partnerName,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'averageCycleLength': averageCycleLength,
        'averagePeriodLength': averagePeriodLength,
        'partnerName': partnerName,
        'notificationsEnabled': notificationsEnabled,
      };

  factory CycleSettings.fromJson(Map<String, dynamic> json) {
    return CycleSettings(
      averageCycleLength: (json['averageCycleLength'] as num?)?.toInt() ?? 28,
      averagePeriodLength: (json['averagePeriodLength'] as num?)?.toInt() ?? 5,
      partnerName: json['partnerName'] as String? ?? '',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
    );
  }
}
