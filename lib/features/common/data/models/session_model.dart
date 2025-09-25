import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionStatus {
  scheduled, // <-- ĐỔI TÊN: từ upcoming thành scheduled
  inProgress, // <-- ĐỔI TÊN: từ ongoing thành inProgress
  completed,
  cancelled,
}

enum SessionType {
  lecture, // Lý thuyết
  practice, // Thực hành
  exam, // Kiểm tra
  review, // Ôn tập
}

class SessionModel {
  final String id;
  final String classId;
  final String courseId; // <<<--- ĐÂY LÀ TRƯỜNG CỐT LÕI CẦN THÊM

  // Các trường denormalized (lưu sẵn để tăng tốc độ đọc)
  final String className;
  final String classCode;
  final String lecturerId;
  final String lecturerName;

  // Các trường thông tin chính của buổi học
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final SessionType type;
  final SessionStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int totalStudents;
  final int attendedStudents;
  final bool isAttendanceOpen;
  final String? qrCode; // QR code for attendance
  final Map<String, String> attendanceStatus; // studentId -> status (present/absent/late)

  SessionModel({
    required this.id,
    required this.classId,
    required this.courseId, // <<<--- THÊM VÀO CONSTRUCTOR
    required this.className,
    required this.classCode,
    required this.lecturerId,
    required this.lecturerName,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.type,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.totalStudents = 0,
    this.attendedStudents = 0,
    this.isAttendanceOpen = false,
    this.qrCode,
    this.attendanceStatus = const {},
  });

  // Duration of the session
  Duration get duration => endTime.difference(startTime);

  // Is session happening now?
  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  // Time until session starts (if upcoming)
  Duration? get timeUntilStart {
    final now = DateTime.now();
    if (now.isBefore(startTime)) {
      return startTime.difference(now);
    }
    return null;
  }

  // Attendance percentage
  double get attendancePercentage {
    if (totalStudents == 0) return 0.0;
    return (attendedStudents / totalStudents) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'courseId': courseId,
      'className': className,
      'classCode': classCode,
      'lecturerId': lecturerId,
      'lecturerName': lecturerName,
      'title': title,
      'description': description,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'location': location,
      'type': type.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'totalStudents': totalStudents,
      'attendedStudents': attendedStudents,
      'isAttendanceOpen': isAttendanceOpen,
      'qrCode': qrCode,
      'attendanceStatus': attendanceStatus,
    };
  }

  factory SessionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    // Hàm helper để parse Timestamp một cách an toàn
    DateTime parseTimestamp(dynamic timestamp, {required DateTime fallback}) {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      }
      return fallback;
    }

    return SessionModel(
      id: doc.id,
      classId: data['classId'] ?? '',
      courseId: data['courseId'] ?? '',
      className: data['className'] ?? '',
      classCode: data['classCode'] ?? '',
      lecturerId: data['lecturerId'] ?? '',
      lecturerName: data['lecturerName'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      // SỬA LỖI: Sử dụng hàm helper để tránh lỗi null
      startTime: parseTimestamp(data['startTime'], fallback: DateTime.now()),
      endTime: parseTimestamp(data['endTime'], fallback: DateTime.now()),
      location: data['location'] ?? '',
      type: SessionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => SessionType.lecture,
      ),
      status: SessionStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => SessionStatus.scheduled,
      ),
      // SỬA LỖI: Sử dụng hàm helper cho createdAt
      createdAt: parseTimestamp(data['createdAt'], fallback: DateTime.now()),
      updatedAt: data['updatedAt'] != null
          ? parseTimestamp(data['updatedAt'], fallback: DateTime.now())
          : null,
      totalStudents: data['totalStudents'] ?? 0,
      attendedStudents: data['attendedStudents'] ?? 0,
      isAttendanceOpen: data['isAttendanceOpen'] ?? false,
      qrCode: data['qrCode'],
      attendanceStatus: Map<String, String>.from(data['attendanceStatus'] ?? {}),
    );
  }

  SessionModel copyWith({
    String? id,
    String? classId,
    String? courseId,
    String? className,
    String? classCode,
    String? lecturerId,
    String? lecturerName,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    SessionType? type,
    SessionStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalStudents,
    int? attendedStudents,
    bool? isAttendanceOpen,
    String? qrCode,
    Map<String, String>? attendanceStatus,
  }) {
    return SessionModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      courseId: courseId ?? this.courseId,
      className: className ?? this.className,
      classCode: classCode ?? this.classCode,
      lecturerId: lecturerId ?? this.lecturerId,
      lecturerName: lecturerName ?? this.lecturerName,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalStudents: totalStudents ?? this.totalStudents,
      attendedStudents: attendedStudents ?? this.attendedStudents,
      isAttendanceOpen: isAttendanceOpen ?? this.isAttendanceOpen,
    );
  }
}

// Extension for easy formatting
extension SessionModelExtension on SessionModel {
  String get typeDisplayName {
    switch (type) {
      case SessionType.lecture:
        return 'Lý thuyết';
      case SessionType.practice:
        return 'Thực hành';
      case SessionType.exam:
        return 'Kiểm tra';
      case SessionType.review:
        return 'Ôn tập';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case SessionStatus.scheduled: // <-- ĐỔI TÊN
        return 'Đã lên lịch';
      case SessionStatus.inProgress: // <-- ĐỔI TÊN
        return 'Đang diễn ra';
      case SessionStatus.completed:
        return 'Đã kết thúc';
      case SessionStatus.cancelled:
        return 'Đã hủy';
    }
  }

  String get timeRangeString {
    final startStr =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$startStr - $endStr';
  }

  String get dateString {
    final weekdays = [
      '',
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
      'Chủ nhật',
    ];
    final weekday = weekdays[startTime.weekday];
    final date =
        '${startTime.day.toString().padLeft(2, '0')}/${startTime.month.toString().padLeft(2, '0')}';
    return '$weekday, $date';
  }
}
