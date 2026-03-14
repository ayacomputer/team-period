enum Mood { great, good, okay, low, rough }

extension MoodLabel on Mood {
  String get label {
    switch (this) {
      case Mood.great:
        return 'Great';
      case Mood.good:
        return 'Good';
      case Mood.okay:
        return 'Okay';
      case Mood.low:
        return 'Low';
      case Mood.rough:
        return 'Rough';
    }
  }
}

/// Conditions that can be logged alongside a mood.
const kConditionOptions = [
  'Cramps',
  'Headache',
  'Bloating',
  'Tired',
  'Spotting',
  'Back pain',
  'Nausea',
  'Mood swings',
];

class MoodEntry {
  const MoodEntry({
    required this.date,
    required this.mood,
    required this.conditions,
    this.note,
  });

  /// ISO date string "YYYY-MM-DD"
  final String date;
  final Mood mood;
  final List<String> conditions;
  final String? note;

  MoodEntry copyWith({
    String? date,
    Mood? mood,
    List<String>? conditions,
    String? note,
  }) {
    return MoodEntry(
      date: date ?? this.date,
      mood: mood ?? this.mood,
      conditions: conditions ?? this.conditions,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'mood': mood.name,
        'conditions': conditions,
        if (note != null) 'note': note,
      };

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      date: json['date'] as String,
      mood: Mood.values.firstWhere(
        (m) => m.name == json['mood'],
        orElse: () => Mood.okay,
      ),
      conditions: List<String>.from(json['conditions'] as List? ?? []),
      note: json['note'] as String?,
    );
  }

  factory MoodEntry.fromFirestore(Map<String, dynamic> data) =>
      MoodEntry.fromJson(data);

  Map<String, dynamic> toFirestore() => toJson();
}
