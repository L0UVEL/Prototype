import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to log all emails sent by the system to Firestore.
/// This ensures a record exists even when SMTP is unavailable (e.g. on web).
class EmailLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Logs an email to the `sent_emails` Firestore collection.
  ///
  /// [to] – recipient email address
  /// [subject] – email subject line
  /// [htmlBody] – full HTML body of the email
  /// [type] – category of email: 'credentials', 'password_reset', etc.
  /// [sentBy] – UID of the admin/user who triggered the email, or 'system'
  /// [status] – 'sent', 'failed', or 'skipped_web'
  /// [error] – error message if the send failed
  static Future<void> logEmail({
    required String to,
    required String subject,
    required String htmlBody,
    required String type,
    String sentBy = 'system',
    required String status,
    String? error,
  }) async {
    try {
      await _firestore.collection('sent_emails').add({
        'to': to,
        'subject': subject,
        'htmlBody': htmlBody,
        'type': type,
        'sentBy': sentBy,
        'status': status,
        'error': error,
        'sentAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Email logged to Firestore: $type -> $to ($status)');
    } catch (e) {
      debugPrint('Failed to log email to Firestore: $e');
    }
  }
}
