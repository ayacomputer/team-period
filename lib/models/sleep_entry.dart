/// A daily sleep quality rating.
///
/// Stored as a top-level `sleep` array on the couple document alongside
/// period logs and temperatures.
class SleepEntry {
  const SleepEntry({
    required this.date,
    required this.quality,
    this.hoursSlept,
    this.note,
  });

  /// ISO date string "YYYY-MM-DD"
  final String date;

  /// Sleep quality rating: 1 (poor) – 5 (excellent)
  final int quality;

  /// Optional hours slept, e.g. 7.5
  final double? hoursSlept;

  final String? note;

  SleepEntry copyWith({
    String? date,
    int? quality,
    double? hoursSlept,
    String? note,
  }) {
    return SleepEntry(
      date: date ?? this.date,
      quality: quality ?? this.quality,
      hoursSlept: hoursSlept ?? this.hoursSlept,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'quality': quality,
        if (hoursSlept != null) 'hoursSlept': hoursSlept,
        if (note != null) 'note': note,
      };

  factory SleepEntry.fromJson(Map<String, dynamic> json) {
    return SleepEntry(
      date: json['date'] as String,
      quality: (json['quality'] as num?)?.toInt() ?? 3,
      hoursSlept: (json['hoursSlept'] as num?)?.toDouble(),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => toJson();

  factory SleepEntry.fromFirestore(Map<String, dynamic> data) =>
      SleepEntry.fromJson(data);
}
