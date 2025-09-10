import 'package:cloud_firestore/cloud_firestore.dart';

class ClassSchedule {
  final int day; // 1 = Mon ... 7 = Sun
  final String start; // HH:mm
  final String end; // HH:mm
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
  final String id;
  final String className; // tên môn
  final String classCode; // mã môn
  final String lecturerId; // uid giảng viên
  final String lecturerName;
  final String lecturerEmail;
  final List<ClassSchedule> schedules;
  final int maxAbsences;
  final String joinCode;
  final DateTime createdAt;

  ClassModel({
    required this.id,
    required this.className,
    required this.classCode,
    required this.lecturerId,
    required this.lecturerName,
    required this.lecturerEmail,
    required this.schedules,
    required this.maxAbsences,
    required this.joinCode,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'className': className,
    'classCode': classCode,
    'lecturerId': lecturerId,
    'lecturerName': lecturerName,
    'lecturerEmail': lecturerEmail,
    'schedules': schedules.map((e) => e.toMap()).toList(),
    'maxAbsences': maxAbsences,
    'joinCode': joinCode,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory ClassModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ClassModel(
      id: doc.id,
      className: (d['className'] ?? '') as String,
      classCode: (d['classCode'] ?? '') as String,
      lecturerId: (d['lecturerId'] ?? '') as String,
      lecturerName: (d['lecturerName'] ?? '') as String,
      lecturerEmail: (d['lecturerEmail'] ?? '') as String,
      schedules: (d['schedules'] as List? ?? const [])
          .map((e) => ClassSchedule.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      maxAbsences: (d['maxAbsences'] ?? 0) as int,
      joinCode: (d['joinCode'] ?? '') as String,
      createdAt: ((d['createdAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
    );
  }
}
