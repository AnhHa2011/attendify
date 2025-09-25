// lib/features/admin/data/models/course_import_model.dart
class WeeklySlot {
  final int dayOfWeek; // 1=Mon ... 7=Sun (ISO-8601)
  final String startTime; // 'HH:mm'
  final String endTime; // 'HH:mm'
  final String room;

  WeeklySlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.room,
  });

  Map<String, dynamic> toJson() => {
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'room': room,
  };
}

class CourseImportModel {
  final String courseCode;
  final String courseName;
  final int credits;
  final String? description;
  final String? lecturerId;
  final String? lecturerEmail;
  final String? lecturerName;
  final int minStudents;
  final int maxStudents;
  final DateTime startDate;
  final DateTime endDate;
  final String? notes;
  final List<WeeklySlot> weeklySchedule;

  CourseImportModel({
    required this.courseCode,
    required this.courseName,
    required this.credits,
    required this.minStudents,
    required this.maxStudents,
    required this.startDate,
    required this.endDate,
    this.description,
    this.lecturerId,
    this.lecturerEmail,
    this.lecturerName,
    this.notes,
    this.weeklySchedule = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'courseCode': courseCode,
      'courseName': courseName,
      'credits': credits,
      'description': description ?? '',
      'lecturerEmail': lecturerEmail ?? '',
      'lecturerId': lecturerId ?? '',
      'minStudents': minStudents,
      'maxStudents': maxStudents,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'notes': notes ?? '',
      'weeklySchedule': weeklySchedule.map((e) => e.toJson()).toList(),
      'createdAt': DateTime.now().toIso8601String(),
      'isActive': true,
    };
  }
}
