import 'package:flutter/foundation.dart';
import '../models/class_session.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Mock initialization for now
    // In production, this would initialize flutter_local_notifications
    await Future.delayed(const Duration(milliseconds: 100));

    _initialized = true;
    if (kDebugMode) {
      print('NotificationService initialized (mock implementation)');
    }
  }

  // Schedule class reminder (1 hour before)
  Future<void> scheduleClassReminder(ClassSession session) async {
    if (!_initialized) await initialize();

    final reminderTime = session.startTime.subtract(const Duration(hours: 1));

    // Don't schedule if reminder time has passed
    if (reminderTime.isBefore(DateTime.now())) {
      return;
    }

    // Mock scheduling
    if (kDebugMode) {
      print(
        'Scheduled reminder for ${session.title} at ${_formatTime(reminderTime)}',
      );
    }

    // TODO: Implement actual notification scheduling
    // Add to pubspec.yaml:
    // flutter_local_notifications: ^17.0.0
    // timezone: ^0.9.2
    /*
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'class_reminders',
      'Class Reminders',
      channelDescription: 'Notifications for upcoming classes',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      session.id.hashCode,
      'Sắp có lớp học',
      '${session.title} - ${session.location}\nBắt đầu lúc ${_formatTime(session.startTime)}',
      tz.TZDateTime.from(reminderTime, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'class_reminder_${session.id}',
    );
    */
  }

  // Schedule multiple class reminders
  Future<void> scheduleClassReminders(List<ClassSession> sessions) async {
    for (final session in sessions) {
      await scheduleClassReminder(session);
    }

    if (kDebugMode) {
      print('Scheduled ${sessions.length} class reminders');
    }
  }

  // Cancel specific notification
  Future<void> cancelClassReminder(String sessionId) async {
    if (kDebugMode) {
      print('Cancelled reminder for session: $sessionId');
    }

    // TODO: Implement actual cancellation
    // await _flutterLocalNotificationsPlugin.cancel(sessionId.hashCode);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (kDebugMode) {
      print('Cancelled all notifications');
    }

    // TODO: Implement actual cancellation
    // await _flutterLocalNotificationsPlugin.cancelAll();
  }

  // Show immediate notification
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    if (kDebugMode) {
      print('Immediate notification: $title - $body');
    }

    // TODO: Implement actual immediate notification
    /*
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'immediate_notifications',
      'Immediate Notifications',
      channelDescription: 'Immediate notifications for app events',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
    */
  }

  // Test notification
  Future<void> showTestNotification() async {
    await showImmediateNotification(
      title: 'Test Notification',
      body: 'This is a test notification from Attendify',
      payload: 'test_notification',
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Get pending notifications count (mock)
  Future<int> getPendingNotificationCount() async {
    return 0; // Mock return
  }

  // Schedule daily reminder for lecturers
  Future<void> scheduleDailyLecturerReminder() async {
    if (!_initialized) await initialize();

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 8, 0);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    if (kDebugMode) {
      print('Scheduled daily reminder for ${_formatTime(scheduledDate)}');
    }

    // TODO: Implement actual daily scheduling
  }

  // Auto schedule notifications for upcoming sessions
  Future<void> autoScheduleUpcomingReminders(
    List<ClassSession> sessions,
  ) async {
    // Cancel existing notifications first
    await cancelAllNotifications();

    // Filter sessions that are upcoming (next 7 days)
    final upcomingSessions = sessions.where((session) {
      final now = DateTime.now();
      final weekFromNow = now.add(const Duration(days: 7));
      return session.startTime.isAfter(now) &&
          session.startTime.isBefore(weekFromNow);
    }).toList();

    // Schedule reminders for upcoming sessions
    await scheduleClassReminders(upcomingSessions);

    // Schedule daily reminder
    await scheduleDailyLecturerReminder();

    if (kDebugMode) {
      print('Auto-scheduled ${upcomingSessions.length} upcoming reminders');
    }
  }

  // Check if notifications are enabled
  bool get isInitialized => _initialized;

  // Request permissions (for future implementation)
  Future<bool> requestPermissions() async {
    if (kDebugMode) {
      print('Notification permissions requested (mock)');
    }
    return true; // Mock return
  }
}
