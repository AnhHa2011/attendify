// lib/features/common/data/models/course_schedule_model.dart

import 'package:attendify/app_imports.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';

/// Mô tả lịch học trong tuần cho một môn học
/// Dùng để tạo recurring sessions
class CourseSchedule {
  /// Ngày trong tuần (1 = Thứ 2, 2 = Thứ 3, ..., 7 = Chủ nhật)
  final int dayOfWeek;

  /// Giờ bắt đầu
  final TimeOfDay startTime;

  /// Giờ kết thúc
  final TimeOfDay endTime;

  /// Phòng học
  final String room;

  const CourseSchedule({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.room,
  });

  /// Tên ngày trong tuần (tiếng Việt)
  String get dayName {
    switch (dayOfWeek) {
      case 1:
        return 'Thứ 2';
      case 2:
        return 'Thứ 3';
      case 3:
        return 'Thứ 4';
      case 4:
        return 'Thứ 5';
      case 5:
        return 'Thứ 6';
      case 6:
        return 'Thứ 7';
      case 7:
        return 'Chủ nhật';
      default:
        return 'Không xác định';
    }
  }

  /// Định dạng giờ
  String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Format giờ học: ví dụ "08:00 - 09:30"
  String get timeRange =>
      '${formatTimeOfDay(startTime)} - ${formatTimeOfDay(endTime)}';

  /// Mô tả đầy đủ: "Thứ 2, 08:00 - 09:30, Phòng A101"
  String get description => '$dayName, $timeRange, $room';

  /// Copy with new values
  CourseSchedule copyWith({
    int? dayOfWeek,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? room,
  }) {
    return CourseSchedule(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
    );
  }

  /// Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'dayOfWeek': dayOfWeek,
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'room': room,
    };
  }

  /// Create from Map
  factory CourseSchedule.fromDoc(Map<String, dynamic> map) {
    return CourseSchedule(
      dayOfWeek: map['dayOfWeek'] ?? 1,
      startTime: TimeOfDay(
        hour: map['startHour'] ?? 7,
        minute: map['startMinute'] ?? 0,
      ),
      endTime: TimeOfDay(
        hour: map['endHour'] ?? 9,
        minute: map['endMinute'] ?? 0,
      ),
      room: map['room'] ?? 'Chưa xác định',
    );
  }

  factory CourseSchedule.empty() {
    final now = Timestamp.now().toDate();
    final start = TimeOfDay(hour: now.hour, minute: now.minute);
    final end = TimeOfDay(hour: (now.hour + 1) % 24, minute: now.minute);
    return CourseSchedule(
      dayOfWeek: 1,
      startTime: start,
      endTime: end,
      room: 'Chưa có phòng',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CourseSchedule &&
        other.dayOfWeek == dayOfWeek &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.room == room;
  }

  @override
  int get hashCode =>
      dayOfWeek.hashCode ^
      startTime.hashCode ^
      endTime.hashCode ^
      room.hashCode;

  @override
  String toString() {
    return 'CourseSchedule(dayOfWeek: $dayOfWeek, startTime: $startTime, endTime: $endTime, room: $room)';
  }
}

/// Extension để làm việc với danh sách CourseSchedule
extension CourseScheduleListExtension on List<CourseSchedule> {
  /// Sắp xếp theo ngày trong tuần
  List<CourseSchedule> sortByDay() {
    final sorted = List<CourseSchedule>.from(this);
    sorted.sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    return sorted;
  }

  /// Nhóm theo ngày
  Map<int, List<CourseSchedule>> groupByDay() {
    final groups = <int, List<CourseSchedule>>{};
    for (final schedule in this) {
      groups.putIfAbsent(schedule.dayOfWeek, () => []).add(schedule);
    }
    return groups;
  }

  /// Mô tả ngắn gọn tất cả lịch
  String get briefDescription {
    if (isEmpty) return 'Chưa có lịch';
    if (length == 1) return first.description;

    final groups = groupByDay();
    final descriptions = groups.entries
        .map((entry) {
          final dayName = CourseSchedule(
            dayOfWeek: entry.key,
            startTime: const TimeOfDay(hour: 0, minute: 0),
            endTime: const TimeOfDay(hour: 0, minute: 0),
            room: '',
          ).dayName;

          final times = entry.value.map((s) => s.timeRange).join(', ');
          return '$dayName ($times)';
        })
        .join('; ');

    return descriptions;
  }
}
