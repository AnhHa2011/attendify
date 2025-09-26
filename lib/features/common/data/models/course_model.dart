// lib/features/common/data/models/course_model.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourseModel {
  final String id;
  final String courseCode;
  final String courseName;
  final int credits;
  final bool isArchived;

  // New fields for enhanced course management
  final int minStudents;
  final int maxStudents;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? lecturerId; // Assigned lecturer
  final String? lecturerName; // Populated from lecturer info
  final String? lecturerEmail; // Populated from lecturer info
  final List<String> enrolledStudents; // Student UIDs enrolled in this course
  final String? description;
  final String? semester;

  CourseModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.credits,
    required this.isArchived,
    this.minStudents = 10,
    this.maxStudents = 50,
    this.startDate,
    this.endDate,
    this.lecturerId,
    this.lecturerName,
    this.lecturerEmail,
    this.enrolledStudents = const [],
    this.description,
    this.semester,
  });

  // Enhanced factory constructor
  factory CourseModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CourseModel(
      id: doc.id,
      courseCode: data['courseCode'] ?? '',
      courseName: data['courseName'] ?? '',
      credits: data['credits'] ?? 0,
      isArchived: data['isArchived'] ?? false,
      minStudents: data['minStudents'] ?? 10,
      maxStudents: data['maxStudents'] ?? 50,
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : null,
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      lecturerId: data['lecturerId'],
      lecturerName: data['lecturerName'],
      lecturerEmail: data['lecturerEmail'],
      enrolledStudents: List<String>.from(data['enrolledStudents'] ?? []),
      description: data['description'],
      semester: data['semester'],
    );
  }

  // Enhanced toMap method
  Map<String, dynamic> toMap() {
    return {
      'courseCode': courseCode,
      'courseName': courseName,
      'credits': credits,
      'isArchived': isArchived,
      'minStudents': minStudents,
      'maxStudents': maxStudents,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'lecturerId': lecturerId,
      'lecturerName': lecturerName,
      'lecturerEmail': lecturerEmail,
      'enrolledStudents': enrolledStudents,
      'description': description,
      'semester': semester,
    };
  }

  // copyWith method for easy updates
  CourseModel copyWith({
    String? id,
    String? courseCode,
    String? courseName,
    int? credits,
    bool? isArchived,
    int? minStudents,
    int? maxStudents,
    DateTime? startDate,
    DateTime? endDate,
    String? lecturerId,
    String? lecturerName,
    String? lecturerEmail,
    List<String>? enrolledStudents,
    String? description,
    String? semester,
  }) {
    return CourseModel(
      id: id ?? this.id,
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      credits: credits ?? this.credits,
      isArchived: isArchived ?? this.isArchived,
      minStudents: minStudents ?? this.minStudents,
      maxStudents: maxStudents ?? this.maxStudents,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      lecturerId: lecturerId ?? this.lecturerId,
      lecturerName: lecturerName ?? this.lecturerName,
      lecturerEmail: lecturerEmail ?? this.lecturerEmail,
      enrolledStudents: enrolledStudents ?? this.enrolledStudents,
      description: description ?? this.description,
      semester: semester ?? this.semester,
    );
  }

  // Helper methods
  bool get hasLecturer => lecturerId != null && lecturerId!.isNotEmpty;

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
  CourseModel.empty()
    : this(
        id: '',
        courseCode: 'N/A',
        courseName: 'Không rõ',
        credits: 0,
        isArchived: false,
        minStudents: 0,
        maxStudents: 0,
      );
}

// Enum for course status
enum CourseStatus { upcoming, active, completed, cancelled }

extension CourseStatusExtension on CourseStatus {
  String get displayName {
    switch (this) {
      case CourseStatus.upcoming:
        return 'Sắp diễn ra';
      case CourseStatus.active:
        return 'Đang diễn ra';
      case CourseStatus.completed:
        return 'Đã kết thúc';
      case CourseStatus.cancelled:
        return 'Đã hủy';
    }
  }

  Color get color {
    switch (this) {
      case CourseStatus.upcoming:
        return const Color(0xFF3B82F6); // Blue
      case CourseStatus.active:
        return const Color(0xFF10B981); // Green
      case CourseStatus.completed:
        return const Color(0xFF6B7280); // Gray
      case CourseStatus.cancelled:
        return const Color(0xFFEF4444); // Red
    }
  }
}

// Extension for CourseModel
extension CourseModelExtension on CourseModel {
  CourseStatus get status {
    final now = DateTime.now();

    if (startDate != null && now.isBefore(startDate!)) {
      return CourseStatus.upcoming;
    }

    if (endDate != null && now.isAfter(endDate!)) {
      return CourseStatus.completed;
    }

    if (startDate != null && endDate != null) {
      if (now.isAfter(startDate!) && now.isBefore(endDate!)) {
        return CourseStatus.active;
      }
    }

    return CourseStatus.active; // Default to active if dates are not set
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
