class DailyLog {
  final String id;
  final String userId;
  final DateTime date;
  final String mood;
  final List<String> symptoms;
  final double sleepHours;
  final String notes;

  DailyLog({
    required this.id,
    required this.userId,
    required this.date,
    required this.mood,
    required this.symptoms,
    this.sleepHours = 0.0,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': date.millisecondsSinceEpoch,
      'mood': mood,
      'symptoms': symptoms,
      'sleepHours': sleepHours,
      'notes': notes,
    };
  }

  factory DailyLog.fromMap(Map<String, dynamic> map, String id) {
    return DailyLog(
      id: id,
      userId: map['userId'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] ?? 0),
      mood: map['mood'] ?? '',
      symptoms: List<String>.from(map['symptoms'] ?? []),
      sleepHours: (map['sleepHours'] ?? 0).toDouble(),
      notes: map['notes'] ?? '',
    );
  }
}
