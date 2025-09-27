import 'package:cloud_firestore/cloud_firestore.dart';

class ClassSession {
  final String id;
  final String courseCode;
  final String lecturerId;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final bool isAttendanceOpen;
  final String? qrCode;
  final DateTime? qrCodeExpiry;
  final List<String> attendedStudents;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClassSession({
    required this.id,
    required this.courseCode,
    required this.lecturerId,
    required this.title,
    this.description = '',
    required this.startTime,
    required this.endTime,
    required this.location,
    this.isAttendanceOpen = false,
    this.qrCode,
    this.qrCodeExpiry,
    this.attendedStudents = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClassSession.fromMap(Map<String, dynamic> map) {
    return ClassSession(
      id: map['id'] ?? '',
      courseCode: map['courseCode'] ?? '',
      lecturerId: map['lecturerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      location: map['location'] ?? '',
      isAttendanceOpen: map['isAttendanceOpen'] ?? false,
      qrCode: map['qrCode'],
      qrCodeExpiry: map['qrCodeExpiry'] != null
          ? (map['qrCodeExpiry'] as Timestamp).toDate()
          : null,
      attendedStudents: List<String>.from(map['attendedStudents'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  factory ClassSession.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassSession.fromMap({...data, 'id': doc.id});
  }

  Map<String, dynamic> toMap() {
    return {
      'courseCode': courseCode,
      'lecturerId': lecturerId,
      'title': title,
      'description': description,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'location': location,
      'isAttendanceOpen': isAttendanceOpen,
      'qrCode': qrCode,
      'qrCodeExpiry': qrCodeExpiry != null
          ? Timestamp.fromDate(qrCodeExpiry!)
          : null,
      'attendedStudents': attendedStudents,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ClassSession copyWith({
    String? id,
    String? courseCode,
    String? lecturerId,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    bool? isAttendanceOpen,
    String? qrCode,
    DateTime? qrCodeExpiry,
    List<String>? attendedStudents,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClassSession(
      id: id ?? this.id,
      courseCode: courseCode ?? this.courseCode,
      lecturerId: lecturerId ?? this.lecturerId,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      isAttendanceOpen: isAttendanceOpen ?? this.isAttendanceOpen,
      qrCode: qrCode ?? this.qrCode,
      qrCodeExpiry: qrCodeExpiry ?? this.qrCodeExpiry,
      attendedStudents: attendedStudents ?? this.attendedStudents,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Duration get duration => endTime.difference(startTime);

  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  bool get isUpcoming => startTime.isAfter(DateTime.now());

  bool get isOngoing {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  bool get isFinished => DateTime.now().isAfter(endTime);

  String get statusText {
    if (isOngoing) return 'Đang diễn ra';
    if (isUpcoming) return 'Sắp tới';
    if (isFinished) return 'Đã kết thúc';
    return 'Không xác định';
  }

  double get attendanceRate {
    // This would need to be calculated with total enrolled students
    // For now, returning 0
    return 0.0;
  }
}
