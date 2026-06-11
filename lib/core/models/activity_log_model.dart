import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogModel {
  final String id;
  final String studentId;
  final String moduleName;
  final String action;
  final DateTime timestamp;

  ActivityLogModel({
    required this.id,
    required this.studentId,
    required this.moduleName,
    required this.action,
    required this.timestamp,
  });

  factory ActivityLogModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedTimestamp = DateTime.now();
    if (map['timestamp'] != null) {
      if (map['timestamp'] is Timestamp) {
        parsedTimestamp = (map['timestamp'] as Timestamp).toDate();
      } else if (map['timestamp'] is String) {
        parsedTimestamp = DateTime.tryParse(map['timestamp']) ?? DateTime.now();
      }
    }

    return ActivityLogModel(
      id: id,
      studentId: map['studentId'] ?? '',
      moduleName: map['moduleName'] ?? '',
      action: map['action'] ?? '',
      timestamp: parsedTimestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'moduleName': moduleName,
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
