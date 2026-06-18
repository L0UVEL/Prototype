import 'dart:convert';
import 'dart:math';
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

  /// Serialises the announcement for the main Firestore document.
  /// NOTE: PDF attachments are stored in a subcollection (pdf_chunks),
  /// NOT in this map, to avoid the 1 MiB document size limit.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'title': title,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'adminId': adminId,
    };

    // Store image base64 strings individually to avoid array issues on web
    if (imageUrls.isNotEmpty) {
      for (int i = 0; i < imageUrls.length; i++) {
        map['image_$i'] = imageUrls[i];
      }
      map['imageCount'] = imageUrls.length;
    }

    // Store the number of PDFs so the UI knows to lazy-load them
    if (pdfAttachments.isNotEmpty) {
      map['pdfCount'] = pdfAttachments.length;
    }

    return map;
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

    // Read images: support both new (image_0, image_1, ...) and legacy (imageUrls array)
    List<String> images = [];
    if (map.containsKey('imageCount')) {
      final count = map['imageCount'] as int;
      for (int i = 0; i < count; i++) {
        final img = map['image_$i'];
        if (img is String) images.add(img);
      }
    } else if (map['imageUrls'] != null) {
      images = List<String>.from(map['imageUrls']);
    }

    // Read PDFs: support both new (JSON string) and legacy (array of maps)
    List<PdfAttachment> pdfs = [];
    if (map.containsKey('pdfAttachmentsJson') && map['pdfAttachmentsJson'] is String) {
      final decoded = jsonDecode(map['pdfAttachmentsJson'] as String) as List;
      pdfs = decoded
          .map((p) => PdfAttachment.fromMap(Map<String, dynamic>.from(p)))
          .toList();
    } else {
      final rawPdfs = map['pdfAttachments'] as List<dynamic>? ?? [];
      pdfs = rawPdfs
          .map((p) => PdfAttachment.fromMap(Map<String, dynamic>.from(p)))
          .toList();
    }

    return Announcement(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      timestamp: dt,
      imageUrls: images,
      pdfAttachments: pdfs,
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

  /// Maximum main-document size for images (leave headroom under 1 MiB).
  static const int _maxMainDocBytes = 800 * 1024; // ~800 KB

  /// Chunk size for PDF subcollection documents.
  static const int _chunkSize = 800 * 1024; // ~800 KB per chunk

  Future<void> addAnnouncement(
    String title,
    String content, {
    List<XFile> images = const [],
    List<PlatformFile> pdfs = const [],
  }) async {
    // 1. Process images to base64
    List<String> base64Images = [];
    if (images.isNotEmpty) {
      base64Images = await _processImagesToBase64(images);
    }

    // 2. Process PDFs to base64
    List<PdfAttachment> pdfAttachments = [];
    if (pdfs.isNotEmpty) {
      pdfAttachments = await _processPdfsToBase64(pdfs);
    }

    // 3. Validate main document size (images + metadata, NO PDFs)
    int mainDocSize = title.length + content.length + 200;
    for (final img in base64Images) {
      mainDocSize += img.length;
    }
    if (mainDocSize > _maxMainDocBytes) {
      final sizeMB = (mainDocSize / (1024 * 1024)).toStringAsFixed(1);
      throw Exception(
        'Images are too large (${sizeMB}MB total). '
        'Please use smaller or fewer images (max ~800KB combined).',
      );
    }

    // Create announcement (PDFs excluded from main doc)
    final announcementId = const Uuid().v4();
    final announcement = Announcement(
      id: announcementId,
      title: title,
      content: content,
      timestamp: DateTime.now(),
      imageUrls: base64Images,
      pdfAttachments: pdfAttachments, // kept in model for pdfCount
      adminId: _auth.currentUser?.uid ?? '',
    );

    // 4. Write main document to Firestore
    final docRef = _firestore.collection('announcements').doc(announcementId);
    try {
      await docRef.set(announcement.toMap());
    } catch (e) {
      debugPrint('Error creating announcement: $e');
      rethrow;
    }

    // 5. Write PDF attachments to subcollection as chunks
    for (int i = 0; i < pdfAttachments.length; i++) {
      final pdf = pdfAttachments[i];
      final dataUri = pdf.dataUri;
      final totalChunks = (dataUri.length / _chunkSize).ceil();

      for (int j = 0; j < totalChunks; j++) {
        final start = j * _chunkSize;
        final end = min(start + _chunkSize, dataUri.length);
        await docRef.collection('pdf_chunks').doc('pdf${i}_chunk$j').set({
          'pdfIndex': i,
          'chunkIndex': j,
          'totalChunks': totalChunks,
          'name': pdf.name,
          'data': dataUri.substring(start, end),
        });
      }
    }

    // notifyListeners is handled by the stream listener
  }

  /// Loads PDF attachments from the subcollection for a given announcement.
  /// Returns legacy inline PDFs if no subcollection data exists.
  Future<List<PdfAttachment>> loadPdfAttachments(String announcementId) async {
    // First check if there are PDFs in the subcollection
    final snapshot = await _firestore
        .collection('announcements')
        .doc(announcementId)
        .collection('pdf_chunks')
        .get();

    if (snapshot.docs.isEmpty) {
      // Fall back to inline PDFs from the in-memory model (legacy support)
      final announcement = getAnnouncement(announcementId);
      return announcement?.pdfAttachments ?? [];
    }

    // Group chunks by pdfIndex
    final Map<int, List<QueryDocumentSnapshot>> grouped = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final pdfIndex = data['pdfIndex'] as int;
      grouped.putIfAbsent(pdfIndex, () => []).add(doc);
    }

    // Reconstruct each PDF from its chunks
    final List<PdfAttachment> pdfs = [];
    final sortedKeys = grouped.keys.toList()..sort();

    for (final key in sortedKeys) {
      final chunks = grouped[key]!;
      chunks.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        return (aData['chunkIndex'] as int).compareTo(bData['chunkIndex'] as int);
      });

      final firstData = chunks.first.data() as Map<String, dynamic>;
      final name = firstData['name'] as String;
      final fullData = chunks.map((c) {
        final d = c.data() as Map<String, dynamic>;
        return d['data'] as String;
      }).join();

      pdfs.add(PdfAttachment(name: name, dataUri: fullData));
    }

    return pdfs;
  }

  Future<void> deleteAnnouncement(String id) async {
    // Delete PDF chunks subcollection first (Firestore doesn't auto-delete subcollections)
    final chunks = await _firestore
        .collection('announcements')
        .doc(id)
        .collection('pdf_chunks')
        .get();

    for (final doc in chunks.docs) {
      await doc.reference.delete();
    }

    // Then delete the main document
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
