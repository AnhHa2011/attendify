import '../../../../app_imports.dart';

class LeaveRequestModel {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String lecturerId;
  final String classCode;
  final String className;
  final String courseCode;
  final String courseName;
  final String sessionId;
  final DateTime sessionDate;
  final String reason;
  final String status; // pending, approved, rejected
  final DateTime createdAt;
  final DateTime requestDate;
  final DateTime updatedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? approverNote;

  LeaveRequestModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.lecturerId,
    required this.classCode,
    required this.className,
    required this.courseCode,
    required this.courseName,
    required this.sessionId,
    required this.sessionDate,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.requestDate,
    this.reviewedAt,
    this.reviewedBy,
    this.approverNote,
  });

  // Convert from Firestore document
  factory LeaveRequestModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return LeaveRequestModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      lecturerId: data['studentName'] ?? '',
      studentEmail: data['studentEmail'] ?? '',
      classCode: data['classCode'] ?? '',
      className: data['className'] ?? '',
      courseCode: data['courseCode'] ?? '',
      courseName: data['courseName'] ?? '',
      sessionId: data['sessionId'] ?? '',
      sessionDate:
          (data['sessionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      requestDate:
          (data['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'],
      approverNote: data['approverNote'],
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'classCode': classCode,
      'className': className,
      'courseCode': courseCode,
      'courseName': courseName,
      'sessionId': sessionId,
      'sessionDate': Timestamp.fromDate(sessionDate),
      'reason': reason,
      'status': status,
      'requestDate': Timestamp.fromDate(requestDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
      'approverNote': approverNote,
    };
  }

  // Create a copy with updated fields
  LeaveRequestModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? studentEmail,
    String? lecturerId,
    String? classCode,
    String? className,
    String? courseCode,
    String? courseName,
    String? sessionId,
    DateTime? sessionDate,
    String? reason,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? requestDate,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? approverNote,
  }) {
    return LeaveRequestModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      lecturerId: lecturerId ?? this.lecturerId,
      classCode: classCode ?? this.classCode,
      className: className ?? this.className,
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      sessionId: sessionId ?? this.sessionId,
      sessionDate: sessionDate ?? this.sessionDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      approverNote: approverNote ?? this.approverNote,
      requestDate: requestDate ?? this.requestDate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LeaveRequestModel &&
        other.id == id &&
        other.studentId == studentId &&
        other.studentName == studentName &&
        other.studentEmail == studentEmail &&
        other.classCode == classCode &&
        other.className == className &&
        other.courseCode == courseCode &&
        other.courseName == courseName &&
        other.sessionId == sessionId &&
        other.sessionDate == sessionDate &&
        other.reason == reason &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.reviewedAt == reviewedAt &&
        other.reviewedBy == reviewedBy &&
        other.requestDate == requestDate &&
        other.approverNote == approverNote;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        studentId.hashCode ^
        studentName.hashCode ^
        studentEmail.hashCode ^
        classCode.hashCode ^
        className.hashCode ^
        courseCode.hashCode ^
        courseName.hashCode ^
        sessionId.hashCode ^
        sessionDate.hashCode ^
        reason.hashCode ^
        status.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        reviewedAt.hashCode ^
        reviewedBy.hashCode ^
        approverNote.hashCode;
  }

  @override
  String toString() {
    return 'LeaveRequestModel(id: $id, studentName: $studentName, className: $className, courseName: $courseName, status: $status, reason: $reason)';
  }

  // Helper methods for status checking
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  // Helper method to get status display text
  String get statusDisplayText {
    switch (status) {
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Từ chối';
      case 'pending':
      default:
        return 'Đang chờ';
    }
  }
}
