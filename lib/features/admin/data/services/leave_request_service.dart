// lib/features/admin/data/services/leave_request_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../common/data/models/leave_request_model.dart';
import '../../../common/data/models/user_model.dart';
import '../../../common/data/models/session_model.dart';

class LeaveRequestService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===============================
  // ADMIN FUNCTIONS
  // ===============================

  /// Lấy tất cả đơn xin nghỉ (cho Admin)
  Stream<List<LeaveRequestModel>> getAllLeaveRequestsStream() {
    return _db
        .collection('leave_requests')
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LeaveRequestModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Lấy đơn xin nghỉ theo trạng thái
  Stream<List<LeaveRequestModel>> getLeaveRequestsByStatusStream(
    LeaveRequestStatus status,
  ) {
    return _db
        .collection('leave_requests')
        .where('status', isEqualTo: status.name)
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LeaveRequestModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Lấy đơn xin nghỉ theo courseId
  Stream<List<LeaveRequestModel>> getLeaveRequestsForCourseStream(
    String courseId,
  ) {
    return _db
        .collection('leave_requests')
        .where('courseId', isEqualTo: courseId)
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LeaveRequestModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Lấy đơn xin nghỉ theo classId
  Stream<List<LeaveRequestModel>> getLeaveRequestsForClassStream(
    String classId,
  ) {
    return _db
        .collection('leave_requests')
        .where('classId', isEqualTo: classId)
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LeaveRequestModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Lấy đơn xin nghỉ của một sinh viên cụ thể
  Stream<List<LeaveRequestModel>> getLeaveRequestsForStudentStream(
    String studentId,
  ) {
    return _db
        .collection('leave_requests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LeaveRequestModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Duyệt đơn xin nghỉ
  Future<void> approveLeaveRequest({
    required String requestId,
    required String reviewerId,
    required String reviewerName,
    String? reviewNote,
  }) async {
    await _db.collection('leave_requests').doc(requestId).update({
      'status': LeaveRequestStatus.approved.name,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewNote': reviewNote,
      'reviewDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Từ chối đơn xin nghỉ
  Future<void> rejectLeaveRequest({
    required String requestId,
    required String reviewerId,
    required String reviewerName,
    String? reviewNote,
  }) async {
    await _db.collection('leave_requests').doc(requestId).update({
      'status': LeaveRequestStatus.rejected.name,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewNote': reviewNote,
      'reviewDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Hủy đơn xin nghỉ
  Future<void> cancelLeaveRequest(String requestId) async {
    await _db.collection('leave_requests').doc(requestId).update({
      'status': LeaveRequestStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Lấy thống kê đơn xin nghỉ
  Future<Map<String, int>> getLeaveRequestStats({
    String? courseId,
    String? classId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query query = _db.collection('leave_requests');

    if (courseId != null) {
      query = query.where('courseId', isEqualTo: courseId);
    }

    if (classId != null) {
      query = query.where('classId', isEqualTo: classId);
    }

    if (startDate != null) {
      query = query.where(
        'requestDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'requestDate',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snapshot = await query.get();
    final requests = snapshot.docs
        .map((doc) => LeaveRequestModel.fromFirestore(doc))
        .toList();

    return {
      'total': requests.length,
      'pending': requests
          .where((r) => r.status == LeaveRequestStatus.pending)
          .length,
      'approved': requests
          .where((r) => r.status == LeaveRequestStatus.approved)
          .length,
      'rejected': requests
          .where((r) => r.status == LeaveRequestStatus.rejected)
          .length,
      'cancelled': requests
          .where((r) => r.status == LeaveRequestStatus.cancelled)
          .length,
    };
  }

  // ===============================
  // STUDENT FUNCTIONS
  // ===============================

  /// Tạo đơn xin nghỉ mới (dành cho sinh viên)
  Future<String> createLeaveRequest({
    required String studentId,
    required String studentName,
    required String studentEmail,
    String? courseId,
    String? courseName,
    String? classId,
    String? className,
    String? sessionId,
    required String sessionTitle,
    required DateTime sessionDate,
    required LeaveRequestType type,
    required String reason,
    List<String> attachments = const [],
  }) async {
    final now = DateTime.now();

    final leaveRequest = {
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
      'status': LeaveRequestStatus.pending.name,
      'requestDate': Timestamp.fromDate(now),
      'attachments': attachments,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _db.collection('leave_requests').add(leaveRequest);
    return docRef.id;
  }

  /// Cập nhật đơn xin nghỉ (chỉ khi status = pending)
  Future<void> updateLeaveRequest({
    required String requestId,
    String? reason,
    LeaveRequestType? type,
    List<String>? attachments,
  }) async {
    // Kiểm tra trạng thái trước khi cập nhật
    final doc = await _db.collection('leave_requests').doc(requestId).get();
    if (!doc.exists) {
      throw Exception('Đơn xin nghỉ không tồn tại');
    }

    final request = LeaveRequestModel.fromFirestore(doc);
    if (request.status != LeaveRequestStatus.pending) {
      throw Exception('Chỉ có thể chỉnh sửa đơn xin nghỉ đang chờ duyệt');
    }

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (reason != null) updates['reason'] = reason;
    if (type != null) updates['type'] = type.name;
    if (attachments != null) updates['attachments'] = attachments;

    await _db.collection('leave_requests').doc(requestId).update(updates);
  }

  /// Hủy đơn xin nghỉ (dành cho sinh viên)
  Future<void> cancelLeaveRequestByStudent(
    String requestId,
    String studentId,
  ) async {
    // Kiểm tra quyền sở hữu
    final doc = await _db.collection('leave_requests').doc(requestId).get();
    if (!doc.exists) {
      throw Exception('Đơn xin nghỉ không tồn tại');
    }

    final request = LeaveRequestModel.fromFirestore(doc);
    if (request.studentId != studentId) {
      throw Exception('Bạn không có quyền hủy đơn này');
    }

    if (request.status != LeaveRequestStatus.pending) {
      throw Exception('Chỉ có thể hủy đơn xin nghỉ đang chờ duyệt');
    }

    await cancelLeaveRequest(requestId);
  }

  // ===============================
  // LECTURER FUNCTIONS
  // ===============================

  /// Lấy đơn xin nghỉ cho các lớp/môn học mà giảng viên phụ trách
  Stream<List<LeaveRequestModel>> getLeaveRequestsForLecturerStream(
    String lecturerId,
  ) {
    // Note: This needs to be implemented after establishing relationship
    // between lecturers and their courses/classes
    return Stream.value([]);
  }

  /// Duyệt đơn xin nghỉ (dành cho giảng viên)
  Future<void> reviewLeaveRequestAsLecturer({
    required String requestId,
    required String lecturerId,
    required String lecturerName,
    required bool approve,
    String? reviewNote,
  }) async {
    if (approve) {
      await approveLeaveRequest(
        requestId: requestId,
        reviewerId: lecturerId,
        reviewerName: lecturerName,
        reviewNote: reviewNote,
      );
    } else {
      await rejectLeaveRequest(
        requestId: requestId,
        reviewerId: lecturerId,
        reviewerName: lecturerName,
        reviewNote: reviewNote,
      );
    }
  }

  // ===============================
  // UTILITY FUNCTIONS
  // ===============================

  /// Kiểm tra xem sinh viên đã gửi đơn xin nghỉ cho buổi học này chưa
  Future<bool> hasLeaveRequestForSession({
    required String studentId,
    required String sessionId,
  }) async {
    final snapshot = await _db
        .collection('leave_requests')
        .where('studentId', isEqualTo: studentId)
        .where('sessionId', isEqualTo: sessionId)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Lấy số lượng đơn xin nghỉ pending
  Future<int> getPendingLeaveRequestCount({
    String? courseId,
    String? classId,
  }) async {
    Query query = _db
        .collection('leave_requests')
        .where('status', isEqualTo: LeaveRequestStatus.pending.name);

    if (courseId != null) {
      query = query.where('courseId', isEqualTo: courseId);
    }

    if (classId != null) {
      query = query.where('classId', isEqualTo: classId);
    }

    final snapshot = await query.get();
    return snapshot.docs.length;
  }

  /// Xóa đơn xin nghỉ (chỉ Admin)
  Future<void> deleteLeaveRequest(String requestId) async {
    await _db.collection('leave_requests').doc(requestId).delete();
  }

  /// Lấy lịch sử đơn xin nghỉ cho báo cáo
  Future<List<LeaveRequestModel>> getLeaveRequestHistory({
    String? courseId,
    String? classId,
    String? studentId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    Query query = _db.collection('leave_requests');

    if (courseId != null) {
      query = query.where('courseId', isEqualTo: courseId);
    }

    if (classId != null) {
      query = query.where('classId', isEqualTo: classId);
    }

    if (studentId != null) {
      query = query.where('studentId', isEqualTo: studentId);
    }

    if (startDate != null) {
      query = query.where(
        'requestDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'requestDate',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    query = query.orderBy('requestDate', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => LeaveRequestModel.fromFirestore(doc))
        .toList();
  }

  /// Cập nhật trạng thái hàng loạt (cho Admin)
  Future<void> bulkUpdateLeaveRequestStatus({
    required List<String> requestIds,
    required LeaveRequestStatus newStatus,
    required String reviewerId,
    required String reviewerName,
    String? reviewNote,
  }) async {
    final batch = _db.batch();

    for (final requestId in requestIds) {
      final docRef = _db.collection('leave_requests').doc(requestId);
      batch.update(docRef, {
        'status': newStatus.name,
        'reviewerId': reviewerId,
        'reviewerName': reviewerName,
        'reviewNote': reviewNote,
        'reviewDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Lấy tổng quan thống kê cho dashboard
  Future<Map<String, dynamic>> getDashboardStats() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    // Lấy tất cả request trong tháng hiện tại
    final snapshot = await _db
        .collection('leave_requests')
        .where(
          'requestDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
        .where(
          'requestDate',
          isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth),
        )
        .get();

    final requests = snapshot.docs
        .map((doc) => LeaveRequestModel.fromFirestore(doc))
        .toList();

    // Thống kê theo trạng thái
    final statusStats = <String, int>{};
    for (final status in LeaveRequestStatus.values) {
      statusStats[status.name] = requests
          .where((r) => r.status == status)
          .length;
    }

    // Thống kê theo loại đơn
    final typeStats = <String, int>{};
    for (final type in LeaveRequestType.values) {
      typeStats[type.name] = requests.where((r) => r.type == type).length;
    }

    // Thống kê theo tuần
    final weeklyStats = <String, int>{};
    for (int i = 0; i < 4; i++) {
      final weekStart = startOfMonth.add(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final weekRequests = requests
          .where(
            (r) =>
                r.requestDate.isAfter(
                  weekStart.subtract(const Duration(days: 1)),
                ) &&
                r.requestDate.isBefore(weekEnd.add(const Duration(days: 1))),
          )
          .length;
      weeklyStats['week_${i + 1}'] = weekRequests;
    }

    return {
      'total_this_month': requests.length,
      'pending_count': statusStats[LeaveRequestStatus.pending.name] ?? 0,
      'approved_count': statusStats[LeaveRequestStatus.approved.name] ?? 0,
      'rejected_count': statusStats[LeaveRequestStatus.rejected.name] ?? 0,
      'status_breakdown': statusStats,
      'type_breakdown': typeStats,
      'weekly_stats': weeklyStats,
      'avg_requests_per_day': requests.length / now.day,
    };
  }

  /// Kiểm tra quyền truy cập đơn xin nghỉ
  Future<bool> hasAccessToLeaveRequest(
    String requestId,
    String userId,
    UserRole userRole,
  ) async {
    final doc = await _db.collection('leave_requests').doc(requestId).get();
    if (!doc.exists) return false;

    final request = LeaveRequestModel.fromFirestore(doc);

    switch (userRole) {
      case UserRole.admin:
        return true; // Admin có thể truy cập tất cả
      case UserRole.lecture:
        // Lecturer có thể truy cập nếu là reviewer hoặc phụ trách lớp/môn
        return request.reviewerId == userId; // Simplified, needs more logic
      case UserRole.student:
        return request.studentId == userId; // Student chỉ truy cập đơn của mình
      default:
        return false;
    }
  }

  /// Tạo notification khi có thay đổi trạng thái
  Future<void> _createNotification({
    required String userId,
    required String title,
    required String message,
    String? data,
  }) async {
    // Implementation for notification creation
    // This would integrate with a notification service
    await _db.collection('notifications').add({
      'userId': userId,
      'title': title,
      'message': message,
      'data': data,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Export leave requests to Excel-compatible format
  Future<List<Map<String, dynamic>>> exportLeaveRequestsData({
    String? courseId,
    String? classId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final requests = await getLeaveRequestHistory(
      courseId: courseId,
      classId: classId,
      startDate: startDate,
      endDate: endDate,
    );

    return requests
        .map(
          (request) => {
            'Mã đơn': request.id,
            'Sinh viên': request.studentName,
            'Email': request.studentEmail,
            'Môn học': request.courseName ?? request.className ?? 'N/A',
            'Buổi học': request.sessionTitle,
            'Ngày học': request.sessionDateString,
            'Loại đơn': request.type.displayName,
            'Lý do': request.reason,
            'Trạng thái': request.status.displayName,
            'Ngày gửi': request.requestDate.toIso8601String().split('T')[0],
            'Người duyệt': request.reviewerName ?? '',
            'Ghi chú duyệt': request.reviewNote ?? '',
            'Ngày duyệt':
                request.reviewDate?.toIso8601String().split('T')[0] ?? '',
          },
        )
        .toList();
  }
}

/// Extension methods for LeaveRequestService
extension LeaveRequestServiceExtensions on LeaveRequestService {
  /// Get leave request statistics for a specific period
  Future<Map<String, double>> getLeaveRequestTrends({
    required DateTime startDate,
    required DateTime endDate,
    required String groupBy, // 'day', 'week', 'month'
  }) async {
    final requests = await getLeaveRequestHistory(
      startDate: startDate,
      endDate: endDate,
    );

    final trends = <String, double>{};

    for (final request in requests) {
      String key;
      switch (groupBy) {
        case 'day':
          key = '${request.requestDate.day}/${request.requestDate.month}';
          break;
        case 'week':
          final weekStart = request.requestDate.subtract(
            Duration(days: request.requestDate.weekday - 1),
          );
          key = '${weekStart.day}/${weekStart.month}';
          break;
        case 'month':
          key = '${request.requestDate.month}/${request.requestDate.year}';
          break;
        default:
          key = request.requestDate.toIso8601String().split('T')[0];
      }

      trends[key] = (trends[key] ?? 0) + 1;
    }

    return trends;
  }
}
