import '../../../../app_imports.dart';

class LeaveRequestModel {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String classId;
  final String className;
  final String courseId;
  final String courseName;
  final String sessionId;
  final DateTime sessionDate;
  final String reason;
  final String status; // pending, approved, rejected
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  LeaveRequestModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.classId,
    required this.className,
    required this.courseId,
    required this.courseName,
    required this.sessionId,
    required this.sessionDate,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  // Convert from Firestore document
  factory LeaveRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return LeaveRequestModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentEmail: data['studentEmail'] ?? '',
      classId: data['classId'] ?? '',
      className: data['className'] ?? '',
      courseId: data['courseId'] ?? '',
      courseName: data['courseName'] ?? '',
      sessionId: data['sessionId'] ?? '',
      sessionDate:
          (data['sessionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'],
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'classId': classId,
      'className': className,
      'courseId': courseId,
      'courseName': courseName,
      'sessionId': sessionId,
      'sessionDate': Timestamp.fromDate(sessionDate),
      'reason': reason,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
    };
  }

  // Create a copy with updated fields
  LeaveRequestModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? studentEmail,
    String? classId,
    String? className,
    String? courseId,
    String? courseName,
    String? sessionId,
    DateTime? sessionDate,
    String? reason,
    String? status,
    DateTime? createdAt,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return LeaveRequestModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      sessionId: sessionId ?? this.sessionId,
      sessionDate: sessionDate ?? this.sessionDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
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
        other.classId == classId &&
        other.className == className &&
        other.courseId == courseId &&
        other.courseName == courseName &&
        other.sessionId == sessionId &&
        other.sessionDate == sessionDate &&
        other.reason == reason &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.reviewedAt == reviewedAt &&
        other.reviewedBy == reviewedBy;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        studentId.hashCode ^
        studentName.hashCode ^
        studentEmail.hashCode ^
        classId.hashCode ^
        className.hashCode ^
        courseId.hashCode ^
        courseName.hashCode ^
        sessionId.hashCode ^
        sessionDate.hashCode ^
        reason.hashCode ^
        status.hashCode ^
        createdAt.hashCode ^
        reviewedAt.hashCode ^
        reviewedBy.hashCode;
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
