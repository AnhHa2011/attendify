import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveRequestModel {
  final String? id;
  final String studentId;
  final String? studentName;
  final String classId;
  final String? className;
  final String? subjectId;
  final String? subjectName;
  final String sessionId;
  final DateTime? sessionDate;
  final String reason;
  final String? attachmentUrl;
  final String status; // pending | approved | rejected
  final String? approverId;
  final String? approverNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  LeaveRequestModel({
    this.id,
    required this.studentId,
    this.studentName,
    required this.classId,
    this.className,
    this.subjectId,
    this.subjectName,
    required this.sessionId,
    this.sessionDate,
    required this.reason,
    this.attachmentUrl,
    this.status = 'pending',
    this.approverId,
    this.approverNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'studentName': studentName,
    'classId': classId,
    'className': className,
    'subjectId': subjectId,
    'subjectName': subjectName,
    'sessionId': sessionId,
    'sessionDate': sessionDate != null
        ? Timestamp.fromDate(sessionDate!)
        : null,
    'reason': reason,
    'attachmentUrl': attachmentUrl,
    'status': status,
    'approverId': approverId,
    'approverNote': approverNote,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  }..removeWhere((k, v) => v == null);

  factory LeaveRequestModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LeaveRequestModel(
      id: doc.id,
      studentId: d['studentId'],
      studentName: d['studentName'],
      classId: d['classId'],
      className: d['className'],
      subjectId: d['subjectId'],
      subjectName: d['subjectName'],
      sessionId: d['sessionId'],
      sessionDate: (d['sessionDate'] as Timestamp?)?.toDate(),
      reason: d['reason'] ?? '',
      attachmentUrl: d['attachmentUrl'],
      status: d['status'] ?? 'pending',
      approverId: d['approverId'],
      approverNote: d['approverNote'],
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      updatedAt: (d['updatedAt'] as Timestamp).toDate(),
    );
  }

  LeaveRequestModel copyWith({
    String? id,
    String? status,
    String? approverId,
    String? approverNote,
    String? attachmentUrl,
    DateTime? updatedAt,
  }) {
    return LeaveRequestModel(
      id: id ?? this.id,
      studentId: studentId,
      studentName: studentName,
      classId: classId,
      className: className,
      subjectId: subjectId,
      subjectName: subjectName,
      sessionId: sessionId,
      sessionDate: sessionDate,
      reason: reason,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      status: status ?? this.status,
      approverId: approverId ?? this.approverId,
      approverNote: approverNote ?? this.approverNote,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
