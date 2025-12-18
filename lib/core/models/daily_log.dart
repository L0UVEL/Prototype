class DailyLog {
  final String id;
  final String userId;
  final DateTime date;
  final String mood;
  final List<String> symptoms;
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

  final double sleepHours;
}
