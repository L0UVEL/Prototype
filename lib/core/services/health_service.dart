import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/health_model.dart';
import '../models/user_model.dart';
import '../utils/image_utils.dart';

class HealthService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Converts a profile image to base64 for storing in Firestore.
  Future<String> convertProfileImage(File imageFile) async {
    try {
      return await imageFileToBase64(imageFile);
    } catch (e) {
      debugPrint('Error converting profile image: $e');
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

    await _firestore.collection('appointments').doc(id).set(map);
  }

  Future<void> updateAppointmentStatus(
    String appointmentId,
    String status,
  ) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'status': status,
    });
  }

  Future<void> removeAppointment(String appointmentId) async {
    await _firestore.collection('appointments').doc(appointmentId).delete();
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

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}
