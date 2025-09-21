// lib/features/notifications/local_notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Service thông báo cục bộ (giữ tương thích với cách gọi cũ)
class LocalNotificationService {
  // ===== Singleton (tương thích code cũ) =====
  LocalNotificationService._internal();
  static final LocalNotificationService _singleton =
      LocalNotificationService._internal();
  static LocalNotificationService get instance => _singleton;

  /// Static helper giữ tương thích: gọi xin quyền nếu cần
  static Future<void> requestPermissionsIfNeeded() async {
    await instance.requestPermissions();
  }

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Kênh Android
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'attendify_reminders',
        'Attendify Reminders',
        description: 'Nhắc lịch học & thông báo trong Attendify',
        importance: Importance.high,
      );

  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;

    // Init plugin
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(initSettings);

    // Tạo notification channel (Android)
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        // Lưu ý: tùy version plugin mà tên method có thể khác.
        ?.createNotificationChannel(_androidChannel);

    // Timezone phục vụ schedule
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    _inited = true;
  }

  /// Android 13+ và iOS cần runtime permission
  Future<void> requestPermissions() async {
    // Android
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        // Trên một số version là requestNotificationsPermission()
        ?.requestNotificationsPermission();

    // iOS/macOS
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Hiện thông báo NGAY
  Future<void> showNow({
    int id = 0,
    required String title,
    required String body,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// Lên lịch thông báo tại thời điểm [when] (local time)
  Future<void> scheduleAt({
    int id = 0,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzWhen,
      details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      payload: payload,
    );
  }

  /// Tiện ích: nhắc trước 1 giờ buổi học (nếu còn ở tương lai)
  Future<void> scheduleOneHourBefore({
    required DateTime startTime,
    required String title,
    required String body,
    int id = 0,
  }) async {
    final when = startTime.subtract(const Duration(hours: 1));
    if (when.isAfter(DateTime.now())) {
      await scheduleAt(id: id, when: when, title: title, body: body);
    }
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();
}
