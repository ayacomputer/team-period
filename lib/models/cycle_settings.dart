class CycleSettings {
  const CycleSettings({
    this.averageCycleLength = 28,
    this.averagePeriodLength = 5,
    this.partnerName = '',
    this.notificationsEnabled = false,
    this.languageCode = 'en',
    this.dailyWaterGoalMl = 2000,
    this.pillReminderEnabled = false,
    this.pillReminderHour = 8,
    this.pillReminderMinute = 0,
  });

  final int averageCycleLength;
  final int averagePeriodLength;

  /// Display name for the person who has the period (shown in kindness card).
  final String partnerName;
  final bool notificationsEnabled;

  /// BCP-47 language code — 'en' or 'ja'.
  final String languageCode;

  /// Daily water intake goal in millilitres. Default 2000 ml (2 L).
  final int dailyWaterGoalMl;

  /// Whether the daily pill/medication reminder is enabled.
  final bool pillReminderEnabled;

  /// Hour of day (0–23) for the pill reminder notification.
  final int pillReminderHour;

  /// Minute (0–59) for the pill reminder notification.
  final int pillReminderMinute;

  CycleSettings copyWith({
    int? averageCycleLength,
    int? averagePeriodLength,
    String? partnerName,
    bool? notificationsEnabled,
    String? languageCode,
    int? dailyWaterGoalMl,
    bool? pillReminderEnabled,
    int? pillReminderHour,
    int? pillReminderMinute,
  }) {
    return CycleSettings(
      averageCycleLength: averageCycleLength ?? this.averageCycleLength,
      averagePeriodLength: averagePeriodLength ?? this.averagePeriodLength,
      partnerName: partnerName ?? this.partnerName,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      languageCode: languageCode ?? this.languageCode,
      dailyWaterGoalMl: dailyWaterGoalMl ?? this.dailyWaterGoalMl,
      pillReminderEnabled: pillReminderEnabled ?? this.pillReminderEnabled,
      pillReminderHour: pillReminderHour ?? this.pillReminderHour,
      pillReminderMinute: pillReminderMinute ?? this.pillReminderMinute,
    );
  }

  Map<String, dynamic> toJson() => {
        'averageCycleLength': averageCycleLength,
        'averagePeriodLength': averagePeriodLength,
        'partnerName': partnerName,
        'notificationsEnabled': notificationsEnabled,
        'languageCode': languageCode,
        'dailyWaterGoalMl': dailyWaterGoalMl,
        'pillReminderEnabled': pillReminderEnabled,
        'pillReminderHour': pillReminderHour,
        'pillReminderMinute': pillReminderMinute,
      };

  factory CycleSettings.fromJson(Map<String, dynamic> json) {
    return CycleSettings(
      averageCycleLength: (json['averageCycleLength'] as num?)?.toInt() ?? 28,
      averagePeriodLength:
          (json['averagePeriodLength'] as num?)?.toInt() ?? 5,
      partnerName: json['partnerName'] as String? ?? '',
      notificationsEnabled:
          json['notificationsEnabled'] as bool? ?? false,
      languageCode: json['languageCode'] as String? ?? 'en',
      dailyWaterGoalMl:
          (json['dailyWaterGoalMl'] as num?)?.toInt() ?? 2000,
      pillReminderEnabled:
          json['pillReminderEnabled'] as bool? ?? false,
      pillReminderHour:
          (json['pillReminderHour'] as num?)?.toInt() ?? 8,
      pillReminderMinute:
          (json['pillReminderMinute'] as num?)?.toInt() ?? 0,
    );
  }
}
