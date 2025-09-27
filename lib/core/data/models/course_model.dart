import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_schedule_model.dart';

class CourseModel {
  final String id; // documentId
  final String courseCode;
  final String courseName;
  final String lecturerId;
  final int minStudents;
  final int maxStudents;
  final String semester;
  final int credits;
  final int maxAbsences;
  final List<CourseSchedule> schedules;
  final bool isArchived;
  final String joinCode;
  final DateTime createdAt;
  final String description;
  final DateTime startDate;
  final DateTime endDate;

  CourseModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.lecturerId,
    required this.minStudents,
    required this.maxStudents,
    required this.semester,
    required this.credits,
    required this.maxAbsences,
    required this.schedules,
    required this.isArchived,
    required this.joinCode,
    required this.createdAt,
    required this.startDate,
    required this.endDate,
    required this.description,
  });

  factory CourseModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CourseModel(
      id: doc.id,
      courseCode: data['courseCode'] ?? '',
      courseName: data['courseName'] ?? '',
      lecturerId: data['lecturerId'] ?? '',
      minStudents: data['minStudents'] ?? 0,
      maxStudents: data['maxStudents'] ?? 0,
      semester: data['semester'] ?? '',
      credits: (data['credits'] ?? 0) as int,
      maxAbsences: (data['maxAbsences'] ?? 0) as int,
      schedules: (data['schedules'] as List<dynamic>? ?? [])
          .map((e) => CourseSchedule.fromDoc(e as Map<String, dynamic>))
          .toList(),
      isArchived: data['isArchived'] ?? false,
      joinCode: data['joinCode'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseCode': courseCode,
      'courseName': courseName,
      'lecturerId': lecturerId,
      'minStudents': minStudents,
      'maxStudents': maxStudents,
      'semester': semester,
      'credits': credits,
      'maxAbsences': maxAbsences,
      'schedules': schedules.map((e) => e.toMap()).toList(),
      'isArchived': isArchived,
      'joinCode': joinCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'description': description,
    };
  }

  factory CourseModel.empty() {
    return CourseModel(
      id: '',
      courseCode: '',
      courseName: '',
      lecturerId: '',
      minStudents: 0,
      maxStudents: 0,
      semester: '',
      schedules: [],
      maxAbsences: 0,
      isArchived: false,
      credits: 0,
      joinCode: '',
      createdAt: Timestamp.now().toDate(),
      startDate: Timestamp.now().toDate(),
      endDate: Timestamp.now().toDate(),
      description: '',
    );
  }
}
