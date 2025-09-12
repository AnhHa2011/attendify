// lib/data/models/course_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CourseModel {
  final String id;
  final String courseCode;
  final String courseName;
  final int credits;

  CourseModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.credits,
  });

  factory CourseModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CourseModel(
      id: doc.id,
      courseCode: data['courseCode'] ?? '',
      courseName: data['courseName'] ?? '',
      credits: data['credits'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseCode': courseCode,
      'courseName': courseName,
      'credits': credits,
    };
  }
}
