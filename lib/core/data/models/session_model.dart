import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionStatus {
  scheduled, // trước: upcoming
  inProgress, // trước: ongoing
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
  final String courseCode;

  // Denormalized
  final String courseName;
  final String lecturerId;
  final String lecturerName;

  // Info chính
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final SessionType type;
  final SessionStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Attendance - UPDATED to match QrScannerPage
  final int totalStudents;
  final int attendedStudents;
  final bool
  isOpen; // Changed from isAttendanceOpen to isOpen to match QrScannerPage
  final String? qrCode;
  final Map<String, String>
  attendanceStatus; // studentId -> present/absent/late

  // Add classCode field that QrScannerPage expects
  final String classCode;

  SessionModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
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
    this.isOpen = false, // Changed name to match QrScannerPage
    this.qrCode,
    this.attendanceStatus = const {},
    String? classCode, // Add classCode parameter
  }) : classCode =
           classCode ?? courseCode; // Default to courseCode if not provided

  // ===== Convenience getters =====
  Duration get duration => endTime.difference(startTime);

  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  Duration? get timeUntilStart {
    final now = DateTime.now();
    if (now.isBefore(startTime)) return startTime.difference(now);
    return null;
  }

  double get attendancePercentage {
    if (totalStudents == 0) return 0.0;
    return (attendedStudents / totalStudents) * 100;
  }

  // Add convenience getter for backward compatibility
  bool get isAttendanceOpen => isOpen;

  // ===== Serialize =====
  Map<String, dynamic> toMap() {
    return {
      'courseCode': courseCode,
      'classCode': classCode, // Add classCode to Firestore
      'courseName': courseName,
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
      'isOpen': isOpen, // Use isOpen to match QrScannerPage expectations
      'qrCode': qrCode,
      'attendanceStatus': attendanceStatus,
    };
  }

  // ===== Deserialize =====
  factory SessionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime _ts(dynamic v, {required DateTime fallback}) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return fallback;
    }

    // Support both 'isOpen' (new), 'isAttendanceOpen' (medium), and 'attendanceOpen' (old)
    final bool open =
        (data['isOpen'] as bool?) ??
        (data['isAttendanceOpen'] as bool?) ??
        (data['attendanceOpen'] as bool?) ??
        false;

    // Get classCode, fallback to courseCode if not found
    final String classCodeValue =
        (data['classCode'] ?? data['courseCode'] ?? '').toString();

    return SessionModel(
      id: doc.id,
      courseCode: (data['courseCode'] ?? '').toString(),
      classCode: classCodeValue,
      courseName: (data['courseName'] ?? '').toString(),
      lecturerId: (data['lecturerId'] ?? '').toString(),
      lecturerName: (data['lecturerName'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      description: (data['description'] as String?),
      startTime: _ts(data['startTime'], fallback: DateTime.now()),
      endTime: _ts(data['endTime'], fallback: DateTime.now()),
      location: (data['location'] ?? '').toString(),
      type: SessionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => SessionType.lecture,
      ),
      status: SessionStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => SessionStatus.scheduled,
      ),
      createdAt: _ts(data['createdAt'], fallback: DateTime.now()),
      updatedAt: data['updatedAt'] != null
          ? _ts(data['updatedAt'], fallback: DateTime.now())
          : null,
      totalStudents: (data['totalStudents'] ?? 0) as int,
      attendedStudents: (data['attendedStudents'] ?? 0) as int,
      isOpen: open, // Use isOpen
      qrCode: data['qrCode'] as String?,
      attendanceStatus: Map<String, String>.from(
        data['attendanceStatus'] ?? const {},
      ),
    );
  }

  // ===== CopyWith =====
  SessionModel copyWith({
    String? id,
    String? courseCode,
    String? classCode,
    String? courseName,
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
    bool? isOpen, // Changed from isAttendanceOpen
    String? qrCode,
    Map<String, String>? attendanceStatus,
  }) {
    return SessionModel(
      id: id ?? this.id,
      courseCode: courseCode ?? this.courseCode,
      classCode: classCode ?? this.classCode,
      courseName: courseName ?? this.courseName,
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
      isOpen: isOpen ?? this.isOpen, // Changed from isAttendanceOpen
      qrCode: qrCode ?? this.qrCode,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
    );
  }

  factory SessionModel.empty() {
    final now = DateTime.now();
    return SessionModel(
      id: '',
      courseCode: '',
      classCode: '',
      courseName: '',
      lecturerId: '',
      lecturerName: '',
      title: '',
      description: null,
      startTime: now,
      endTime: now.add(const Duration(hours: 1)),
      location: '',
      type: SessionType.lecture,
      status: SessionStatus.scheduled,
      createdAt: now,
      updatedAt: null,
      totalStudents: 0,
      attendedStudents: 0,
      isOpen: false,
      qrCode: null,
      attendanceStatus: const {},
    );
  }
}

// ===== UI helpers =====
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

  // String get statusDisplayName {
  //   switch (status) {
  //     case SessionStatus.scheduled:
  //       return 'Đã lên lịch';
  //     case SessionStatus.inProgress:
  //       return 'Đang diễn ra';
  //     case SessionStatus.completed:
  //       return 'Đã kết thúc';
  //     case SessionStatus.cancelled:
  //       return 'Đã hủy';
  //   }
  // }

  String get statusDisplayName {
    final now = DateTime.now(); // Lấy thời gian hiện tại

    switch (status) {
      case SessionStatus.scheduled:
        // Cải tiến: Nếu đã qua giờ kết thúc mà vẫn là "scheduled" -> đã lỡ
        if (endTime.isBefore(now)) {
          return 'Đã qua';
        }
        return 'Đã lên lịch';

      case SessionStatus.inProgress:
        // === FIX LỖI TẠI ĐÂY ===
        // Nếu trạng thái là "đang diễn ra" NHƯNG giờ kết thúc đã qua -> hiển thị là "Đã kết thúc"
        if (endTime.isBefore(now)) {
          return 'Đã kết thúc';
        }
        return 'Đang diễn ra';

      case SessionStatus.completed:
        return 'Đã kết thúc';

      case SessionStatus.cancelled:
        return 'Đã hủy';
    }
  }

  String get timeRangeString {
    final hh = (int h, int m) =>
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    return '${hh(startTime.hour, startTime.minute)} - ${hh(endTime.hour, endTime.minute)}';
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
    final wd = weekdays[startTime.weekday];
    final d =
        '${startTime.day.toString().padLeft(2, '0')}/${startTime.month.toString().padLeft(2, '0')}';
    return '$wd, $d';
  }
}
