import '../../../app_imports.dart';

class AttendanceModel {
  final String attendanceId;
  final String sessionId;
  final String studentId;
  final String status; // present, absent
  final DateTime timestamp;

  AttendanceModel({
    required this.attendanceId,
    required this.sessionId,
    required this.studentId,
    required this.status,
    required this.timestamp,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      attendanceId: map['attendanceId'],
      sessionId: map['sessionId'],
      studentId: map['studentId'],
      status: map['status'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
  factory AttendanceModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      attendanceId: doc.id,
      studentId: data['studentId'] ?? '',
      sessionId: data['sessionId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'absent',
    );
  }

  /// Factory để tạo instance rỗng (dùng khi không tìm thấy bản ghi)
  factory AttendanceModel.empty() {
    return AttendanceModel(
      attendanceId: '',
      sessionId: '',
      studentId: '',
      status: 'absent',
      timestamp: DateTime.now(),
    );
  }
}
