import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../models/health_model.dart';
import '../models/user_model.dart';
import '../utils/image_utils.dart';
import 'notification_service.dart';

class HealthService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Listen for status changes on a student's appointments.
  /// Returns a [StreamSubscription] the caller must cancel in `dispose()`.
  StreamSubscription? listenForAppointmentStatusChanges({
    required String userId,
    required NotificationService notificationService,
  }) {
    if (kIsWeb) return null;

    bool isFirstSnapshot = true;

    return _firestore
        .collection('appointments')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      if (isFirstSnapshot) {
        isFirstSnapshot = false;
        return;
      }

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data();
          if (data != null) {
            final status = (data['status'] ?? '').toString().toLowerCase();
            final reason = data['reasonForVisit'] ?? 'consultation';

            if (status == 'approved') {
              notificationService.showAppointmentNotification(
                id: change.doc.id.hashCode,
                title: '✅ Appointment Approved',
                body: 'Your appointment for "$reason" has been approved.',
              );
            } else if (status == 'cancelled') {
              final cancelReason = data['cancellationReason'] ?? '';
              notificationService.showAppointmentNotification(
                id: change.doc.id.hashCode,
                title: '❌ Appointment Declined',
                body: cancelReason.isNotEmpty
                    ? 'Your appointment for "$reason" was declined. Reason: $cancelReason'
                    : 'Your appointment for "$reason" was declined.',
              );
            } else if (status == 'completed') {
              notificationService.showAppointmentNotification(
                id: change.doc.id.hashCode,
                title: '🏥 Appointment Completed',
                body: 'Your appointment for "$reason" has been marked as completed.',
              );
            }
          }
        }
      }
    });
  }

  /// Listen for new appointment bookings (for admin side).
  /// Returns a [StreamSubscription] the caller must cancel in `dispose()`.
  StreamSubscription? listenForNewAppointments({
    required NotificationService notificationService,
    required DateTime sinceTime,
  }) {
    if (kIsWeb) return null;

    return _firestore
        .collection('appointments')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(sinceTime))
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final reason = data['reasonForVisit'] ?? 'consultation';
            final studentId = data['studentId'] ?? 'Unknown';
            notificationService.showAppointmentNotification(
              id: change.doc.id.hashCode,
              title: '📅 New Appointment Request',
              body: 'Student $studentId has requested an appointment for "$reason".',
            );
          }
        }
      }
    });
  }

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
