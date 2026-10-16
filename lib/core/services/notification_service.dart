import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:firebase_core/firebase_core.dart';

// Top-level function for background handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static void Function(String route)? onNotificationTap;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static const List<int> reminderHours = [7, 8, 9, 10, 11, 12, 14, 16, 18, 20];
  static const int daysToSchedule = 14;

  /// Deterministic ID generator per date and hour.
  /// Fits safely inside a 32-bit signed integer (max ~2.7M).
  static int getCheckInReminderId(DateTime date, int hour) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    return ((date.year % 100) * 100000) + (dayOfYear * 100) + hour;
  }

  Future<void> init() async {
    // 0. Initialize Timezones
    if (kIsWeb) return;

    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = tzInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Could not get local timezone via flutter_timezone: $e');
      try {
        final timeZoneName = DateTime.now().timeZoneName;
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        try {
          tz.setLocalLocation(tz.getLocation('Asia/Manila'));
        } catch (_) {}
      }
    }

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
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTap?.call(payload);
        }
      },
    );

    // 2. Request Permission (iOS & Android 13+)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Also request local notification permissions for Android 13+
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();

      // Create high importance channels for all notification categories
      const AndroidNotificationChannel highChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );
      await androidImplementation.createNotificationChannel(highChannel);

      const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
        'reminder_channel',
        'Daily Check-in Reminders',
        description: 'Reminders to complete your daily health check-in',
        importance: Importance.max,
      );
      await androidImplementation.createNotificationChannel(reminderChannel);

      const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
        'general_channel',
        'General Notifications',
        description: 'General system notifications',
        importance: Importance.max,
      );
      await androidImplementation.createNotificationChannel(generalChannel);

      const AndroidNotificationChannel appointmentChannel = AndroidNotificationChannel(
        'appointment_channel',
        'Appointments',
        description: 'Notifications for appointment updates',
        importance: Importance.max,
      );
      await androidImplementation.createNotificationChannel(appointmentChannel);

      const AndroidNotificationChannel announcementChannel = AndroidNotificationChannel(
        'announcement_channel',
        'Announcements',
        description: 'Notifications for new announcements',
        importance: Importance.max,
      );
      await androidImplementation.createNotificationChannel(announcementChannel);
    }

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

    // 5. Get FCM Token and Subscribe to Announcements
    try {
      await _firebaseMessaging.subscribeToTopic('announcements');
      debugPrint('Subscribed to topic: announcements');
    } catch (e) {
      debugPrint('Failed to subscribe to topic: $e');
    }

    final token = await _firebaseMessaging.getToken();
    debugPrint("FCM Token: $token");
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'general_channel',
          'General',
          channelDescription: 'General notifications',
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

  /// Show a notification for appointment status changes (approved/rejected).
  Future<void> showAppointmentNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'appointment_channel',
          'Appointments',
          channelDescription: 'Notifications for appointment updates',
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

  /// Show a notification when a new announcement is posted.
  Future<void> showAnnouncementNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
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

  Future<void> _scheduleNotificationSafe({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    String? payload,
  }) async {
    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      // Fallback for devices or battery modes where exact alarms are denied
      try {
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } catch (e2) {
        debugPrint('Failed to schedule reminder $id at $scheduledDate: $e2');
      }
    }
  }

  bool _isSyncing = false;
  bool _hasPendingSync = false;
  bool _pendingCheckedIn = false;

  /// Synchronize check-in reminders for the next 14 days.
  /// If [isCheckedInToday] is true, today's remaining reminders are cancelled,
  /// but all future days remain scheduled so they fire even if the app is closed.
  /// If [isCheckedInToday] is false, today's remaining hours are scheduled along with future days.
  Future<void> syncCheckInReminders({required bool isCheckedInToday}) async {
    if (kIsWeb) return;

    if (_isSyncing) {
      _hasPendingSync = true;
      _pendingCheckedIn = isCheckedInToday;
      return;
    }

    _isSyncing = true;
    try {
      await _executeSync(isCheckedInToday);
    } catch (e) {
      debugPrint('Error syncing check-in reminders: $e');
    } finally {
      _isSyncing = false;
      if (_hasPendingSync) {
        final nextCheckedIn = _pendingCheckedIn;
        _hasPendingSync = false;
        Future.microtask(() => syncCheckInReminders(isCheckedInToday: nextCheckedIn));
      }
    }
  }

  Future<void> _executeSync(bool isCheckedInToday) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'reminder_channel',
          'Daily Check-in Reminders',
          channelDescription: 'Reminders to complete your daily health check-in',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'check_in_reminder',
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    // Cancel legacy IDs 990..999 from previous implementations
    for (int i = 0; i < 10; i++) {
      try {
        await _flutterLocalNotificationsPlugin.cancel(id: 990 + i);
      } catch (_) {}
    }

    final now = tz.TZDateTime.now(tz.local);

    // 1. Day 0 (Today)
    if (isCheckedInToday) {
      // User has checked in today: ensure today's reminders are completely cancelled!
      await cancelTodayCheckInReminders();
    } else {
      // User has not checked in today: schedule remaining hours for today
      for (final hour in reminderHours) {
        final scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          hour,
        );

        if (scheduledDate.isAfter(now)) {
          final id = getCheckInReminderId(now, hour);
          await _scheduleNotificationSafe(
            id: id,
            title: 'Daily Check-in Reminder',
            body: 'Don\'t forget to complete your daily health check-in!',
            scheduledDate: scheduledDate,
            notificationDetails: notificationDetails,
            payload: '/daily-check-in',
          );
        }
      }
    }

    // 2. Future days (Day 1 through daysToSchedule)
    // Pre-schedule future days so that even if the student does not open the app tomorrow,
    // the notifications will still arrive on time!
    for (int dayOffset = 1; dayOffset <= daysToSchedule; dayOffset++) {
      final targetDate = now.add(Duration(days: dayOffset));
      for (final hour in reminderHours) {
        final scheduledDate = tz.TZDateTime(
          tz.local,
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hour,
        );

        final id = getCheckInReminderId(targetDate, hour);
        await _scheduleNotificationSafe(
          id: id,
          title: 'Daily Check-in Reminder',
          body: 'Don\'t forget to complete your daily health check-in!',
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
          payload: '/daily-check-in',
        );
      }
    }
  }

  /// Cancel today's check-in reminders immediately.
  /// Future days remain scheduled so tomorrow's reminders are not affected.
  Future<void> cancelTodayCheckInReminders() async {
    if (kIsWeb) return;
    final today = DateTime.now();
    for (final hour in reminderHours) {
      try {
        await _flutterLocalNotificationsPlugin.cancel(
          id: getCheckInReminderId(today, hour),
        );
      } catch (e) {
        debugPrint('Failed to cancel today reminder for $hour:00: $e');
      }
    }

    // Cancel legacy IDs 990..999
    for (int i = 0; i < 10; i++) {
      try {
        await _flutterLocalNotificationsPlugin.cancel(id: 990 + i);
      } catch (_) {}
    }
  }

  /// Cancel all check-in reminders (past, today, and future).
  /// Used during user logout or when switching to admin account.
  Future<void> cancelAllCheckInReminders() async {
    if (kIsWeb) return;
    final today = DateTime.now();
    for (int d = -1; d <= daysToSchedule; d++) {
      final targetDate = today.add(Duration(days: d));
      for (final hour in reminderHours) {
        try {
          await _flutterLocalNotificationsPlugin.cancel(
            id: getCheckInReminderId(targetDate, hour),
          );
        } catch (_) {}
      }
    }

    for (int i = 0; i < 10; i++) {
      try {
        await _flutterLocalNotificationsPlugin.cancel(id: 990 + i);
      } catch (_) {}
    }
  }

  /// Backwards-compatible methods
  Future<void> scheduleDailyCheckInReminders() => syncCheckInReminders(isCheckedInToday: false);
  Future<void> cancelCheckInReminders() => cancelTodayCheckInReminders();
}
