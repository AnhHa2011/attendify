import 'package:cloud_firestore/cloud_firestore.dart';

enum LeaveStatus { pending, approved, rejected }

class LeaveRequestModel {
  final String id;
  final String studentUid;
  final String studentName;
  final String studentEmail;

  final String classId;
  final String
  sessionId; // có thể để '' nếu xin nghỉ theo ngày không gắn session

  final String reason;
  final List<String> attachmentUrls; // ảnh chứng minh (Storage URLs)
  final LeaveStatus status;

  final DateTime createdAt;

  LeaveRequestModel({
    required this.id,
    required this.studentUid,
    required this.studentName,
    required this.studentEmail,
    required this.classId,
    required this.sessionId,
    required this.reason,
    required this.attachmentUrls,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'studentUid': studentUid,
    'studentName': studentName,
    'studentEmail': studentEmail,
    'classId': classId,
    'sessionId': sessionId,
    'reason': reason,
    'attachmentUrls': attachmentUrls,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  static LeaveRequestModel fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LeaveRequestModel(
      id: doc.id,
      studentUid: d['studentUid'] ?? '',
      studentName: d['studentName'] ?? '',
      studentEmail: d['studentEmail'] ?? '',
      classId: d['classId'] ?? '',
      sessionId: d['sessionId'] ?? '',
      reason: d['reason'] ?? '',
      attachmentUrls:
          (d['attachmentUrls'] as List?)?.cast<String>() ?? const [],
      status: _parseStatus(d['status']),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static LeaveStatus _parseStatus(dynamic v) {
    final s = (v ?? '').toString();
    return LeaveStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => LeaveStatus.pending,
    );
  }
}
