import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

// Top-level function for background handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `Firebase.initializeApp` before using other Firebase services.
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> init() async {
    // 1. Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false, // We request manually
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // 2. Request Permission (iOS & Android 13+)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }

    // 3. Setup FCM Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification}',
        );
        showNotification(
          id: message.hashCode,
          title: message.notification?.title ?? 'New Notification',
          body: message.notification?.body ?? '',
        );
      }
    });

    // 5. Get FCM Token (for testing/backend)
    final token = await _firebaseMessaging.getToken();
    debugPrint("FCM Token: $token");
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'announcement_channel',
          'Announcements',
          channelDescription: 'Notifications for new announcements',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }

  Future<void> scheduleDailyCheckInReminder() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'reminder_channel',
          'Reminders',
          channelDescription: 'Daily check-in reminders',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    // Schedule notification for 10:00 AM daily
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 10, 0);

    // If it's already past 10 AM, schedule for tomorrow
    if (now.isAfter(scheduledDate)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // In a real app, you would use flutter_local_notifications' zonedSchedule
    // and timezone package for robust daily scheduling across reboots.
    // Here we simulate it with a simple delay if it's within the current app session.
    final delay = scheduledDate.difference(now);

    Future.delayed(delay, () async {
      await _flutterLocalNotificationsPlugin.show(
        id: 999,
        title: 'Daily Check-in Reminder',
        body: 'Don\'t forget to complete your daily health check-in!',
        notificationDetails: notificationDetails,
      );
      // Re-schedule for next day
      scheduleDailyCheckInReminder();
    });
  }

  Future<void> cancelCheckInReminder() async {
    await _flutterLocalNotificationsPlugin.cancel(id: 999);
  }
}
