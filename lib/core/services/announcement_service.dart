import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/image_utils.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:async';
import 'notification_service.dart';

class Announcement {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;
  final List<String> imageUrls;
  final String adminId;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    this.imageUrls = const [],
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

    return Announcement(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      timestamp: dt,
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      adminId: map['adminId'] ?? '',
    );
  }
}

class AnnouncementService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  StreamSubscription? _firestoreSubscription;

  List<Announcement> _announcements = [];
  List<Announcement> get announcements => List.unmodifiable(_announcements);

  AnnouncementService() {
    _initNotifications();
    _initAuthListener();
  }

  Future<void> _initNotifications() async {
    await _notificationService.init();
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

    _firestoreSubscription = _firestore
        .collection('announcements')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            _announcements = snapshot.docs
                .map((doc) => Announcement.fromMap(doc.data()))
                .toList();
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

  Future<List<String>> _processImagesToBase64(List<String> filePaths) async {
    List<String> base64Images = [];
    for (String path in filePaths) {
      try {
        final file = File(path);
        final base64Str = await imageFileToBase64(file);
        base64Images.add(base64Str);
      } catch (e) {
        debugPrint('Error converting image to base64: $e');
      }
    }
    return base64Images;
  }

  Future<void> addAnnouncement(
    String title,
    String content, {
    List<String> imageUrls = const [],
  }) async {
    // 1. Process images to base64 first
    List<String> uploadedUrls = [];
    if (imageUrls.isNotEmpty) {
      uploadedUrls = await _processImagesToBase64(imageUrls);
    }

    final announcement = Announcement(
      id: const Uuid().v4(),
      title: title,
      content: content,
      timestamp: DateTime.now(),
      imageUrls: uploadedUrls,
      adminId: _auth.currentUser?.uid ?? '',
    );

    // 2. Add to Firestore
    await _firestore
        .collection('announcements')
        .doc(announcement.id)
        .set(announcement.toMap());

    // Trigger notification
    await _notificationService.showNotification(
      id: announcement.id.hashCode,
      title: 'New Announcement: $title',
      body: content,
    );

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
