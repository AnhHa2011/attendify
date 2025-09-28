// lib/features/common/data/models/class_model.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String classCode;
  final String className;
  final bool isArchived;

  // Quản lý theo năm học
  final int? startYear;
  final int? endYear;

  // Quản lý sĩ số/mô tả
  final int minStudents;
  final int maxStudents;
  final List<String> enrolledStudents;
  final String? description;

  ClassModel({
    required this.id,
    required this.classCode,
    required this.className,
    required this.isArchived,
    this.startYear,
    this.endYear,
    this.minStudents = 10,
    this.maxStudents = 50,
    this.enrolledStudents = const [],
    this.description,
  });

  factory ClassModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ClassModel(
      id: doc.id,
      classCode: data['classCode'] ?? '',
      className: data['className'] ?? '',
      isArchived: data['isArchived'] ?? false,

      startYear: (data['startYear'] as num?)?.toInt(),
      endYear: (data['endYear'] as num?)?.toInt(),

      minStudents: (data['minStudents'] as num?)?.toInt() ?? 10,
      maxStudents: (data['maxStudents'] as num?)?.toInt() ?? 50,

      enrolledStudents: List<String>.from(data['enrolledStudents'] ?? []),
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'classCode': classCode,
      'className': className,
      'isArchived': isArchived,

      'startYear': startYear,
      'endYear': endYear,

      'minStudents': minStudents,
      'maxStudents': maxStudents,

      'enrolledStudents': enrolledStudents,
      'description': description,
    };
  }

  ClassModel copyWith({
    String? id,
    String? classCode,
    String? className,
    bool? isArchived,
    int? startYear,
    int? endYear,
    int? minStudents,
    int? maxStudents,
    List<String>? enrolledStudents,
    String? description,
  }) {
    return ClassModel(
      id: id ?? this.id,
      classCode: classCode ?? this.classCode,
      className: className ?? this.className,
      isArchived: isArchived ?? this.isArchived,

      startYear: startYear ?? this.startYear,
      endYear: endYear ?? this.endYear,

      minStudents: minStudents ?? this.minStudents,
      maxStudents: maxStudents ?? this.maxStudents,
      enrolledStudents: enrolledStudents ?? this.enrolledStudents,
      description: description ?? this.description,
    );
  }

  bool get isEnrollmentOpen {
    // Nếu quản lý theo năm: mở nếu còn slot và năm hiện tại nằm trong [startYear, endYear]
    final year = DateTime.now().year;
    final yearOk = (startYear == null && endYear == null)
        ? true
        : (startYear ?? year) <= year && year <= (endYear ?? year);
    return yearOk && (enrolledStudents.length < maxStudents);
  }

  bool get isEnrollmentFull => enrolledStudents.length >= maxStudents;

  int get availableSlots => maxStudents - enrolledStudents.length;

  double get enrollmentPercentage =>
      maxStudents > 0 ? (enrolledStudents.length / maxStudents) * 100 : 0;

  bool canEnrollStudent() => isEnrollmentOpen && !isEnrollmentFull;
}

enum ClassStatus { upcoming, active, completed, cancelled }

extension ClassStatusExtension on ClassStatus {
  String get displayName {
    switch (this) {
      case ClassStatus.upcoming:
        return 'Sắp diễn ra';
      case ClassStatus.active:
        return 'Đang diễn ra';
      case ClassStatus.completed:
        return 'Đã kết thúc';
      case ClassStatus.cancelled:
        return 'Đã hủy';
    }
  }

  Color get color {
    switch (this) {
      case ClassStatus.upcoming:
        return const Color(0xFF3B82F6);
      case ClassStatus.active:
        return const Color(0xFF10B981);
      case ClassStatus.completed:
        return const Color(0xFF6B7280);
      case ClassStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }
}

extension ClassModelExtension on ClassModel {
  ClassStatus get status {
    final year = DateTime.now().year;

    if (startYear != null && year < startYear!) return ClassStatus.upcoming;
    if (endYear != null && year > endYear!) return ClassStatus.completed;

    if (startYear != null && endYear != null) {
      if (startYear! <= year && year <= endYear!) return ClassStatus.active;
    }
    // Nếu không set năm → mặc định active
    return ClassStatus.active;
  }

  String get dateRangeString {
    if (startYear == null && endYear == null) return 'Chưa xác định';
    final s = startYear?.toString() ?? '—';
    final e = endYear?.toString() ?? '—';
    return '$s - $e';
  }

  String get enrollmentInfo =>
      '${enrolledStudents.length}/$maxStudents sinh viên';
}
