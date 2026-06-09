import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/health_model.dart';
import '../models/user_model.dart';
import '../utils/image_utils.dart';

class HealthService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Converts an XFile to base64 for storing in Firestore.
  Future<String> convertXFileToProfileImage(XFile xFile) async {
    try {
      return await xFileToBase64(xFile);
    } catch (e) {
      debugPrint('Error converting XFile profile image: $e');
      rethrow;
    }
  }

  // --- Users / Students ---

  Stream<List<User>> getStudentsStream() {
    return _firestore
        .collection('users')
        .where('roleId', isEqualTo: 'student')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return User(
              id: doc.id,
              studentId: data['studentId'] ?? '',
              email: data['email'] ?? '',
              firstName: data['firstName'] ?? data['name'] ?? 'Unknown',
              lastName: data['lastName'] ?? '',
              roleId: data['roleId'] ?? 'student',
              role: UserRole.user,
              program: data['program'],
            );
          }).toList();
        });
  }

  Stream<User> getStudentStream(String id) {
    return _firestore.collection('users').doc(id).snapshots().map((doc) {
      if (!doc.exists) {
        throw Exception('User not found');
      }
      final data = doc.data()!;
      return User(
        id: doc.id,
        studentId: data['studentId'] ?? '',
        email: data['email'] ?? '',
        firstName: data['firstName'] ?? data['name'] ?? 'Unknown',
        lastName: data['lastName'] ?? '',
        roleId: data['roleId'] ?? 'student',
        role: UserRole.user,
        program: data['program'],
      );
    });
  }

  // --- Health Profile ---

  Stream<HealthProfile?> getHealthProfileStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('health_profile')
        .doc('main')
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            return HealthProfile.fromMap(snapshot.data()!, snapshot.id);
          }
          return null;
        });
  }

  Future<void> updateHealthProfile(HealthProfile info) async {
    await _firestore
        .collection('users')
        .doc(info.userId) // Ensure we write to userId Auth UID
        .collection('health_profile')
        .doc('main')
        .set(info.toMap());
  }

  // --- Health Updates ---

  Stream<List<HealthUpdate>> getDailyLogsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('health_updates')
        .orderBy('checkinDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => HealthUpdate.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Future<void> addDailyLog(HealthUpdate log) async {
    await _firestore
        .collection('users')
        .doc(log.userId) // Use Auth UID for routing!
        .collection('health_updates')
        .doc(log.updateId)
        .set(log.toMap());
  }

  Future<HealthUpdate?> getLatestLog(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_updates')
          .orderBy('checkinDate', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return HealthUpdate.fromMap(
          snapshot.docs.first.data(),
          snapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error getting latest log: $e');
      return null;
    }
  }

  // --- Appointments ---

  Stream<List<Appointment>> getAppointmentsStream({String? userId}) {
    Query query = _firestore.collection('appointments');
    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) =>
                Appointment.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    });
  }

  Future<void> addAppointment(
    String userId,
    String studentId, // Add custom studentId
    DateTime dateTime,
    String reason,
  ) async {
    final id = const Uuid().v4();
    final appointment = Appointment(
      appointmentId: id,
      studentId: studentId,
      userId: userId,
      adminId: '', // To be filled by admin assigned
      appointmentDate: dateTime,
      reasonForVisit: reason,
      status: 'Pending',
      createdAt: DateTime.now(),
    );
    // Include createdAt for admin notification listening
    var map = appointment.toMap();
    // Override createdAt with server timestamp for reliable admin listener queries
    map['createdAt'] = FieldValue.serverTimestamp();

    final batch = _firestore.batch();
    batch.set(_firestore.collection('appointments').doc(id), map);

    final slotId = dateTime.toIso8601String();
    batch.set(_firestore.collection('taken_slots').doc(slotId), {
      'appointmentId': id,
      'userId': userId,
      'date': slotId,
    });

    await batch.commit();
  }

  Future<void> updateAppointmentStatus(
    String appointmentId,
    String status, {
    String cancellationReason = '',
  }) async {
    final doc = await _firestore.collection('appointments').doc(appointmentId).get();
    if (!doc.exists) return;

    final batch = _firestore.batch();
    final updateData = <String, dynamic>{
      'status': status,
    };

    if (cancellationReason.isNotEmpty) {
      updateData['cancellationReason'] = cancellationReason;
    }

    batch.update(_firestore.collection('appointments').doc(appointmentId), updateData);

    if (status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'rejected') {
      final appt = Appointment.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      final slotId = appt.appointmentDate.toIso8601String();
      batch.delete(_firestore.collection('taken_slots').doc(slotId));
    }

    await batch.commit();
  }

  Future<void> removeAppointment(String appointmentId) async {
    final doc = await _firestore.collection('appointments').doc(appointmentId).get();
    if (!doc.exists) return;

    final appt = Appointment.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    final slotId = appt.appointmentDate.toIso8601String();

    final batch = _firestore.batch();
    batch.delete(_firestore.collection('appointments').doc(appointmentId));
    batch.delete(_firestore.collection('taken_slots').doc(slotId));
    await batch.commit();
  }

  Stream<List<DateTime>> getTakenSlotsForDateStream(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection('taken_slots')
        .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .where('date', isLessThanOrEqualTo: endOfDay.toIso8601String())
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => DateTime.parse(doc.id)).toList();
    });
  }

  // --- Helpers / Status ---

  // Helper to determine status (Logic preserved)
  Map<String, dynamic> calculateStudentStatus(List<HealthUpdate> logs) {
    if (logs.isEmpty) {
      return {
        'status': 'No Data',
        'color': 0xFF9E9E9E,
        'description': 'No check-ins yet',
      };
    }

    // Sort logs by date descending already done by stream generally, but ensure:
    logs.sort((a, b) => b.checkinDate.compareTo(a.checkinDate));
    final latestLog = logs.first;

    final now = DateTime.now();
    final isToday =
        latestLog.checkinDate.year == now.year &&
        latestLog.checkinDate.month == now.month &&
        latestLog.checkinDate.day == now.day;

    if (!isToday) {
      return {
        'status': 'Missed Check-in',
        'color': 0xFFFFA000,
        'description': 'Last check-in: ${_formatDate(latestLog.checkinDate)}',
      };
    }

    if (latestLog.status == 'At Risk') {
      return {
        'status': 'At Risk',
        'color': 0xFFD32F2F,
        'description': 'Reported symptoms: ${latestLog.symptoms}',
      };
    }

    return {
      'status': 'Healthy',
      'color': 0xFF388E3C,
      'description': 'Checked in today',
    };
  }

  /// Calculates the health status of a student for a specific [targetDate],
  /// enabling historical analytics lookback.
  Map<String, dynamic> calculateStudentStatusForDate(
    List<HealthUpdate> logs,
    DateTime targetDate,
  ) {
    if (logs.isEmpty) {
      return {
        'status': 'No Data',
        'color': 0xFF9E9E9E,
        'description': 'No check-ins yet',
      };
    }

    // Find logs that match the target date
    final logsOnDate = logs.where((log) =>
      log.checkinDate.year == targetDate.year &&
      log.checkinDate.month == targetDate.month &&
      log.checkinDate.day == targetDate.day,
    ).toList();

    if (logsOnDate.isEmpty) {
      // Find the most recent log before the target date
      final logsBefore = logs.where((log) =>
        log.checkinDate.isBefore(
          DateTime(targetDate.year, targetDate.month, targetDate.day + 1),
        ),
      ).toList();
      logsBefore.sort((a, b) => b.checkinDate.compareTo(a.checkinDate));

      if (logsBefore.isEmpty) {
        return {
          'status': 'No Data',
          'color': 0xFF9E9E9E,
          'description': 'No check-ins before this date',
        };
      }

      return {
        'status': 'Missed Check-in',
        'color': 0xFFFFA000,
        'description': 'Last check-in: ${_formatDate(logsBefore.first.checkinDate)}',
      };
    }

    // Sort logs on that date descending and use the latest
    logsOnDate.sort((a, b) => b.checkinDate.compareTo(a.checkinDate));
    final latestLog = logsOnDate.first;

    if (latestLog.status == 'At Risk') {
      return {
        'status': 'At Risk',
        'color': 0xFFD32F2F,
        'description': 'Reported symptoms: ${latestLog.symptoms}',
      };
    }

    return {
      'status': 'Healthy',
      'color': 0xFF388E3C,
      'description': 'Checked in on ${_formatDate(latestLog.checkinDate)}',
    };
  }

  /// Fetches a full health snapshot for all students on a specific [date].
  /// Returns a list of maps containing student info and their computed status.
  Future<List<Map<String, dynamic>>> getHealthSnapshotForDate(DateTime date) async {
    final students = await getStudentsStream().first;
    final List<Map<String, dynamic>> snapshot = [];

    for (var student in students) {
      final logs = await getDailyLogsStream(student.id).first;
      final statusData = calculateStudentStatusForDate(logs, date);

      snapshot.add({
        'student': student,
        'status': statusData['status'],
        'color': statusData['color'],
        'description': statusData['description'],
      });
    }

    return snapshot;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}
