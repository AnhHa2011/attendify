// lib/features/common/data/models/leave_request_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum LeaveRequestStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

enum LeaveRequestType {
  sick,
  personal,
  family,
  emergency,
  other,
}

extension LeaveRequestStatusExtension on LeaveRequestStatus {
  String get displayName {
    switch (this) {
      case LeaveRequestStatus.pending:
        return 'Chờ duyệt';
      case LeaveRequestStatus.approved:
        return 'Đã duyệt';
      case LeaveRequestStatus.rejected:
        return 'Từ chối';
      case LeaveRequestStatus.cancelled:
        return 'Đã hủy';
    }
  }

  Color get color {
    switch (this) {
      case LeaveRequestStatus.pending:
        return const Color(0xFFF59E0B); // Orange
      case LeaveRequestStatus.approved:
        return const Color(0xFF10B981); // Green
      case LeaveRequestStatus.rejected:
        return const Color(0xFFEF4444); // Red
      case LeaveRequestStatus.cancelled:
        return const Color(0xFF6B7280); // Gray
    }
  }

  IconData get icon {
    switch (this) {
      case LeaveRequestStatus.pending:
        return Icons.schedule_rounded;
      case LeaveRequestStatus.approved:
        return Icons.check_circle_rounded;
      case LeaveRequestStatus.rejected:
        return Icons.cancel_rounded;
      case LeaveRequestStatus.cancelled:
        return Icons.block_rounded;
    }
  }
}

extension LeaveRequestTypeExtension on LeaveRequestType {
  String get displayName {
    switch (this) {
      case LeaveRequestType.sick:
        return 'Ốm đau';
      case LeaveRequestType.personal:
        return 'Việc cá nhân';
      case LeaveRequestType.family:
        return 'Gia đình';
      case LeaveRequestType.emergency:
        return 'Khẩn cấp';
      case LeaveRequestType.other:
        return 'Khác';
    }
  }

  IconData get icon {
    switch (this) {
      case LeaveRequestType.sick:
        return Icons.local_hospital_rounded;
      case LeaveRequestType.personal:
        return Icons.person_rounded;
      case LeaveRequestType.family:
        return Icons.family_restroom_rounded;
      case LeaveRequestType.emergency:
        return Icons.emergency_rounded;
      case LeaveRequestType.other:
        return Icons.help_outline_rounded;
    }
  }
}

class LeaveRequestModel {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  
  // Context - either courseId OR classId (or both)
  final String? courseId;
  final String? courseName;
  final String? classId;
  final String? className;
  
  // Session information
  final String? sessionId;
  final String sessionTitle;
  final DateTime sessionDate;
  
  // Request details
  final LeaveRequestType type;
  final String reason;
  final LeaveRequestStatus status;
  final DateTime requestDate;
  final DateTime? reviewDate;
  
  // Reviewer information
  final String? reviewerId; // Lecturer/Admin who reviewed
  final String? reviewerName;
  final String? reviewNote;
  
  // Supporting documents (optional)
  final List<String> attachments;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  LeaveRequestModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    this.courseId,
    this.courseName,
    this.classId,
    this.className,
    this.sessionId,
    required this.sessionTitle,
    required this.sessionDate,
    required this.type,
    required this.reason,
    required this.status,
    required this.requestDate,
    this.reviewDate,
    this.reviewerId,
    this.reviewerName,
    this.reviewNote,
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory LeaveRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return LeaveRequestModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentEmail: data['studentEmail'] ?? '',
      courseId: data['courseId'],
      courseName: data['courseName'],
      classId: data['classId'],
      className: data['className'],
      sessionId: data['sessionId'],
      sessionTitle: data['sessionTitle'] ?? '',
      sessionDate: (data['sessionDate'] as Timestamp).toDate(),
      type: LeaveRequestType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => LeaveRequestType.other,
      ),
      reason: data['reason'] ?? '',
      status: LeaveRequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => LeaveRequestStatus.pending,
      ),
      requestDate: (data['requestDate'] as Timestamp).toDate(),
      reviewDate: data['reviewDate'] != null
          ? (data['reviewDate'] as Timestamp).toDate()
          : null,
      reviewerId: data['reviewerId'],
      reviewerName: data['reviewerName'],
      reviewNote: data['reviewNote'],
      attachments: List<String>.from(data['attachments'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'courseId': courseId,
      'courseName': courseName,
      'classId': classId,
      'className': className,
      'sessionId': sessionId,
      'sessionTitle': sessionTitle,
      'sessionDate': Timestamp.fromDate(sessionDate),
      'type': type.name,
      'reason': reason,
      'status': status.name,
      'requestDate': Timestamp.fromDate(requestDate),
      'reviewDate': reviewDate != null ? Timestamp.fromDate(reviewDate!) : null,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewNote': reviewNote,
      'attachments': attachments,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  LeaveRequestModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? studentEmail,
    String? courseId,
    String? courseName,
    String? classId,
    String? className,
    String? sessionId,
    String? sessionTitle,
    DateTime? sessionDate,
    LeaveRequestType? type,
    String? reason,
    LeaveRequestStatus? status,
    DateTime? requestDate,
    DateTime? reviewDate,
    String? reviewerId,
    String? reviewerName,
    String? reviewNote,
    List<String>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeaveRequestModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      sessionId: sessionId ?? this.sessionId,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      sessionDate: sessionDate ?? this.sessionDate,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      requestDate: requestDate ?? this.requestDate,
      reviewDate: reviewDate ?? this.reviewDate,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewNote: reviewNote ?? this.reviewNote,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // Helper methods
  bool get isPending => status == LeaveRequestStatus.pending;
  bool get isApproved => status == LeaveRequestStatus.approved;
  bool get isRejected => status == LeaveRequestStatus.rejected;
  bool get isCancelled => status == LeaveRequestStatus.cancelled;
  bool get isReviewed => reviewDate != null;
  
  String get contextInfo {
    if (courseName != null && className != null) {
      return '$courseName - $className';
    } else if (courseName != null) {
      return courseName!;
    } else if (className != null) {
      return className!;
    }
    return 'Không xác định';
  }

  Duration get timeSinceRequest => DateTime.now().difference(requestDate);
  
  String get timeSinceRequestString {
    final duration = timeSinceRequest;
    if (duration.inDays > 0) {
      return '${duration.inDays} ngày trước';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} giờ trước';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }

  String get sessionDateString {
    return '${sessionDate.day}/${sessionDate.month}/${sessionDate.year}';
  }

  String get sessionTimeString {
    return '${sessionDate.hour.toString().padLeft(2, '0')}:${sessionDate.minute.toString().padLeft(2, '0')}';
  }

  bool get isUpcoming => sessionDate.isAfter(DateTime.now());
  bool get isPast => sessionDate.isBefore(DateTime.now());
}

// Extension for List<LeaveRequestModel>
extension LeaveRequestListExtension on List<LeaveRequestModel> {
  List<LeaveRequestModel> get pending => 
      where((request) => request.isPending).toList();
  
  List<LeaveRequestModel> get approved => 
      where((request) => request.isApproved).toList();
  
  List<LeaveRequestModel> get rejected => 
      where((request) => request.isRejected).toList();

  List<LeaveRequestModel> forCourse(String courseId) =>
      where((request) => request.courseId == courseId).toList();

  List<LeaveRequestModel> forClass(String classId) =>
      where((request) => request.classId == classId).toList();

  List<LeaveRequestModel> forStudent(String studentId) =>
      where((request) => request.studentId == studentId).toList();

  List<LeaveRequestModel> sortByDate({bool descending = true}) {
    final sorted = List<LeaveRequestModel>.from(this);
    sorted.sort((a, b) => descending 
        ? b.requestDate.compareTo(a.requestDate)
        : a.requestDate.compareTo(b.requestDate));
    return sorted;
  }

  Map<LeaveRequestStatus, int> get statusCounts {
    final counts = <LeaveRequestStatus, int>{};
    for (final request in this) {
      counts[request.status] = (counts[request.status] ?? 0) + 1;
    }
    return counts;
  }
}
