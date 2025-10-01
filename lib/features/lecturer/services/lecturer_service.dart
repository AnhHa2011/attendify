import 'package:attendify/app_imports.dart' hide LeaveRequestStatus;
import '../../../core/data/models/attendance_model.dart';
import '../../../core/data/models/course_model.dart';
import '../../../core/data/models/enrollment_model.dart';
import '../../../core/data/models/leave_request_model.dart';
import '../models/class_session.dart';
import '../models/attendance_record.dart';
import 'notification_service.dart';

class LecturerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Get current lecturer ID
  String? get currentLecturerId => _auth.currentUser?.uid;

  // Initialize notifications
  Future<void> initializeNotifications() async {
    await _notificationService.initialize();
  }

  // Dashboard Statistics
  Future<Map<String, dynamic>> getDashboardStatistics() async {
    try {
      if (currentLecturerId == null) {
        throw Exception('Lecturer not authenticated');
      }

      // Get lecturer's courses
      final coursesSnapshot = await _firestore
          .collection('courses')
          .where('lecturerId', isEqualTo: currentLecturerId)
          .get();

      final courseCodes = coursesSnapshot.docs.map((doc) => doc.id).toList();

      // Get total students across all courses
      int totalStudents = 0;
      for (String courseCode in courseCodes) {
        final enrollmentsSnapshot = await _firestore
            .collection('enrollments')
            .where('courseCode', isEqualTo: courseCode)
            .get();
        totalStudents += enrollmentsSnapshot.docs.length;
      }

      // Get today's sessions
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final todaySessionsSnapshot = await _firestore
          .collection('sessions')
          .where('lecturerId', isEqualTo: currentLecturerId)
          .where('startTime', isGreaterThanOrEqualTo: startOfDay)
          .where('startTime', isLessThanOrEqualTo: endOfDay)
          .get();

      // Get upcoming sessions (next 7 days)
      final nextWeek = now.add(const Duration(days: 7));
      final upcomingSessionsSnapshot = await _firestore
          .collection('sessions')
          .where('lecturerId', isEqualTo: currentLecturerId)
          .where('startTime', isGreaterThan: now)
          .where('startTime', isLessThanOrEqualTo: nextWeek)
          .orderBy('startTime')
          .limit(5)
          .get();

      final upcomingSessions = upcomingSessionsSnapshot.docs
          .map((doc) => ClassSession.fromDocumentSnapshot(doc))
          .toList();

      return {
        'totalCourses': coursesSnapshot.docs.length,
        'totalStudents': totalStudents,
        'todaySessions': todaySessionsSnapshot.docs.length,
        'upcomingSessions': upcomingSessions,
      };
    } catch (e) {
      throw Exception('Error loading dashboard statistics: $e');
    }
  }

  // Get lecturer's courses
  Stream<List<Map<String, dynamic>>> getLecturerCourses() {
    if (currentLecturerId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('courses')
        .where('lecturerId', isEqualTo: currentLecturerId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return {...data, 'id': doc.id};
          }).toList(),
        );
  }

  // Generate new join code for course
  Future<String> generateNewJoinCode(String courseCode) async {
    try {
      final newJoinCode = _generateJoinCode();

      await _firestore.collection('courses').doc(courseCode).update({
        'joinCode': newJoinCode,
        'updatedAt': Timestamp.now().toDate(),
      });

      return newJoinCode;
    } catch (e) {
      throw Exception('Error generating join code: $e');
    }
  }

  // Create new session
  Future<String> createSession(ClassSession session) async {
    try {
      final docRef = await _firestore
          .collection('sessions')
          .add(session.toMap());

      // Schedule notification reminder for this session
      final sessionWithId = session.copyWith(id: docRef.id);
      await _notificationService.scheduleClassReminder(sessionWithId);

      return docRef.id;
    } catch (e) {
      throw Exception('Error creating session: $e');
    }
  }

  // Generate QR code for attendance
  Future<String> generateAttendanceQR(String sessionId) async {
    try {
      final qrCode = _generateQRCode();
      final expiry = DateTime.now().add(const Duration(minutes: 15));

      await _firestore.collection('sessions').doc(sessionId).update({
        'qrCode': qrCode,
        'qrCodeExpiry': expiry,
        'isAttendanceOpen': true,
        'updatedAt': Timestamp.now().toDate(),
      });

      return qrCode;
    } catch (e) {
      throw Exception('Error generating QR code: $e');
    }
  }

  // Close attendance for session
  Future<void> closeAttendance(String sessionId) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'isAttendanceOpen': false,
        'qrCode': null,
        'qrCodeExpiry': null,
        'updatedAt': Timestamp.now().toDate(),
      });
    } catch (e) {
      throw Exception('Error closing attendance: $e');
    }
  }

  // Get session attendance records
  Stream<List<AttendanceRecord>> getSessionAttendance(String sessionId) {
    return _firestore
        .collection('attendances')
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('checkInTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AttendanceRecord.fromDocumentSnapshot(doc))
              .toList(),
        );
  }

  // Get leave requests for lecturer's courses
  Stream<List<LeaveRequestModel>> getLeaveRequests({
    LeaveRequestStatus? status,
  }) {
    if (currentLecturerId == null) {
      return Stream.value([]);
    }

    Query query = _firestore
        .collection('leave_requests')
        .where('lecturerId', isEqualTo: currentLecturerId);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => LeaveRequestModel.fromDoc(doc)).toList(),
    );
  }

  // Respond to leave request
  Future<void> respondToLeaveRequest(
    String requestId,
    LeaveRequestStatus status,
    String? response,
  ) async {
    try {
      await _firestore.collection('leave_requests').doc(requestId).update({
        'status': status.name,
        'reviewedBy': response,
        'responseDate': Timestamp.now().toDate(),
        'reviewedAt': Timestamp.now().toDate(),
        'updatedAt': Timestamp.now().toDate(),
      });
    } catch (e) {
      throw Exception('Error responding to leave request: $e');
    }
  }

  // Helper methods
  String _generateJoinCode() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  String _generateQRCode() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomString = List.generate(
      8,
      (_) => String.fromCharCode(65 + random.nextInt(26)),
    ).join();
    return '$timestamp-$randomString';
  }

  // Get course sessions
  Stream<List<ClassSession>> getCourseSessions(String courseCode) {
    return _firestore
        .collection('sessions')
        .where('courseCode', isEqualTo: courseCode)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ClassSession.fromDocumentSnapshot(doc))
              .toList(),
        );
  }

  // Get course sessions
  Stream<List<CourseModel>> getCourseByLecturer(String lecturerId) {
    return _firestore
        .collection(FirestoreCollections.courses)
        .where('lecturerId', isEqualTo: lecturerId)
        .orderBy('courseName', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => CourseModel.fromDoc(doc)).toList(),
        );
  }

  /// Lấy lịch dạy của giảng viên theo khoảng thời gian (tuỳ chọn).
  /// Trả về Stream<List<ClassSession>> để UI nhận realtime update.
  Stream<List<ClassSession>> getLecturerSchedule({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final lecturerId = currentLecturerId;
    if (lecturerId == null) {
      // Có thể thay bằng Stream.value([]) nếu muốn UI hiển thị rỗng thay vì throw
      throw Exception('Giảng viên chưa đăng nhập');
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('sessions')
        .where('lecturerId', isEqualTo: lecturerId);

    // Lọc theo khoảng thời gian nếu truyền vào
    if (startDate != null) {
      query = query.where(
        'startTime',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      // Dùng < endDate để tránh trùng ngày kế tiếp nếu endDate là cuối tháng
      query = query.where('startTime', isLessThan: Timestamp.fromDate(endDate));
    }

    // Firestore cần orderBy field đã filter range
    query = query.orderBy('startTime');

    return query.snapshots().map((snap) {
      return snap.docs
          .map((doc) => ClassSession.fromDocumentSnapshot(doc))
          .toList();
    });
  }

  Future<List<UserModel>> getAllStudents() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.student)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromDoc(doc)).toList();
  }

  Future<List<SessionModel>> getSessionsForCourse(String courseId) async {
    final snapshot = await _firestore
        .collection('sessions')
        .where('courseCode', isEqualTo: courseId)
        .get();

    return snapshot.docs.map((doc) => SessionModel.fromDoc(doc)).toList();
  }

  // Lấy toàn bộ danh sách sinh viên đăng ký của 1 môn học
  Future<List<EnrollmentModel>> getEnrollmentsByCourse(
    String courseCode,
  ) async {
    final snap = await _firestore
        .collection('enrollments')
        .where('courseCode', isEqualTo: courseCode)
        .get();

    return snap.docs.map((doc) => EnrollmentModel.fromDoc(doc)).toList();
  }

  /// Lấy toàn bộ bản ghi điểm danh của 1 môn học
  Future<List<AttendanceModel>> getAttendancesByCourse(
    String courseCode,
  ) async {
    final snap = await _firestore
        .collection('attendances')
        .where('courseCode', isEqualTo: courseCode)
        .get();

    return snap.docs.map((doc) => AttendanceModel.fromDoc(doc)).toList();
  }

  /// Lấy toàn bộ đơn xin nghỉ của 1 môn học
  Future<List<LeaveRequestModel>> getLeaveRequestsByCourse(
    String courseCode,
  ) async {
    final snap = await _firestore
        .collection('leaveRequests')
        .where('courseCode', isEqualTo: courseCode)
        .get();

    return snap.docs.map((doc) => LeaveRequestModel.fromDoc(doc)).toList();
  }
}
