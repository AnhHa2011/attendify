// lib/features/student/data/models/student_session_detail.dart

class StudentSessionDetail {
  final String sessionId;
  final String sesionName;
  final String courseName;
  final String lecturerName;
  final DateTime startTime;
  final DateTime endTime;
  final String room;
  final String attendanceStatus; // 'present', 'absent', 'leave_approved'
  final DateTime? attendanceTime;
  final String? leaveReason;

  const StudentSessionDetail({
    required this.sessionId,
    required this.sesionName,
    required this.courseName,
    required this.lecturerName,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.attendanceStatus,
    this.attendanceTime,
    this.leaveReason,
  });

  bool get isPresent => attendanceStatus == 'present';
  bool get isAbsent => attendanceStatus == 'absent';
  bool get hasLeaveApproved => attendanceStatus == 'leave_approved';

  String get statusText {
    switch (attendanceStatus) {
      case 'present':
        return 'Có mặt';
      case 'absent':
        return 'Vắng mặt';
      case 'leave_approved':
        return 'Nghỉ phép';
      default:
        return 'Không xác định';
    }
  }

  factory StudentSessionDetail.fromMap(Map<String, dynamic> map) {
    return StudentSessionDetail(
      sessionId: map['sessionId'] ?? '',
      courseName: map['courseName'] ?? '',
      sesionName: map['sesionName'] ?? '',
      lecturerName: map['lecturerName'] ?? '',
      startTime: (map['startTime'] as DateTime?) ?? DateTime.now(),
      endTime: (map['endTime'] as DateTime?) ?? DateTime.now(),
      room: map['room'] ?? '',
      attendanceStatus: map['attendanceStatus'] ?? 'absent',
      attendanceTime: map['attendanceTime'] as DateTime?,
      leaveReason: map['leaveReason'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'courseName': courseName,
      'sesionName': sesionName,
      'lecturerName': lecturerName,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
      'attendanceStatus': attendanceStatus,
      'attendanceTime': attendanceTime,
      'leaveReason': leaveReason,
    };
  }
}
