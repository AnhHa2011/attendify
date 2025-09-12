// lib/data/models/class_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ClassSchedule không cần thay đổi, có thể giữ nguyên ở đây hoặc tách file riêng.
class ClassSchedule {
  final int day;
  final String start;
  final String end;
  const ClassSchedule({
    required this.day,
    required this.start,
    required this.end,
  });
  Map<String, dynamic> toMap() => {'day': day, 'start': start, 'end': end};
  factory ClassSchedule.fromMap(Map<String, dynamic> m) => ClassSchedule(
    day: m['day'] as int,
    start: m['start'] as String,
    end: m['end'] as String,
  );
}

class ClassModel {
  // === Dữ liệu gốc, lưu trên Firestore ===
  final String id;
  final String courseId; // THAY ĐỔI: Tham chiếu tới collection 'courses'
  final String lecturerId; // THAY ĐỔI: Tham chiếu tới collection 'users'
  final String semester; // THÊM MỚI
  final List<ClassSchedule> schedules;
  final int maxAbsences;
  final String joinCode;
  final DateTime createdAt;

  // === Dữ liệu "làm giàu", không lưu trên Firestore, chỉ dùng ở UI ===
  // Được gán sau khi truy vấn từ các collection khác
  final String? courseName;
  final String? courseCode;
  final String? lecturerName;

  ClassModel({
    required this.id,
    required this.courseId,
    required this.lecturerId,
    required this.semester,
    required this.schedules,
    required this.maxAbsences,
    required this.joinCode,
    required this.createdAt,
    // Các trường "làm giàu" là tùy chọn
    this.courseName,
    this.courseCode,
    this.lecturerName,
  });

  // Tạo một bản sao của đối tượng với các giá trị được cập nhật
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
      schedules: schedules,
      maxAbsences: maxAbsences,
      joinCode: joinCode,
      createdAt: createdAt,
      courseName: courseName ?? this.courseName,
      courseCode: courseCode ?? this.courseCode,
      lecturerName: lecturerName ?? this.lecturerName,
    );
  }

  // toMap chỉ chứa các trường dữ liệu gốc để ghi lên Firestore
  Map<String, dynamic> toMap() => {
    'courseId': courseId,
    'lecturerId': lecturerId,
    'semester': semester,
    'schedules': schedules.map((e) => e.toMap()).toList(),
    'maxAbsences': maxAbsences,
    'joinCode': joinCode,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory ClassModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ClassModel(
      id: doc.id,
      courseId: (d['courseId'] ?? '') as String,
      lecturerId: (d['lecturerId'] ?? '') as String,
      semester: (d['semester'] ?? '') as String,
      schedules: (d['schedules'] as List? ?? const [])
          .map((e) => ClassSchedule.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      maxAbsences: (d['maxAbsences'] ?? 0) as int,
      joinCode: (d['joinCode'] ?? '') as String,
      createdAt: ((d['createdAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
    );
  }
}
