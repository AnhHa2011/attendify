import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id;
  final String sessionId;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final DateTime checkInTime;
  final String? location;
  final double? latitude;
  final double? longitude;
  final bool isPresent;
  final String? note;
  final DateTime createdAt;

  AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.checkInTime,
    this.location,
    this.latitude,
    this.longitude,
    this.isPresent = true,
    this.note,
    required this.createdAt,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] ?? '',
      sessionId: map['sessionId'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentEmail: map['studentEmail'] ?? '',
      checkInTime: (map['checkInTime'] as Timestamp).toDate(),
      location: map['location'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      isPresent: map['isPresent'] ?? true,
      note: map['note'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  factory AttendanceRecord.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceRecord.fromMap({...data, 'id': doc.id});
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'checkInTime': Timestamp.fromDate(checkInTime),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'isPresent': isPresent,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AttendanceRecord copyWith({
    String? id,
    String? sessionId,
    String? studentId,
    String? studentName,
    String? studentEmail,
    DateTime? checkInTime,
    String? location,
    double? latitude,
    double? longitude,
    bool? isPresent,
    String? note,
    DateTime? createdAt,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      checkInTime: checkInTime ?? this.checkInTime,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isPresent: isPresent ?? this.isPresent,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get statusText => isPresent ? 'Có mặt' : 'Vắng mặt';

  bool get isLate {
    // This would need session start time to determine if late
    // For now, returning false
    return false;
  }
}

// Statistics model for attendance
class AttendanceStatistics {
  final int totalSessions;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final double attendanceRate;

  AttendanceStatistics({
    required this.totalSessions,
    required this.presentCount,
    required this.absentCount,
    this.lateCount = 0,
  }) : attendanceRate = totalSessions > 0 ? (presentCount / totalSessions) * 100 : 0.0;

  factory AttendanceStatistics.fromList(List<AttendanceRecord> records) {
    final present = records.where((r) => r.isPresent).length;
    final absent = records.where((r) => !r.isPresent).length;
    final late = records.where((r) => r.isLate).length;
    
    return AttendanceStatistics(
      totalSessions: records.length,
      presentCount: present,
      absentCount: absent,
      lateCount: late,
    );
  }

  String get attendanceRateString => '${attendanceRate.toStringAsFixed(1)}%';
}
