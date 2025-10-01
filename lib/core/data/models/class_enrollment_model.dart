import 'package:attendify/app_imports.dart';

class ClassEnrollmentModel {
  final String studentId;
  final DateTime joinDate;
  final String classCode;

  ClassEnrollmentModel({
    required this.studentId,
    required this.joinDate,
    required this.classCode,
  });

  factory ClassEnrollmentModel.fromMap(Map<String, dynamic> map) {
    return ClassEnrollmentModel(
      studentId: map['studentId'],
      joinDate: map['joinDate'],
      classCode: map['classCode'],
    );
  }
  factory ClassEnrollmentModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassEnrollmentModel(
      studentId: data['studentId'] ?? '',
      classCode: data['classCode'] ?? '',
      joinDate: (data['joinDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
