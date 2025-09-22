// lib/data/models/class_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  // === Dữ liệu gốc, lưu trên Firestore ===
  final String id;
  final String courseId;
  final String lecturerId;
  final String semester;
  final String? className;
  final String joinCode;
  final DateTime createdAt;
  final bool isArchived;

  // === Dữ liệu "làm giàu" ===
  final String? courseName;
  final String? courseCode;
  final String? lecturerName;

  ClassModel({
    required this.id,
    required this.courseId,
    required this.lecturerId,
    required this.semester,
    this.className, // <-- THÊM MỚI
    required this.joinCode,
    required this.createdAt,
    required this.isArchived, // <-- THÊM MỚI
    this.courseName,
    this.courseCode,
    this.lecturerName,
  });

  ClassModel copyWith({
    String? courseName,
    String? courseCode,
    String? lecturerName,
  }) {
    return ClassModel(
      id: id,
      courseId: courseId,
      lecturerId: lecturerId,
      semester: semester,
      className: className,
      joinCode: joinCode,
      createdAt: createdAt,
      isArchived: isArchived,
      courseName: courseName ?? this.courseName,
      courseCode: courseCode ?? this.courseCode,
      lecturerName: lecturerName ?? this.lecturerName,
    );
  }

  factory ClassModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ClassModel(
      id: doc.id,
      courseId: d['courseId'] ?? '',
      lecturerId: d['lecturerId'] ?? '',
      semester: d['semester'] ?? '',
      className: d['className'], // có thể null
      joinCode: d['joinCode'] ?? '',
      createdAt: ((d['createdAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
      isArchived: d['isArchived'] ?? false, // Mặc định là false nếu không có
    );
  }
}
