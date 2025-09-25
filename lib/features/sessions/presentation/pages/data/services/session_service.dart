import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../common/data/models/session_model.dart';
import '../../../../../common/data/models/user_model.dart';

class SessionService {
  final _db = FirebaseFirestore.instance;

  // Tạo buổi học mới
  Future<String> createSession({
    required String classId,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    required SessionType type,
  }) async {
    final now = DateTime.now();

    final ref = await _db.collection('sessions').add({
      'classId': classId,
      // === CÁC TRƯỜNG BỊ LOẠI BỎ ===
      'title': title,
      'description': description,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'location': location,
      'type': type.name,
      'status': SessionStatus.scheduled.name,
      'createdAt': Timestamp.fromDate(now),
      'isAttendanceOpen': false,
    });

    return ref.id;
  }

  /// Lấy danh sách các buổi học ĐÃ ĐƯỢC LÊN LỊCH (chưa bắt đầu) của một lớp
  Stream<List<SessionModel>> getScheduledSessionsForClass(String classId) {
    return _db
        .collection('sessions')
        .where('classId', isEqualTo: classId)
        .where('status', isEqualTo: SessionStatus.scheduled.name)
        .orderBy('startTime')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SessionModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Kích hoạt điểm danh VÀ đặt thời gian tự động đóng sau 2 giờ
  Future<void> startAttendanceForSession(String sessionId) async {
    final autoCloseTime = DateTime.now().add(const Duration(hours: 2));

    await _db.collection('sessions').doc(sessionId).update({
      'status': SessionStatus.inProgress.name,
      'actualStartTime': FieldValue.serverTimestamp(),
      'attendanceOpen': true,
      // THÊM MỚI: Ghi lại thời gian hết hạn
      'attendanceAutoCloseTime': Timestamp.fromDate(autoCloseTime),
    });
  }

  /// Bao gồm các buổi 'scheduled' và 'inProgress' tính đến cuối ngày hôm nay.
  Stream<List<SessionModel>> getAttendableSessionsForClass(String classId) {
    final now = DateTime.now();
    // Tạo mốc thời gian là cuối ngày hôm nay (23:59:59)
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _db
        .collection('sessions')
        .where('classId', isEqualTo: classId)
        // Chỉ lấy các buổi có trạng thái 'scheduled' hoặc 'inProgress'
        .where(
          'status',
          whereIn: [
            SessionStatus.scheduled.name,
            SessionStatus.inProgress.name,
          ],
        )
        // Chỉ lấy các buổi có thời gian bắt đầu từ quá khứ cho đến hết ngày hôm nay
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy(
          'startTime',
          descending: true,
        ) // Hiển thị buổi gần nhất lên đầu
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SessionModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Lắng nghe thay đổi của MỘT buổi học cụ thể
  Stream<SessionModel> getSessionStream(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => SessionModel.fromFirestore(doc));
  }

  /// Bật hoặc tắt điểm danh cho một buổi học (Dành cho Giảng viên)
  Future<void> toggleAttendance(String sessionId, bool isOpen) {
    return _db.collection('sessions').doc(sessionId).update({
      'attendanceOpen': isOpen,
    });
  }

  /// Ghi nhận điểm danh cho sinh viên (Khi SV quét mã QR)
  /// Ghi nhận điểm danh cho sinh viên (Khi SV quét mã QR)
  Future<void> markAttendance({
    required String sessionId,
    required String studentId,
  }) async {
    final sessionRef = _db.collection('sessions').doc(sessionId);
    final sessionDoc = await sessionRef.get();

    if (!sessionDoc.exists) {
      throw Exception('Buổi học không tồn tại.');
    }

    final sessionData = sessionDoc.data()!;
    final isAttendanceOpen = sessionData['attendanceOpen'] ?? false;
    if (!isAttendanceOpen) {
      throw Exception('Giảng viên chưa mở hoặc đã đóng điểm danh.');
    }

    // THÊM MỚI: KIỂM TRA THỜI GIAN HẾT HẠN
    final autoCloseTimestamp =
        sessionData['attendanceAutoCloseTime'] as Timestamp?;
    if (autoCloseTimestamp != null &&
        DateTime.now().isAfter(autoCloseTimestamp.toDate())) {
      // Nếu đã quá giờ, tự động đóng điểm danh trên server và báo lỗi
      await sessionRef.update({'attendanceOpen': false});
      throw Exception('Đã hết thời gian điểm danh cho buổi học này.');
    }

    if (!sessionDoc.exists) {
      throw Exception('Buổi học không tồn tại.');
    }

    final attendeeRef = sessionRef.collection('attendees').doc(studentId);
    final attendeeDoc = await attendeeRef.get();

    if (attendeeDoc.exists) {
      throw Exception('Bạn đã điểm danh cho buổi học này rồi.');
    }

    await attendeeRef.set({
      'studentId': studentId,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'present',
    });
  }

  /// Thêm điểm danh thủ công (Dành cho Giảng viên)
  Future<void> addManualAttendance({
    required String sessionId,
    required String studentId,
  }) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('attendees')
        .doc(studentId)
        .set({
          'studentId': studentId,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'present',
        });
  }

  /// Lấy danh sách sinh viên đã điểm danh (đã "làm giàu")
  Stream<List<Map<String, dynamic>>> getRichAttendanceList(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('attendees')
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) return [];

          final studentIds = snapshot.docs.map((doc) => doc.id).toList();
          final userDocs = await _db
              .collection('users')
              .where(FieldPath.documentId, whereIn: studentIds)
              .get();
          final userMap = {
            for (var doc in userDocs.docs) doc.id: UserModel.fromFirestore(doc),
          };

          return snapshot.docs.map((doc) {
            final student = userMap[doc.id];
            return {
              'studentId': doc.id,
              'displayName': student?.displayName ?? 'N/A',
              'email': student?.email ?? 'N/A',
              'timestamp': doc.data()['timestamp'],
              'status': doc.data()['status'],
            };
          }).toList();
        });
  }

  /// Cập nhật trạng thái điểm danh của một sinh viên
  Future<void> updateAttendanceStatus({
    required String sessionId,
    required String studentId,
    required String newStatus, // Ví dụ: 'present', 'late', 'excused'
  }) {
    final attendeeRef = _db
        .collection('sessions')
        .doc(sessionId)
        .collection('attendees')
        .doc(studentId);

    // Dùng .set() với merge: true
    // - Nếu sinh viên chưa điểm danh (document chưa tồn tại), nó sẽ TẠO MỚI.
    // - Nếu sinh viên đã điểm danh (document đã tồn tại), nó sẽ CẬP NHẬT.
    return attendeeRef.set({
      'status': newStatus,
      // Thêm các trường này để đảm bảo dữ liệu nhất quán khi tạo mới
      'studentId': studentId,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); // SetOptions(merge: true) rất quan trọng!
  }

  /// === NÂNG CẤP: Lấy danh sách TẤT CẢ sinh viên trong lớp (bao gồm cả trạng thái điểm danh) ===
  Stream<List<Map<String, dynamic>>> getFullStudentListWithStatus({
    required String sessionId,
    required String classId,
  }) {
    // 1. Lắng nghe danh sách sinh viên ĐÃ điểm danh
    final attendeesStream = _db
        .collection('sessions')
        .doc(sessionId)
        .collection('attendees')
        .snapshots();

    // 2. Lấy danh sách TẤT CẢ sinh viên trong lớp (chỉ 1 lần)
    final allStudentsFuture = _db
        .collection('enrollments')
        .where('classId', isEqualTo: classId)
        .get()
        .then((snapshot) async {
          if (snapshot.docs.isEmpty) return <UserModel>[];
          final studentIds = snapshot.docs
              .map((doc) => doc['studentUid'] as String)
              .toList();
          if (studentIds.isEmpty) return <UserModel>[]; // Thêm kiểm tra này
          final studentsSnapshot = await _db
              .collection('users')
              .where(FieldPath.documentId, whereIn: studentIds)
              .get();
          return studentsSnapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();
        });

    // 3. Kết hợp 2 nguồn dữ liệu
    return attendeesStream.asyncMap((attendeesSnapshot) async {
      final allStudents = await allStudentsFuture;
      final attendedMap = {
        for (var doc in attendeesSnapshot.docs) doc.id: doc.data(),
      };

      final fullList = allStudents.map((student) {
        final attendanceData = attendedMap[student.uid];
        return {
          'uid': student.uid,
          'displayName': student.displayName,
          'email': student.email,
          'status': attendanceData?['status'] ?? 'absent',
          'timestamp': attendanceData?['timestamp'],
        };
      }).toList();

      fullList.sort((a, b) {
        if (a['status'] != 'absent' && b['status'] == 'absent') return -1;
        if (a['status'] == 'absent' && b['status'] != 'absent') return 1;
        return (a['displayName'] as String).compareTo(
          b['displayName'] as String,
        );
      });

      return fullList;
    });
  }

  // Lấy tất cả buổi học
  Stream<List<SessionModel>> allSessions() {
    return _db
        .collection('sessions')
        .orderBy('startTime', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SessionModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Lấy danh sách sinh viên đã điểm danh cho một buổi học cụ thể
  Stream<List<Map<String, dynamic>>> getAttendanceList(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('attendances')
        .orderBy(
          'attendTime',
          descending: false,
        ) // Sắp xếp theo thời gian điểm danh
        .snapshots()
        .map((snapshot) {
          // Lấy dữ liệu từ mỗi document điểm danh
          return snapshot.docs.map((doc) {
            final data = doc.data();
            // THÊM THÔNG TIN CỦA SINH VIÊN VÀO ĐÂY (SẼ LÀM Ở BƯỚC NÂNG CẤP)
            // Hiện tại, chúng ta chỉ lấy dữ liệu gốc
            return data;
          }).toList();
        });
  }

  // Lấy buổi học của giảng viên
  Stream<List<SessionModel>> sessionsOfLecturer(String lecturerId) {
    return _db
        .collection('sessions')
        .where('lecturerId', isEqualTo: lecturerId)
        .orderBy('startTime', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SessionModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Lấy buổi học của lớp
  Stream<List<SessionModel>> sessionsOfClass(String classId) {
    return _db
        .collection('sessions')
        .where('classId', isEqualTo: classId)
        .orderBy('startTime', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SessionModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Lấy buổi học của sinh viên (từ các lớp đã đăng ký)
  Stream<List<SessionModel>> sessionsOfStudent(String studentUid) {
    // Lấy danh sách classId mà sinh viên đã đăng ký
    return _db
        .collection('enrollments')
        .where('studentUid', isEqualTo: studentUid)
        .snapshots()
        .asyncMap((enrollmentSnapshot) async {
          if (enrollmentSnapshot.docs.isEmpty) return <SessionModel>[];

          final classIds = enrollmentSnapshot.docs
              .map((doc) => doc.data()['classId'] as String)
              .toList();

          // Lấy sessions của các lớp đó
          final sessionSnapshot = await _db
              .collection('sessions')
              .where('classId', whereIn: classIds)
              .orderBy('startTime', descending: false)
              .get();

          return sessionSnapshot.docs
              .map((doc) => SessionModel.fromFirestore(doc))
              .toList();
        });
  }

  // Lấy buổi học tiếp theo của user (lecturer hoặc student)
  Future<SessionModel?> getNextSession(
    String userId, {
    bool isLecturer = false,
  }) async {
    final now = DateTime.now();

    Query query;
    if (isLecturer) {
      query = _db
          .collection('sessions')
          .where('lecturerId', isEqualTo: userId)
          .where('startTime', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('startTime', descending: false)
          .limit(1);
    } else {
      // Cho student, cần lấy từ enrollments trước
      final enrollmentSnapshot = await _db
          .collection('enrollments')
          .where('studentUid', isEqualTo: userId)
          .get();

      if (enrollmentSnapshot.docs.isEmpty) return null;

      final classIds = enrollmentSnapshot.docs
          .map((doc) => doc.data()['classId'] as String)
          .toList();

      if (classIds.isEmpty) return null;

      query = _db
          .collection('sessions')
          .where('classId', whereIn: classIds)
          .where('startTime', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('startTime', descending: false)
          .limit(1);
    }

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return null;

    return SessionModel.fromFirestore(
      snapshot.docs.first as DocumentSnapshot<Map<String, dynamic>>,
    );
  }

  // Lấy buổi học hôm nay
  Stream<List<SessionModel>> getTodaySessions(
    String userId, {
    bool isLecturer = false,
  }) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    if (isLecturer) {
      return _db
          .collection('sessions')
          .where('lecturerId', isEqualTo: userId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('startTime', descending: false)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => SessionModel.fromFirestore(doc))
                .toList(),
          );
    } else {
      // Cho student
      return _db
          .collection('enrollments')
          .where('studentUid', isEqualTo: userId)
          .snapshots()
          .asyncMap((enrollmentSnapshot) async {
            if (enrollmentSnapshot.docs.isEmpty) return <SessionModel>[];

            final classIds = enrollmentSnapshot.docs
                .map((doc) => doc.data()['classId'] as String)
                .toList();

            if (classIds.isEmpty) return <SessionModel>[];

            final sessionSnapshot = await _db
                .collection('sessions')
                .where('classId', whereIn: classIds)
                .where(
                  'startTime',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
                )
                .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
                .orderBy('startTime', descending: false)
                .get();

            return sessionSnapshot.docs
                .map((doc) => SessionModel.fromFirestore(doc))
                .toList();
          });
    }
  }

  // Lấy thời khóa biểu tuần
  Stream<List<SessionModel>> getWeeklySchedule(
    String userId,
    DateTime weekStart, {
    bool isLecturer = false,
  }) {
    final weekEnd = weekStart.add(const Duration(days: 7));

    if (isLecturer) {
      return _db
          .collection('sessions')
          .where('lecturerId', isEqualTo: userId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
          )
          .where('startTime', isLessThan: Timestamp.fromDate(weekEnd))
          .orderBy('startTime', descending: false)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => SessionModel.fromFirestore(doc))
                .toList(),
          );
    } else {
      return _db
          .collection('enrollments')
          .where('studentUid', isEqualTo: userId)
          .snapshots()
          .asyncMap((enrollmentSnapshot) async {
            if (enrollmentSnapshot.docs.isEmpty) return <SessionModel>[];

            final classIds = enrollmentSnapshot.docs
                .map((doc) => doc.data()['classId'] as String)
                .toList();

            if (classIds.isEmpty) return <SessionModel>[];

            final sessionSnapshot = await _db
                .collection('sessions')
                .where('classId', whereIn: classIds)
                .where(
                  'startTime',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
                )
                .where('startTime', isLessThan: Timestamp.fromDate(weekEnd))
                .orderBy('startTime', descending: false)
                .get();

            return sessionSnapshot.docs
                .map((doc) => SessionModel.fromFirestore(doc))
                .toList();
          });
    }
  }

  // Cập nhật trạng thái buổi học
  Future<void> updateSessionStatus(
    String sessionId,
    SessionStatus status,
  ) async {
    await _db.collection('sessions').doc(sessionId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Xóa buổi học
  Future<void> deleteSession(String sessionId) async {
    await _db.collection('sessions').doc(sessionId).delete();
  }

  // Lấy thống kê buổi học
  Future<Map<String, int>> getSessionStats(
    String userId, {
    bool isLecturer = false,
  }) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    Query query;
    if (isLecturer) {
      query = _db
          .collection('sessions')
          .where('lecturerId', isEqualTo: userId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          );
    } else {
      // Cần implement cho student
      return {'total': 0, 'completed': 0, 'upcoming': 0, 'cancelled': 0};
    }

    final snapshot = await query.get();
    final sessions = snapshot.docs
        .map(
          (doc) => SessionModel.fromFirestore(
            doc as DocumentSnapshot<Map<String, dynamic>>,
          ),
        )
        .toList();

    return {
      'total': sessions.length,
      'completed': sessions
          .where((s) => s.status == SessionStatus.completed)
          .length,
      'upcoming': sessions
          .where((s) => s.status == SessionStatus.scheduled)
          .length,
      'cancelled': sessions
          .where((s) => s.status == SessionStatus.cancelled)
          .length,
    };
  }
}
