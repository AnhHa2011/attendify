// lib/features/common/data/models/class_model.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String classCode;
  final String className;
  final bool isArchived;

  // New fields for enhanced class management
  final int minStudents;
  final int maxStudents;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> enrolledStudents; // Student UIDs enrolled in this class
  final String? description;

  ClassModel({
    required this.id,
    required this.classCode,
    required this.className,
    required this.isArchived,
    this.minStudents = 10,
    this.maxStudents = 50,
    this.startDate,
    this.endDate,
    this.enrolledStudents = const [],
    this.description,
  });

  // Enhanced factory constructor
  factory ClassModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassModel(
      id: doc.id,
      classCode: data['classCode'] ?? '',
      className: data['className'] ?? '',
      isArchived: data['isArchived'] ?? false,
      minStudents: data['minStudents'] ?? 10,
      maxStudents: data['maxStudents'] ?? 50,
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : null,
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      enrolledStudents: List<String>.from(data['enrolledStudents'] ?? []),
      description: data['description'],
    );
  }

  // Enhanced toMap method
  Map<String, dynamic> toMap() {
    return {
      'classCode': classCode,
      'className': className,
      'isArchived': isArchived,
      'minStudents': minStudents,
      'maxStudents': maxStudents,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'enrolledStudents': enrolledStudents,
      'description': description,
    };
  }

  // copyWith method for easy updates
  ClassModel copyWith({
    String? id,
    String? classCode,
    String? className,
    int? credits,
    bool? isArchived,
    int? minStudents,
    int? maxStudents,
    DateTime? startDate,
    DateTime? endDate,
    String? lecturerId,
    String? lecturerName,
    List<String>? enrolledStudents,
    String? description,
    String? semester,
  }) {
    return ClassModel(
      id: id ?? this.id,
      classCode: classCode ?? this.classCode,
      className: className ?? this.className,
      isArchived: isArchived ?? this.isArchived,
      minStudents: minStudents ?? this.minStudents,
      maxStudents: maxStudents ?? this.maxStudents,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      enrolledStudents: enrolledStudents ?? this.enrolledStudents,
      description: description ?? this.description,
    );
  }

  bool get isEnrollmentOpen {
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return enrolledStudents.length < maxStudents;
  }

  bool get isEnrollmentFull => enrolledStudents.length >= maxStudents;

  int get availableSlots => maxStudents - enrolledStudents.length;

  double get enrollmentPercentage =>
      maxStudents > 0 ? (enrolledStudents.length / maxStudents) * 100 : 0;

  bool canEnrollStudent() => isEnrollmentOpen && !isEnrollmentFull;

  // Empty constructor for placeholder
  ClassModel.empty()
    : this(
        id: '',
        classCode: 'N/A',
        className: 'Không rõ',
        isArchived: false,
        minStudents: 0,
        maxStudents: 0,
      );
}

// Enum for class status
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
        return const Color(0xFF3B82F6); // Blue
      case ClassStatus.active:
        return const Color(0xFF10B981); // Green
      case ClassStatus.completed:
        return const Color(0xFF6B7280); // Gray
      case ClassStatus.cancelled:
        return const Color(0xFFEF4444); // Red
    }
  }
}

// Extension for ClassModel
extension ClassModelExtension on ClassModel {
  ClassStatus get status {
    final now = DateTime.now();

    if (startDate != null && now.isBefore(startDate!)) {
      return ClassStatus.upcoming;
    }

    if (endDate != null && now.isAfter(endDate!)) {
      return ClassStatus.completed;
    }

    if (startDate != null && endDate != null) {
      if (now.isAfter(startDate!) && now.isBefore(endDate!)) {
        return ClassStatus.active;
      }
    }

    return ClassStatus.active; // Default to active if dates are not set
  }

  String get dateRangeString {
    if (startDate == null && endDate == null) return 'Chưa xác định';

    final startStr = startDate != null
        ? '${startDate!.day}/${startDate!.month}/${startDate!.year}'
        : 'Chưa xác định';

    final endStr = endDate != null
        ? '${endDate!.day}/${endDate!.month}/${endDate!.year}'
        : 'Chưa xác định';

    return '$startStr - $endStr';
  }

  String get enrollmentInfo =>
      '${enrolledStudents.length}/$maxStudents sinh viên';
}
