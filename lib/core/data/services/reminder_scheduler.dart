import 'package:attendify/features/notifications/local_notification_service.dart';
import 'package:attendify/core/data/services/schedule_service.dart';
import 'package:intl/intl.dart';

class ReminderScheduler {
  final ScheduleService scheduleService;
  ReminderScheduler(this.scheduleService);

  /// Gọi khi user đăng nhập / mở app / kéo refresh.
  Future<void> rescheduleForUser({
    required String uid,
    required bool isLecturer,
  }) async {
    // Xoá lịch cũ để tránh trùng
    await LocalNotificationService.instance.cancelAll();

    final now = DateTime.now();
    final to = now.add(const Duration(days: 30));

    final sessions = isLecturer
        ? await scheduleService
              .lecturerSessions(lecturerUid: uid, from: now, to: to)
              .first
        : await scheduleService
              .studentSessions(studentUid: uid, from: now, to: to)
              .first;

    for (final s in sessions) {
      final start =
          (s['startAt'] as DateTime?) ?? (s['startTime'] as DateTime?);
      if (start == null) continue;

      final remindAt = start.subtract(const Duration(hours: 1));
      if (remindAt.isBefore(now)) continue;

      final title = 'Sắp đến giờ học';
      final timeStr = DateFormat('HH:mm dd/MM').format(start);
      final course =
          (s['title'] as String?) ?? (s['courseName'] as String?) ?? 'Buổi học';
      final room = (s['location'] as String?) ?? '';
      final body =
          '$course • $timeStr${room.isNotEmpty ? " • Phòng $room" : ""}';

      final id = (s['id'] as String).hashCode & 0x7fffffff;
      await LocalNotificationService.instance.scheduleAt(
        id: id,
        title: title,
        body: body,
        when: remindAt,
        payload: s['id'] as String?,
      );
    }
  }
}
