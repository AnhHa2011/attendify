// lib/features/common/data/models/class_schedule_model.dart

import 'package:flutter/material.dart';

/// Mô tả lịch học trong tuần cho một lớp học
/// Dùng để tạo recurring sessions
class ClassSchedule {
  /// Ngày trong tuần (1 = Thứ 2, 2 = Thứ 3, ..., 7 = Chủ nhật)
  final int dayOfWeek;
  
  /// Giờ bắt đầu
  final TimeOfDay startTime;
  
  const ClassSchedule({
    required this.dayOfWeek,
    required this.startTime,
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

  /// Format thời gian dễ đọc
  String formatTime() {
    final hour = startTime.hour.toString().padLeft(2, '0');
    final minute = startTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Mô tả đầy đủ
  String get description => '$dayName, $formatTime()';

  /// Copy with new values
  ClassSchedule copyWith({
    int? dayOfWeek,
    TimeOfDay? startTime,
  }) {
    return ClassSchedule(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
    );
  }

  /// Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'dayOfWeek': dayOfWeek,
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
    };
  }

  /// Create from Map
  factory ClassSchedule.fromMap(Map<String, dynamic> map) {
    return ClassSchedule(
      dayOfWeek: map['dayOfWeek'] ?? 1,
      startTime: TimeOfDay(
        hour: map['startHour'] ?? 7,
        minute: map['startMinute'] ?? 0,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClassSchedule &&
        other.dayOfWeek == dayOfWeek &&
        other.startTime == startTime;
  }

  @override
  int get hashCode => dayOfWeek.hashCode ^ startTime.hashCode;

  @override
  String toString() {
    return 'ClassSchedule(dayOfWeek: $dayOfWeek, startTime: $startTime)';
  }
}

/// Extension để làm việc với danh sách ClassSchedule
extension ClassScheduleListExtension on List<ClassSchedule> {
  /// Sắp xếp theo ngày trong tuần
  List<ClassSchedule> sortByDay() {
    final sorted = List<ClassSchedule>.from(this);
    sorted.sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    return sorted;
  }

  /// Nhóm theo ngày
  Map<int, List<ClassSchedule>> groupByDay() {
    final groups = <int, List<ClassSchedule>>{};
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
    final descriptions = groups.entries.map((entry) {
      final dayName = ClassSchedule(dayOfWeek: entry.key, startTime: const TimeOfDay(hour: 0, minute: 0)).dayName;
      final times = entry.value.map((s) => s.formatTime()).join(', ');
      return '$dayName ($times)';
    }).join('; ');
    
    return descriptions;
  }
}
