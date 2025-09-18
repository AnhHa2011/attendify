// lib/data/models/course_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CourseModel {
  final String id;
  final String courseCode;
  final String courseName;
  final int credits;
  final bool isArchived;

  CourseModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.credits,
    required this.isArchived,
  });

  // Cập nhật hàm fromDoc để xử lý trường mới
  factory CourseModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CourseModel(
      id: doc.id,
      courseCode: data['courseCode'] ?? '',
      courseName: data['courseName'] ?? '',
      credits: data['credits'] ?? 0,
      // QUAN TRỌNG: Nếu trường 'isArchived' không tồn tại trên Firebase,
      // coi như nó là `false`.
      isArchived: data['isArchived'] ?? false,
    );
  }

  // Hàm toMap không cần thay đổi vì ta không cập nhật isArchived từ form
  Map<String, dynamic> toMap() {
    return {
      'courseCode': courseCode,
      'courseName': courseName,
      'credits': credits,
    };
  }
}
