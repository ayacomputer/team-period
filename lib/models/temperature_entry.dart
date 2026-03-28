class TemperatureEntry {
  const TemperatureEntry({
    required this.id,
    required this.datetime,
    required this.celsius,
    this.note,
  });

  /// Unique id — millisecondsSinceEpoch as string.
  final String id;

  /// ISO datetime string "YYYY-MM-DDTHH:MM" (date + time, no seconds).
  final String datetime;

  /// Basal body temperature in degrees Celsius.
  final double celsius;

  /// Optional free-text note.
  final String? note;

  /// Returns just the date portion "YYYY-MM-DD".
  String get dateOnly => datetime.substring(0, 10);

  /// Returns just the time portion "HH:MM".
  String get timeOnly => datetime.length >= 16 ? datetime.substring(11, 16) : '';

  TemperatureEntry copyWith({
    String? id,
    String? datetime,
    double? celsius,
    String? note,
    bool clearNote = false,
  }) {
    return TemperatureEntry(
      id: id ?? this.id,
      datetime: datetime ?? this.datetime,
      celsius: celsius ?? this.celsius,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'datetime': datetime,
        'celsius': celsius,
        if (note != null) 'note': note,
      };

  factory TemperatureEntry.fromJson(Map<String, dynamic> json) {
    return TemperatureEntry(
      id: json['id'] as String,
      datetime: json['datetime'] as String,
      celsius: (json['celsius'] as num).toDouble(),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => toJson();

  factory TemperatureEntry.fromFirestore(Map<String, dynamic> data) =>
      TemperatureEntry.fromJson(data);
}
