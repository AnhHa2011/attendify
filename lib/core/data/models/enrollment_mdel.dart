import 'package:attendify/app_imports.dart';

class EnrollmentModel {
  final String enrollmentId;
  final String studentUid;
  final DateTime joinDate;
  final String courseCode;

  EnrollmentModel({
    required this.enrollmentId,
    required this.studentUid,
    required this.joinDate,
    required this.courseCode,
  });

  factory EnrollmentModel.fromMap(Map<String, dynamic> map) {
    return EnrollmentModel(
      enrollmentId: map['enrollmentId'],
      studentUid: map['studentUid'],
      joinDate: map['joinDate'],
      courseCode: map['courseCode'],
    );
  }
  factory EnrollmentModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EnrollmentModel(
      enrollmentId: data['courseCode'] ?? '',
      studentUid: data['studentUid'] ?? '',
      courseCode: data['courseCode'] ?? '',
      joinDate: (data['joinDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
