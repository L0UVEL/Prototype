class HealthProfile {
  final String profileId;
  final String studentId;
  final String userId;
  final String healthInformation;
  final String bloodType;
  final String emergencyContact;
  final DateTime lastUpdated;

  HealthProfile({
    required this.profileId,
    required this.studentId,
    required this.userId,
    required this.healthInformation,
    required this.bloodType,
    required this.emergencyContact,
    required this.lastUpdated,
  });

  HealthProfile copyWith({
    String? profileId,
    String? studentId,
    String? userId,
    String? healthInformation,
    String? bloodType,
    String? emergencyContact,
    DateTime? lastUpdated,
  }) {
    return HealthProfile(
      profileId: profileId ?? this.profileId,
      studentId: studentId ?? this.studentId,
      userId: userId ?? this.userId,
      healthInformation: healthInformation ?? this.healthInformation,
      bloodType: bloodType ?? this.bloodType,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'profileId': profileId,
      'studentId': studentId,
      'userId': userId,
      'healthInformation': healthInformation,
      'bloodType': bloodType,
      'emergencyContact': emergencyContact,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory HealthProfile.fromMap(Map<String, dynamic> map, String id) {
    final lastUpdatedRaw = map['lastUpdated'];
    DateTime lu = DateTime.now();
    if (lastUpdatedRaw is int) {
      lu = DateTime.fromMillisecondsSinceEpoch(lastUpdatedRaw);
    } else if (lastUpdatedRaw is String) {
      lu = DateTime.tryParse(lastUpdatedRaw) ?? DateTime.now();
    }

    return HealthProfile(
      profileId: id,
      studentId: map['studentId'] ?? '',
      userId: map['userId'] ?? '',
      healthInformation: map['healthInformation'] ?? '',
      bloodType: map['bloodType'] ?? '',
      emergencyContact: map['emergencyContact'] ?? '',
      lastUpdated: lu,
    );
  }
}

class HealthUpdate {
  final String updateId;
  final String studentId;
  final String userId;
  final DateTime checkinDate;
  final String symptoms;
  final String status; // 'Cleared', 'At Risk'

  HealthUpdate({
    required this.updateId,
    required this.studentId,
    required this.userId,
    required this.checkinDate,
    required this.symptoms,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'updateId': updateId,
      'studentId': studentId,
      'userId': userId,
      'checkinDate': checkinDate.toIso8601String(),
      'symptoms': symptoms,
      'status': status,
    };
  }

  factory HealthUpdate.fromMap(Map<String, dynamic> map, String id) {
    final checkinRaw = map['checkinDate'];
    DateTime checkin = DateTime.now();
    if (checkinRaw is int) {
      checkin = DateTime.fromMillisecondsSinceEpoch(checkinRaw);
    } else if (checkinRaw is String) {
      checkin = DateTime.tryParse(checkinRaw) ?? DateTime.now();
    }

    return HealthUpdate(
      updateId: id,
      studentId: map['studentId'] ?? '',
      userId: map['userId'] ?? '',
      checkinDate: checkin,
      symptoms: map['symptoms'] ?? '',
      status: map['status'] ?? 'Cleared',
    );
  }
}

class Appointment {
  final String appointmentId;
  final String studentId;
  final String userId;
  final String adminId;
  final DateTime appointmentDate;
  final String reasonForVisit;
  final String status; // 'Pending', 'Approved', 'Completed'
  final DateTime createdAt;

  Appointment({
    required this.appointmentId,
    required this.studentId,
    required this.userId,
    required this.adminId,
    required this.appointmentDate,
    required this.reasonForVisit,
    this.status = 'Pending',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'appointmentId': appointmentId,
      'studentId': studentId,
      'userId': userId,
      'adminId': adminId,
      'appointmentDate': appointmentDate.toIso8601String(),
      'reasonForVisit': reasonForVisit,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map, String id) {
    final adRaw = map['appointmentDate'];
    DateTime ad = DateTime.now();
    if (adRaw is int) {
      ad = DateTime.fromMillisecondsSinceEpoch(adRaw);
    } else if (adRaw is String) {
      ad = DateTime.tryParse(adRaw) ?? DateTime.now();
    }

    final caRaw = map['createdAt'];
    DateTime ca = DateTime.now();
    if (caRaw is int) {
      ca = DateTime.fromMillisecondsSinceEpoch(caRaw);
    } else if (caRaw is String) {
      ca = DateTime.tryParse(caRaw) ?? DateTime.now();
    }

    return Appointment(
      appointmentId: id,
      studentId: map['studentId'] ?? '',
      userId: map['userId'] ?? '',
      adminId: map['adminId'] ?? '',
      appointmentDate: ad,
      reasonForVisit: map['reasonForVisit'] ?? '',
      status: map['status'] ?? 'Pending',
      createdAt: ca,
    );
  }
}
