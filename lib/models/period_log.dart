import 'mood_entry.dart';

class PeriodLog {
  const PeriodLog({
    required this.id,
    required this.startDate,
    this.endDate,
    this.moods = const [],
  });

  final String id;

  /// ISO date string "YYYY-MM-DD"
  final String startDate;

  /// ISO date string "YYYY-MM-DD" — null if period is still active
  final String? endDate;

  final List<MoodEntry> moods;

  bool get isActive => endDate == null;

  PeriodLog copyWith({
    String? id,
    String? startDate,
    String? endDate,
    bool clearEndDate = false,
    List<MoodEntry>? moods,
  }) {
    return PeriodLog(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      moods: moods ?? this.moods,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        'moods': moods.map((m) => m.toJson()).toList(),
      };

  factory PeriodLog.fromJson(Map<String, dynamic> json) {
    return PeriodLog(
      id: json['id'] as String,
      startDate: json['startDate'] as String,
      endDate: json['endDate'] as String?,
      moods: (json['moods'] as List? ?? [])
          .map((m) => MoodEntry.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() => toJson();

  factory PeriodLog.fromFirestore(Map<String, dynamic> data) =>
      PeriodLog.fromJson(data);
}
