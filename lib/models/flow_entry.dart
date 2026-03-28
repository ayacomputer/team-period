/// Flow intensity levels for daily period logging.
enum FlowIntensity { spotting, light, medium, heavy }

extension FlowIntensityLabel on FlowIntensity {
  String get label {
    switch (this) {
      case FlowIntensity.spotting:
        return 'Spotting';
      case FlowIntensity.light:
        return 'Light';
      case FlowIntensity.medium:
        return 'Medium';
      case FlowIntensity.heavy:
        return 'Heavy';
    }
  }

  String get emoji {
    switch (this) {
      case FlowIntensity.spotting:
        return '🩸';
      case FlowIntensity.light:
        return '🩸🩸';
      case FlowIntensity.medium:
        return '🩸🩸🩸';
      case FlowIntensity.heavy:
        return '🩸🩸🩸🩸';
    }
  }

  /// 0 = spotting, 1 = light, 2 = medium, 3 = heavy
  int get level => FlowIntensity.values.indexOf(this);
}

/// A single day's flow intensity entry within a [PeriodLog].
class FlowEntry {
  const FlowEntry({
    required this.date,
    required this.intensity,
  });

  /// ISO date string "YYYY-MM-DD"
  final String date;
  final FlowIntensity intensity;

  FlowEntry copyWith({String? date, FlowIntensity? intensity}) {
    return FlowEntry(
      date: date ?? this.date,
      intensity: intensity ?? this.intensity,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'intensity': intensity.name,
      };

  factory FlowEntry.fromJson(Map<String, dynamic> json) {
    return FlowEntry(
      date: json['date'] as String,
      intensity: FlowIntensity.values.firstWhere(
        (f) => f.name == json['intensity'],
        orElse: () => FlowIntensity.medium,
      ),
    );
  }

  Map<String, dynamic> toFirestore() => toJson();

  factory FlowEntry.fromFirestore(Map<String, dynamic> data) =>
      FlowEntry.fromJson(data);
}
