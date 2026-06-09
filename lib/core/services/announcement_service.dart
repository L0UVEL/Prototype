import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/image_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'notification_service.dart';

/// Represents a PDF attachment stored as a base64 data URI.
class PdfAttachment {
  final String name;
  final String dataUri; // "data:application/pdf;base64,..."

  PdfAttachment({required this.name, required this.dataUri});

  Map<String, dynamic> toMap() => {'name': name, 'dataUri': dataUri};

  factory PdfAttachment.fromMap(Map<String, dynamic> map) {
    return PdfAttachment(
      name: map['name'] ?? 'attachment.pdf',
      dataUri: map['dataUri'] ?? '',
    );
  }
}

class Announcement {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;
  final List<String> imageUrls;
  final List<PdfAttachment> pdfAttachments;
  final String adminId;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    this.imageUrls = const [],
    this.pdfAttachments = const [],
    this.adminId = '',
  });

  // Backward compatibility
  String? get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrls': imageUrls,
      'pdfAttachments': pdfAttachments.map((p) => p.toMap()).toList(),
      'adminId': adminId,
    };
  }

  factory Announcement.fromMap(Map<String, dynamic> map) {
    DateTime dt;
    final dynamic rawTs = map['timestamp'];
    if (rawTs is Timestamp) {
      dt = rawTs.toDate();
    } else if (rawTs is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else {
      dt = DateTime.now();
    }

    final rawPdfs = map['pdfAttachments'] as List<dynamic>? ?? [];

    return Announcement(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      timestamp: dt,
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      pdfAttachments: rawPdfs
          .map((p) => PdfAttachment.fromMap(Map<String, dynamic>.from(p)))
          .toList(),
      adminId: map['adminId'] ?? '',
    );
  }
}

class AnnouncementService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  StreamSubscription? _firestoreSubscription;
  bool _isFirstSnapshot = true;

  List<Announcement> _announcements = [];
  List<Announcement> get announcements => List.unmodifiable(_announcements);

  AnnouncementService() {
    _initNotifications();
    _initAuthListener();
  }

  Future<void> _initNotifications() async {
    if (!kIsWeb) {
      await _notificationService.init();
    }
  }

  void _initAuthListener() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _startFirestoreListener();
      } else {
        _stopFirestoreListener();
      }
    });
  }

  void _startFirestoreListener() {
    _stopFirestoreListener(); // Close existing if any
    _isFirstSnapshot = true;

    _firestoreSubscription = _firestore
        .collection('announcements')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            _announcements = snapshot.docs
                .map((doc) => Announcement.fromMap(doc.data()))
                .toList();

            // Notify for newly added announcements (skip initial load)
            if (_isFirstSnapshot) {
              _isFirstSnapshot = false;
            } else {
              for (var change in snapshot.docChanges) {
                if (change.type == DocumentChangeType.added) {
                  final data = change.doc.data();
                  if (data != null) {
                    final title = data['title'] ?? 'New Announcement';
                    final content = data['content'] ?? '';
                    _notificationService.showAnnouncementNotification(
                      id: change.doc.id.hashCode,
                      title: '📢 $title',
                      body: content.length > 100
                          ? '${content.substring(0, 100)}...'
                          : content,
                    );
                  }
                }
              }
            }

            notifyListeners();
          },
          onError: (e) {
            debugPrint('Error listening to announcements: $e');
          },
        );
  }

  void _stopFirestoreListener() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    _announcements = [];
    notifyListeners();
  }

  Future<List<String>> _processImagesToBase64(List<XFile> files) async {
    List<String> base64Images = [];
    for (XFile file in files) {
      try {
        final base64Str = await xFileToBase64(file);
        base64Images.add(base64Str);
      } catch (e) {
        debugPrint('Error converting image to base64: $e');
      }
    }
    return base64Images;
  }

  /// Convert [PlatformFile]s from file_picker into [PdfAttachment]s.
  Future<List<PdfAttachment>> _processPdfsToBase64(
    List<PlatformFile> files,
  ) async {
    List<PdfAttachment> attachments = [];
    for (final file in files) {
      try {
        final Uint8List? bytes = file.bytes;
        if (bytes != null) {
          final base64Str = base64Encode(bytes);
          attachments.add(PdfAttachment(
            name: file.name,
            dataUri: 'data:application/pdf;base64,$base64Str',
          ));
        }
      } catch (e) {
        debugPrint('Error converting PDF to base64: $e');
      }
    }
    return attachments;
  }

  Future<void> addAnnouncement(
    String title,
    String content, {
    List<XFile> images = const [],
    List<PlatformFile> pdfs = const [],
  }) async {
    // 1. Process images to base64 first
    List<String> base64Images = [];
    if (images.isNotEmpty) {
      base64Images = await _processImagesToBase64(images);
    }

    // 2. Process PDFs to base64
    List<PdfAttachment> pdfAttachments = [];
    if (pdfs.isNotEmpty) {
      pdfAttachments = await _processPdfsToBase64(pdfs);
    }

    final announcement = Announcement(
      id: const Uuid().v4(),
      title: title,
      content: content,
      timestamp: DateTime.now(),
      imageUrls: base64Images,
      pdfAttachments: pdfAttachments,
      adminId: _auth.currentUser?.uid ?? '',
    );

    // 3. Add to Firestore
    // The Firestore snapshot listener will handle notifications for all devices
    await _firestore
        .collection('announcements')
        .doc(announcement.id)
        .set(announcement.toMap());

    // notifyListeners is handled by the stream listener
  }

  Future<void> deleteAnnouncement(String id) async {
    await _firestore.collection('announcements').doc(id).delete();
  }

  Announcement? getAnnouncement(String id) {
    try {
      return _announcements.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }
}
