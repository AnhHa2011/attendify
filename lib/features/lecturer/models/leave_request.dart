import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveRequest {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String courseCode;
  final String courseName;
  final String sessionId;
  final String sessionTitle;
  final String reason;
  final String description;
  final DateTime requestDate;
  final DateTime sessionDate;
  final LeaveRequestStatus status;
  final String? lecturerResponse;
  final DateTime? responseDate;
  final List<String> attachments;

  LeaveRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.courseCode,
    required this.courseName,
    required this.sessionId,
    required this.sessionTitle,
    required this.reason,
    this.description = '',
    required this.requestDate,
    required this.sessionDate,
    this.status = LeaveRequestStatus.pending,
    this.lecturerResponse,
    this.responseDate,
    this.attachments = const [],
  });

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    return LeaveRequest(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentEmail: map['studentEmail'] ?? '',
      courseCode: map['courseCode'] ?? '',
      courseName: map['courseName'] ?? '',
      sessionId: map['sessionId'] ?? '',
      sessionTitle: map['sessionTitle'] ?? '',
      reason: map['reason'] ?? '',
      description: map['description'] ?? '',
      requestDate: (map['requestDate'] as Timestamp).toDate(),
      sessionDate: (map['sessionDate'] as Timestamp).toDate(),
      status: LeaveRequestStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => LeaveRequestStatus.pending,
      ),
      lecturerResponse: map['lecturerResponse'],
      responseDate: map['responseDate'] != null
          ? (map['responseDate'] as Timestamp).toDate()
          : null,
      attachments: List<String>.from(map['attachments'] ?? []),
    );
  }

  factory LeaveRequest.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaveRequest.fromMap({...data, 'id': doc.id});
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'courseCode': courseCode,
      'courseName': courseName,
      'sessionId': sessionId,
      'sessionTitle': sessionTitle,
      'reason': reason,
      'description': description,
      'requestDate': Timestamp.fromDate(requestDate),
      'sessionDate': Timestamp.fromDate(sessionDate),
      'status': status.name,
      'lecturerResponse': lecturerResponse,
      'responseDate': responseDate != null
          ? Timestamp.fromDate(responseDate!)
          : null,
      'attachments': attachments,
    };
  }

  LeaveRequest copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? studentEmail,
    String? courseCode,
    String? courseName,
    String? sessionId,
    String? sessionTitle,
    String? reason,
    String? description,
    DateTime? requestDate,
    DateTime? sessionDate,
    LeaveRequestStatus? status,
    String? lecturerResponse,
    DateTime? responseDate,
    List<String>? attachments,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      sessionId: sessionId ?? this.sessionId,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      requestDate: requestDate ?? this.requestDate,
      sessionDate: sessionDate ?? this.sessionDate,
      status: status ?? this.status,
      lecturerResponse: lecturerResponse ?? this.lecturerResponse,
      responseDate: responseDate ?? this.responseDate,
      attachments: attachments ?? this.attachments,
    );
  }

  bool get isPending => status == LeaveRequestStatus.pending;
  bool get isApproved => status == LeaveRequestStatus.approved;
  bool get isRejected => status == LeaveRequestStatus.rejected;

  String get statusText {
    switch (status) {
      case LeaveRequestStatus.pending:
        return 'Đang chờ duyệt';
      case LeaveRequestStatus.approved:
        return 'Đã duyệt';
      case LeaveRequestStatus.rejected:
        return 'Từ chối';
    }
  }

  bool get canRespond {
    return isPending && sessionDate.isAfter(DateTime.now());
  }

  int get daysUntilSession {
    return sessionDate.difference(DateTime.now()).inDays;
  }
}

enum LeaveRequestStatus { pending, approved, rejected }

// Extension for LeaveRequestStatus
extension LeaveRequestStatusExtension on LeaveRequestStatus {
  String get displayName {
    switch (this) {
      case LeaveRequestStatus.pending:
        return 'Đang chờ duyệt';
      case LeaveRequestStatus.approved:
        return 'Đã duyệt';
      case LeaveRequestStatus.rejected:
        return 'Từ chối';
    }
  }

  bool get isPending => this == LeaveRequestStatus.pending;
  bool get isApproved => this == LeaveRequestStatus.approved;
  bool get isRejected => this == LeaveRequestStatus.rejected;
}
