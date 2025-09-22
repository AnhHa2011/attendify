// lib/features/common/data/models/class_schedule_model.dart

import 'package:flutter/material.dart';

class ClassSchedule {
  final int dayOfWeek;
  final TimeOfDay startTime;

  const ClassSchedule({required this.dayOfWeek, required this.startTime});

  // === THÊM HÀM NÀY VÀO ĐÂY ===
  Map<String, dynamic> toMap() {
    return {
      'day': dayOfWeek,
      // Lưu giờ và phút dưới dạng số để dễ truy vấn và xử lý
      'hour': startTime.hour,
      'minute': startTime.minute,
    };
  }

  // (Bạn cũng có thể thêm hàm fromMap nếu cần sau này)
}
