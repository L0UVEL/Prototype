import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class Announcement {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
  });
}

class AnnouncementService extends ChangeNotifier {
  final List<Announcement> _announcements = [
    Announcement(
      id: 'dummy-1',
      title: 'Welcome to the System',
      content: 'This is a sample announcement for students to see.',
      timestamp: DateTime.now(),
    ),
  ];

  List<Announcement> get announcements => List.unmodifiable(_announcements);

  void addAnnouncement(String title, String content) {
    final announcement = Announcement(
      id: const Uuid().v4(),
      title: title,
      content: content,
      timestamp: DateTime.now(),
    );
    _announcements.insert(0, announcement);
    notifyListeners();
  }

  void deleteAnnouncement(String id) {
    _announcements.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  Announcement? getAnnouncement(String id) {
    try {
      return _announcements.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }
}
