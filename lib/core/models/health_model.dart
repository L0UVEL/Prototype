class HealthInfo {
  final String userId;
  final double height; // in cm
  final double weight; // in kg
  final String bloodType;
  final List<String> allergies;
  final List<String> conditions;
  final String emergencyContactPath;

  HealthInfo({
    required this.userId,
    required this.height,
    required this.weight,
    required this.bloodType,
    this.allergies = const [],
    this.conditions = const [],
    this.emergencyContactPath = '',
  });

  // CopyWith method for easy updates
  HealthInfo copyWith({
    String? userId,
    double? height,
    double? weight,
    String? bloodType,
    List<String>? allergies,
    List<String>? conditions,
    String? emergencyContactPath,
  }) {
    return HealthInfo(
      userId: userId ?? this.userId,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      conditions: conditions ?? this.conditions,
      emergencyContactPath: emergencyContactPath ?? this.emergencyContactPath,
    );
  }
}

class Appointment {
  final String id;
  final String userId;
  final DateTime dateTime;
  final String reason;
  final String status; // 'pending', 'approved', 'completed', 'cancelled'

  Appointment({
    required this.id,
    required this.userId,
    required this.dateTime,
    required this.reason,
    this.status = 'pending',
  });
}
